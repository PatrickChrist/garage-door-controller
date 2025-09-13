import Foundation
import Network

enum DoorStatus: String, CaseIterable {
    case open = "open"
    case closed = "closed"
    case opening = "opening"
    case closing = "closing"
    case unknown = "unknown"
}

@MainActor
class GarageController: ObservableObject {
    @Published var door1Status: DoorStatus = .unknown
    @Published var door2Status: DoorStatus = .unknown
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private let baseURL: String
    
    init(baseURL: String = "192.168.1.100:8000") {
        self.baseURL = baseURL
        self.urlSession = URLSession(configuration: .default)
    }
    
    func connect() {
        guard let url = URL(string: "ws://\(baseURL)/ws") else {
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
        
        guard let url = URL(string: "http://\(baseURL)/api/trigger/\(doorNumber)") else {
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
        guard let url = URL(string: "http://\(baseURL)/api/status") else {
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
}