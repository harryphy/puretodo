//  Pull_to_doApp.swift
//  Pull to do
//
//  Created by PHY on 2023/12/8.
//

import SwiftUI
import UserNotifications

@main
struct Pull_to_doApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var todoDataStore = TodoDataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(todoDataStore)
                .preferredColorScheme(.light)
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            } else if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
}
