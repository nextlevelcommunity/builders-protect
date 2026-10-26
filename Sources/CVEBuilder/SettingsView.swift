import AppKit
import CVECore
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case analysis
    case redTeam
    case account
    case folders
    case routine
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analysis: return "Análises"
        case .redTeam: return "Red Teaming"
        case .account: return "Conta"
        case .folders: return "Pastas"
        case .routine: return "Rotina"
        case .about: return "Sobre"
        }
    }

    var symbol: String {
        switch self {
        case .analysis: return "doc.text.magnifyingglass"
        case .redTeam: return "shield.lefthalf.filled"
        case .account: return "person.crop.circle"
        case .folders: return "folder"
        case .routine: return "clock.arrow.circlepath"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var onClose: () -> Void

    @State private var draft = AppSettings()
    @State private var launchAtLogin = false
    @State private var preview: FolderPreview?
    @State private var isPreviewing = false
    @State private var loaded = false
    @State private var saved = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 196)
            Rectangle()
                .fill(CBTheme.hairline)
                .frame(width: 1)
            if section == .analysis {
                AnalysisPanelView(model: model)
            } else if section == .redTeam {
                RedTeamView(model: model)
            } else {
                VStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    footer
                }
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .background(background)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !loaded else { return }
            draft = model.settings
            launchAtLogin = model.launchAtLoginEnabled
            loaded = true
        }
        .task(id: folderKey) {
            await updatePreview()
        }
        .onChange(of: model.settings.excludedPaths) { paths in
            draft.excludedPaths = paths
        }
    }

    private var section: SettingsSection {
        model.settingsSection
    }

    private var background: some View {
        ZStack {
            CBTheme.background
            RadialGradient(
                colors: [CBTheme.lime.opacity(0.055), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 620
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                BrandMark(size: 31)
                BrandWordmark(compact: true)
            }
            .padding(.top, 22)
            .padding(.horizontal, 18)

            Text("NAVEGAÇÃO")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(CBTheme.textTertiary)
                .padding(.top, 24)
                .padding(.horizontal, 18)

            VStack(spacing: 3) {
                ForEach(SettingsSection.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            model.settingsSection = item
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 12, weight: .regular))
                                .frame(width: 16)
                            Text(item.title)
                                .font(.system(size: 12.5, weight: section == item ? .medium : .regular, design: .rounded))
                            Spacer(minLength: 0)
                            if item == .redTeam {
                                Text("Em breve")
                                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                    .tracking(0.4)
                                    .foregroundStyle(CBTheme.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(CBTheme.surfaceStrong, in: Capsule())
                            }
                        }
                        .foregroundStyle(
                            section == item ? CBTheme.text : CBTheme.textSecondary
                        )
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(
                            section == item ? CBTheme.surfaceStrong : .clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(item == .redTeam)
                    .help(item == .redTeam ? "Em breve" : "")
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("Builders Protect")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                Text("v\(BrandAssets.version)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(CBTheme.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.018))
    }

    @ViewBuilder
    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                pageHeader
                switch section {
                case .analysis:
                    EmptyView()
                case .redTeam:
                    EmptyView()
                case .account:
                    accountSection
                case .folders:
                    foldersSection
                case .routine:
                    routineSection
                case .about:
                    aboutSection
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(section.title)
                .font(.system(size: 27, weight: .light, design: .rounded))
                .foregroundStyle(CBTheme.text)
            Text(sectionDescription)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    private var sectionDescription: String {
        switch section {
        case .analysis:
            return "Resultados da última varredura e o que corrigir primeiro."
        case .redTeam:
            return "Análise profunda de um projeto, com consentimento explícito."
        case .account:
            return "Sua sessão da Cultura Builder libera o diagnóstico da IA."
        case .folders:
            return "Estas são as pastas que o Builders Protect varre em busca de lockfiles."
        case .routine:
            return "Defina quando verificar e como o app avisa você."
        case .about:
            return "Um app da Cultura Builder para acompanhar dependências."
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SurfaceCard(padding: 15) {
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
                            Text(model.authStatus.connected ? "Conta conectada" : "Sessão não encontrada")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(CBTheme.text)
                            Text(
                                model.authStatus.connected
                                    ? (model.authStatus.expiryLabel.map { "Token válido até \($0)" } ?? "Sessão ativa")
                                    : "A verificação de vulnerabilidades continua, mas sem diagnóstico da IA."
                            )
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                        }
                        Spacer(minLength: 0)
                        if model.authStatus.connected {
                            Text("ATIVA")
                                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(CBTheme.mint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(CBTheme.mint.opacity(0.1), in: Capsule())
                        }
                    }

                    Divider().overlay(CBTheme.hairline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Para entrar ou trocar de conta, rode no terminal:")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                        Text(model.authStatus.loginCommand)
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(CBTheme.lime)
                            .textSelection(.enabled)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }

                    HStack(spacing: 8) {
                        Button {
                            model.copyLoginCommand()
                        } label: {
                            Label("Copiar comando", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(LimeButtonStyle())

                        Button {
                            Task { await model.refreshAuth(force: true) }
                        } label: {
                            Text(model.isRefreshingAuth ? "Renovando…" : "Já fiz login")
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .disabled(model.isRefreshingAuth)

                        Spacer(minLength: 0)

                        Button("Abrir o Hub") {
                            model.openHub()
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
            }

            NoticeCard(
                kind: .info,
                title: "O que vai para a Cultura Builder",
                message: "O diagnóstico recebe nomes, versões, vulnerabilidades e caminhos dos projetos. Nenhum código-fonte, segredo ou arquivo .env é enviado. O Red Teaming está em breve e, quando ativado, enviará código somente após sua autorização."
            )

            if let path = model.authStatus.authFilePath {
                HStack(spacing: 7) {
                    Image(systemName: "key")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(CBTheme.textTertiary)
                    Text("Sessão lida de \(path.homeAbbreviated)")
                        .font(.system(size: 8.8, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                addFolders()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                    Text("Adicionar pasta")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.text)
                    Spacer()
                    Text("⌘ O")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(CBTheme.limeMuted, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)

            if draft.folders.isEmpty {
                NoticeCard(
                    kind: .warning,
                    title: "Nenhuma pasta monitorada",
                    message: "Adicione a raiz onde ficam seus repositórios para que o app encontre os lockfiles."
                )
            } else {
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
                                NSWorkspace.shared.open(URL(fileURLWithPath: folder.path))
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .buttonStyle(IconButtonStyle(size: 23))
                            .help("Abrir no Finder")

                            Button {
                                draft.folders.removeAll { $0.id == folder.id }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(IconButtonStyle(size: 23))
                            .help("Remover pasta")
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Pastas ignoradas")
                    Spacer()
                    Button {
                        addExclusion()
                    } label: {
                        Label("Ignorar subpasta", systemImage: "eye.slash")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                if draft.excludedPaths.isEmpty {
                    Text("Nenhuma subpasta ignorada. Use esta opção para deixar worktrees e sandboxes fora da varredura.")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 6) {
                        ForEach(draft.excludedPaths, id: \.self) { path in
                            HStack(spacing: 9) {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(CBTheme.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(CBTheme.textSecondary)
                                    Text(path.homeAbbreviated)
                                        .font(.system(size: 8.8, weight: .regular, design: .monospaced))
                                        .foregroundStyle(CBTheme.textTertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button {
                                    draft.excludedPaths.removeAll { $0 == path }
                                } label: {
                                    Text("Acompanhar")
                                }
                                .buttonStyle(GhostButtonStyle(tint: CBTheme.mint))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                Text("As pastas ignoradas valem para as próximas varreduras.")
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            previewCard

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(CBTheme.textTertiary)
                    .padding(.top, 1)
                Text("A varredura ignora node_modules, .git, builds, caches e ambientes virtuais. Ela lê apenas manifests e lockfiles.")
                    .font(.system(size: 9.3, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        Group {
            if isPreviewing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Procurando projetos…")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                }
            } else if let preview, preview.projectCount > 0 {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CBTheme.mint)
                        Text("\(Vocabulary.quantity(preview.projectCount, "projeto", "projetos")) · \(Vocabulary.quantity(preview.lockfileCount, "lockfile", "lockfiles"))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                    }
                    Text(preview.projects.prefix(5).joined(separator: " · "))
                        .font(.system(size: 8.8, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(2)
                }
            } else if let preview, preview.projectCount == 0, !draft.folders.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CBTheme.high)
                        .padding(.top, 1)
                    Text("Nenhum lockfile encontrado. Tente adicionar a pasta raiz dos repositórios.")
                        .font(.system(size: 9.8, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                EmptyView()
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    settingToggle(
                        title: "Rotina diária",
                        detail: "Verifica todos os projetos uma vez por dia.",
                        isOn: $draft.scheduleEnabled
                    )

                    if draft.scheduleEnabled {
                        Divider().overlay(CBTheme.hairline)
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Horário")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CBTheme.text)
                                Text("Próxima execução: \(model.nextRunLabel.lowercased())")
                                    .font(.system(size: 9.2, weight: .regular, design: .rounded))
                                    .foregroundStyle(CBTheme.textTertiary)
                            }
                            Spacer()
                            Text(draft.scheduleLabel)
                                .font(.system(size: 27, weight: .light, design: .rounded))
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
                    settingToggle(
                        title: "Abrir ao iniciar o Mac",
                        detail: Bundle.main.bundleURL.pathExtension == "app"
                            ? "Mantém o radar ativo depois de reiniciar."
                            : "Disponível quando o app está instalado como .app.",
                        isOn: $launchAtLogin
                    )

                    Divider().overlay(CBTheme.hairline)
                    settingToggle(
                        title: "Avisar sobre novas vulnerabilidades",
                        detail: "Envia uma notificação quando uma vulnerabilidade nova aparece.",
                        isOn: $draft.notifyOnFindings
                    )
                }
            }

            HStack(spacing: 8) {
                Button {
                    NotificationService.requestAuthorization()
                } label: {
                    Label("Permitir notificações", systemImage: "bell")
                }
                .buttonStyle(SurfaceButtonStyle())

                Button {
                    model.scan()
                } label: {
                    Label("Verificar agora", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))
                .disabled(!model.canScan)

                Spacer()
            }

            NoticeCard(
                kind: .info,
                title: "Se o Mac estiver dormindo",
                message: "A varredura acontece quando o Mac acordar. Ao abrir o app, o Builders Protect também recupera uma rotina perdida."
            )
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 15) {
                BrandMark(size: 62)
                VStack(alignment: .leading, spacing: 4) {
                    BrandWordmark()
                    Text("Versão \(BrandAssets.version)")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                }
            }

            Text("O Builders Protect transforma lockfiles em um plano de correção claro. Ele compara as versões instaladas com a base de vulnerabilidades e usa a LLM da Cultura Builder para priorizar o que realmente importa.")
                .font(.system(size: 10.8, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                aboutRow(
                    symbol: "lock.shield",
                    title: "Privacidade",
                    detail: "A varredura envia nomes, versões e lockfiles. Nenhum código-fonte sai do Mac. O Red Teaming está em breve."
                )
                Divider().overlay(CBTheme.hairline)
                aboutRow(
                    symbol: "externaldrive",
                    title: "Dados locais",
                    detail: "Ajustes e relatórios ficam em ~/Library/Application Support/Builders Protect."
                )
                Divider().overlay(CBTheme.hairline)
                aboutRow(
                    symbol: "network",
                    title: "Fontes",
                    detail: "hub.culturabuilder.com para vulnerabilidades e análise."
                )
            }
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 8) {
                Button("Abrir o Hub") {
                    model.openHub()
                }
                .buttonStyle(SurfaceButtonStyle())

                Spacer()

                Button("Rever configuração") {
                    onClose()
                    model.openOnboarding()
                }
                .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))
            }

            Text("Feito pela Cultura Builder.")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
        }
    }

    private func settingToggle(
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

    private func aboutRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CBTheme.lime)
                .frame(width: 16)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text(detail)
                    .font(.system(size: 9.3, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            if saved {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CBTheme.mint)
                    Text("Ajustes salvos")
                }
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .transition(.opacity)
            } else {
                Text("As alterações ficam salvas neste Mac.")
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
            }

            Spacer()

            Button("Fechar", action: onClose)
                .buttonStyle(GhostButtonStyle())

            Button {
                save()
            } label: {
                Text("Salvar alterações")
            }
            .buttonStyle(LimeButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .overlay(
            Rectangle()
                .fill(CBTheme.hairline)
                .frame(height: 1),
            alignment: .top
        )
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
        for folder in picked {
            guard !draft.folders.contains(where: { $0.path == folder.path }) else { continue }
            draft.folders.append(folder)
        }
    }

    private func addExclusion() {
        let panel = NSOpenPanel()
        panel.title = "Ignorar subpasta"
        panel.message = "Escolha uma pasta que não deve entrar nas próximas varreduras."
        panel.prompt = "Ignorar"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let path = url.standardizedFileURL.path
            if !draft.excludedPaths.contains(path) {
                draft.excludedPaths.append(path)
            }
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

    private func save() {
        draft.hasCompletedOnboarding = true
        model.updateSettings(draft)
        model.setLaunchAtLogin(launchAtLogin)
        withAnimation(.easeInOut(duration: 0.18)) {
            saved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.18)) {
                saved = false
            }
        }
    }
}
