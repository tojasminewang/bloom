// BloomApp.swift — app entry: one store, one root.
import SwiftUI

@main
struct BloomApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
