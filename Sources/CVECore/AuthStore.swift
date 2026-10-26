import Foundation

public struct BuilderAuthStatus: Sendable {
    public var connected: Bool
    public var needsLogin: Bool
    public var hasRefreshToken: Bool
    public var loginCommand: String
    public var authFilePath: String?
    public var expiresAt: Date?
    public var accountLabel: String

    public init(
        connected: Bool,
        needsLogin: Bool,
        hasRefreshToken: Bool,
        loginCommand: String,
        authFilePath: String?,
        expiresAt: Date?,
        accountLabel: String
    ) {
        self.connected = connected
        self.needsLogin = needsLogin
        self.hasRefreshToken = hasRefreshToken
        self.loginCommand = loginCommand
        self.authFilePath = authFilePath
        self.expiresAt = expiresAt
        self.accountLabel = accountLabel
    }

    public var expiryLabel: String? {
        guard let expiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expiresAt)
    }
}

public enum BuilderAuthError: Error, LocalizedError {
    case notFound
    case invalidFile
    case sessionExpired(String)
    case refreshFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Não encontrei uma sessão da Cultura Builder neste Mac."
        case .invalidFile:
            return "A sessão da Cultura Builder está em um formato inesperado."
        case .sessionExpired(let command):
            return "Sua sessão da Cultura Builder expirou. Rode `\(command)` e tente de novo."
        case .refreshFailed(let detail):
            return "Não consegui renovar sua sessão da Cultura Builder. \(detail)"
        }
    }
}

private struct BuilderSession {
    var fileURL: URL
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date?
    var loginCommand: String
    var accountLabel: String

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date().addingTimeInterval(30)
    }
}

public final class BuilderAuthStore: @unchecked Sendable {
    public static let shared = BuilderAuthStore()

    private let hubURL: URL
    private let session: URLSession

    public init(
        hubURL: URL = URL(string: "https://hub.culturabuilder.com")!,
        session: URLSession = .shared
    ) {
        self.hubURL = hubURL
        self.session = session
    }

    public func status() -> BuilderAuthStatus {
        guard let found = try? loadSession() else {
            return BuilderAuthStatus(
                connected: false,
                needsLogin: true,
                hasRefreshToken: false,
                loginCommand: "culturabuilder auth login",
                authFilePath: nil,
                expiresAt: nil,
                accountLabel: "Cultura Builder"
            )
        }

        let canRefresh = !found.refreshToken.isEmpty
        let connected = !found.isExpired || canRefresh
        return BuilderAuthStatus(
            connected: connected,
            needsLogin: !connected,
            hasRefreshToken: canRefresh,
            loginCommand: found.loginCommand,
            authFilePath: found.fileURL.path,
            expiresAt: found.expiresAt,
            accountLabel: found.accountLabel
        )
    }

    public func validAccessToken() async throws -> String {
        let found = try loadSession()
        if !found.isExpired {
            return found.accessToken
        }
        return try await refresh(found)
    }

    public func forceRefresh() async throws -> String {
        let found = try loadSession()
        return try await refresh(found)
    }

    public static func candidateAuthPaths(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory()
    ) -> [String] {
        var paths: [String] = []

        if let configDir = environment["OPENCODE_CONFIG_DIR"], !configDir.isEmpty {
            paths.append("\(configDir)/data/opencode/auth.json")
        }
        if let configFile = environment["OPENCODE_CONFIG"], !configFile.isEmpty {
            let directory = (configFile as NSString).deletingLastPathComponent
            paths.append("\(directory)/data/opencode/auth.json")
        }
        if let xdgConfig = environment["XDG_CONFIG_HOME"], !xdgConfig.isEmpty {
            paths.append("\(xdgConfig)/builder-ai/opencode/data/opencode/auth.json")
        }
        if let xdgData = environment["XDG_DATA_HOME"], !xdgData.isEmpty {
            paths.append("\(xdgData)/opencode/auth.json")
        }

        paths.append(contentsOf: [
            "\(home)/Library/Application Support/CulturaBuilder/opencode/data/opencode/auth.json",
            "\(home)/Library/Application Support/BuilderAI/opencode/data/opencode/auth.json",
            "\(home)/.config/builder-ai/opencode/data/opencode/auth.json",
            "\(home)/.config/cultura-builder/opencode/data/opencode/auth.json",
            "\(home)/.local/share/opencode/auth.json"
        ])

        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    private func refresh(_ found: BuilderSession) async throws -> String {
        guard !found.refreshToken.isEmpty else {
            throw BuilderAuthError.sessionExpired(found.loginCommand)
        }

        var request = URLRequest(
            url: hubURL.appendingPathComponent("/api/mcp-oauth/token")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: found.refreshToken)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BuilderAuthError.refreshFailed("Verifique sua conexão.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw BuilderAuthError.refreshFailed("Resposta inválida do servidor.")
        }
        guard http.statusCode == 200 else {
            throw BuilderAuthError.sessionExpired(found.loginCommand)
        }

        guard
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = body["access_token"] as? String,
            !access.isEmpty
        else {
            throw BuilderAuthError.refreshFailed("O servidor não devolveu um token válido.")
        }

        let newRefresh = (body["refresh_token"] as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? found.refreshToken
        let expiresIn = (body["expires_in"] as? NSNumber)?.doubleValue ?? 900
        let expiresAt = Date().addingTimeInterval(expiresIn)

        try persist(
            fileURL: found.fileURL,
            accessToken: access,
            refreshToken: newRefresh,
            expiresAt: expiresAt
        )

        return access
    }

    private func persist(
        fileURL: URL,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date
    ) throws {
        let data = try Data(contentsOf: fileURL)
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var credential = root["builder-ai"] as? [String: Any] else {
            throw BuilderAuthError.invalidFile
        }

        credential["type"] = "oauth"
        credential["access"] = accessToken
        credential["refresh"] = refreshToken
        credential["expires"] = Int(expiresAt.timeIntervalSince1970 * 1000)
        root["builder-ai"] = credential

        let encoded = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        try encoded.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private func loadSession() throws -> BuilderSession {
        for path in Self.candidateAuthPaths() {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let credential = root["builder-ai"] as? [String: Any] else {
                continue
            }
            guard
                (credential["type"] as? String) == "oauth",
                let access = credential["access"] as? String,
                !access.isEmpty
            else {
                continue
            }

            let refresh = credential["refresh"] as? String ?? ""
            var expiresAt: Date?
            if let expires = credential["expires"] as? NSNumber {
                let raw = expires.doubleValue
                let seconds = raw > 10_000_000_000 ? raw / 1000 : raw
                if seconds > 0 {
                    expiresAt = Date(timeIntervalSince1970: seconds)
                }
            }

            let identity = productIdentity(for: url)
            return BuilderSession(
                fileURL: url,
                accessToken: access,
                refreshToken: refresh,
                expiresAt: expiresAt,
                loginCommand: identity.command,
                accountLabel: identity.label
            )
        }

        throw BuilderAuthError.notFound
    }

    private func productIdentity(for url: URL) -> (command: String, label: String) {
        let path = url.path
        if path.contains("CulturaBuilder") || path.contains("cultura-builder") {
            return ("culturabuilder auth login", "Cultura Builder")
        }
        if path.contains("BuilderAI") || path.contains("builder-ai") {
            return ("builder auth login", "Builder AI")
        }
        return ("builder auth login", "Cultura Builder")
    }
}
