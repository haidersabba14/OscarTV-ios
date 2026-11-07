import SwiftUI
import UIKit
import RemoteInteractionCore

private enum Atelier {
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let ink = Color(red: 0.055, green: 0.065, blue: 0.08)
    static let muted = Color(red: 0.46, green: 0.47, blue: 0.46)
    static let gold = Color(red: 0.83, green: 0.70, blue: 0.46)
    static let paleGold = Color(red: 0.98, green: 0.89, blue: 0.69)
    static let line = Color(red: 0.85, green: 0.83, blue: 0.78)
    static let metal = LinearGradient(colors: [paleGold, gold, Color(red: 0.65, green: 0.50, blue: 0.29)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private enum RemotePage: String, CaseIterable {
    case remote = "التحكم", more = "المزيد", connection = "الاتصال"
    var symbol: String {
        switch self {
        case .remote: return "appletvremote.gen4"
        case .more: return "slider.horizontal.3"
        case .connection: return "wifi"
        }
    }
}

struct RemoteHomeView: View {
    @ObservedObject var store: RemoteStore
    @State private var page: RemotePage = .remote
    @State private var manualHost = ""
    @AppStorage("remote.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("remote.keepAwake.enabled") private var keepAwake = false
    @AppStorage("remote.shortcuts") private var shortcutStorage = "HOME,MUTE,WAKE"
    @State private var editingShortcuts = false
    @State private var choosingShortcut = false
    @State private var shortcutSlot = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    @State private var capturedAction = ""
    @State private var capturedCommandCount = 0
    #endif

    var body: some View {
        ZStack {
            Atelier.paper.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    masthead
                    if store.paired {
                        deviceSummary
                        switch page {
                        case .remote: remoteWorkspace
                        case .more: moreWorkspace
                        case .connection: connectionWorkspace
                        }
                    } else {
                        pairingWorkspace
                    }
                    footer
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { if store.paired { await store.refreshCapabilities() } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.paired { navigationDock }
        }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--ui-test") {
                Text(capturedAction).accessibilityIdentifier("captured-command")
                    .accessibilityValue(String(capturedCommandCount))
                    .font(.system(size: 1)).opacity(0.01).allowsHitTesting(false)
            }
            #endif
            #endif
        }
        .preferredColorScheme(.light)
        .onChange(of: store.paired) { _, _ in
            page = .remote
            updateIdleTimer()
        }
        .onChange(of: keepAwake) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, _ in updateIdleTimer() }
        .onChange(of: page) { _, value in if value != .remote { editingShortcuts = false } }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("اختر الاختصار", isPresented: $choosingShortcut, titleVisibility: .visible) {
            ForEach(RemoteShortcut.allCases.filter(shortcutAvailable)) { shortcut in
                Button(shortcut.title) {
                    var selection = ShortcutSelection(storage: shortcutStorage)
                    selection.replace(slot: shortcutSlot, with: shortcut)
                    shortcutStorage = selection.storage
                    pressFeedback()
                }
            }
            Button("إلغاء", role: .cancel) {}
        }
        .onAppear {
            updateIdleTimer()
            if manualHost.isEmpty {
                manualHost = Bundle.main.object(forInfoDictionaryKey: "ReceiverSuggestedHost") as? String ?? ""
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--capture-more") { page = .more }
            if ProcessInfo.processInfo.arguments.contains("--capture-connection") { page = .connection }
            #endif
        }
    }

    private var masthead: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RECEIVER / REMOTE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2).foregroundStyle(Atelier.muted)
                Text(store.paired ? "التحكّم، على ذوقك." : "اتصال بسيط.\nتحكّم استثنائي.")
                    .font(.system(size: store.paired ? 25 : 31, weight: .semibold))
                    .tracking(-0.7).foregroundStyle(Atelier.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            ZStack {
                RoundedRectangle(cornerRadius: 19).fill(Atelier.ink)
                Image(systemName: "appletvremote.gen4")
                    .font(.system(size: 25, weight: .light)).foregroundStyle(Atelier.metal)
            }
            .frame(width: 54, height: 64)
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
        }
        .padding(.vertical, 9)
    }

    private var deviceSummary: some View {
        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { page = .connection } } label: {
            HStack(spacing: 13) {
                Image(systemName: "tv").font(.system(size: 23, weight: .light))
                    .foregroundStyle(Atelier.ink).frame(width: 46, height: 46)
                    .background(Atelier.paper, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.selected?.name ?? "الرسيفر")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Atelier.ink)
                    Text(store.message).font(.system(size: 11)).foregroundStyle(Atelier.muted)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Circle().fill(connectionColor).frame(width: 7, height: 7)
                Image(systemName: "chevron.forward").font(.system(size: 10, weight: .bold)).foregroundStyle(Atelier.muted)
            }
            .padding(14).paperSurface(radius: 23)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("معلومات الرسيفر والاتصال")
    }

