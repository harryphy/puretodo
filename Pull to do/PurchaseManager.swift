//
//  PurchaseManager.swift
//  Pull to do
//
//  Created by PHY on 2024/10/12.
//

import Foundation
import StoreKit

class PurchaseManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    static let shared = PurchaseManager()
    
    var product: SKProduct?
    
    func startPurchase() {
        // 获取产品信息
        let productIdentifiers = Set(["Puretodounlock"]) // 替换为您的产品标识符
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
    }
    
    // 恢复购买
    func restorePurchases() {
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let fullVersionProduct = response.products.first {
            self.product = fullVersionProduct
            // 开始购买
            let payment = SKPayment(product: fullVersionProduct)
            SKPaymentQueue.default().add(self)
            SKPaymentQueue.default().add(payment)
        } else {
            // 未找到产品，处理错误
            print("未找到产品")
        }
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // 购买成功
                SKPaymentQueue.default().finishTransaction(transaction)
                // 解锁全部功能
                self.unlockAllFeatures()
            case .failed:
                // 购买失败
                SKPaymentQueue.default().finishTransaction(transaction)
                if let error = transaction.error as NSError? {
                    print("购买失败：\(error.localizedDescription)")
                }
            case .restored:
                // 恢复购买
                SKPaymentQueue.default().finishTransaction(transaction)
                // 解锁全部功能
                self.unlockAllFeatures()
            default:
                break
            }
        }
    }
    
    // 恢复购买完成
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("恢复购买流程完成")
        // 可以在这里通知用户恢复购买已完成
    }
    
    // 恢复购买失败
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("恢复购买失败：\(error.localizedDescription)")
        // 在这里处理恢复购买失败的情况
    }
    
    func unlockAllFeatures() {
        // 设置标志位
        UserDefaults.standard.set(true, forKey: "isAllFeaturesUnlocked")
        // 通知应用更新状态
        NotificationCenter.default.post(name: NSNotification.Name("FeaturesUnlocked"), object: nil)
    }
}
