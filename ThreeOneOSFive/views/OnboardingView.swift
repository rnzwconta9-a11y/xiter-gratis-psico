import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "scope")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 12) {
                    Text("RNZW / EXECUTOR")
                        .font(.system(.caption, design: .monospaced).weight(.bold)).tracking(2)
                        .foregroundStyle(AppTheme.accent)
                    Text("Seu painel.\nTudo à mão.")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Três opções, um executor. Escolha os pacotes no painel ou importe seus arquivos .3105.")
                        .font(.body).foregroundStyle(AppTheme.muted)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Label("Feche o app de destino antes de executar.", systemImage: "app.badge.checkmark")
                    Label("Pacotes protegidos pedem a senha original.", systemImage: "lock.square")
                    Label("Compatibilidade e assinatura seguem os requisitos da base 3105.", systemImage: "iphone")
                }
                .font(.subheadline).foregroundStyle(AppTheme.muted)
                Button(action: onComplete) {
                    HStack {
                        Text("Abrir painel")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline).padding(18).frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle(isPrimary: true))
                Text("RNZW MODZ · Base 3105 / YangJiii")
                    .font(.caption2).foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(28).padding(.vertical, 30)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
        .preferredColorScheme(.light)
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
