//
//  iosStoreKit2.swift
//  ios_storekit
//
//  Created by iOS on 2023/5/23.
//

import Foundation
import StoreKit

public enum StoreError: Error { // 错误回调枚举
    case failedVerification
    case noProduct
}

@available(iOS 15.0, *)
class Store: ObservableObject {

    public var stateBlock:((_ state: StoreState, _ transaction: Transaction?)->(Void))! // 状态回调
    
    var updateListenerTask: Task<Void, Error>? // 支付事件监听
    
    var transactionMap: [String: Transaction] // 用于完成Id的缓存map
    
    var name: String = "iosStore" // 单例的写法
    static let shared = {
        let instance = Store()
        return instance
    }()

    private init() { // 单例需要保证private的私有性质
        transactionMap = [:] // 初始化
        Task {
            updateListenerTask = listenForTransactions()
        }
    }
    
    // 退订
    func refunRequest(for transactionId: UInt64, scene: UIWindowScene) async {
        do {
           let ret = try await Transaction.beginRefundRequest(for: transactionId, in: scene)
            print("refunRequest:\(ret)")
        } catch {
            print("iap error")
        }
    }
    
    // 购买某个产品
    func requestBuyProduct(productId: String, orderID: String) async throws -> Transaction? {
        stateBlock?(StoreState.start, nil)

        do {
            let list: [String] = [productId]
            let storeProducts = try await Product.products(for: Set(list))
            
            if storeProducts.count > 0 {
                return try await purchase(storeProducts[0], orderID: orderID)
            } else {
                throw StoreError.noProduct // 没有该产品
            }
        } catch {
            throw StoreError.noProduct // 没有该产品
        }
    }
    
    // 购买
    private func purchase(_ product: Product, orderID: String) async throws -> Transaction? {
        stateBlock?(StoreState.pay, nil)
        // E73B723A-DB8D-4FE3-B6F4-B6B95A1D4A78
        let uuidString = UUID().uuidString //"367E28C7-CF53-438A-98C3-24DFA11706BF"
        print("------uuid ------: \(uuidString)")
        let uuid = Product.PurchaseOption.appAccountToken(UUID.init(uuidString: uuidString)!)
        let orderID = Product.PurchaseOption.custom(key: "orderID", value: orderID)
        let result = try await product.purchase(options: [uuid, orderID])
        
        switch result {
        case .success(let verification): // 用户购买完成
            let transaction = try await verifiedAndFinish(verification)
//            print("transaction: \(String(describing: transaction))")
            return transaction
        case .userCancelled: // 用户取消
            stateBlock?(StoreState.userCancelled, nil)
            return nil
        case .pending: // 此次购买被挂起
            stateBlock?(StoreState.pending, nil)
            return nil
        default:
            stateBlock?(StoreState.unowned, nil)
            return nil
        }
    }
    
    // 校验
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            print("iap: verified success")
            return safe
        }
    }
    
    // 校验&完成后传给服务器
    func verifiedAndFinish(_ verification: VerificationResult<Transaction>) async throws -> Transaction? {
        // Check whether the transaction is verified. If it isn't,
        // this function rethrows the verification error.
        let transaction = try checkVerified(verification)
        
        // 这里将订单提交给服务器进行验证 ~~~
        let transactionId = try verification.payloadValue.id
        
        // 添加进入待完成map
        let key = String(transactionId)
        transactionMap[key] = transaction
        await uploadServer(for: transaction)
        
        // 这里不触发完成，等服务器验证再触发完成逻辑
//        await transaction.finish()
        print("iap: finish")
        return transaction
    }
    
    // 事件完成处理
    func transactionFinish(transaction: String) async {
        if transactionMap[transaction] != nil {
            await transactionMap[transaction]!.finish()
            print("transactionFinish end")
        } else {
            print("transaction不存在，参数不正确,Id=\(transaction)")
        }
    }
    
    @MainActor
    func uploadServer(for transaction: Transaction) async {
//        let dic: [String: Any] = ["transactionId": transactionId]
        stateBlock?(StoreState.verifiedServer, transaction)
    }
    
    // 支付监听事件
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            // 修改update 为 unfinished?
            for await result in Transaction.updates { // 会导致二次校验？
                do {
                    print("iap: updates")
                    print("result:\(result)")
                    let transaction = try await self.verifiedAndFinish(result)
                    print("transaction:\(String(describing: transaction))")
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    // 销毁调用
    deinit {
        updateListenerTask?.cancel()
    }
}
