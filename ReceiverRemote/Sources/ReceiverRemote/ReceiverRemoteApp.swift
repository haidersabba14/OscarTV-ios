import SwiftUI

@main
struct ReceiverRemoteApp: App {
    @StateObject private var store: RemoteStore

    init() {
        let instance = RemoteStore()
        #if DEBUG
        // Simulator-only capture fixtures never run in the distributed iPhone build.
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--capture-remote") || ProcessInfo.processInfo.arguments.contains("--capture-more") || ProcessInfo.processInfo.arguments.contains("--capture-connection") {
            instance.selected = ReceiverEndpoint(name: "CleanYourTV", host: "192.168.1.10", port: 8765)
            instance.paired = true
            instance.message = "متصل بالرسيفر"
            instance.capabilities = RemoteCapabilities(["navigation": true, "home": true, "back": true, "settings": true, "volume": true, "powerMenu": true])
        }
        if ProcessInfo.processInfo.arguments.contains("--capture-pairing") {
            instance.choose(ReceiverEndpoint(name: "CleanYourTV", host: "192.168.1.10", port: 8765))
        }
        #endif
        #endif
        _store = StateObject(wrappedValue: instance)
    }

    var body: some Scene {
        WindowGroup {
            RemoteHomeView(store: store)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
