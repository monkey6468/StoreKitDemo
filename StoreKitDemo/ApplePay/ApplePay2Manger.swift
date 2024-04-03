//
//  ApplePay2Manger.swift
//  StoreKitDemo
//
//  Created by autophix on 2024/4/2.
//

import UIKit

@objcMembers class ApplePay2Manger: NSObject {
    
    public var payClosure:((StoreState) -> ())?

    // 开始进行内购
    func storeKitPay(productId: String, orderID: String) {
        let store = Store.shared
        Task {
            do {
                if try await store.requestBuyProduct(productId: productId, orderID: orderID) != nil {
                    self.payClosure?(.success)
                }
            } catch StoreError.failedVerification, StoreError.noProduct {
                self.payClosure?(.noProduct)
            } catch {
                print("Failed fuel purchase: \(error)")
            }
        }
    }
    
    // 请求退款
    func storeKitRefun(Id: String) {
        let store = Store.shared
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            //            if let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
            Task {
                let transId = UInt64(Id)
                await store.refunRequest(for: transId ?? 0, scene: windowScene)
            }
            //            }
        }
    }

    // 启动自动监听事件
    func storeKitLaunch() {
        let store = Store.shared
        store.stateBlock = { [weak self](state: StoreState, _: [String: Any]?) in
            self?.payClosure?(state)
        }
    }

    // 完成事件
    private func storeKitFinish(Id: String) {
        let store = Store.shared
        Task {
            await store.transactionFinish(transaction: Id)
        }
    }

}
