import CVECore
import SwiftUI

struct AISettingsView: View {
    @ObservedObject var model: AppModel
    @Binding var draft: AppSettings

    @State private var showAdvanced = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                modePicker
                if draft.analysisMode == .rtx {
                    rtxCard
                } else {
                    standardCard
                }
                privacyNote
                memoryNote
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t("IA e segurança"))
                .font(.system(size: 27, weight: .light, design: .rounded))
                .foregroundStyle(CBTheme.text)
            Text(L10n.t("Escolha como as análises consultam a IA e qual modelo responde."))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    private var modePicker: some View {
        SurfaceCard(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                SectionLabel(text: L10n.t("Modo de análise"))

                Picker(L10n.t(""), selection: $draft.analysisMode) {
                    Text(L10n.t("Padrão")).tag(AnalysisMode.standard)
                    Text(L10n.t("RTX · sem censura")).tag(AnalysisMode.rtx)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(
                    draft.analysisMode == .standard
                        ? L10n.t("Usa o gateway da Cultura Builder com a sua sessão do proxy. É o suficiente para o uso normal e não precisa de chave.", "Uses the Cultura Builder gateway with your proxy session. It is enough for normal use and needs no key.")
                        : L10n.t("Usa o endpoint RTX com uma chave dedicada e o modelo sem censura \(RTXDefaults.displayName). A busca passa a usar esse modelo principal em todas as análises.", "Uses the RTX endpoint with a dedicated key and the uncensored model \(RTXDefaults.displayName). Analysis now uses this main model everywhere.")
                )
                .font(.system(size: 10.3, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var standardCard: some View {
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
                        Text(model.authStatus.connected
                            ? L10n.t("Conta conectada", "Connected account")
                            : L10n.t("Sessão não encontrada", "Session not found"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("Faça login no proxy da Cultura Builder pelo terminal e o app usa essa sessão."))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                Divider().overlay(CBTheme.hairline)

                Text(L10n.t("Para entrar ou trocar de conta, rode no terminal:"))
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

                HStack(spacing: 8) {
                    Button {
                        model.copyLoginCommand()
                    } label: {
                        Label(L10n.t("Copiar comando"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(LimeButtonStyle())

                    Button {
                        Task { await model.refreshAuth(force: true) }
                    } label: {
                        Text(model.isRefreshingAuth ? L10n.t("Renovando…", "Renewing…") : L10n.t("Já fiz login", "I signed in"))
                    }
                    .buttonStyle(SurfaceButtonStyle())
                    .disabled(model.isRefreshingAuth)

                    Spacer(minLength: 0)

                    Button {
                        Task { await model.testLLMConnection() }
                    } label: {
                        Text(model.isTestingLLM ? L10n.t("Testando…", "Testing…") : L10n.t("Testar", "Test"))
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.isTestingLLM)
                }

                if let result = model.llmTestResult {
                    testResult(result)
                }
            }
        }
    }

    private var rtxCard: some View {
        SurfaceCard(padding: 15) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CBTheme.lime)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(RTXDefaults.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CBTheme.text)
                        Text(L10n.t("Modelo sem censura para revisão agressiva de código."))
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    Spacer()
                    Text(draft.hasRTXKey ? L10n.t("CHAVE OK", "KEY OK") : L10n.t("SEM CHAVE", "NO KEY"))
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(draft.hasRTXKey ? CBTheme.mint : CBTheme.high)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            (draft.hasRTXKey ? CBTheme.mint : CBTheme.high).opacity(0.1),
                            in: Capsule()
                        )
                }

                Divider().overlay(CBTheme.hairline)

                field(
                    title: L10n.t("Chave dedicada"),
                    detail: L10n.t("Diferente da chave local. Fica só neste Mac, em Ajustes."),
                    text: $draft.rtxAPIKey,
                    secure: true,
                    placeholder: L10n.t("cole a chave RTX")
                )

                field(
                    title: L10n.t("Endpoint"),
                    detail: L10n.t("O endpoint já tem o acesso do túnel. Só mude se a Cultura Builder indicar outro."),
                    text: $draft.rtxEndpoint,
                    secure: false,
                    placeholder: RTXDefaults.endpoint
                )

                DisclosureGroup(isExpanded: $showAdvanced) {
                    field(
                        title: L10n.t("Modelo"),
                        detail: L10n.t("Modelo servido pelo endpoint RTX."),
                        text: $draft.rtxModel,
                        secure: false,
                        placeholder: RTXDefaults.model
                    )
                } label: {
                    Text(L10n.t("Avançado"))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await model.testLLMConnection() }
                    } label: {
                        Label(model.isTestingLLM ? L10n.t("Testando…", "Testing…") : L10n.t("Testar conexão", "Test connection"), systemImage: "bolt")
                    }
                    .buttonStyle(LimeButtonStyle())
                    .disabled(model.isTestingLLM)

                    Spacer(minLength: 0)
                }

                if let result = model.llmTestResult {
                    testResult(result)
                }

                Text(L10n.t("Ao escolher este modo, todas as análises (Pest, Red Team e diagnóstico) usam o RTX no lugar do modelo padrão."))
                    .font(.system(size: 9.3, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func field(
        title: String,
        detail: String,
        text: Binding<String>,
        secure: Bool,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(CBTheme.text)
            Text(detail)
                .font(.system(size: 9.2, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(CBTheme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func testResult(_ result: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: model.llmTestOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(model.llmTestOK ? CBTheme.mint : CBTheme.high)
                .padding(.top, 1)
            Text(result)
                .font(.system(size: 9.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacyNote: some View {
        NoticeCard(
            kind: .info,
            title: L10n.t("O que vai para a IA"),
            message: L10n.t("O diagnóstico de dependências envia nomes, versões, vulnerabilidades e caminhos, sem código-fonte. Pest e Red Team só enviam código após sua autorização, com redaction de segredos. No modo RTX, o destino é o endpoint RTX.")
        )
    }

    private var memoryNote: some View {
        NoticeCard(
            kind: .warning,
            title: L10n.t("Memória em primeiro lugar"),
            message: L10n.t("Pest e Red Team rodam em blocos, com orçamento de memória e pausa automática. Se a análise pausar, retome quando o Mac estiver mais livre.")
        )
    }
}
