//
//  ApplePay2Manger.swift
//  StoreKitDemo
//
//  Created by autophix on 2024/4/2.
//

import UIKit
import StoreKit

@available(iOS 15.0, *)
@objcMembers class ApplePay2Manger: NSObject {
    // 系统会验证是否是一个合法的 Transaction，此时系统不再提供 base64 的 receip string 信息，只需要上传 transaction.id 和 transaction.originalID，服务器端根据需要选择合适的 ID 进行验证。
    public var payClosure:((_ status: StoreState, _ transactionId: String?, _ originalID: String?) -> ())?

    // 开始进行内购
    func storeKitPay(productId: String, orderID: String) {
        let store = Store.shared
        // 启动自动监听事件
        store.stateBlock = { [weak self](state: StoreState, transaction : Transaction?) in
            guard let transactionT = transaction else { return
                (self?.payClosure?(state, nil, nil))!}
            self?.payClosure?(state, String(transactionT.id), String(transactionT.originalID))
        }
        Task {
            do {
                if try await store.requestBuyProduct(productId: productId, orderID: orderID) != nil {
                    self.payClosure?(.success, nil, nil)
                }
            } catch StoreError.failedVerification {
                self.payClosure?(.verifiedFailed, nil, nil)
            } catch StoreError.noProduct {
                self.payClosure?(.noProduct, nil, nil)
            }
        }
    }
    
    // 请求退款
    func storeKitRefund(Id: String) {
//        let store = Store.shared
//        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//            //            if let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
//            Task {
//                let transId = UInt64(Id)
//                await store.refunRequest(for: transId ?? 0, scene: windowScene)
//            }
//            //            }
//        }
    }


    // 完成事件
    private func storeKitFinish(Id: String) {
        let store = Store.shared
        Task {
            await store.transactionFinish(transaction: Id)
        }
    }

}
