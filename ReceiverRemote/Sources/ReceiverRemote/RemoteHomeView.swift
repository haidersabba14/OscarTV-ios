import SwiftUI
import Combine

private enum RemotePalette {
    static let gold = Color(red: 0.88, green: 0.70, blue: 0.37)
    static let goldSoft = Color(red: 0.55, green: 0.40, blue: 0.19)
    static let ink = Color(red: 0.035, green: 0.038, blue: 0.05)
}

struct RemoteHomeView: View {
    @ObservedObject var store: RemoteStore
    @State private var manualHost = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [RemotePalette.ink, Color.black, Color(red: 0.10, green: 0.08, blue: 0.055)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        statusCard
                        if store.paired { remotePanel } else { pairingPanel }
                        capabilityNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(RemotePalette.gold.opacity(0.14))
                Image(systemName: "appletvremote.gen4")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(RemotePalette.gold)
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("RECEIVER REMOTE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(RemotePalette.gold)
                Text("تحكم أنيق من الآيفون")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            if store.paired {
                Button { store.unpair() } label: {
                    Image(systemName: "link.badge.minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .glassCard()
                }
                .accessibilityLabel("إلغاء الاقتران")
            }
        }
        .padding(.vertical, 8)
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(store.paired ? Color.green : RemotePalette.gold)
                .frame(width: 8, height: 8)
                .shadow(color: (store.paired ? Color.green : RemotePalette.gold).opacity(0.7), radius: 6)
            Text(store.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
            Spacer(minLength: 0)
            if store.paired {
                Button { Task { await store.refreshCapabilities() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RemotePalette.gold)
                }
                .accessibilityLabel("تحديث الاتصال")
            }
        }
        .padding(14)
        .glassCard()
    }

    private var pairingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("الاقتران", detail: "اختر الرسيفر المتصل بنفس الشبكة")

            if store.discovery.receivers.isEmpty {
                HStack(spacing: 12) {
                    ProgressView().tint(RemotePalette.gold)
                    Text("جارٍ البحث تلقائيًا عن الرسيفر…")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                }
                .padding(14)
                .glassCard()
            } else {
                ForEach(store.discovery.receivers) { receiver in
                    Button { store.choose(receiver) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tv.fill").foregroundStyle(RemotePalette.gold)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(receiver.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                Text(receiver.host).font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: store.selected?.id == receiver.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(RemotePalette.gold)
                        }
                        .padding(14)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                TextField("أو أدخل IP يدويًا", text: $manualHost)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 13)
                    .frame(height: 48)
                    .glassCard()
                Button("اتصال") {
                    let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !host.isEmpty else { return }
                    store.choose(ReceiverEndpoint(name: "CleanYourTV", host: host, port: 8765))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(RemotePalette.gold, in: RoundedRectangle(cornerRadius: 15))
            }

            if store.selected != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("رمز الاقتران الظاهر على التلفزيون")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 12) {
                        TextField("000000", text: $store.pairingCode)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .tracking(5)
                            .foregroundStyle(RemotePalette.gold)
                            .padding(12)
                            .glassCard()
                        Button {
                            Task { await store.pair() }
                        } label: {
                            HStack(spacing: 8) {
                                if store.busy { ProgressView().tint(.black) }
                                Text("اقتران")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 104, minHeight: 52)
                            .background(RemotePalette.gold, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(store.busy || store.pairingCode.count != 6)
                        .opacity(store.pairingCode.count == 6 ? 1 : 0.55)
                    }
                }
                .padding(16)
                .glassCard()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private var remotePanel: some View {
        VStack(spacing: 18) {
            sectionTitle(store.selected?.name ?? "الرسيفر", detail: "الأزرار المتاحة تتحدد حسب صلاحيات Android")
            dpad
            HStack(spacing: 10) {
                actionButton("الرئيسية", icon: "house.fill", action: "HOME", enabled: store.capabilities.home)
                actionButton("رجوع", icon: "chevron.backward", action: "BACK", enabled: store.capabilities.back)
                actionButton("الإعدادات", icon: "gearshape.fill", action: "SETTINGS", enabled: store.capabilities.settings)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                actionButton("صوت +", icon: "speaker.plus.fill", action: "VOLUME_UP", enabled: store.capabilities.volume)
                actionButton("كتم", icon: "speaker.slash.fill", action: "MUTE", enabled: store.capabilities.volume)
                actionButton("صوت −", icon: "speaker.minus.fill", action: "VOLUME_DOWN", enabled: store.capabilities.volume)
            }
            HStack(spacing: 10) {
                actionButton("إيقاظ", icon: "sun.max.fill", action: "WAKE", enabled: true)
                actionButton("قائمة الطاقة", icon: "power", action: "POWER_MENU", enabled: store.capabilities.powerMenu)
            }
            numberPad
            HStack(spacing: 10) {
                actionButton("القناة السابقة", icon: "minus", action: "CHANNEL_DOWN", enabled: store.capabilities.channels)
                actionButton("القناة التالية", icon: "plus", action: "CHANNEL_UP", enabled: store.capabilities.channels)
            }
            Text("تغيير القنوات المباشر غير متاح في نظام هذا الرسيفر؛ قائمة الطاقة تفتح خيارات Android ولا تطفئه تلقائيًا.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        }
        .padding(16)
        .glassCard()
    }

    private var dpad: some View {
        VStack(spacing: 8) {
            remoteKey(icon: "chevron.up", label: "أعلى", action: "UP", enabled: store.capabilities.navigation)
            HStack(spacing: 8) {
                remoteKey(icon: "chevron.left", label: "يسار", action: "LEFT", enabled: store.capabilities.navigation)
                Button { Task { await store.send("OK") } } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark").font(.system(size: 21, weight: .bold))
                        Text("OK").font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundStyle(.black)
                    .frame(width: 82, height: 66)
                    .background(RemotePalette.gold.gradient, in: Capsule())
                    .shadow(color: RemotePalette.gold.opacity(0.22), radius: 16, y: 4)
                }
                .disabled(!store.capabilities.navigation)
                .scaleEffect(store.capabilities.navigation ? 1 : 0.98)
                remoteKey(icon: "chevron.right", label: "يمين", action: "RIGHT", enabled: store.capabilities.navigation)
            }
            remoteKey(icon: "chevron.down", label: "أسفل", action: "DOWN", enabled: store.capabilities.navigation)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private var numberPad: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("لوحة الأرقام").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
            Text("إدخال الأرقام وتغيير القنوات يحتاج دعمًا من نظام الرسيفر؛ هذه الأزرار غير متاحة لهذا الجهاز.")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.48))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "•", "0", "⌫"], id: \.self) { value in
                    if value == "•" || value == "⌫" {
                        Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white.opacity(0.22))
                            .frame(maxWidth: .infinity, minHeight: 48).glassCard()
                    } else {
                        Button { Task { await store.send("DIGIT_\(value)") } } label: {
                            Text(value).font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 48).glassCard()
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.capabilities.channels)
                    }
                }
            }
        }
        .padding(13)
        .glassCard()
    }

    private var capabilityNote: some View {
        Text("الأوامر تمر عبر الشبكة المحلية فقط. لا يمكن تشغيل الرسيفر وهو مطفأ بالكامل إذا كان Wi-Fi غير متاح.")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.42))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func remoteKey(icon: String, label: String, action: String, enabled: Bool) -> some View {
        Button { Task { await store.send(action) } } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(enabled ? RemotePalette.gold : .white.opacity(0.24))
                .frame(width: 74, height: 58)
                .glassCard()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func actionButton(_ title: String, icon: String, action: String, enabled: Bool) -> some View {
        Button { Task { await store.send(action) } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(enabled ? RemotePalette.gold : .white.opacity(0.25))
            .frame(maxWidth: .infinity, minHeight: 62)
            .glassCard()
        }
        .buttonStyle(GlassPressStyle())
        .disabled(!enabled)
    }
}

private struct GlassCardModifier: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(glassBorder)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), RemotePalette.gold.opacity(0.20), .white.opacity(0.04)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(glassBorder)
    }
}

private extension View { func glassCard() -> some View { modifier(GlassCardModifier()) } }

private struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

