//
//  ApplePay2Manger.swift
//  StoreKitDemo
//
//  Created by autophix on 2024/4/2.
//

import StoreKit
import UIKit

@available(iOS 15.0, *)
@objcMembers class ApplePay2Manger: NSObject {
    // 系统会验证是否是一个合法的 Transaction，此时系统不再提供 base64 的 receip string 信息，只需要上传 transaction.id 和 transaction.originalID，服务器端根据需要选择合适的 ID 进行验证。
    public var payClosure: ((_ status: StoreState, _ response: ApplePayResponseV2?) -> ())?

    // 开始进行内购
    func storeKitPay(productId: String, orderID: String) {
        self.storeKitLaunch()
        let store = Store.shared
        Task {
            do {
                if try await store.requestBuyProduct(productId: productId, orderID: orderID) != nil {
                    self.payClosure?(.finish, nil)
                }
            } catch StoreError.failedVerification {
                self.payClosure?(.verifiedFailed, nil)
            } catch StoreError.noProduct {
                self.payClosure?(.noProduct, nil)
            }
        }
    }

    // 请求退款
    func storeKitRefund(Id: String) {
        self.storeKitLaunch()
        let store = Store.shared
        Task {
            let transId = UInt64(Id)
            let ret = await store.refunRequest(for: transId ?? 0)
            self.payClosure?(ret ? .refundSuccess : .refundFailed, nil)
        }
    }

    // 完成事件
    private func storeKitFinish(Id: String) {
        let store = Store.shared
        Task {
            await store.transactionFinish(transaction: Id)
        }
    }

    // 启动自动监听事件
    func storeKitLaunch() {
        let store = Store.shared
        store.stateBlock = { [weak self] (state: StoreState, transaction: Transaction?) in
            guard let _ = transaction else { return
                (self?.payClosure?(state, nil))!
            }
            let response = ApplePayResponseV2()
            response.transactionId = String((transaction?.id)!)
            response.purchaseDate = transaction?.purchaseDate ?? Date()
            response.inAppOwnershipType = String(transaction?.ownershipType.rawValue ?? "")
            self?.payClosure?(state, response)
        }
    }
}
