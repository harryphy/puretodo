//  AppDelegate.swift
//  Pull to do
//
//  Created by PHY on 2024/7/9.
//

import UIKit
import UserNotifications
import WidgetKit
import StoreKit // 导入 StoreKit 框架

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self
        // 设置导航栏的背景颜色为白色
        UINavigationBar.appearance().backgroundColor = .white
        UINavigationBar.appearance().barTintColor = .white
        UINavigationBar.appearance().shadowImage = UIImage()
        // 加载数据并刷新小组件
        loadDataAndRefreshWidget()

        // 添加支付队列观察者
        SKPaymentQueue.default().add(PurchaseManager.shared)

        // 调用收据验证
        ReceiptValidator.shared.validateReceipt { isOldUser, hasPurchasedFullVersion in
            DispatchQueue.main.async {
                print("收据验证结果：isOldUser = \(isOldUser), hasPurchasedFullVersion = \(hasPurchasedFullVersion)")
                if isOldUser || hasPurchasedFullVersion {
                    // 老用户或已购买完整版的用户，解锁全部功能
                    self.unlockAllFeatures()
                } else {
                    // 新用户，未购买完整版，按照默认流程
                    self.setupForNewUser()
                }
            }
        }

        return true
    }

    func loadDataAndRefreshWidget() {
        // 通知 WidgetKit 刷新小组件
        WidgetCenter.shared.reloadAllTimelines()
    }

    // 解锁全部功能的方法
    func unlockAllFeatures() {
        // 设置标志位
        UserDefaults.standard.set(true, forKey: "isAllFeaturesUnlocked")
        // 通知应用更新状态
        NotificationCenter.default.post(name: NSNotification.Name("FeaturesUnlocked"), object: nil)
    }

    // 针对新用户的设置
    func setupForNewUser() {
        // 设置标志位
        UserDefaults.standard.set(false, forKey: "isAllFeaturesUnlocked")
        // 通知应用更新状态
        NotificationCenter.default.post(name: NSNotification.Name("FeaturesUnlocked"), object: nil)
    }

    // Handle notification when app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            print("Notification will present in foreground")
            completionHandler([.banner, .sound])
        } else {
            print("Notification will present in foreground (iOS 13 or earlier)")
            completionHandler([.alert, .sound])
        }
    }

    // Handle notification when app is opened from a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Notification received with identifier: \(response.notification.request.identifier)")

        let identifier = response.notification.request.identifier
        // 提取 UUID 部分，忽略后面的索引
        let uuidString = identifier.components(separatedBy: "_").first ?? identifier
        if let todoId = UUID(uuidString: uuidString) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("ShowTodoDetail"), object: todoId)
            }
        }
        completionHandler()
    }
}
