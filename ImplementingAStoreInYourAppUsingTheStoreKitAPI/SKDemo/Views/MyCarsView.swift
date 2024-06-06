/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view showing all the user's purchased cars and subscriptions.
*/

import SwiftUI
import StoreKit

struct MyCarsView: View {
    @StateObject var store: Store = Store()

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
            }
        }
        .environmentObject(store)
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
