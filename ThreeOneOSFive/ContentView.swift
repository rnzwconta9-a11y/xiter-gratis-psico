import SwiftUI

private enum PanelMenu: String, CaseIterable, Identifiable {
    case options = "Opções", credits = "Créditos"
    var id: Self { self }
    var symbol: String { self == .options ? "slider.horizontal.3" : "person.crop.square" }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var executor = PanelExecutorStore()
    @State private var menu: PanelMenu = .options
    @State private var showExecutor = false
    @State private var showLogs = false
    @State private var confirmExecution = false
    @State private var confirmRestore = false

    private var canExecute: Bool {
        appState.isSupported && !appState.kernelExploitRunning
            && (!appState.kernelExploitApplicable || appState.exploitStatus.isSuccess)
    }

    private var deviceStatus: String {
        if !appState.isSupported { return "iOS não compatível" }
        if appState.kernelExploitRunning { return "Preparando acesso…" }
        return canExecute ? "Executor disponível" : "Acesso indisponível"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                line
                HStack(alignment: .top, spacing: 0) {
                    sidebar
                    Rectangle().fill(AppTheme.panelBorder).frame(width: 1)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            if menu == .options { options } else { credits }
                            footer
                        }
                        .frame(maxWidth: 600, alignment: .leading)
                        .padding(geometry.size.width < 380 ? 16 : 24)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
        .tint(AppTheme.accent)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showExecutor, onDismiss: executor.refreshReceipts) {
            VStack(spacing: 0) {
                HStack {
                    Text("Executor de arquivos").font(.headline)
                    Spacer()
                    Button("Fechar") { showExecutor = false }
                }.padding()
                Divider()
                PatchProjectsView()
            }.preferredColorScheme(.light)
        }
        .sheet(isPresented: $showLogs) { LogView() }
        .sheet(item: $executor.passwordFeature) { feature in
            PanelPasswordView(executor: executor, feature: feature)
                .id(feature.id)
                .interactiveDismissDisabled()
        }
        .alert(item: $executor.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message),
                  dismissButton: .default(Text("Entendi")))
        }
        .confirmationDialog("Executar as opções selecionadas?", isPresented: $confirmExecution, titleVisibility: .visible) {
            Button("Executar agora", role: executor.selection.contains(.resetGuest) ? .destructive : nil) {
                guard canExecute else { return }
                executor.executeSelection()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(executor.selection.contains(.resetGuest)
                ? "Feche o app de destino. Reset Guest altera os dados da conta de convidado; mantenha uma cópia dos dados importantes antes de continuar."
                : "Feche o app de destino antes de aplicar os pacotes selecionados.")
        }
        .confirmationDialog("Restaurar os arquivos originais?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar selecionadas", role: .destructive) {
                guard canExecute else { return }
                executor.restoreSelection()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Usa os backups do executor para desfazer os pacotes selecionados. Feche o app de destino antes de continuar.")
        }
        .onAppear { executor.refreshReceipts(); openPendingImport() }
        .onChange(of: draftCoordinator.importRequest?.id) { _ in openPendingImport() }
        .onChange(of: draftCoordinator.request?.id) { _ in openPendingImport() }
        .onChange(of: executor.isBusy) { busy in
            if !busy { openPendingImport() }
        }
    }

    private var line: some View { Rectangle().fill(AppTheme.panelBorder).frame(height: 1) }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(AppTheme.accent)
                Image(systemName: "scope").font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
            }
            .frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("RNZW").font(.system(.title3, design: .rounded).weight(.black)).tracking(2)
                Text("PAINEL / EXECUTOR").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 8)
            Button { showExecutor = true } label: {
                Image(systemName: "square.and.arrow.down").font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PanelButtonStyle()).disabled(executor.isBusy)
            .accessibilityLabel("Abrir executor e importar arquivos .3105")
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var sidebar: some View {
        VStack(spacing: 14) {
            ForEach(PanelMenu.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { menu = item }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: item.symbol).font(.system(size: 20, weight: .medium))
                        Text(item.rawValue).font(.system(size: 10, weight: .semibold))
                    }.frame(width: 62).frame(minHeight: 64)
                }
                .buttonStyle(PanelButtonStyle(isSelected: menu == item))
                .accessibilityAddTraits(menu == item ? .isSelected : [])
            }
            Spacer(minLength: 24)
            Text("3105").font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
        }.padding(.horizontal, 10).padding(.vertical, 24)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 22) {
            pageTitle("Opções", subtitle: "Selecione. Execute. Pronto.", index: "01")
            VStack(spacing: 0) {
                ForEach(PanelFeature.allCases) { feature in
                    featureRow(feature)
                    if feature != PanelFeature.allCases.last { line }
                }
            }
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.panelBorder, lineWidth: 1))
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(canExecute ? AppTheme.ink : AppTheme.accent).frame(width: 6, height: 6)
                    Text(executor.isBusy ? executor.progress : deviceStatus).font(.caption.weight(.medium))
                }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.updatesFrequently)
                if !canExecute {
                    Text(appState.kernelExploitRunning ? "Aguarde a preparação do acesso ao dispositivo."
                         : "Abra o diagnóstico para verificar o acesso e a compatibilidade do dispositivo.")
                        .font(.caption).foregroundStyle(AppTheme.muted)
                }
                Button { confirmExecution = true } label: {
                    HStack(spacing: 8) {
                        if executor.isBusy { ProgressView().tint(.white) }
                        else { Image(systemName: "play.fill").font(.caption) }
                        Text(executor.isBusy ? "Aguarde…" : "Executar selecionadas")
                    }
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PanelButtonStyle(isPrimary: true))
                .disabled(executor.selection.isEmpty || executor.isBusy || !canExecute)
                if executor.canRestoreSelection {
                    Button { confirmRestore = true } label: {
                        Label("Restaurar selecionadas", systemImage: "arrow.uturn.backward")
                            .font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PanelButtonStyle()).disabled(executor.isBusy || !canExecute)
                }
                Text("Marcar uma opção prepara a seleção. Desmarcar não desfaz uma execução.")
                    .font(.caption2).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func featureRow(_ feature: PanelFeature) -> some View {
        let selected = executor.selection.contains(feature)
        return Button { executor.toggle(feature) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(selected ? AppTheme.ink : Color.white)
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(selected ? AppTheme.ink : AppTheme.panelBorder, lineWidth: 1.5)
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                }.frame(width: 23, height: 23).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(feature.title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    Text(executor.results[feature] ?? feature.subtitle)
                        .font(.caption2).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text(feature.number).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 14).padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(executor.isBusy)
        .accessibilityLabel(feature.title).accessibilityValue(selected ? "Selecionado" : "Não selecionado")
        .accessibilityHint("Toque para mudar a seleção. Use Executar selecionadas para aplicar.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 22) {
            pageTitle("Créditos", subtitle: "Encontre a RNZW por aqui.", index: "02")
            VStack(spacing: 12) {
                creditLink("Telegram", detail: "@rnzwmodz", symbol: "paperplane", url: "https://t.me/rnzwmodz")
                creditLink("Discord", detail: "Nossa comunidade", symbol: "bubble.left.and.bubble.right", url: "https://discord.gg/a4QmpBuw33")
                creditLink("Tutorial", detail: "YouTube · @rnzwstore", symbol: "play.rectangle", url: "https://www.youtube.com/@rnzwstore")
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("RNZW MODZ").font(.caption.weight(.bold)).tracking(1.5)
                Text("Interface RNZW. Base do executor: 3105, por YangJiii.\nLicença GPLv3 e créditos de terceiros preservados na source.")
                    .font(.caption).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 8)
        }
    }

    private func creditLink(_ title: String, detail: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppTheme.accent).frame(width: 26)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption2).opacity(0.65)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PanelButtonStyle()).accessibilityHint("Abre o link de \(title)")
    }

    private func pageTitle(_ title: String, subtitle: String, index: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Rectangle().fill(AppTheme.accent).frame(width: 16, height: 3)
                Text("PAINEL / \(index)").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2).foregroundStyle(AppTheme.muted)
            }
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold)).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.caption).foregroundStyle(AppTheme.muted)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            line
            HStack {
                Text("RNZW / 3105").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
                Spacer()
                Button { showLogs = true } label: {
                    Label("Diagnóstico", systemImage: "terminal").font(.system(size: 10, weight: .medium))
                        .frame(minHeight: 44)
                }.buttonStyle(.plain)
            }.foregroundStyle(AppTheme.muted)
        }
    }

    private func openPendingImport() {
        guard !executor.isBusy else { return }
        if draftCoordinator.importRequest != nil || draftCoordinator.request != nil { showExecutor = true }
    }
}

