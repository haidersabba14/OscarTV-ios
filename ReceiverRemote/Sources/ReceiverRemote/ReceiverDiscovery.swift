import Foundation
import Combine

struct ReceiverEndpoint: Identifiable, Hashable {
    let name: String
    let host: String
    let port: Int
    var id: String { "\(host):\(port)" }
}

final class ReceiverDiscovery: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published private(set) var receivers: [ReceiverEndpoint] = []
    private let browser = NetServiceBrowser()
    private var services: [String: NetService] = [:]

    override init() {
        super.init()
        browser.delegate = self
        browser.searchForServices(ofType: "_ctvremote._tcp.", inDomain: "local.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services[service.name] = service
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeValue(forKey: service.name)
        DispatchQueue.main.async { self.receivers.removeAll { $0.name == service.name } }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty, sender.port > 0 else { return }
        let endpoint = ReceiverEndpoint(name: sender.name, host: host, port: sender.port)
        DispatchQueue.main.async {
            self.receivers.removeAll { $0.id == endpoint.id }
            self.receivers.append(endpoint)
            self.receivers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}
