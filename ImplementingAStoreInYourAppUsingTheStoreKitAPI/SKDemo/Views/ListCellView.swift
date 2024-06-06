/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A view for an individual car or subscription product that shows a Buy button when it displays within the store.
 */

import StoreKit
import SwiftUI

struct ListCellView: View {
    @EnvironmentObject var store: Store
    @State var isPurchased: Bool = false
    @State var errorTitle = ""
    @State var isShowingError: Bool = false

    let product: Product

    var emoji: String {
        store.emoji(for: product.id)
    }

    init(product: Product) {
        self.product = product
    }

    var body: some View {
        HStack {
            Text(emoji)
                .font(.system(size: 50))
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .padding(.trailing, 20)
            
            productDetail
            
            Spacer()
            buyButton
                .buttonStyle(BuyButtonStyle(isPurchased: isPurchased))
                .disabled(isPurchased)
        }
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("Okay")))
        })
    }

    @ViewBuilder
    var productDetail: some View {
        if product.type == .autoRenewable {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .bold()
                Text(product.description)
            }
        } else {
            Text(product.description)
                .frame(alignment: .leading)
        }
    }

    var buyButton: some View {
        Button(action: {
            Task {
                await buy()
            }
        }) {
            if isPurchased {
                Text(Image(systemName: "checkmark"))
                    .bold()
                    .foregroundColor(.white)
            } else {
                Text(product.displayPrice)
                    .foregroundColor(.white)
                    .bold()
            }
        }
    }

    func buy() async {
        do {
            if try await store.purchase(product) != nil {
                withAnimation {
                    isPurchased = true
                }
            }
        } catch StoreError.failedVerification {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        } catch {
            print("Failed purchase for \(product.id): \(error)")
        }
    }
}
