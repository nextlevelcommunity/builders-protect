import CVECore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var onFinish: () -> Void

    @State private var step = 0
    @State private var draft = AppSettings()
    @State private var launchAtLogin = true
    @State private var preview: FolderPreview?
    @State private var isPreviewing = false
    @State private var loaded = false

    private var stepTitles: [String] {
        [
            L10n.t("Boas-vindas"),
            L10n.t("Conta"),
            L10n.t("Pastas"),
            L10n.t("Rotina"),
            L10n.t("Pronto")
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 300)
            Rectangle()
                .fill(CBTheme.hairline)
                .frame(width: 1)
            VStack(spacing: 0) {
                topBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 48)
                    .padding(.top, 26)
                navigation
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 920, height: 640)
        .background(background)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !loaded else { return }
            draft = model.settings
            launchAtLogin = model.settings.hasCompletedOnboarding
                ? model.launchAtLoginEnabled
                : true
            loaded = true
        }
        .task(id: folderKey) {
            await updatePreview()
        }
        .onChange(of: step) { newValue in
            if newValue == 1 {
                Task { await model.refreshAuth(force: false) }
            }
        }
    }

    private var background: some View {
        ZStack {
            CBTheme.background
            RadialGradient(
                colors: [CBTheme.lime.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 720
            )
            RadialGradient(
                colors: [CBTheme.low.opacity(0.035), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 520
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                BrandMark(size: 58)
                BrandWordmark()
            }
            .padding(.top, 38)
            .padding(.horizontal, 30)

            Text(L10n.t("Um radar de dependências para quem constrói."))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(stepTitles.indices, id: \.self) { index in
                    stepRow(index: index)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 30)

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(L10n.t("PRIVACIDADE POR PADRÃO"))
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(CBTheme.lime)

                Text(L10n.t("Nesta varredura, só nomes, versões e lockfiles saem deste Mac."))
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.025), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func stepRow(index: Int) -> some View {
        let isCurrent = index == step
        let isDone = index < step
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        isCurrent
                            ? CBTheme.lime
                            : (isDone ? CBTheme.lime.opacity(0.14) : CBTheme.surface)
                    )
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(CBTheme.lime)
                } else {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isCurrent ? CBTheme.background : CBTheme.textTertiary)
                }
            }
            .frame(width: 24, height: 24)

            Text(stepTitles[index])
                .font(.system(size: 11.5, weight: isCurrent ? .semibold : .medium, design: .rounded))
                .foregroundStyle(
                    isCurrent
                        ? CBTheme.text
                        : (isDone ? CBTheme.textSecondary : CBTheme.textTertiary)
                )

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                Text(L10n.t("PASSO \(String(format: "%02d", step + 1)) / \(String(format: "%02d", stepTitles.count))", "STEP \(String(format: "%02d", step + 1)) / \(String(format: "%02d", stepTitles.count))"))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(CBTheme.textTertiary)

                Spacer()

                Text(stepTitles[step])
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)

            HStack(spacing: 5) {
                ForEach(stepTitles.indices, id: \.self) { index in
                    Capsule()
                        .fill(
                            index <= step
                                ? (index == step ? CBTheme.lime : CBTheme.lime.opacity(0.28))
                                : Color.white.opacity(0.06)
                        )
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 48)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            welcomeStep
        case 1:
            accountStep
        case 2:
            foldersStep
        case 3:
            routineStep
        default:
            readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("Dependência antiga não precisa ser uma surpresa."))
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.t("O Builders Protect lê os lockfiles dos seus projetos, compara cada versão com a base de vulnerabilidades e explica o que corrigir — com um prompt pronto para o seu agente de código."))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 540, alignment: .leading)
            }

            VStack(spacing: 8) {
                featureRow(
                    symbol: "magnifyingglass",
                    title: L10n.t("Achados reais, não ruído"),
                    detail: L10n.t("Vulnerabilidades confirmadas para as versões instaladas, com KEV e versão corrigida.")
                )
                featureRow(
                    symbol: "sparkles",
                    title: L10n.t("Diagnóstico da Cultura Builder"),
                    detail: L10n.t("A IA prioriza o que reduz risco mais rápido e escreve o plano por projeto.")
                )
                featureRow(
                    symbol: "doc.on.doc",
                    title: L10n.t("Correção em um clique"),
                    detail: L10n.t("Copie um prompt completo e cole no Claude Code, Codex ou Cursor.")
                )
            }
            .frame(maxWidth: 540)

            Spacer(minLength: 0)
        }
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(CBTheme.limeMuted)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CBTheme.lime)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(detail)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Conecte sua conta Cultura Builder."))
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("A conta libera o diagnóstico da IA e o prompt de correção. A verificação de vulnerabilidades funciona mesmo sem login."))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 550, alignment: .leading)

                Text(L10n.t("Prefere o modo RTX? A chave dedicada substitui o login e é configurada depois em Ajustes > IA e segurança."))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 550, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                (model.authStatus.connected ? CBTheme.mint : CBTheme.high)
                                    .opacity(0.12)
                            )
                        Image(
                            systemName: model.authStatus.connected
                                ? "checkmark"
                                : "person.crop.circle.badge.exclamationmark"
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(model.authStatus.connected ? CBTheme.mint : CBTheme.high)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            model.authStatus.connected
                                ? L10n.t("Conta conectada", "Connected account")
                                : L10n.t("Sessão não encontrada", "Session not found")
                        )
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)

                        if model.authStatus.connected {
                            Text(
                                model.authStatus.localizedExpiryLabel.map {
                                    L10n.t("Token válido até \($0)", "Token valid until \($0)")
                                }
                                    ?? L10n.t("Sessão da Cultura Builder ativa", "Cultura Builder session active")
                            )
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                        } else {
                            Text(L10n.t("Entre pelo terminal para liberar a análise da IA."))
                                .font(.system(size: 9.5, weight: .regular, design: .rounded))
                                .foregroundStyle(CBTheme.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                if !model.authStatus.connected {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L10n.t("Rode este comando no terminal:"))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                        Text(model.authStatus.loginCommand)
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(CBTheme.lime)
                            .textSelection(.enabled)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }

                    HStack(spacing: 8) {
                        Button {
                            model.copyLoginCommand()
                        } label: {
                            Label(L10n.t("Copiar comando"), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(LimeButtonStyle())

                        Button {
                            Task { await model.refreshAuth(force: false) }
                        } label: {
                            Text(model.isRefreshingAuth ? L10n.t("Verificando…", "Checking…") : L10n.t("Já fiz login", "I signed in"))
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .disabled(model.isRefreshingAuth)

                        Spacer(minLength: 0)

                        Button(L10n.t("Abrir o Hub")) {
                            model.openHub()
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            model.copyLoginCommand()
                        } label: {
                            Label(L10n.t("Copiar comando de login"), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        Spacer(minLength: 0)
                        Button(L10n.t("Abrir o Hub")) {
                            model.openHub()
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
            }
            .padding(15)
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CBTheme.textTertiary)
                    .padding(.top, 1)
                Text(L10n.t("Você pode continuar sem login e entrar depois em Ajustes. Nesse caso, o diagnóstico da IA fica desligado."))
                    .font(.system(size: 9.8, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var foldersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Onde estão seus projetos?"))
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("Adicione as pastas que contêm seus repositórios. O app desce até 8 níveis, ignora node_modules e procura lockfiles de npm, Python, Rust, Go, Ruby, Elixir e Nix."))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 570, alignment: .leading)
            }

            Button {
                addFolders()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                    Text(L10n.t("Adicionar pasta de projetos"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Spacer()
                    Text(L10n.t("⌘ O"))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(CBTheme.limeMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)

            if !draft.excludedPaths.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                        .padding(.top, 1)
                    Text(L10n.t("\(Vocabulary.quantity(draft.excludedPaths.count, "worktree ignorada", "worktrees ignoradas")) automaticamente. Você pode reativar em Ajustes > Pastas.", "\(Vocabulary.quantity(draft.excludedPaths.count, "worktree ignorada", "worktrees ignoradas")) automatically. You can reactivate them in Settings > Folders."))
                        .font(.system(size: 9.8, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !draft.folders.isEmpty {
                VStack(spacing: 6) {
                    ForEach(draft.folders) { folder in
                        HStack(spacing: 9) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CBTheme.lime.opacity(0.85))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(folder.displayName)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CBTheme.text)
                                Text(folder.path.homeAbbreviated)
                                    .font(.system(size: 8.8, weight: .regular, design: .monospaced))
                                    .foregroundStyle(CBTheme.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                draft.folders.removeAll { $0.id == folder.id }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(IconButtonStyle(size: 22))
                            .help(L10n.t("Remover pasta"))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            previewCard

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isPreviewing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.t("Procurando projetos e lockfiles…"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                }
            } else if let preview {
                if preview.projectCount > 0 {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CBTheme.mint)
                        Text("\(Vocabulary.quantity(preview.projectCount, "projeto", "projetos")) · \(Vocabulary.quantity(preview.lockfileCount, "lockfile", "lockfiles"))")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                    }
                    Text(preview.projects.prefix(4).joined(separator: " · "))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(2)
                    if preview.projects.count > 4 {
                        Text(L10n.t("e mais \(preview.projects.count - 4)…", "and \(preview.projects.count - 4) more…"))
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                } else {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CBTheme.high)
                            .padding(.top, 1)
                        Text(L10n.t("Nenhum lockfile encontrado nessas pastas. Adicione a raiz onde ficam os repositórios, não uma pasta interna."))
                            .font(.system(size: 9.8, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if draft.folders.isEmpty {
                Text(L10n.t("Nenhuma pasta adicionada ainda."))
                    .font(.system(size: 9.8, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var routineStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Uma varredura por dia, sem lembrar de nada."))
                    .font(.system(size: 31, weight: .light, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("O Builders Protect verifica suas dependências no horário escolhido e avisa quando aparece uma vulnerabilidade nova."))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560, alignment: .leading)
            }

            VStack(spacing: 0) {
                routineToggle(
                    title: L10n.t("Rotina diária"),
                    detail: L10n.t("Verifica todos os projetos uma vez por dia."),
                    isOn: $draft.scheduleEnabled
                )

                if draft.scheduleEnabled {
                    Divider().overlay(CBTheme.hairline)
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("Horário da varredura"))
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(CBTheme.text)
                            Text(L10n.t("O Mac precisa estar ligado ou acordar depois do horário."))
                                .font(.system(size: 9.2, weight: .regular, design: .rounded))
                                .foregroundStyle(CBTheme.textTertiary)
                        }
                        Spacer()
                        Text(draft.scheduleLabel)
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(CBTheme.lime)
                        DatePicker(
                            "",
                            selection: timeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .frame(width: 84)
                    }
                    .padding(14)
                }

                Divider().overlay(CBTheme.hairline)
                routineToggle(
                    title: L10n.t("Abrir ao iniciar o Mac"),
                    detail: L10n.t("Mantém o radar ativo sem abrir o app manualmente."),
                    isOn: $launchAtLogin
                )

                Divider().overlay(CBTheme.hairline)
                routineToggle(
                    title: L10n.t("Avisar sobre novas vulnerabilidades"),
                    detail: L10n.t("Uma notificação por varredura, sem repetir achados antigos."),
                    isOn: $draft.notifyOnFindings
                )
            }
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CBTheme.textTertiary)
                    .padding(.top, 1)
                Text(L10n.t("Se o Mac estiver dormindo no horário, a varredura acontece quando ele acordar. Ao abrir o app, o Builders Protect também recupera uma rotina perdida."))
                    .font(.system(size: 9.8, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func routineToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(detail)
                    .font(.system(size: 9.2, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(CBTheme.lime)
                .controlSize(.small)
        }
        .padding(14)
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Tudo pronto para começar."))
                    .font(.system(size: 33, weight: .light, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(L10n.t("A primeira varredura começa assim que você concluir. O resultado aparece no menu bar e no painel do app."))
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 540, alignment: .leading)
            }

            HStack(spacing: 8) {
                summaryTile(
                    value: "\(draft.folders.count)",
                    label: L10n.t("pastas", "folders"),
                    symbol: "folder.fill"
                )
                summaryTile(
                    value: draft.scheduleEnabled ? draft.scheduleLabel : "—",
                    label: L10n.t("rotina diária", "daily routine"),
                    symbol: "clock.fill"
                )
                summaryTile(
                    value: model.authStatus.connected ? L10n.t("ligado", "on") : L10n.t("desligado", "off"),
                    label: L10n.t("diagnóstico IA", "AI diagnosis"),
                    symbol: "sparkles"
                )
            }
            .frame(maxWidth: 560)

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: L10n.t("O que acontece agora"))
                readyRow("1", L10n.t("Lemos os lockfiles e comparamos com a base de vulnerabilidades.", "We read the lockfiles and compare them with the vulnerability database."))
                readyRow("2", L10n.t("A Cultura Builder explica o risco e monta o plano.", "Cultura Builder explains the risk and builds the plan."))
                readyRow("3", L10n.t("Você copia o prompt e corrige com seu agente de código.", "You copy the prompt and fix it with your coding agent."))
            }
            .padding(14)
            .frame(maxWidth: 560, alignment: .leading)
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "terminal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CBTheme.lime)
                    .padding(.top, 1)
                Text(L10n.t("Você pode revisar tudo depois em Ajustes. O prompt de correção fica em cada alerta do painel."))
                    .font(.system(size: 9.8, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func summaryTile(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
            Text(value)
                .font(.system(size: 20, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(CBTheme.text)
            Text(label.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(CBTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func readyRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CBTheme.lime)
                .frame(width: 17, height: 17)
                .background(CBTheme.limeMuted, in: Circle())
            Text(text)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var navigation: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step -= 1
                    }
                } label: {
                    Label(L10n.t("Voltar"), systemImage: "chevron.left")
                }
                .buttonStyle(GhostButtonStyle())
            }

            Spacer()

            Text(footerHint)
                .font(.system(size: 8.8, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)

            Button {
                if step == stepTitles.count - 1 {
                    finish()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step += 1
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(step == stepTitles.count - 1 ? L10n.t("Começar a monitorar", "Start monitoring") : L10n.t("Continuar", "Continue"))
                    Image(systemName: step == stepTitles.count - 1 ? "shield.checkered" : "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .buttonStyle(LimeButtonStyle())
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.5)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 18)
        .overlay(
            Rectangle()
                .fill(CBTheme.hairline)
                .frame(height: 1),
            alignment: .top
        )
    }

    private var canAdvance: Bool {
        if step == 2 {
            return !draft.folders.isEmpty
        }
        return true
    }

    private var footerHint: String {
        switch step {
        case 2:
            return draft.folders.isEmpty
                ? L10n.t("Adicione ao menos uma pasta", "Add at least one folder")
                : ""
        case 3:
            return L10n.t("O Mac precisa estar ligado no horário", "The Mac must be on at the scheduled time")
        default:
            return ""
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: draft.scheduleHour,
                    minute: draft.scheduleMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.scheduleHour = components.hour ?? 9
                draft.scheduleMinute = components.minute ?? 0
            }
        )
    }

    private var folderKey: String {
        let folders = draft.folders.map(\.path).joined(separator: "|")
        let exclusions = draft.excludedPaths.joined(separator: "|")
        return folders + "||" + exclusions
    }

    private func addFolders() {
        let picked = model.pickFolders()
        for folder in picked.folders {
            guard !draft.folders.contains(where: { $0.path == folder.path }) else { continue }
            draft.folders.append(folder)
        }
        for path in picked.autoExcludedPaths where !draft.excludedPaths.contains(path) {
            draft.excludedPaths.append(path)
        }
    }

    private func updatePreview() async {
        guard !draft.folders.isEmpty else {
            preview = nil
            isPreviewing = false
            return
        }
        isPreviewing = true
        let result = await model.previewFolders(
            draft.folders,
            excludedPaths: draft.excludedPaths
        )
        guard !Task.isCancelled else { return }
        preview = result
        isPreviewing = false
    }

    private func finish() {
        draft.hasCompletedOnboarding = true
        model.setLaunchAtLogin(launchAtLogin)
        model.completeOnboarding(draft)
        onFinish()
    }
}
