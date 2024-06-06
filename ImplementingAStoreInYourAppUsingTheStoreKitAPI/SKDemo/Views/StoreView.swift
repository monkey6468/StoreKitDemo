/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 The view for the store.
 */

import StoreKit
import SwiftUI

struct StoreView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            Section("消耗型") {
                ForEach(store.fuel) { car in
                    ListCellView(product: car)
                }
            }
            .listStyle(GroupedListStyle())

            Button("Restore Purchases", action: {
                Task {
                    // This call displays a system prompt that asks users to authenticate with their App Store credentials.
                    // Call this function only in response to an explicit user action, such as tapping a button.
                    try? await AppStore.sync()
                }
            })
        }
        .navigationTitle("Shop")
    }
}

struct StoreView_Previews: PreviewProvider {
    @StateObject static var store = Store()

    static var previews: some View {
        StoreView()
            .environmentObject(store)
    }
}
