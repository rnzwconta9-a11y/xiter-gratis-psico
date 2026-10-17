import SwiftUI
import AudioToolbox

struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        AppLogo(size: 32)
                        Text("rnzwstore").font(.system(.title3, design: .rounded).weight(.bold))
                    }
                    Text("Um toque para ativar.\nOutro para restaurar.")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                    Text("Feche o app de destino antes de usar as opções. O painel guarda os arquivos originais para restaurá-los ao desligar.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                    Button(action: onComplete) {
                        HStack {
                            Text("Abrir painel")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold)).padding(14)
                    }
                    .buttonStyle(PanelButtonStyle(isPrimary: true))
                    Text("RNZW MODZ")
                        .font(.caption2).foregroundStyle(AppTheme.muted)
                }
                .padding(22).frame(maxWidth: 350)
                .foregroundStyle(AppTheme.ink)
                .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.panelBorder).allowsHitTesting(false))
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

/// Appears inside the app, below the status bar, without covering the panel controls.
struct FreePanelBanner: View {
    @Environment(\.openURL) private var openURL
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Painel grátis").font(.system(size: 13, weight: .semibold))
                Text(FreePanelNoticeStore.message)
                    .font(.system(size: 12)).foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    onClose()
                    openURL(FreePanelNoticeStore.purchaseURL)
                } label: {
                    HStack(spacing: 5) {
                        Text("Comprar VIP")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre o Discord da rnzwstore")
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar aviso")
        }
        .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 12)
        .frame(maxWidth: 350, alignment: .leading)
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppTheme.panelBorder).allowsHitTesting(false))
        .onAppear { AudioServicesPlaySystemSound(1007) }
    }
}

/// Banner acknowledgement survives updates and is separate from the former modal and onboarding.
enum FreePanelNoticeStore {
    static let storageKey = "rnzwstore.freePanelBannerSeen"
    static let message = "Isso é um painel grátis. Caso queira a versão VIP, compre aqui."
    static let purchaseURL = URL(string: "https://discord.gg/a4QmpBuw33")!

    static func shouldShow(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: storageKey)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: storageKey)
    }
}

enum OnboardingStore {
    static let completedVersionKey = "onboarding.completedVersion"
    static let completedFingerprintKey = "onboarding.completedFingerprint"

    static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    /// Per-install token: executable mtime changes on every overwrite even if version stays the same.
    static var bundleToken: String {
        if let exe = Bundle.main.executablePath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: exe),
           let date = attrs[.modificationDate] as? Date {
            return String(Int(date.timeIntervalSince1970))
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Bundle.main.bundlePath),
           let date = (attrs[.creationDate] as? Date) ?? (attrs[.modificationDate] as? Date) {
            return String(Int(date.timeIntervalSince1970))
        }
        return "0"
    }

    static var currentFingerprint: String { "\(currentVersion)#\(bundleToken)" }

    static var completedVersion: String? {
        UserDefaults.standard.string(forKey: completedVersionKey)
    }

    static var completedFingerprint: String? {
        UserDefaults.standard.string(forKey: completedFingerprintKey)
    }

    static func shouldShow() -> Bool {
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { return false }
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") { return true }
#endif
        let fp = currentFingerprint
        if let stored = completedFingerprint, !stored.isEmpty {
            return stored != fp
        }
        // Migration: old installs only have completedVersion
        if let completed = completedVersion, !completed.isEmpty {
            if completed == currentVersion {
                // Same version, migrate silently — next overwrite will be detected via fingerprint
                UserDefaults.standard.set(fp, forKey: completedFingerprintKey)
                return false
            }
            return true
        }
        return true
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedVersionKey)
        UserDefaults.standard.set(currentFingerprint, forKey: completedFingerprintKey)
    }
}
