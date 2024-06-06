/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 The store class is responsible for requesting products from the App Store and starting purchases.
 */

import Foundation
import StoreKit

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

// Define our app's subscription tiers by level of service, in ascending order.
public enum SubscriptionTier: Int, Comparable {
    case none = 0
    case standard = 1
    case premium = 2
    case pro = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class Store: ObservableObject {
    @Published private(set) var fuel: [Product]

    @Published private(set) var purchasedCars: [Product] = []
    @Published private(set) var purchasedNonRenewableSubscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?

    var updateListenerTask: Task<Void, Error>?

    private let productIdToEmoji: [String: String]

    init() {
        productIdToEmoji = Store.loadProductIdToEmojiData()

        // Initialize empty products, and then do a product request asynchronously to fill them in.
        fuel = []

        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            // During store initialization, request products from the App Store.
            await requestProducts()

            // Deliver products that the customer purchases.
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    static func loadProductIdToEmojiData() -> [String: String] {
        guard let path = Bundle.main.path(forResource: "Products", ofType: "plist"),
              let plist = FileManager.default.contents(atPath: path),
              let data = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: String]
        else {
            return [:]
        }
        return data
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }

    @MainActor
    func requestProducts() async {
        do {
            // Request products from the App Store using the identifiers that the Products.plist file defines.
            let storeProducts = try await Product.products(for: productIdToEmoji.keys)

            var newFuel: [Product] = []

            // Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    newFuel.append(product)
                case .nonConsumable,
                    .autoRenewable,
                    .nonRenewable:
                    print("product.type\(product.type)")
                default:
                    // Ignore this product.
                    print("Unknown product")
                }
            }

            // Sort each product category by price, lowest to highest, to update the store.
            fuel = sortByPrice(newFuel)
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        // Begin purchasing the `Product` the user selects.
        let uuidString = UUID().uuidString //"367E28C7-CF53-438A-98C3-24DFA11706BF"
        print("------uuid ------: \(uuidString)")
        let orderID = "12345678"
        let uuidConfig = Product.PurchaseOption.appAccountToken(UUID.init(uuidString: uuidString)!)
        let orderIDConfig = Product.PurchaseOption.custom(key: "orderID", value: orderID)

        let result = try await product.purchase(options: [uuidConfig, orderIDConfig])

        switch result {
        case .success(let verification):
            // Check whether the transaction is verified. If it isn't,
            // this function rethrows the verification error.
            let transaction = try checkVerified(verification)

            // 交易已验证。向用户交付内容.
            await updateCustomerProductStatus()

            // Always finish a transaction.
            await transaction.finish()

            print("xwh checkVerified3: \(transaction)")
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }


    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            print("xwh checkVerified2: \(result)")
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            print("xwh checkVerified: \(safe)")
            return safe
        }
    }

    @MainActor
    func updateCustomerProductStatus() async {
        // to do
    }

    func emoji(for productId: String) -> String {
        return productIdToEmoji[productId]!
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { $0.price < $1.price })
    }

    // Get a subscription's level of service using the product ID.
    func tier(for productId: String) -> SubscriptionTier {
        switch productId {
        case "subscription.standard":
            return .standard
        case "subscription.premium":
            return .premium
        case "subscription.pro":
            return .pro
        default:
            return .none
        }
    }
    
    // 退订
//    func refunRequest(for transactionId: UInt64, scene: UIWindowScene) async {
//        do {
//           let ret = try await Transaction.beginRefundRequest(transactionId)
//            print("refunRequest:\(ret)")
//        } catch {
//            print("iap error")
//        }
//    }
    
//    func refunRequest(for transactionId: UInt64) async {
//        if let windowScene = self.view.window?.windowScene {
//        do {
//            let ret = try await StoreKit.Transaction.beginRefundRequest(for: transactionId, in: windowScene)
//            print("refunRequest:\(ret)")
//        } catch {
//            print("iap error")
//        }
//        
//        }
//
////        do {
////            let ret = try await Transaction.beginRefundRequest(for: transactionId, in: scene)
////            print("refunRequest:\(ret)")
////        } catch {
////            print("iap error")
////        }
//    }
//    @objc public final class StoreKitTransaction : NSObject
//    {
//        @objc public static func beginRefundRequest(
//            for transactionId: UInt64,
//            in scene: UIWindowScene) async throws {
//                try await Transaction.beginRefundRequest(for: transactionId, in: scene);
//        }
//    }

}