    private var remoteWorkspace: some View {
        VStack(spacing: 18) {
            shortcutBar
            VStack(spacing: 25) {
                HStack {
                    Text("لوحة التحكّم").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text("CONTROL / 01").font(.system(size: 9, design: .monospaced)).tracking(1.3)
                        .foregroundStyle(Atelier.gold)
                }
                DirectionalDial(enabled: store.capabilities.navigation) { send($0) }
                    .frame(maxWidth: 294)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 18) {
                    navigationKey("رجوع", symbol: "arrow.uturn.backward", action: "BACK", enabled: store.capabilities.back)
                    navigationKey("الرئيسية", symbol: "house", action: "HOME", enabled: store.capabilities.home)
                    navigationKey("الإعدادات", symbol: "gearshape", action: "OPEN_IPTV_SMARTERS_PRO", enabled: store.paired)
                }
                Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                volumeStrip
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.17), Atelier.ink, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 38).strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.025), Atelier.gold.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .shadow(color: .black.opacity(0.17), radius: 18, x: 0, y: 12)
            }
            HStack(spacing: 12) {
                featureTile("إيقاظ الرسيفر", detail: "من وضع الاستعداد", symbol: "sun.max", action: "WAKE", enabled: true)
                featureTile("قائمة الطاقة", detail: "خيارات النظام", symbol: "power", action: "POWER_MENU", enabled: store.capabilities.powerMenu)
            }
            Text("قائمة الطاقة تعرض خيارات Android. الإيقاظ يتطلب بقاء الرسيفر متصلًا بالشبكة.")
                .font(.system(size: 11)).foregroundStyle(Atelier.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 8)
        }
    }

    private func navigationKey(_ label: String, symbol: String, action: String, enabled: Bool) -> some View {
        Button { send(action) } label: {
            VStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 20, weight: .light))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(.white.opacity(0.035), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.07)))
                Text(label).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(enabled ? Atelier.paleGold : .white.opacity(0.28))
        }
        .buttonStyle(QuietPressStyle()).disabled(!enabled).accessibilityLabel(label)
    }

    private var volumeStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                soundKey("minus", label: "خفض الصوت", action: "VOLUME_DOWN")
                Spacer(minLength: 3)
                VStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2").font(.system(size: 16, weight: .light))
                    Text("الصوت").font(.system(size: 9))
                }
                .foregroundStyle(.white.opacity(0.55)).accessibilityHidden(true)
                Spacer(minLength: 3)
                soundKey("plus", label: "رفع الصوت", action: "VOLUME_UP")
            }
            .padding(5).background(.white.opacity(0.045), in: Capsule())
            Button { send("MUTE") } label: {
                Image(systemName: "speaker.slash").font(.system(size: 18, weight: .light))
                    .foregroundStyle(store.capabilities.volume ? Atelier.paleGold : .white.opacity(0.28))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.045), in: Circle())
            }
            .buttonStyle(QuietPressStyle()).disabled(!store.capabilities.volume).accessibilityLabel("كتم الصوت")
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func soundKey(_ symbol: String, label: String, action: String) -> some View {
        RepeatingControl(enabled: store.capabilities.volume, label: label,
                         onPress: pressFeedback, action: { await performAction(action) }) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                .foregroundStyle(store.capabilities.volume ? Atelier.paleGold : .white.opacity(0.28))
                .frame(width: 44, height: 44).contentShape(Circle())
        }
        .accessibilityHint("اضغط مطولًا للتكرار")
    }

    private var shortcutBar: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("اختصاراتك", systemImage: "star").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Atelier.ink)
                Spacer()
                Button(editingShortcuts ? "تم" : "تعديل") { editingShortcuts.toggle() }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Atelier.muted)
                    .frame(minWidth: 44, minHeight: 32).accessibilityIdentifier("edit-shortcuts")
            }
            HStack(spacing: 10) {
                ForEach(Array(ShortcutSelection(storage: shortcutStorage).actions.enumerated()), id: \.offset) { index, shortcut in
                    Button {
                        if editingShortcuts {
                            shortcutSlot = index
                            choosingShortcut = true
                        } else { send(shortcut.rawValue) }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: editingShortcuts ? "pencil" : shortcut.symbol)
                                .font(.system(size: 19, weight: .light))
                            Text(shortcut.title).font(.system(size: 10, weight: .medium))
                                .lineLimit(1).minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(Atelier.ink)
                        .frame(maxWidth: .infinity, minHeight: 68).paperSurface(radius: 22)
                        .opacity(editingShortcuts || shortcutAvailable(shortcut) ? 1 : 0.35)
                    }
                    .buttonStyle(QuietPressStyle())
                    .disabled(!editingShortcuts && !shortcutAvailable(shortcut))
                    .accessibilityLabel("اختصار \(shortcut.title)")
                    .accessibilityIdentifier("shortcut-\(index)")
                }
            }
        }
    }

    private func shortcutAvailable(_ shortcut: RemoteShortcut) -> Bool {
        guard store.paired else { return false }
        switch shortcut {
        case .home: return store.capabilities.home
        case .back: return store.capabilities.back
        case .mute, .volumeUp, .volumeDown: return store.capabilities.volume
        case .wake: return true
        case .powerMenu: return store.capabilities.powerMenu
        case .iptv: return store.capabilities.openIPTVSmarters
        }
    }

    private func featureTile(_ title: String, detail: String, symbol: String, action: String, enabled: Bool) -> some View {
        Button { send(action) } label: {
            VStack(alignment: .leading, spacing: 17) {
                Image(systemName: symbol).font(.system(size: 23, weight: .light)).foregroundStyle(Atelier.gold)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Atelier.ink)
                    Text(detail).font(.system(size: 10)).foregroundStyle(Atelier.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(19).paperSurface(radius: 24)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(QuietPressStyle()).disabled(!enabled).accessibilityLabel(title)
    }

    private var moreWorkspace: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("تحكّم يناسبك", detail: "تفاصيل صغيرة، وراحة أكثر", serial: "02")
            VStack(spacing: 0) {
                Toggle(isOn: $hapticsEnabled) {
                    preferenceLabel("اهتزاز الأزرار", detail: "إحساس خفيف مع كل ضغطة", symbol: "hand.tap")
                }
                .accessibilityIdentifier("preference-haptics").padding(19)
                Divider().padding(.horizontal, 19)
                Toggle(isOn: $keepAwake) {
                    preferenceLabel("إبقاء الشاشة مفتوحة", detail: "أثناء استخدام التطبيق مع الرسيفر", symbol: "sun.max")
                }
                .accessibilityIdentifier("preference-keep-awake").padding(19)
            }
            .tint(Atelier.gold).paperSurface(radius: 27)
            informationNote("اضغط مطولًا على زر رفع الصوت أو خفضه للتغيير المستمر. يتوقف التكرار عند رفع إصبعك أو مغادرة التطبيق.", symbol: "hand.point.up.left")
            Button {
                page = .remote
                editingShortcuts = true
            } label: {
                Label("تخصيص الاختصارات", systemImage: "star")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Atelier.ink)
                    .frame(maxWidth: .infinity, minHeight: 53).background(Atelier.metal, in: Capsule())
            }
            .buttonStyle(QuietPressStyle())
            connectionCheckCard
        }
    }

    private func preferenceLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 21, weight: .light))
                .foregroundStyle(Atelier.gold).frame(width: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Atelier.ink)
                Text(detail).font(.system(size: 10)).foregroundStyle(Atelier.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var connectionCheckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle().fill(connectionColor).frame(width: 7, height: 7)
                Text(store.connectionState.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Atelier.ink)
                Spacer()
                if let milliseconds = store.lastResponseMilliseconds {
                    Text("\(milliseconds) ms").font(.system(size: 12, design: .monospaced)).foregroundStyle(Atelier.muted)
                }
            }
            if let lastContact = store.lastSuccessfulContact {
                Text("آخر تواصل ناجح: \(lastContact.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11)).foregroundStyle(Atelier.muted)
            }
            Button { Task { await store.refreshCapabilities() } } label: {
                HStack(spacing: 9) {
                    if store.checkingConnection { ProgressView().tint(Atelier.ink) }
                    Text(store.checkingConnection ? "جارٍ الفحص…" : "اختبار الاتصال")
                    Image(systemName: "wave.3.right")
                }
                .font(.system(size: 13, weight: .medium)).foregroundStyle(Atelier.ink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Atelier.paper, in: Capsule())
            }
            .buttonStyle(QuietPressStyle()).disabled(store.checkingConnection)
            Text("زمن الاستجابة يخص آخر فحص للشبكة، وقد يختلف وقت تنفيذ الأوامر.")
                .font(.system(size: 10)).foregroundStyle(Atelier.muted)
        }
        .padding(19).paperSurface(radius: 26)
    }

    private var connectionColor: Color {
        switch store.connectionState {
        case .available: return Color(red: 0.30, green: 0.57, blue: 0.40)
        case .unavailable: return Color(red: 0.72, green: 0.34, blue: 0.27)
        case .checking: return Atelier.gold
        case .unknown: return Atelier.muted
        }
    }

    private var connectionWorkspace: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("اتصالك، واضح.", detail: "إدارة الرسيفر المتصل", serial: "03")
            VStack(spacing: 0) {
                connectionRow("اسم الجهاز", value: store.selected?.name ?? "الرسيفر", symbol: "tv")
                Divider().padding(.horizontal, 18)
                connectionRow("عنوان الشبكة", value: store.selected?.host ?? "—", symbol: "network")
                Divider().padding(.horizontal, 18)
                connectionRow("نوع الاتصال", value: "Wi-Fi محلي", symbol: "wifi")
            }
            .paperSurface(radius: 27)
            connectionCheckCard
            Button { Task { await store.refreshCapabilities() } } label: {
                Label("تحديث الاتصال", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Atelier.ink)
                    .frame(maxWidth: .infinity, minHeight: 54).background(Atelier.metal, in: Capsule())
            }
            .buttonStyle(QuietPressStyle()).disabled(store.checkingConnection)
            Button { store.unpair() } label: {
                Label("إلغاء الاقتران", systemImage: "link.badge.minus")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Atelier.muted)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            informationNote(store.message, symbol: "wave.3.right")
        }
    }

    private func connectionRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 19, weight: .light)).foregroundStyle(Atelier.gold).frame(width: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 11)).foregroundStyle(Atelier.muted)
                Text(value).font(.system(size: 15, weight: .medium)).foregroundStyle(Atelier.ink)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(19)
    }

    private var pairingWorkspace: some View {
        VStack(alignment: .leading, spacing: 22) {
            pairingIllustration
            sectionHeading("اختر رسيفرك", detail: "الآيفون والرسيفر على شبكة Wi-Fi نفسها", serial: "01")
            if store.discovery.receivers.isEmpty {
                HStack(spacing: 12) {
                    ProgressView().tint(Atelier.gold)
                    Text("نبحث عن الرسيفر…").font(.system(size: 13)).foregroundStyle(Atelier.muted)
                    Spacer()
                    Image(systemName: "wifi").foregroundStyle(Atelier.gold)
                }
                .padding(18).paperSurface(radius: 22)
            } else {
                discoveredReceivers
            }
            manualConnection
            if store.selected != nil { pairingCodePanel }
            informationNote(store.message, symbol: "info.circle")
        }
    }

    private var pairingIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32).fill(Atelier.ink)
            Circle().stroke(Atelier.gold.opacity(0.12), lineWidth: 1).frame(width: 164, height: 164)
            Circle().stroke(Atelier.gold.opacity(0.10), lineWidth: 1).frame(width: 213, height: 213)
            HStack(alignment: .bottom, spacing: 19) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 58, weight: .ultraLight)).rotationEffect(.degrees(-8))
                Image(systemName: "wave.3.right").font(.system(size: 20, weight: .ultraLight)).padding(.bottom, 20)
                Image(systemName: "tv").font(.system(size: 63, weight: .ultraLight)).padding(.bottom, 4)
            }
            .foregroundStyle(Atelier.metal).environment(\.layoutDirection, .leftToRight)
        }
        .frame(height: 184).clipped().clipShape(RoundedRectangle(cornerRadius: 32))
        .accessibilityHidden(true)
    }

    private var discoveredReceivers: some View {
        VStack(spacing: 10) {
            ForEach(store.discovery.receivers) { receiver in
                Button { store.choose(receiver) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tv").font(.system(size: 23, weight: .light)).foregroundStyle(Atelier.gold)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(receiver.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Atelier.ink)
                            Text(receiver.host).font(.system(size: 11, design: .monospaced)).foregroundStyle(Atelier.muted)
                        }
                        Spacer()
                        Image(systemName: store.selected?.id == receiver.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Atelier.gold)
                    }
                    .padding(18).paperSurface(radius: 23)
                }
                .buttonStyle(QuietPressStyle())
            }
        }
    }

    private var manualConnection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("أو اتصل بعنوان IP").font(.system(size: 12, weight: .medium)).foregroundStyle(Atelier.muted)
            HStack(spacing: 10) {
                TextField("192.168.1.10", text: $manualHost)
                    .font(.system(size: 15, design: .monospaced))
                    .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .multilineTextAlignment(.leading).environment(\.layoutDirection, .leftToRight)
                    .padding(.horizontal, 16).frame(height: 54).paperSurface(radius: 18)
                    .accessibilityLabel("عنوان IP للرسيفر")
                Button {
                    let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !host.isEmpty else { return }
                    store.choose(ReceiverEndpoint(name: "CleanYourTV", host: host, port: 8765))
                } label: {
                    Image(systemName: "arrow.left").font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Atelier.paleGold).frame(width: 54, height: 54)
                        .background(Atelier.ink, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(QuietPressStyle()).accessibilityLabel("اتصال بالرسيفر")
            }
        }
    }

    private var pairingCodePanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 10) {
                Image(systemName: "lock.open").font(.system(size: 23, weight: .light)).foregroundStyle(Atelier.gold)
                VStack(alignment: .leading, spacing: 5) {
                    Text("خطوة واحدة أخيرة").font(.system(size: 16, weight: .semibold)).foregroundStyle(Atelier.ink)
                    Text("أدخل رمز الاقتران الظاهر على التلفزيون").font(.system(size: 11)).foregroundStyle(Atelier.muted)
                }
            }
            TextField("000000", text: $store.pairingCode)
                .keyboardType(.numberPad).multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .light, design: .monospaced)).tracking(8)
                .environment(\.layoutDirection, .leftToRight).foregroundStyle(Atelier.ink)
                .frame(height: 65).background(Atelier.paper, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("رمز الاقتران المكوّن من ستة أرقام")
            Button { Task { await store.pair() } } label: {
                HStack(spacing: 9) {
                    if store.busy { ProgressView().tint(Atelier.ink) }
                    Text("اقتران بالرسيفر").font(.system(size: 15, weight: .semibold))
                    Image(systemName: "link").font(.system(size: 15))
                }
                .foregroundStyle(Atelier.ink).frame(maxWidth: .infinity, minHeight: 53)
                .background(Atelier.metal, in: Capsule())
                .opacity(store.pairingCode.count == 6 ? 1 : 0.5)
            }
            .buttonStyle(QuietPressStyle()).disabled(store.busy || store.pairingCode.count != 6)
        }
        .padding(20).paperSurface(radius: 27)
    }

    private func sectionHeading(_ title: String, detail: String, serial: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 22, weight: .semibold)).foregroundStyle(Atelier.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(Atelier.muted)
            }
            Spacer(minLength: 5)
            Text(serial).font(.system(size: 28, weight: .ultraLight, design: .serif)).foregroundStyle(Atelier.gold.opacity(0.7))
        }
    }

    private var navigationDock: some View {
        HStack(spacing: 5) {
            ForEach(RemotePage.allCases, id: \.self) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { page = item }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.symbol).font(.system(size: 17, weight: .medium))
                        Text(item.rawValue).font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(page == item ? Atelier.paleGold : Atelier.muted)
                    .background(page == item ? Atelier.ink : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityIdentifier("tab-\(item.symbol)")
                .accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }
        .padding(7).background(.white, in: Capsule())
        .overlay(Capsule().strokeBorder(Atelier.line.opacity(0.6)))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 5)
        .frame(maxWidth: 440).padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 8)
        .frame(maxWidth: .infinity).background(Atelier.paper.opacity(0.97))
    }

    private func informationNote(_ text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Atelier.gold)
            Text(text).font(.system(size: 12)).foregroundStyle(Atelier.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16).background(Atelier.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Rectangle().fill(Atelier.line).frame(width: 28, height: 1)
                Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 12, weight: .light)).foregroundStyle(Atelier.gold)
                Rectangle().fill(Atelier.line).frame(width: 28, height: 1)
            }
            Text("الأوامر عبر الشبكة المحلية فقط").font(.system(size: 10)).foregroundStyle(Atelier.muted)
        }
        .padding(.top, 6).accessibilityElement(children: .combine)
    }

    private func pressFeedback() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake && store.paired && scenePhase == .active
    }

    private func send(_ action: String) {
        pressFeedback()
        Task { await performAction(action) }
    }

    @discardableResult
    private func performAction(_ action: String) async -> Bool {
        #if DEBUG
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-test") {
            capturedAction = action
            capturedCommandCount += 1
            return true
        }
        #endif
        #endif
        if action == "OPEN_IPTV_SMARTERS_PRO" {
            await store.openIPTVSmarters()
            return store.capabilities.openIPTVSmarters
        }
        return await store.send(action)
    }

}

