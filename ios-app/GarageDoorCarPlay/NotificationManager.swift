import Foundation
import UserNotifications
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleStatusNotification(doorId: Int, status: String) {
        let content = UNMutableNotificationContent()
        content.title = "Garage Door \(doorId)"
        content.body = "Door is now \(status)"
        content.sound = UNNotificationSound.default
        
        // Add custom data
        content.userInfo = [
            "doorId": doorId,
            "status": status,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "garage-door-\(doorId)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleSecurityAlert(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Garage Security Alert"
        content.body = message
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "SECURITY_ALERT"
        
        // Immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "security-alert-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Security alert error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDailyStatusReport() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Garage Report"
        content.body = "Check your garage door status"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "DAILY_REPORT"
        
        // Schedule for 8 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-garage-report",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Daily report error: \(error.localizedDescription)")
            }
        }
    }
    
    func setupNotificationCategories() {
        // Security Alert Actions
        let checkStatusAction = UNNotificationAction(
            identifier: "CHECK_STATUS",
            title: "Check Status",
            options: [.foreground]
        )
        
        let securityCategory = UNNotificationCategory(
            identifier: "SECURITY_ALERT",
            actions: [checkStatusAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Daily Report Actions
        let viewStatusAction = UNNotificationAction(
            identifier: "VIEW_STATUS",
            title: "View Status",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        let dailyReportCategory = UNNotificationCategory(
            identifier: "DAILY_REPORT",
            actions: [viewStatusAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            securityCategory,
            dailyReportCategory
        ])
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "CHECK_STATUS", "VIEW_STATUS":
            // Open app to main view
            if let sceneDelegate = UIApplication.shared.connectedScenes
                .first?.delegate as? SceneDelegate {
                // Navigate to main view
                print("Opening app to check status")
            }
            
        case "DISMISS":
            print("Notification dismissed")
            
        default:
            break
        }
    }
}