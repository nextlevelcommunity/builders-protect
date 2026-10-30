import Foundation

/// Como o app conversa com a IA.
///
/// - `standard` usa o gateway da Cultura Builder com a sessão do proxy (`builder-auto`).
/// - `rtx` usa o endpoint RTX com uma chave dedicada e o modelo sem censura (`The Psy RTX`).
public enum AnalysisMode: String, Codable, CaseIterable, Sendable {
    case standard
    case rtx

    public var isHack: Bool { self == .rtx }
}

/// Idioma da interface. O padrão segue o idioma do sistema e cai em inglês
/// quando o sistema não é português.
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case english
    case portuguese

    public var resolvedCode: String {
        switch self {
        case .english: return "en"
        case .portuguese: return "pt-BR"
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("pt") ? "pt-BR" : "en"
        }
    }

    public var isPortuguese: Bool {
        resolvedCode.hasPrefix("pt")
    }
}

public enum RTXDefaults {
    public static let endpoint = "https://llm-rtx.culturabuilder.com/v1"
    public static let model = "deepseek-v4.1-flash-1017-uncensored"
    public static let displayName = "The Psy RTX"

    /// Arquivo local usado como fallback quando a chave não foi colada em Ajustes.
    public static func keyFileURL(home: String = NSHomeDirectory()) -> URL {
        URL(fileURLWithPath: home)
            .appendingPathComponent(".config/cultura-builder-llm/rtx-litellm-key")
    }
}

public struct LLMConfiguration: Sendable {
    public var mode: AnalysisMode
    public var endpoint: URL
    public var model: String
    public var token: String?

    public init(mode: AnalysisMode, endpoint: URL, model: String, token: String?) {
        self.mode = mode
        self.endpoint = endpoint
        self.model = model
        self.token = token
    }
}

public enum LLMConfigurationError: Error, LocalizedError {
    case missingKey
    case invalidEndpoint

    public var errorDescription: String? {
        switch self {
        case .missingKey:
            return "O modo RTX precisa de uma chave dedicada. Cole a chave em Ajustes > Análises."
        case .invalidEndpoint:
            return "O endpoint RTX configurado não é uma URL válida."
        }
    }
}

public extension AppSettings {
    var rtxKey: String {
        let typed = rtxAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let file = RTXDefaults.keyFileURL()
        guard let data = try? Data(contentsOf: file),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var rtxEndpointValue: String {
        let typed = rtxEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? RTXDefaults.endpoint : typed
    }

    var rtxModelValue: String {
        let typed = rtxModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? RTXDefaults.model : typed
    }

    var hasRTXKey: Bool { !rtxKey.isEmpty }

    var language: AppLanguage { appLanguage }

    /// Configuração pronta para uma requisição. A sessão do proxy é resolvida
    /// pelo `LLMClient`, que também renova o token quando preciso.
    func llmConfiguration() throws -> LLMConfiguration {
        switch analysisMode {
        case .standard:
            return LLMConfiguration(
                mode: .standard,
                endpoint: URL(
                    string: "https://hub.culturabuilder.com/api/builder-ai/gateway/v1/chat/completions"
                )!,
                model: "builder-auto",
                token: nil
            )
        case .rtx:
            guard hasRTXKey else { throw LLMConfigurationError.missingKey }
            let base = rtxEndpointValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard var components = URLComponents(string: base) else {
                throw LLMConfigurationError.invalidEndpoint
            }
            var path = components.path
            if !path.hasSuffix("/chat/completions") {
                path += path.hasSuffix("/") ? "chat/completions" : "/chat/completions"
            }
            components.path = path
            guard let url = components.url else { throw LLMConfigurationError.invalidEndpoint }
            return LLMConfiguration(mode: .rtx, endpoint: url, model: rtxModelValue, token: rtxKey)
        }
    }
}
