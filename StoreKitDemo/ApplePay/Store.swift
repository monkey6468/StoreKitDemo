//
//  Store.swift
//  MyRefund
//
//  Created by peak on 2022/1/28.
//

import Foundation
import os
import StoreKit

public enum StoreError: Error {
    case failedVerification
    case noProduct
}

@available(iOS 15.0, *)
class Store: ObservableObject {

    public var stateBlock:((_ state: StoreState, _ transaction: Transaction?)->(Void))! // 状态回调
    
    @Published private(set) var consumableProducts: [Product]
    
    @Published private(set) var purchasedTransaction = Set<Transaction>() // 支付事件监听
    @Published private(set) var historyTransaction: [Transaction] = []
    
    @Published public var isError: Bool = false
    @Published private(set) var errorMessage = ""
    
    @Published public var isRequestingProduct: Bool = false
    
    private var updateListenerTask: Task<Void, Error>?
    
    private let productIdconfig: [String: String]
    
    private let logger: Logger
    var transactionMap: [String: Transaction] // 用于完成Id的缓存map

    static let shared = {
        let instance = Store()
        return instance
    }()

    init() {
        logger = Logger(subsystem: "MyRefund", category: "MyRefund")
        
        if let path = Bundle.main.path(forResource: "Products", ofType: "plist"),
           let plist = FileManager.default.contents(atPath: path)
        {
            productIdconfig = (try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: String]) ?? [:]
        } else {
            productIdconfig = [:]
        }
        
        consumableProducts = []
        transactionMap = [:] // 初始化
        updateListenerTask = listenForTransaction()
        
        log("Store init")
        
        Task {
            // Initialize the store by starting a product request.
            await requestProducts()
        }
        
        Task {
            await updateHistoryTransaction()
        }
    }
    
    public func log(_ message: String) {
//        logger.info("\(message, privacy: .public)")
    }
    
    deinit {
        log("Store deinit")
        updateListenerTask?.cancel()
    }
    
    private func listenForTransaction() -> Task<Void, Error> {
        return Task.detached { [self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await self.updatePurchasedTransaction(transaction)
                    log("purchased2 success finished")
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    @MainActor
    private func updateHistoryTransaction() async {
        do {
            var iterator = Transaction.all.makeAsyncIterator()
            while let result = await iterator.next() {
                let transaction = try checkVerified(result)
                historyTransaction.append(transaction)
            }
        } catch {
            log("Error update history transaction: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isError = true
        }
    }
    
    // MARK: Product Request

    @MainActor
    func requestProducts() async {
        isRequestingProduct = true
        do {
            let storeProducts = try await Product.products(for: productIdconfig.keys)
            if storeProducts.count == 0 {
                errorMessage = "Not found products from apple"
                isError = true
            }
            log("request [\(storeProducts.count)] products")
            
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    log("consumable product: \(product.description)")
                    consumableProducts.append(product)
                case .nonConsumable:
                    log("non consumable product: \(product.description)")
                case .autoRenewable:
                    log("auto renewable product: \(product.description)")
                default:
                    log("Unknown product")
                }
            }
        } catch {
            logger.error("Failed product reqeust: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            isError = true
        }
        isRequestingProduct = false
    }
    
    // MARK: Purchase
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

    func purchase(_ product: Product, orderID: String) async throws -> Transaction? {
        stateBlock?(StoreState.pay, nil)
        log("begin purchase")

        let orderIDConfig = Product.PurchaseOption.appAccountToken(UUID(uuidString: orderID)!)
        let result = try await product.purchase(options: [orderIDConfig])
        
        switch result {
        case .success(let verification):
            log("purchase success, begin verify")
            let transaction = try checkVerified(verification)
            log("check verified success: \(transaction.jsonRepresentation.toString())")
            stateBlock?(StoreState.success, transaction)
//            let receipt = getAppStoreReceipt()
//            log("receipt: \(receipt)")
//            await updatePurchasedTransaction(transaction)
            
            // Always finish a transaction
            log("purchased success finished")
            await transaction.finish()
            
            return transaction
        case .userCancelled:
            stateBlock?(StoreState.userCancelled, nil)
            return nil
        case .pending:
            stateBlock?(StoreState.pending, nil)
            return nil
        default:
            stateBlock?(StoreState.unowned, nil)
            return nil
        }
    }
    
    /// Reference:
    /// https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/validating_receipts_with_the_app_store
    /// In the sandbox environment and in StoreKit Testing in Xcode, the app receipt is present only after the tester makes the first in-app purchase.
    private func getAppStoreReceipt() -> String {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return "no url"
        }
        log("appStoreReceiptURL: \(appStoreReceiptURL)")
        
        guard FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return "file not exist"
        }
        do {
            log("appStoreReceiptURL path: \(appStoreReceiptURL.path)")
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            let receiptString = receiptData.base64EncodedString(options: [])
            log("receipt: \(receiptString)")
            return receiptString
        } catch {
            log("get app store receipt occur error: \(error.localizedDescription)")
        }
        return "error"
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check if the transaction passes StoreKit verfication.
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            // If the transaction is verified, upwrap and return it.
            return safe
        }
    }
    
    @MainActor
    private func updatePurchasedTransaction(_ transaction: Transaction) async {
        if transaction.revocationDate == nil {
            purchasedTransaction.insert(transaction)
        } else {
            purchasedTransaction.remove(transaction)
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
    
    @MainActor
    func uploadServer(for transaction: Transaction) async {
//        let dic: [String: Any] = ["transactionId": transactionId]
        stateBlock?(StoreState.verifiedServer, transaction)
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
    
    
    // MARK: Refund
    
    func refunRequest(for transactionId: UInt64) async -> Bool {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return false
        }
        
        do {
            log("begin refund request: \(transactionId)")
            
            let status = try await Transaction.beginRefundRequest(for: transactionId, in: windowScene)
            
            switch status {
            case .userCancelled:
                log("user cancel")
                return false
            case .success:
                log("success")
                return true
            @unknown default:
                fatalError()
            }
        } catch {
            log("Occur error: \(error.localizedDescription)")
        }
        return false
    }
    
}

public extension Data {
    func toString() -> String { String(decoding: self, as: UTF8.self) }
}
