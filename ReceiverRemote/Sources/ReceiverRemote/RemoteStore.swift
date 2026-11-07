import Foundation
import Security
import Combine

struct RemoteCapabilities {
    var navigation = false
    var home = false
    var back = false
    var settings = false
    var powerMenu = false
    var volume = false
    var channels = false
    var powerOn = false

    init(_ values: [String: Any] = [:]) {
        navigation = values["navigation"] as? Bool ?? false
        home = values["home"] as? Bool ?? false
        back = values["back"] as? Bool ?? false
        settings = values["settings"] as? Bool ?? false
        powerMenu = values["powerMenu"] as? Bool ?? false
        volume = values["volume"] as? Bool ?? false
        channels = values["channels"] as? Bool ?? false
        powerOn = values["powerOn"] as? Bool ?? false
    }
}

@MainActor
final class RemoteStore: ObservableObject {
    @Published var discovery = ReceiverDiscovery()
    @Published var selected: ReceiverEndpoint?
    @Published var pairingCode = ""
    @Published var paired = false
    @Published var capabilities = RemoteCapabilities()
    @Published var message = "ابحث عن الرسيفر على شبكة Wi-Fi نفسها"
    @Published var busy = false

    private let defaults = UserDefaults.standard
    private var discoveryCancellable: AnyCancellable?
    private var token = ""

    init() {
        if let host = defaults.string(forKey: "receiver.host"),
           let port = defaults.object(forKey: "receiver.port") as? Int {
            selected = ReceiverEndpoint(name: defaults.string(forKey: "receiver.name") ?? "CleanYourTV",
                                        host: host, port: port)
            token = Keychain.read(account: selected!.id) ?? ""
            paired = !token.isEmpty
            if paired { Task { await refreshCapabilities() } }
        }
        discoveryCancellable = discovery.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func choose(_ endpoint: ReceiverEndpoint) {
        selected = endpoint
        message = "رسيفر متصل بالشبكة؛ أدخل رمز الاقتران الظاهر على الشاشة"
    }

    func pair() async {
        guard let selected, pairingCode.count == 6 else {
            message = "أدخل رمز الاقتران المكوّن من 6 أرقام"
            return
        }
        busy = true
        defer { busy = false }
        do {
            let response = try await request(endpoint: selected, path: "/v1/pair", method: "POST",
                                             body: ["code": pairingCode])
            guard let newToken = response["token"] as? String else {
                message = "رمز الاقتران غير صحيح"
                return
            }
            token = newToken
            Keychain.save(newToken, account: selected.id)
            defaults.set(selected.host, forKey: "receiver.host")
            defaults.set(selected.port, forKey: "receiver.port")
            defaults.set(selected.name, forKey: "receiver.name")
            paired = true
            pairingCode = ""
            capabilities = RemoteCapabilities(response["capabilities"] as? [String: Any] ?? [:])
            message = "تم الاقتران بالرسيفر"
        } catch {
            if let remoteError = error as? RemoteError, case .unauthorized = remoteError {
                message = "رمز الاقتران غير صحيح أو انتهت صلاحيته؛ استخدم الرمز الظاهر على التلفزيون"
            } else {
                message = "تعذر الاقتران؛ تأكد من اتصال الجهازين بالشبكة نفسها"
            }
        }
    }

    func unpair() {
        if let selected { Keychain.delete(account: selected.id) }
        token = ""
        paired = false
        capabilities = RemoteCapabilities()
        message = "تم إلغاء الاقتران"
    }

    func refreshCapabilities() async {
        guard let selected, paired else { return }
        do {
            let response = try await request(endpoint: selected, path: "/v1/info", method: "GET")
            capabilities = RemoteCapabilities(response["capabilities"] as? [String: Any] ?? [:])
            message = "متصل بـ\(response["model"] as? String ?? selected.name)"
        } catch {
            message = "الرسيفر غير متاح الآن"
        }
    }

    func send(_ action: String) async {
        guard paired, let selected, !token.isEmpty else {
            message = "اقرن الآيفون بالرسيفر أولًا"
            return
        }
        do {
            _ = try await request(endpoint: selected, path: "/v1/command", method: "POST",
                                  body: ["action": action], bearer: token)
        } catch RemoteError.unsupported {
            message = "هذه الوظيفة غير مدعومة في نظام الرسيفر الحالي"
        } catch RemoteError.accessibility {
            message = "فعّل Remote Accessibility من إعدادات الرسيفر"
        } catch RemoteError.unauthorized {
            unpair()
            message = "انتهى الاقتران؛ اربط الآيفون من جديد"
        } catch {
            message = "فشل إرسال الأمر؛ تحقق من اتصال Wi-Fi"
        }
    }

    private func request(endpoint: ReceiverEndpoint, path: String, method: String,
                         body: [String: Any]? = nil, bearer: String? = nil) async throws -> [String: Any] {
        var components = URLComponents()
        components.scheme = "http"
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = path
        guard let url = components.url else { throw RemoteError.network }
        var request = URLRequest(url: url, timeoutInterval: 4)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteError.network }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if http.statusCode == 501 { throw RemoteError.unsupported }
        if http.statusCode == 503 { throw RemoteError.accessibility }
        if http.statusCode == 401 { throw RemoteError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw RemoteError.network }
        return json
    }
}

private enum RemoteError: Error { case network, unsupported, accessibility, unauthorized }

private enum Keychain {
    static func save(_ value: String, account: String) {
        delete(account: account)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.gathin.receiverremote",
                                    kSecAttrAccount as String: account,
                                    kSecValueData as String: Data(value.utf8)]
        SecItemAdd(query as CFDictionary, nil)
    }
    static func read(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.gathin.receiverremote",
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.gathin.receiverremote",
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}
