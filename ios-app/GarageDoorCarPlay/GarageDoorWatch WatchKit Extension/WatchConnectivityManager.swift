import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var door1Status = "Unknown"
    @Published var door2Status = "Unknown"
    @Published var isConnected = false
    
    private let session = WCSession.default
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Public Methods
    
    func requestStatus() {
        guard session.isReachable else { return }
        
        let message = ["action": "getStatus"]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let door1 = reply["door1"] as? String {
                    self?.door1Status = door1
                }
                if let door2 = reply["door2"] as? String {
                    self?.door2Status = door2
                }
            }
        }) { error in
            print("Error requesting status: \(error.localizedDescription)")
        }
    }
    
    func triggerDoor(_ doorId: Int, completion: @escaping (Bool) -> Void) {
        guard session.isReachable else {
            completion(false)
            return
        }
        
        let message = ["action": "triggerDoor", "doorId": doorId] as [String : Any]
        session.sendMessage(message, replyHandler: { reply in
            let success = reply["success"] as? Bool ?? false
            completion(success)
        }) { error in
            print("Error triggering door: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated && session.isReachable)
        }
        
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let type = message["type"] as? String, type == "statusUpdate" {
                if let doorId = message["doorId"] as? Int, let status = message["status"] as? String {
                    if doorId == 1 {
                        self.door1Status = status
                    } else if doorId == 2 {
                        self.door2Status = status
                    }
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
}