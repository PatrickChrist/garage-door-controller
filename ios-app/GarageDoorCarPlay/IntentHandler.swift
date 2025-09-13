import Intents
import Foundation

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is TriggerGarageDoorIntent:
            return TriggerGarageDoorIntentHandler()
        case is GetGarageStatusIntent:
            return GetGarageStatusIntentHandler()
        default:
            fatalError("Unhandled intent type: \(intent)")
        }
    }
}

class TriggerGarageDoorIntentHandler: NSObject, TriggerGarageDoorIntentHandling {
    
    func handle(intent: TriggerGarageDoorIntent, completion: @escaping (TriggerGarageDoorIntentResponse) -> Void) {
        guard let doorNumber = intent.doorNumber?.intValue else {
            completion(TriggerGarageDoorIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Task {
            do {
                // Get base URL from UserDefaults or use default
                let baseURL = UserDefaults.standard.string(forKey: "garage_base_url") ?? "192.168.1.100:8000"
                guard let url = URL(string: "http://\(baseURL)/api/trigger/\(doorNumber)") else {
                    completion(TriggerGarageDoorIntentResponse(code: .failure, userActivity: nil))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let successResponse = TriggerGarageDoorIntentResponse(code: .success, userActivity: nil)
                    completion(successResponse)
                } else {
                    completion(TriggerGarageDoorIntentResponse(code: .failure, userActivity: nil))
                }
                
            } catch {
                print("Intent error: \(error)")
                completion(TriggerGarageDoorIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
    
    func resolveDoorNumber(for intent: TriggerGarageDoorIntent, with completion: @escaping (INIntegerResolutionResult) -> Void) {
        guard let doorNumber = intent.doorNumber?.intValue else {
            completion(.needsValue())
            return
        }
        
        if doorNumber == 1 || doorNumber == 2 {
            completion(.success(with: doorNumber))
        } else {
            completion(.unsupported(forReason: .greaterThanMaximumValue))
        }
    }
    
    func provideDoorNumberOptions(for intent: TriggerGarageDoorIntent, with completion: @escaping ([NSNumber]?, Error?) -> Void) {
        completion([1, 2], nil)
    }
    
    func provideDoorNumberOptionsCollection(for intent: TriggerGarageDoorIntent, with completion: @escaping (INObjectCollection<NSNumber>?, Error?) -> Void) {
        let options = [NSNumber(value: 1), NSNumber(value: 2)]
        let collection = INObjectCollection(items: options)
        completion(collection, nil)
    }
}

class GetGarageStatusIntentHandler: NSObject, GetGarageStatusIntentHandling {
    
    func handle(intent: GetGarageStatusIntent, completion: @escaping (GetGarageStatusIntentResponse) -> Void) {
        Task {
            do {
                // Get base URL from UserDefaults or use default
                let baseURL = UserDefaults.standard.string(forKey: "garage_base_url") ?? "192.168.1.100:8000"
                guard let url = URL(string: "http://\(baseURL)/api/status") else {
                    completion(GetGarageStatusIntentResponse(code: .failure, userActivity: nil))
                    return
                }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                    let door1Status = json["1"] ?? "unknown"
                    let door2Status = json["2"] ?? "unknown"
                    
                    let response = GetGarageStatusIntentResponse(code: .success, userActivity: nil)
                    response.door1Status = door1Status.capitalized
                    response.door2Status = door2Status.capitalized
                    
                    completion(response)
                } else {
                    completion(GetGarageStatusIntentResponse(code: .failure, userActivity: nil))
                }
                
            } catch {
                print("Status intent error: \(error)")
                completion(GetGarageStatusIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}