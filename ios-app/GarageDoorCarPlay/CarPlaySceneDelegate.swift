import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    private var garageController = GarageController()
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Connect to garage controller
        Task { @MainActor in
            garageController.connect()
        }
        
        // Set up the root template
        let rootTemplate = createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true, completion: nil)
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        garageController.disconnect()
    }
    
    private func createRootTemplate() -> CPListTemplate {
        let door1Item = CPListItem(
            text: "Garage Door 1",
            detailText: "Tap to toggle",
            image: UIImage(systemName: "car.garage.closed")
        )
        door1Item.handler = { [weak self] item, completion in
            self?.triggerDoor(1)
            completion()
        }
        
        let door2Item = CPListItem(
            text: "Garage Door 2",
            detailText: "Tap to toggle",
            image: UIImage(systemName: "car.garage.closed")
        )
        door2Item.handler = { [weak self] item, completion in
            self?.triggerDoor(2)
            completion()
        }
        
        let statusItem = CPListItem(
            text: "Refresh Status",
            detailText: "Update door status",
            image: UIImage(systemName: "arrow.clockwise")
        )
        statusItem.handler = { [weak self] item, completion in
            self?.refreshStatus()
            completion()
        }
        
        let section = CPListSection(items: [door1Item, door2Item, statusItem])
        
        let template = CPListTemplate(title: "🏠 Garage Doors", sections: [section])
        template.tabImage = UIImage(systemName: "house.garage")
        template.tabTitle = "Garage"
        
        return template
    }
    
    private func triggerDoor(_ doorNumber: Int) {
        Task {
            await garageController.triggerDoor(doorNumber)
            
            // Show confirmation alert
            await MainActor.run {
                let alert = CPAlertTemplate(
                    titleVariants: ["Door Triggered"],
                    shortTitleVariants: ["Triggered"]
                )
                alert.addAction(CPAlertAction(title: "OK", style: .default) { _ in
                    // Dismiss alert
                })
                
                interfaceController?.presentTemplate(alert, animated: true, completion: nil)
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.interfaceController?.dismissTemplate(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func refreshStatus() {
        Task {
            await garageController.refreshStatus()
            
            await MainActor.run {
                // Update the root template to show current status
                let updatedTemplate = createUpdatedTemplate()
                interfaceController?.setRootTemplate(updatedTemplate, animated: false, completion: nil)
                
                // Show confirmation
                let alert = CPAlertTemplate(
                    titleVariants: ["Status Updated"],
                    shortTitleVariants: ["Updated"]
                )
                alert.addAction(CPAlertAction(title: "OK", style: .default) { _ in })
                
                interfaceController?.presentTemplate(alert, animated: true, completion: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.interfaceController?.dismissTemplate(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func createUpdatedTemplate() -> CPListTemplate {
        let door1Status = garageController.door1Status.rawValue.capitalized
        let door2Status = garageController.door2Status.rawValue.capitalized
        
        let door1Item = CPListItem(
            text: "Garage Door 1",
            detailText: "Status: \(door1Status)",
            image: UIImage(systemName: garageController.door1Status == .open ? "car.garage.open" : "car.garage.closed")
        )
        door1Item.handler = { [weak self] item, completion in
            self?.triggerDoor(1)
            completion()
        }
        
        let door2Item = CPListItem(
            text: "Garage Door 2",
            detailText: "Status: \(door2Status)",
            image: UIImage(systemName: garageController.door2Status == .open ? "car.garage.open" : "car.garage.closed")
        )
        door2Item.handler = { [weak self] item, completion in
            self?.triggerDoor(2)
            completion()
        }
        
        let statusItem = CPListItem(
            text: "Refresh Status",
            detailText: garageController.isConnected ? "Connected" : "Disconnected",
            image: UIImage(systemName: "arrow.clockwise")
        )
        statusItem.handler = { [weak self] item, completion in
            self?.refreshStatus()
            completion()
        }
        
        let section = CPListSection(items: [door1Item, door2Item, statusItem])
        
        let template = CPListTemplate(title: "🏠 Garage Doors", sections: [section])
        template.tabImage = UIImage(systemName: "house.garage")
        template.tabTitle = "Garage"
        
        return template
    }
}