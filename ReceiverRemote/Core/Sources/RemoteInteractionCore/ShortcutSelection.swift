import Foundation

public enum RemoteShortcut: String, CaseIterable, Identifiable, Sendable {
    case home = "HOME", back = "BACK", mute = "MUTE"
    case volumeUp = "VOLUME_UP", volumeDown = "VOLUME_DOWN"
    case wake = "WAKE", powerMenu = "POWER_MENU", iptv = "OPEN_IPTV_SMARTERS_PRO"
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .home: return "الرئيسية"
        case .back: return "رجوع"
        case .mute: return "كتم الصوت"
        case .volumeUp: return "رفع الصوت"
        case .volumeDown: return "خفض الصوت"
        case .wake: return "إيقاظ"
        case .powerMenu: return "قائمة الطاقة"
        case .iptv: return "IPTV Smarters"
        }
    }
    public var symbol: String {
        switch self {
        case .home: return "house"
        case .back: return "arrow.uturn.backward"
        case .mute: return "speaker.slash"
        case .volumeUp: return "speaker.plus"
        case .volumeDown: return "speaker.minus"
        case .wake: return "sun.max"
        case .powerMenu: return "power"
        case .iptv: return "play.tv"
        }
    }
}

public struct ShortcutSelection: Equatable, Sendable {
    public static let defaults: [RemoteShortcut] = [.home, .mute, .wake]
    public private(set) var actions: [RemoteShortcut]

    public init(storage: String) {
        var unique = [RemoteShortcut]()
        for value in storage.split(separator: ",") {
            guard let action = RemoteShortcut(rawValue: String(value)), !unique.contains(action) else { continue }
            unique.append(action)
            if unique.count == 3 { break }
        }
        for fallback in Self.defaults where unique.count < 3 && !unique.contains(fallback) {
            unique.append(fallback)
        }
        actions = unique
    }

    public var storage: String { actions.map(\.rawValue).joined(separator: ",") }

    public mutating func replace(slot: Int, with action: RemoteShortcut) {
        guard actions.indices.contains(slot) else { return }
        if let existing = actions.firstIndex(of: action) {
            actions.swapAt(slot, existing)
        } else {
            actions[slot] = action
        }
    }
}
