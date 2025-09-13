import Foundation
import Network
import WatchConnectivity

enum DoorStatus: String, CaseIterable {
    case open = "open"
    case closed = "closed"
    case opening = "opening"
    case closing = "closing"
    case unknown = "unknown"
}

@MainActor
class GarageController: NSObject, ObservableObject, WCSessionDelegate {
    @Published var door1Status: DoorStatus = .unknown
    @Published var door2Status: DoorStatus = .unknown
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private let session = WCSession.default
    private let baseURL: String
    
    init(baseURL: String? = nil) {
        // Determine URL from user preferences
        let useExternal = UserDefaults.standard.bool(forKey: "use_external_access")
        let duckdnsDomain = UserDefaults.standard.string(forKey: "duckdns_domain") ?? ""
        let localURL = UserDefaults.standard.string(forKey: "garage_base_url") ?? "192.168.1.100:8000"
        
        if let providedURL = baseURL {
            self.baseURL = providedURL
        } else if useExternal && !duckdnsDomain.isEmpty {
            self.baseURL = duckdnsDomain
        } else {
            self.baseURL = localURL
        }
        
        self.urlSession = URLSession(configuration: .default)
        super.init()
        setupWatchConnectivity()
    }
    
    func connect() {
        // Use WSS for external DuckDNS domains, WS for local
        let useExternal = UserDefaults.standard.bool(forKey: "use_external_access")
        let protocol = (useExternal && baseURL.contains("duckdns.org")) ? "wss" : "ws"
        
        guard let url = URL(string: "\(protocol)://\(baseURL)/ws") else {
            print("Invalid WebSocket URL")
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        // Start ping timer to keep connection alive
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.sendPing()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                Task { @MainActor in
                    self?.handleMessage(message)
                    self?.receiveMessage() // Continue listening
                }
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                Task { @MainActor in
                    self?.isConnected = false
                    // Attempt to reconnect after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.connect()
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            isConnected = true
            
            if let type = json["type"] as? String {
                switch type {
                case "initial_status":
                    if let doors = json["doors"] as? [String: String] {
                        door1Status = DoorStatus(rawValue: doors["1"] ?? "unknown") ?? .unknown
                        door2Status = DoorStatus(rawValue: doors["2"] ?? "unknown") ?? .unknown
                        updateWatchComplications()
                        sendStatusToWatch()
                    }
                case "status_update":
                    if let doorId = json["door_id"] as? Int,
                       let statusString = json["status"] as? String,
                       let status = DoorStatus(rawValue: statusString) {
                        if doorId == 1 {
                            door1Status = status
                        } else if doorId == 2 {
                            door2Status = status
                        }
                        updateWatchComplications()
                        sendStatusToWatch()
                        
                        // Send notification for significant status changes
                        if status == .open || status == .closed {
                            NotificationManager.shared.scheduleStatusNotification(
                                doorId: doorId,
                                status: status.rawValue
                            )
                        }
                    }
                default:
                    break
                }
            }
        case .data:
            break
        @unknown default:
            break
        }
    }
    
    private func sendPing() {
        webSocketTask?.send(.string("ping")) { error in
            if let error = error {
                print("WebSocket ping error: \(error)")
            }
        }
    }
    
    func triggerDoor(_ doorNumber: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        // Use HTTPS for external DuckDNS domains, HTTP for local
        let useExternal = UserDefaults.standard.bool(forKey: "use_external_access")
        let scheme = (useExternal && baseURL.contains("duckdns.org")) ? "https" : "http"
        
        guard let url = URL(string: "\(scheme)://\(baseURL)/api/trigger/\(doorNumber)") else {
            print("Invalid trigger URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    print("HTTP error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("Network error: \(error)")
        }
    }
    
    func refreshStatus() async {
        // Use HTTPS for external DuckDNS domains, HTTP for local
        let useExternal = UserDefaults.standard.bool(forKey: "use_external_access")
        let scheme = (useExternal && baseURL.contains("duckdns.org")) ? "https" : "http"
        
        guard let url = URL(string: "\(scheme)://\(baseURL)/api/status") else {
            print("Invalid status URL")
            return
        }
        
        do {
            let (data, _) = try await urlSession.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                door1Status = DoorStatus(rawValue: json["1"] ?? "unknown") ?? .unknown
                door2Status = DoorStatus(rawValue: json["2"] ?? "unknown") ?? .unknown
            }
        } catch {
            print("Status refresh error: \(error)")
        }
    }
    
    // MARK: - Watch Connectivity
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    private func updateWatchComplications() {
        // Update complications with current status
        UserDefaults.standard.set(door1Status.rawValue, forKey: "door1Status")
        UserDefaults.standard.set(door2Status.rawValue, forKey: "door2Status")
        
        // Request complication update
        if WCSession.isSupported() && session.isWatchAppInstalled {
            session.transferCurrentComplicationUserInfo([
                "door1Status": door1Status.rawValue,
                "door2Status": door2Status.rawValue,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    private func sendStatusToWatch() {
        guard WCSession.isSupported() && session.isReachable else { return }
        
        let message = [
            "type": "statusUpdate",
            "door1Status": door1Status.rawValue,
            "door2Status": door2Status.rawValue
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending status to watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "getStatus":
                    let reply = [
                        "door1": door1Status.rawValue,
                        "door2": door2Status.rawValue
                    ]
                    replyHandler(reply)
                    
                case "triggerDoor":
                    if let doorId = message["doorId"] as? Int {
                        await triggerDoor(doorId)
                        replyHandler(["success": true])
                    } else {
                        replyHandler(["success": false])
                    }
                    
                default:
                    replyHandler(["error": "Unknown action"])
                }
            } else {
                replyHandler(["error": "No action specified"])
            }
        }
    }
}