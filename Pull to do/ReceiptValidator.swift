//
//  ReceiptValidator.swift
//  Pull to do
//
//  Created by PHY on 2024/11/13.
//

import Foundation
import StoreKit

class ReceiptValidator: NSObject, SKRequestDelegate {

    // 单例实例
    static let shared = ReceiptValidator()

    // 标记用户是否为老用户
    var isOldUser: Bool = false

    // 标记用户是否已购买完整版
    var hasPurchasedFullVersion: Bool = false

    // 收据验证完成后的回调
    var completionHandler: ((Bool, Bool) -> Void)?

    // 当前的收据字符串
    private var currentReceiptString: String?

    // 开始验证收据的方法
    func validateReceipt(completion: ((Bool, Bool) -> Void)? = nil) {
        // 仅在 completion 不为 nil 时设置 self.completionHandler
        if let completion = completion {
            self.completionHandler = completion
        }

        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            // 如果收据 URL 为空，请求刷新收据
            let receiptRefreshRequest = SKReceiptRefreshRequest()
            receiptRefreshRequest.delegate = self
            receiptRefreshRequest.start()
            return
        }

        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL)
            let receiptString = receiptData.base64EncodedString(options: [])
            self.currentReceiptString = receiptString
            // 继续验证收据
            verifyReceiptWithApple(receiptString: receiptString)
        } catch {
            print("无法读取收据数据：\(error.localizedDescription)")
            // 如果无法读取收据数据，请求刷新收据
            let receiptRefreshRequest = SKReceiptRefreshRequest()
            receiptRefreshRequest.delegate = self
            receiptRefreshRequest.start()
        }
    }

    // 发送收据到苹果服务器验证
    private func verifyReceiptWithApple(receiptString: String) {
        // 保存 receiptString，以便在需要时重新验证
        self.currentReceiptString = receiptString

        // 根据构建配置选择验证服务器
        #if DEBUG
        let validationURLString = "https://sandbox.itunes.apple.com/verifyReceipt"
        #else
        let validationURLString = "https://buy.itunes.apple.com/verifyReceipt"
        #endif

        guard let validationURL = URL(string: validationURLString) else { return }

        var request = URLRequest(url: validationURL)
        request.httpMethod = "POST"
        let requestData = ["receipt-data": receiptString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])

        // 发送网络请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("验证请求失败：\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
                return
            }

            do {
                // 解析响应数据
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    self.handleReceiptValidationResponse(jsonResponse, receiptData: receiptString)
                } else {
                    DispatchQueue.main.async {
                        self.completionHandler?(false, false)
                    }
                }
            } catch {
                print("解析验证响应失败：\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
            }
        }
        task.resume()
    }

    // 处理验证响应
    private func handleReceiptValidationResponse(_ response: [String: Any], receiptData: String) {
        if let status = response["status"] as? Int {
            switch status {
            case 0:
                // 验证成功
                if let receipt = response["receipt"] as? [String: Any],
                   let originalPurchaseDateMsString = receipt["original_purchase_date_ms"] as? String,
                   let originalPurchaseDateMs = Double(originalPurchaseDateMsString) {

                    let originalPurchaseDate = Date(timeIntervalSince1970: originalPurchaseDateMs / 1000.0)
                    print("original_purchase_date: \(originalPurchaseDate)")

                    // 判断是否为老用户
                    self.isOldUser = self.isDateBeforeFreeDate(originalPurchaseDate)

                    // 检查 IAP 交易
                    if let inApp = receipt["in_app"] as? [[String: Any]] {
                        self.hasPurchasedFullVersion = self.checkIfPurchasedFullVersion(inAppReceipts: inApp)
                    }

                    DispatchQueue.main.async {
                        // 调用完成回调，并传递用户状态
                        self.completionHandler?(self.isOldUser, self.hasPurchasedFullVersion)
                    }
                } else {
                    print("无法获取 original_purchase_date")
                    DispatchQueue.main.async {
                        self.completionHandler?(false, false)
                    }
                }

            case 21007:
                // 收据是沙盒环境的，但发送到了生产服务器，需要重新发送到沙盒服务器验证
                print("收到状态码 21007，重试沙盒服务器验证")
                self.verifyReceiptInSandbox(receiptString: receiptData)

            default:
                print("收据验证失败，状态码：\(status)")
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
            }
        } else {
            DispatchQueue.main.async {
                self.completionHandler?(false, false)
            }
        }
    }

    // 在沙盒环境重新验证收据
    private func verifyReceiptInSandbox(receiptString: String) {
        let validationURLString = "https://sandbox.itunes.apple.com/verifyReceipt"
        guard let validationURL = URL(string: validationURLString) else { return }

        var request = URLRequest(url: validationURL)
        request.httpMethod = "POST"
        let requestData = ["receipt-data": receiptString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])

        // 发送网络请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("沙盒验证请求失败：\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
                return
            }

            do {
                // 解析响应数据
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    self.handleReceiptValidationResponse(jsonResponse, receiptData: receiptString)
                } else {
                    DispatchQueue.main.async {
                        self.completionHandler?(false, false)
                    }
                }
            } catch {
                print("解析沙盒验证响应失败：\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completionHandler?(false, false)
                }
            }
        }
        task.resume()
    }

    // 判断日期是否在免费版本之前
    private func isDateBeforeFreeDate(_ date: Date) -> Bool {
        // 假设您的应用在 2024 年 11 月 18 日开始免费
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // 使用 UTC
        if let freeDate = dateFormatter.date(from: "2024-11-18") {
            return date.compare(freeDate) == .orderedAscending
        }
        return false
    }

    // 检查用户是否已购买完整版
    private func checkIfPurchasedFullVersion(inAppReceipts: [[String: Any]]) -> Bool {
        // 您的解锁完整版的 IAP 产品标识符
        let fullVersionProductIdentifier = "Puretodounlock"

        for receipt in inAppReceipts {
            if let productID = receipt["product_id"] as? String,
               productID == fullVersionProductIdentifier {
                // 找到了购买记录，用户已购买完整版
                return true
            }
        }
        // 未找到购买记录，用户未购买完整版
        return false
    }

    // MARK: - SKRequestDelegate

    func requestDidFinish(_ request: SKRequest) {
        // 收据刷新成功，尝试再次验证
        print("收据刷新成功")
        // 不传入 completion，保留原始的 completionHandler
        validateReceipt()
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("收据刷新失败：\(error.localizedDescription)")
        DispatchQueue.main.async {
            self.completionHandler?(false, false)
        }
    }
}
