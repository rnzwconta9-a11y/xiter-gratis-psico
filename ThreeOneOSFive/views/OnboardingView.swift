import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "scope").font(.title2).foregroundStyle(AppTheme.accent)
                        Text("RNZW").font(.system(.title3, design: .rounded).weight(.bold)).tracking(2)
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
                    Text("RNZW MODZ · Base 3105 / YangJiii")
                        .font(.caption2).foregroundStyle(AppTheme.muted)
                }
                .padding(22).frame(maxWidth: 350)
                .foregroundStyle(AppTheme.ink)
                .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.panelBorder))
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
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
