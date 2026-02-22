import SwiftUI
import UserNotifications

//
// HTTPPostButtonApp.swift
// Version 0.9
// App entry point for QikPOST - configurable HTTP POST request buttons
//

@main
struct HTTPPostButtonApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Delegate

/// Handles notification permission request and foreground banner display.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        // Register a category with no name — this suppresses the default "Notification" label
        // that iOS shows in the banner header when no category is set.
        let category = UNNotificationCategory(identifier: "COMMAND_SENT", actions: [], intentIdentifiers: [])
        center.setNotificationCategories([category])
        
        return true
    }
    
    /// This delegate method makes iOS show the banner even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
