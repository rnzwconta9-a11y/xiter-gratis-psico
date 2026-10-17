import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0–26.6.1"

    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 6 || (minor == 6 && patch <= 1)
        }

        guard major == 27, minor == 0, patch == 0 else { return false }
        return iOS27BetaNumber(for: build) != nil
    }
}

/// Explains a blocked tap without confusing app support with kernel support.
enum PanelAccessPolicy {
    static let requiredBundleIdentifier = "com.apple.mobile.MobileHouseArrest"

    static func blockReason(
        systemSupported: Bool,
        kernelRequired: Bool,
        kernelRunning: Bool,
        kernelSucceeded: Bool,
        kernelFailed: Bool,
        hostBundleIdentifier: String?,
        osVersion: String
    ) -> String? {
        guard hostBundleIdentifier == requiredBundleIdentifier else {
            return "A assinatura alterou o identificador do app para \(hostBundleIdentifier ?? "não identificado"). Esta base exige \(requiredBundleIdentifier). Assine novamente preservando esse identificador."
        }
        guard systemSupported else {
            return "O iOS \(osVersion) não está na lista de versões aceitas por esta base. Nenhum pacote foi aplicado."
        }
        if kernelRunning {
            return "O acesso ao dispositivo ainda está sendo preparado. Aguarde a conclusão e consulte o diagnóstico se a preparação falhar."
        }
        if kernelRequired && !kernelSucceeded {
            return kernelFailed
                ? "A base não conseguiu obter acesso ao dispositivo. Por isso a opção não foi aplicada. Consulte o diagnóstico; uma nova tentativa exige fechar e reabrir o app."
                : "A preparação do acesso ainda não foi concluída. Consulte o diagnóstico antes de tentar ativar a opção."
        }
        return nil
    }
}
