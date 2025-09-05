//  Helpers.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import Foundation
import SwiftUI
import UserNotifications
import WidgetKit

// 全局函数
func refreshWidget() {
    WidgetCenter.shared.reloadAllTimelines()
}

// 日期格式化
let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

// 触觉反馈工具
struct HapticFeedbackGenerator {
    static func triggerLightFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func triggerMediumFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func triggerHeavyFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    static func triggerSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// 通知权限请求
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

// 日期格式化工具
struct DateFormatterHelper {
    static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    static func weekdaySymbol(for weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = (weekday - 1) % 7
        return symbols[index]
    }
}

// 通知调度工具
struct NotificationHelper {
    static func scheduleNotification(for item: TodoItem) {
        // 移除与此事项相关的所有通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
        
        guard let reminderType = item.reminderType else {
            print("Reminder type is nil for item: \(item.title)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = item.title
        content.sound = .default
        
        var triggers: [UNNotificationTrigger] = []
        
        switch reminderType {
        case .single:
            guard let reminderDate = item.reminderDate else { return }
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            triggers.append(trigger)
            
        case .daily:
            guard let reminderTime = item.reminderTime else { return }
            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            triggers.append(trigger)
            
        case .weekly:
            guard let reminderTime = item.reminderTime, let weekdays = item.reminderWeekdays else { return }
            let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            for weekday in weekdays {
                var dateComponents = DateComponents()
                dateComponents.weekday = weekday
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                triggers.append(trigger)
            }
            
        case .monthly:
            guard let reminderTime = item.reminderTime, let daysOfMonth = item.reminderDaysOfMonth else { return }
            let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            for day in daysOfMonth {
                var dateComponents = DateComponents()
                dateComponents.day = day
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                triggers.append(trigger)
            }
        }
        
        for (index, trigger) in triggers.enumerated() {
            let request = UNNotificationRequest(identifier: "\(item.id.uuidString)_\(index)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding notification: \(error.localizedDescription)")
                } else {
                    print("Notification scheduled for item \(item.title) with identifier \(request.identifier)")
                }
            }
        }
    }
    
    static func cancelReminder(for item: TodoItem) {
        // 移除与此事项相关的所有通知
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(item.id.uuidString) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}

// 自定义虚线形状
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        return path
    }
} 