private struct DirectionalDial: View {
    let enabled: Bool
    let send: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.25), .black, Atelier.gold.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
                ForEach(DialDirection.allCases) { direction in
                    Button { send(direction.action) } label: {
                        ZStack {
                            DialSector(start: direction.start).fill(.white.opacity(0.012))
                            DialSector(start: direction.start).stroke(.white.opacity(0.055), lineWidth: 0.7)
                            Image(systemName: direction.symbol).font(.system(size: 20, weight: .light))
                                .foregroundStyle(enabled ? Atelier.paleGold : .white.opacity(0.24))
                                .position(x: side / 2 + cos(CGFloat(direction.angle)) * side * 0.365,
                                          y: side / 2 + sin(CGFloat(direction.angle)) * side * 0.365)
                        }
                        .contentShape(DialSector(start: direction.start))
                    }
                    .buttonStyle(.plain).disabled(!enabled).accessibilityLabel(direction.label)
                }
                Button { send("OK") } label: {
                    Text("OK").font(.system(size: 23, weight: .medium, design: .rounded)).tracking(1)
                        .foregroundStyle(Atelier.ink).frame(width: side * 0.335, height: side * 0.335)
                        .background(Atelier.metal, in: Circle())
                        .overlay(Circle().strokeBorder(Atelier.paleGold.opacity(0.8), lineWidth: 1))
                        .shadow(color: Atelier.gold.opacity(0.13), radius: 15)
                        .shadow(color: .black.opacity(0.7), radius: 8, y: 5)
                        .opacity(enabled ? 1 : 0.45)
                }
                .buttonStyle(QuietPressStyle()).disabled(!enabled).accessibilityLabel("تأكيد")
                Circle().strokeBorder(.black.opacity(0.7), lineWidth: 6).frame(width: side * 0.385, height: side * 0.385)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("directional-dial")
        .environment(\.layoutDirection, .leftToRight)
    }
}

