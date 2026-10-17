import SwiftUI

private enum PanelMenu: String, CaseIterable, Identifiable {
    case options = "Opções", credits = "Créditos"
    var id: Self { self }
    var symbol: String { self == .options ? "slider.horizontal.3" : "person.crop.circle" }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var executor = PanelExecutorStore()
    @State private var menu: PanelMenu = .options
    @State private var showExecutor = false
    @State private var showLogs = false

    private var canExecute: Bool {
        appState.isSupported && !appState.kernelExploitRunning
            && (!appState.kernelExploitApplicable || appState.exploitStatus.isSuccess)
    }

    private var status: String {
        if executor.isBusy { return executor.feedback ?? "Aguarde…" }
        if !appState.isSupported { return "iOS não compatível" }
        if appState.kernelExploitRunning { return "Preparando acesso…" }
        if !canExecute { return "Acesso indisponível · diagnóstico" }
        return executor.feedback ?? "Pronto · \(executor.active.count)/3 ativas"
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    header
                    menuPicker
                    if menu == .options { options } else { credits }
                    footer
                }
                .padding(16)
                .frame(maxWidth: 350)
                .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.panelBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 16)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showExecutor, onDismiss: executor.refreshReceipts) {
            VStack(spacing: 0) {
                HStack {
                    Text("Arquivos .3105").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Fechar") { showExecutor = false }
                }.padding()
                Divider()
                PatchProjectsView()
            }
            .background(AppTheme.pageBackground)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLogs) { LogView() }
        .alert(item: $executor.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message),
                  dismissButton: .default(Text("Entendi")))
        }
        .onAppear { executor.refreshReceipts(); openPendingImport() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { executor.refreshReceipts() }
        }
        .onChange(of: draftCoordinator.importRequest?.id) { _ in openPendingImport() }
        .onChange(of: draftCoordinator.request?.id) { _ in openPendingImport() }
        .onChange(of: executor.isBusy) { busy in
            if !busy { openPendingImport() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("RNZW").font(.system(size: 17, weight: .bold, design: .rounded)).tracking(1.5)
                Text("EXECUTOR").font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(2).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 8)
            Button { showExecutor = true } label: {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(executor.isBusy)
            .accessibilityLabel("Abrir executor e importar arquivos .3105")
        }
    }

    private var menuPicker: some View {
        HStack(spacing: 3) {
            ForEach(PanelMenu.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { menu = item }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol).font(.system(size: 11, weight: .medium))
                        Text(item.rawValue).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(menu == item ? AppTheme.ink : AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(menu == item ? AppTheme.raisedBackground : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(menu == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var options: some View {
        VStack(spacing: 6) {
            ForEach(PanelFeature.allCases) { feature in featureRow(feature) }
        }
    }

    private func featureRow(_ feature: PanelFeature) -> some View {
        let active = executor.active.contains(feature)
        let working = executor.busyFeature == feature
        return Button {
            guard canExecute else { return }
            executor.toggle(feature)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: feature.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(active ? AppTheme.accent : AppTheme.muted)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(feature.title).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer(minLength: 4)
                if working {
                    ProgressView().controlSize(.small).tint(AppTheme.accent).frame(width: 20, height: 20)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(active ? Color.black : Color.black.opacity(0.22))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(active ? AppTheme.accent : AppTheme.muted.opacity(0.3), lineWidth: 1)
                        if active {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.ink)
                        }
                    }.frame(width: 19, height: 19).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PanelButtonStyle(isSelected: active))
        .disabled(executor.isBusy || !canExecute)
        .opacity(executor.isBusy && !working ? 0.65 : 1)
        .accessibilityLabel(feature.title)
        .accessibilityValue(working ? (executor.isRestoring ? "Restaurando" : "Ativando") : (active ? "Ativo" : "Desativado"))
        .accessibilityHint(active ? "Toque para restaurar o arquivo original" : "Toque para aplicar o pacote")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var credits: some View {
        VStack(spacing: 6) {
            creditLink("Telegram", detail: "@rnzwmodz", symbol: "paperplane", url: "https://t.me/rnzwmodz")
            creditLink("Discord", detail: "Comunidade", symbol: "bubble.left.and.bubble.right", url: "https://discord.gg/a4QmpBuw33")
            creditLink("Tutorial", detail: "@rnzwstore", symbol: "play.rectangle", url: "https://www.youtube.com/@rnzwstore")
        }
    }

    private func creditLink(_ title: String, detail: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.muted).frame(width: 20)
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 4)
                Text(detail).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(PanelButtonStyle())
        .accessibilityHint("Abre o link de \(title)")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                if menu == .options {
                    HStack(spacing: 5) {
                        Circle().fill(AppTheme.accent).frame(width: 4, height: 4)
                        Text(status).font(.system(size: 10, weight: .medium))
                    }
                    .accessibilityElement(children: .combine).accessibilityAddTraits(.updatesFrequently)
                    Text("Toque para ativar ou restaurar. Feche o app de destino.")
                        .font(.system(size: 9)).foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("RNZW MODZ").font(.system(size: 10, weight: .semibold)).tracking(1)
                    Text("Base 3105 · YangJiii · GPLv3")
                        .font(.system(size: 9)).foregroundStyle(AppTheme.muted)
                }
            }
            Spacer(minLength: 0)
            Button { showLogs = true } label: {
                Image(systemName: "waveform.path.ecg").font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted).frame(width: 32, height: 44)
            }
            .buttonStyle(.plain).accessibilityLabel("Abrir diagnóstico")
        }
    }

    private func openPendingImport() {
        guard !executor.isBusy else { return }
        if draftCoordinator.importRequest != nil || draftCoordinator.request != nil { showExecutor = true }
    }
}
