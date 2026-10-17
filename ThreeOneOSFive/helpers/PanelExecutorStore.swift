import Combine
import Foundation

enum PanelFeature: String, CaseIterable, Identifiable {
    case fps = "144-fps", aimhead = "aimhead-lock", resetGuest = "reset-guest"
    var id: Self { self }
    var title: String {
        switch self {
        case .fps: return "144 FPS"
        case .aimhead: return "Aimhead Lock"
        case .resetGuest: return "Reset Guest"
        }
    }
    var symbol: String {
        switch self {
        case .fps: return "speedometer"
        case .aimhead: return "scope"
        case .resetGuest: return "arrow.counterclockwise"
        }
    }
    var packageID: UUID {
        switch self {
        case .fps: return UUID(uuidString: "5B6FEAB4-94F7-43F3-B676-E494AD7EF9D8")!
        case .aimhead: return UUID(uuidString: "8D39ED14-F154-4952-988D-4415FDE10943")!
        case .resetGuest: return UUID(uuidString: "D5894F60-373E-49D1-86DD-95AB0024DF99")!
        }
    }
}

struct PanelNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum PanelLoadError: Error {
    case missingResource, wrongPackage, protectedResource
    case conflictingFeature(PanelFeature)
}

/// A switch reflects the engine's active backup receipt, never an optimistic selection.
@MainActor
final class PanelExecutorStore: ObservableObject {
    @Published private(set) var active: Set<PanelFeature> = []
    @Published private(set) var busyFeature: PanelFeature?
    @Published private(set) var isRestoring = false
    @Published private(set) var feedback: String?
    @Published var notice: PanelNotice?

    var isBusy: Bool { busyFeature != nil }

    func refreshReceipts() {
        guard !isBusy else { return }
        active = Set(PanelFeature.allCases.filter {
            DevicePatchService.latestReceipt(projectID: $0.packageID) != nil
        })
    }

    func toggle(_ feature: PanelFeature) {
        // Serializes writes and ignores repeated taps until the actual result is known.
        guard !isBusy else { return }
        refreshReceipts()
        let receipt = DevicePatchService.latestReceipt(projectID: feature.packageID)
        busyFeature = feature
        isRestoring = receipt != nil
        feedback = receipt == nil ? "Ativando \(feature.title)…" : "Restaurando \(feature.title)…"
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                if let receipt {
                    try DevicePatchService.restore(receipt: receipt)
                } else {
                    let project = try Self.load(feature)
                    try Self.validateAgainstActivePackages(project, feature: feature)
                    _ = try DevicePatchService.apply(project: project)
                }
                await self?.complete(feature, restoring: receipt != nil)
            } catch {
                await self?.fail(error, feature: feature, restoring: receipt != nil)
            }
        }
    }

    private func complete(_ feature: PanelFeature, restoring: Bool) {
        busyFeature = nil
        isRestoring = false
        refreshReceipts()
        let expectedState = !restoring
        guard active.contains(feature) == expectedState else {
            feedback = "Confira o diagnóstico"
            notice = PanelNotice(title: feature.title,
                                 message: "O estado final não foi confirmado pelo executor. Confira o diagnóstico antes de tentar novamente.")
            return
        }
        feedback = restoring ? "\(feature.title): original restaurado" : "\(feature.title) ativado"
    }

    private func fail(_ error: Error, feature: PanelFeature, restoring: Bool) {
        busyFeature = nil
        isRestoring = false
        refreshReceipts()
        feedback = restoring ? "Restauração não concluída" : "Ativação não concluída"
        notice = PanelNotice(title: feature.title, message: Self.message(for: error))
    }

    nonisolated private static func load(_ feature: PanelFeature) throws -> PatchProject {
        guard let url = Bundle.main.url(forResource: feature.rawValue, withExtension: "3105", subdirectory: "PanelPackages") else {
            throw PanelLoadError.missingResource
        }
        let data = try PatchProjectLibrary.readPackage(at: url)
        let summary = try PatchPackageCodec.inspect(data)
        guard summary.packageID == feature.packageID else { throw PanelLoadError.wrongPackage }
        guard !summary.isPasswordProtected else { throw PanelLoadError.protectedResource }
        // Runtime copies use the original format's public-key mode; payload validation stays intact.
        return try PatchPackageCodec.decode(data, password: nil).project
    }

    nonisolated private static func validateAgainstActivePackages(_ project: PatchProject, feature: PanelFeature) throws {
        let targets = Set(project.rules.map { $0.bundleID + "/" + $0.relativePath })
        for other in PanelFeature.allCases where other != feature {
            guard DevicePatchService.latestReceipt(projectID: other.packageID) != nil else { continue }
            let otherProject = try load(other)
            if otherProject.rules.contains(where: { targets.contains($0.bundleID + "/" + $0.relativePath) }) {
                throw PanelLoadError.conflictingFeature(other)
            }
        }
    }

    nonisolated private static func message(for error: Error) -> String {
        if let error = error as? PanelLoadError {
            switch error {
            case .missingResource: return "O pacote não está disponível nesta instalação. Instale a versão completa do painel."
            case .wrongPackage: return "O arquivo não corresponde à opção escolhida."
            case .protectedResource: return "Esta instalação contém um pacote que não foi preparado para ativação direta."
            case .conflictingFeature(let other): return "Desative \(other.title) antes de ativar esta opção: os pacotes alteram o mesmo arquivo."
            }
        }
        if let error = error as? PatchPackageError {
            switch error {
            case .invalidPasswordOrCorruptedPackage: return "O pacote não passou pela verificação de integridade."
            case .targetAppUnavailable: return "O app de destino está indisponível. Verifique se está instalado e se o executor tem acesso ao dispositivo."
            case .restoreFailed: return "Não foi possível restaurar com segurança. Os arquivos ou os backups podem ter mudado. A opção não será indicada como desligada sem confirmar a restauração."
            case .applyFailed: return "O executor não concluiu a aplicação. Consulte o diagnóstico."
            default: return "O pacote não passou pela validação do executor. Consulte o diagnóstico."
            }
        }
        return "Não foi possível concluir a operação. Consulte o diagnóstico do executor."
    }
}