private enum DialDirection: Int, CaseIterable, Identifiable {
    case up, right, down, left
    var id: Int { rawValue }
    var start: Double { Double(rawValue) * 90 + 225 }
    var angle: Double { (Double(rawValue) * 90 - 90) * .pi / 180 }
    var action: String { ["UP", "RIGHT", "DOWN", "LEFT"][rawValue] }
    var label: String { ["أعلى", "يمين", "أسفل", "يسار"][rawValue] }
    var symbol: String { ["chevron.up", "chevron.right", "chevron.down", "chevron.left"][rawValue] }
}

private struct DialSector: Shape {
    var start: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outside = min(rect.width, rect.height) * 0.49
        let inside = min(rect.width, rect.height) * 0.215
        let a = CGFloat(start * Double.pi / 180)
        var path = Path()
        path.move(to: CGPoint(x: center.x + cos(a) * inside, y: center.y + sin(a) * inside))
        path.addLine(to: CGPoint(x: center.x + cos(a) * outside, y: center.y + sin(a) * outside))
        path.addArc(center: center, radius: outside, startAngle: .degrees(start), endAngle: .degrees(start + 90), clockwise: false)
        path.addLine(to: CGPoint(x: center.x + cos(a + .pi / 2) * inside, y: center.y + sin(a + .pi / 2) * inside))
        path.addArc(center: center, radius: inside, startAngle: .degrees(start + 90), endAngle: .degrees(start), clockwise: true)
        path.closeSubpath()
        return path
    }
}

