/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A view showing all the user's purchased cars and subscriptions.
 */

import StoreKit
import SwiftUI

struct MyCarsView: View {
    @StateObject var store: Store = .init()

    var body: some View {
        NavigationView {
            VStack {
                Text("SK Demo App")
                    .bold()
                    .font(.system(size: 50))
                    .padding(.bottom, 20)
                Text("🏎💨")
                    .font(.system(size: 120))
                    .padding(.bottom, 20)
                Text("Head over to the shop to get started!")
                    .font(.headline)
                    .padding()
                    .multilineTextAlignment(.center)
                NavigationLink {
                    StoreView()
                } label: {
                    Label("Shop", systemImage: "cart")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 300, height: 50, alignment: .center)
                        .background(Color.blue)
                        .cornerRadius(15.0)
                }
                

                buyButton
                    .buttonStyle(BuyButtonStyle(isPurchased: false))
                    .padding()
                    .disabled(false)

            }
        }
        .environmentObject(store)
    }
    
    var buyButton: some View {
        Button(action: {
            Task {
                await buy()
            }
        }) {
            Text("Refund")
                .foregroundColor(.white)
                .bold()
        }
    }
    
    func buy() async {
//        if try await store.refunRequest(for: 2000000620525653) {
//            
//            
//        }
//
//        print("Failed purchase for ")
//        Store.refunRequest(<#T##self: Store##Store#>)
    }
    
    
}

struct MyCarsView_Previews: PreviewProvider {
    static var previews: some View {
        MyCarsView()
    }
}

extension Date {
    func formattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        return dateFormatter.string(from: self)
    }
}
