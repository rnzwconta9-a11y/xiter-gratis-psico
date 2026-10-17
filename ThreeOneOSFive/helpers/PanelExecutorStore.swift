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
    var subtitle: String {
        switch self {
        case .fps: return "Pacote de desempenho"
        case .aimhead: return "Pacote NO HEAD FFTH"
        case .resetGuest: return "Redefinição de convidado"
        }
    }
    var number: String {
        switch self {
        case .fps: return "01"
        case .aimhead: return "02"
        case .resetGuest: return "03"
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

private enum PanelLoadError: Error { case missingResource, wrongPackage, passwordRequired, conflictingTargets }

private struct PreparedPanelFeature {
    let feature: PanelFeature
    let project: PatchProject
}

/// UI orchestration only. Decoding, passwords, backup, apply and restore use the original engine.
@MainActor
final class PanelExecutorStore: ObservableObject {
    @Published private(set) var selection: Set<PanelFeature> = []
    @Published private(set) var results: [PanelFeature: String] = [:]
    @Published private(set) var isBusy = false
    @Published private(set) var isUnlocking = false
    @Published private(set) var progress = ""
    @Published private(set) var passwordError: String?
    @Published var passwordFeature: PanelFeature?
    @Published var notice: PanelNotice?
    @Published private var applied: Set<PanelFeature> = []

    private var pending: [PanelFeature] = []
    private var prepared: [PreparedPanelFeature] = []
    private var completed: [PanelFeature] = []

    var canRestoreSelection: Bool { !selection.intersection(applied).isEmpty }

    func toggle(_ feature: PanelFeature) {
        guard !isBusy else { return }
        if selection.contains(feature) { selection.remove(feature) }
        else { selection.insert(feature) }
    }

    func refreshReceipts() {
        guard !isBusy else { return }
        applied = Set(PanelFeature.allCases.filter { DevicePatchService.latestReceipt(projectID: $0.packageID) != nil })
        for feature in PanelFeature.allCases {
            if applied.contains(feature) { results[feature] = "Aplicado · backup disponível" }
            else if results[feature] == "Aplicado · backup disponível" { results[feature] = nil }
        }
    }

    func executeSelection() {
        guard !isBusy, !selection.isEmpty else { return }
        refreshReceipts()
        // Preserve the original backup: do not stack another application over an active receipt.
        guard selection.intersection(applied).isEmpty else {
            notice = PanelNotice(title: "Pacote já aplicado", message: "Restaure as opções já aplicadas antes de executá-las novamente, ou desmarque essas opções.")
            return
        }
        isBusy = true
        completed = []
        prepared = []
        pending = PanelFeature.allCases.filter { selection.contains($0) }
        prepareNext()
    }

    func cancelPreparation() {
        guard !isUnlocking else { return }
        passwordFeature = nil
        passwordError = nil
        pending = []
        prepared = []
        isBusy = false
        progress = ""
        // All password prompts precede all writes, so cancelling never applies a partial selection.
    }

    func unlock(password: String) {
        guard let feature = passwordFeature, isBusy, !isUnlocking, !password.isEmpty else { return }
        isUnlocking = true
        passwordError = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let item = try Self.load(feature, password: password)
                await self?.acceptUnlocked(item)
            } catch {
                await self?.rejectPassword(error)
            }
        }
    }

    private func acceptUnlocked(_ item: PreparedPanelFeature) {
        isUnlocking = false
        passwordFeature = nil
        acceptPrepared(item)
    }

    private func rejectPassword(_ error: Error) {
        isUnlocking = false
        passwordError = Self.message(for: error)
    }

    private func prepareNext() {
        guard let feature = pending.first else {
            // Independent packages must not overwrite each other's targets in one batch.
            var targets = Set<String>()
            for item in prepared {
                for rule in item.project.rules {
                    if !targets.insert(rule.bundleID + "/" + rule.relativePath).inserted {
                        fail(PanelLoadError.conflictingTargets, feature: item.feature)
                        return
                    }
                }
            }
            applyNext()
            return
        }
        progress = "Verificando \(feature.title)…"
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let item = try Self.load(feature, password: nil)
                await self?.acceptPrepared(item)
            } catch PanelLoadError.passwordRequired {
                await self?.requestPassword(for: feature)
            } catch {
                await self?.fail(error, feature: feature)
            }
        }
    }

    private func requestPassword(for feature: PanelFeature) {
        passwordError = nil
        passwordFeature = feature
    }

    private func acceptPrepared(_ item: PreparedPanelFeature) {
        prepared.append(item)
        pending.removeFirst()
        prepareNext()
    }

    private func applyNext() {
        guard let item = prepared.first else { finish(restoring: false); return }
        progress = "Executando \(item.feature.title)…"
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                _ = try DevicePatchService.apply(project: item.project)
                await self?.didApply(item.feature)
            } catch {
                await self?.fail(error, feature: item.feature)
            }
        }
    }

    private func didApply(_ feature: PanelFeature) {
        results[feature] = "Aplicado · backup disponível"
        completed.append(feature)
        prepared.removeFirst()
        applyNext()
    }

    func restoreSelection() {
        guard !isBusy, canRestoreSelection else { return }
        isBusy = true
        completed = []
        // Reverse the fixed application order; the engine verifies current files before restoring.
        pending = PanelFeature.allCases.reversed().filter { selection.contains($0) && applied.contains($0) }
        restoreNext()
    }

    private func restoreNext() {
        guard let feature = pending.first else { finish(restoring: true); return }
        progress = "Restaurando \(feature.title)…"
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let receipt = DevicePatchService.latestReceipt(projectID: feature.packageID) else {
                    throw PatchPackageError.restoreFailed
                }
                try DevicePatchService.restore(receipt: receipt)
                await self?.didRestore(feature)
            } catch {
                await self?.fail(error, feature: feature)
            }
        }
    }

    private func didRestore(_ feature: PanelFeature) {
        results[feature] = "Originais restaurados"
        completed.append(feature)
        pending.removeFirst()
        restoreNext()
    }

    private func finish(restoring: Bool) {
        isBusy = false
        progress = ""
        refreshReceipts()
        notice = PanelNotice(title: restoring ? "Restauração concluída" : "Execução concluída",
                             message: completed.map(\.title).joined(separator: ", ")
                                + (restoring ? ": arquivos originais restaurados." : ": pacotes aplicados pelo executor."))
    }

    private func fail(_ error: Error, feature: PanelFeature) {
        results[feature] = "Não concluído · veja a mensagem"
        isBusy = false
        isUnlocking = false
        progress = ""
        pending = []
        prepared = []
        refreshReceipts()
        let prefix = completed.isEmpty ? "Nenhuma opção desta execução foi concluída. "
            : "Concluídas: \(completed.map(\.title).joined(separator: ", ")). As demais não foram concluídas. "
        notice = PanelNotice(title: feature.title, message: prefix + Self.message(for: error))
    }

    nonisolated private static func load(_ feature: PanelFeature, password: String?) throws -> PreparedPanelFeature {
        guard let url = Bundle.main.url(forResource: feature.rawValue, withExtension: "3105", subdirectory: "PanelPackages") else {
            throw PanelLoadError.missingResource
        }
        let data = try PatchProjectLibrary.readPackage(at: url)
        let summary = try PatchPackageCodec.inspect(data)
        guard summary.packageID == feature.packageID else { throw PanelLoadError.wrongPackage }
        let decoded: DecodedPatchPackage
        if summary.isPasswordProtected, let key = try PatchKeyStore.load(for: summary) {
            decoded = try PatchPackageCodec.decode(data, contentKey: key)
        } else {
            if summary.isPasswordProtected && password == nil { throw PanelLoadError.passwordRequired }
            decoded = try PatchPackageCodec.decode(data, password: password)
            if summary.isPasswordProtected { try PatchKeyStore.store(decoded.contentKey, for: summary) }
        }
        return PreparedPanelFeature(feature: feature, project: decoded.project)
    }

    nonisolated private static func message(for error: Error) -> String {
        if let error = error as? PanelLoadError {
            switch error {
            case .missingResource: return "O pacote não foi incluído no app. Verifique PanelPackages nos recursos do projeto Xcode."
            case .wrongPackage: return "O arquivo não corresponde à opção escolhida."
            case .passwordRequired: return "Digite a senha original deste pacote."
            case .conflictingTargets: return "Os pacotes selecionados alteram o mesmo arquivo. Execute e restaure cada opção separadamente. Nenhuma alteração foi feita."
            }
        }
        if let error = error as? PatchPackageError {
            switch error {
            case .invalidPasswordOrCorruptedPackage: return "Senha incorreta ou arquivo corrompido. Confira a senha original do pacote."
            case .targetAppUnavailable: return "App de destino indisponível. Verifique se está instalado e se o executor tem acesso ao dispositivo."
            case .keychainFailed: return "Não foi possível acessar o Chaves do iOS para desbloquear o pacote."
            case .restoreFailed: return "Não foi possível restaurar com segurança. Os arquivos ou os backups podem ter mudado."
            case .applyFailed: return "O executor não concluiu a aplicação. Consulte o diagnóstico."
            default: return "O pacote não passou pela validação do executor. Consulte o diagnóstico."
            }
        }
        return "Não foi possível concluir a operação. Consulte o diagnóstico do executor."
    }
}