private struct QuietPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private extension View {
    func paperSurface(radius: CGFloat) -> some View {
        background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Atelier.line.opacity(0.5), lineWidth: 0.8))
    }
}

/// A touch starts exactly one worker. Leaving the button, lifting the finger,
/// disabling the control or leaving the active app all stop future repeats.
@MainActor
private struct RepeatingControl<Content: View>: View {
    let enabled: Bool
    let label: String
    let onPress: () -> Void
    let action: @MainActor () async -> Bool
    let content: Content
    @State private var repeater = CommandRepeater()
    @State private var trackingTouch = false
    @State private var pressed = false
    @Environment(\.scenePhase) private var scenePhase

    init(enabled: Bool, label: String, onPress: @escaping () -> Void,
         action: @escaping @MainActor () async -> Bool, @ViewBuilder content: () -> Content) {
        self.enabled = enabled
        self.label = label
        self.onPress = onPress
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .opacity(pressed ? 0.65 : 1)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard enabled, scenePhase == .active else { return }
                    if !trackingTouch {
                        trackingTouch = true
                        pressed = true
                        onPress()
                        repeater.begin(action: action)
                    }
                    if abs(value.translation.width) > 32 || abs(value.translation.height) > 32 {
                        pressed = false
                        repeater.stop()
                    }
                }
                .onEnded { _ in stop() })
            .allowsHitTesting(enabled)
            .disabled(!enabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard enabled else { return }
                onPress()
                Task { await action() }
            }
            .onDisappear { stop() }
            .onChange(of: enabled) { _, active in if !active { stop() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
    }

    private func stop() {
        repeater.stop()
        trackingTouch = false
        pressed = false
    }
}