private struct PanelPasswordView: View {
    @ObservedObject var executor: PanelExecutorStore
    let feature: PanelFeature
    @State private var password = ""
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "lock.square").font(.largeTitle).foregroundStyle(AppTheme.accent)
                    Text(feature.title).font(.title2.bold())
                    Text("Este pacote é protegido. Digite a senha original do arquivo para continuar.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                    SecureField("Senha do pacote", text: $password)
                        .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(16).background(AppTheme.consoleBackground, in: RoundedRectangle(cornerRadius: 6))
                        .focused($passwordFocused).submitLabel(.go).onSubmit(unlock)
                    if let error = executor.passwordError {
                        Text(error).font(.caption).foregroundStyle(AppTheme.accent)
                    }
                    Button(action: unlock) {
                        HStack {
                            if executor.isUnlocking { ProgressView().tint(.white) }
                            Text(executor.isUnlocking ? "Verificando…" : "Desbloquear e continuar")
                        }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(PanelButtonStyle(isPrimary: true))
                    .disabled(password.isEmpty || executor.isUnlocking)
                }.padding(24)
            }
            .background(Color.white).navigationTitle("Pacote protegido").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { password = ""; executor.cancelPreparation() }.disabled(executor.isUnlocking)
                }
            }
            .onAppear { passwordFocused = true }
        }.preferredColorScheme(.light)
    }

    private func unlock() {
        guard !password.isEmpty, !executor.isUnlocking else { return }
        passwordFocused = false
        executor.unlock(password: password)
        password = ""
    }
}
