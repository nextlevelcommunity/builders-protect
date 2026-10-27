import Foundation

public struct PestCheck: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var category: String
    public var severity: RiskLevel
    public var nuclei: String
    public var nucleiID: String
    public var tags: [String]
    public var languages: [String]
    public var fileHints: [String]
    public var guidance: String
    public var remediation: String
    public var patterns: [String]

    public init(
        id: String,
        title: String,
        category: String,
        severity: RiskLevel,
        nuclei: String,
        nucleiID: String,
        tags: [String],
        languages: [String],
        fileHints: [String],
        guidance: String,
        remediation: String,
        patterns: [String]
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.severity = severity
        self.nuclei = nuclei
        self.nucleiID = nucleiID
        self.tags = tags
        self.languages = languages
        self.fileHints = fileHints
        self.guidance = guidance
        self.remediation = remediation
        self.patterns = patterns
    }
}

public struct PestKnowledge: Codable, Sendable {
    public var version: String
    public var source: String
    public var updatedAt: String
    public var notes: String
    public var checks: [PestCheck]

    public init(
        version: String,
        source: String,
        updatedAt: String,
        notes: String,
        checks: [PestCheck]
    ) {
        self.version = version
        self.source = source
        self.updatedAt = updatedAt
        self.notes = notes
        self.checks = checks
    }
}

public struct PestKnowledgeBase: Sendable {
    public let knowledge: PestKnowledge

    public static let shared = PestKnowledgeBase()

    public init(knowledge: PestKnowledge) {
        self.knowledge = knowledge
    }

    public init(checks: [PestCheck]) {
        self.knowledge = PestKnowledge(
            version: "local",
            source: "local",
            updatedAt: "",
            notes: "",
            checks: checks
        )
    }

    public init() {
        if let loaded = Self.loadBundled() {
            self = loaded
        } else {
            self = PestKnowledgeBase(checks: Self.fallbackChecks)
        }
    }

    public var checks: [PestCheck] { knowledge.checks }

    public var summaryLabel: String {
        let categories = Set(checks.map(\.category)).count
        return "\(checks.count) checks · \(categories) categorias · base \(knowledge.version)"
    }

    public func selectChecks(
        project: ProjectRef,
        filePaths: [String],
        limit: Int = 20
    ) -> [PestCheck] {
        guard !checks.isEmpty else { return [] }
        let lowerPaths = filePaths.map { $0.lowercased() }
        let extensions = Set(
            filePaths.compactMap { path -> String? in
                let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
                return ext.isEmpty ? nil : ext
            }
        )
        let stackTags = inferStackTags(project: project, extensions: extensions)
        let hasConfig = extensions.contains("conf")
            || extensions.contains("yaml")
            || extensions.contains("yml")
            || extensions.contains("toml")
            || extensions.contains("ini")
            || extensions.contains("json")

        var scored: [(check: PestCheck, score: Int)] = []
        for check in checks {
            var score = check.severity.rank * 2
            if !check.languages.isEmpty {
                let matches = check.languages.contains { language in
                    stackTags.contains(language) || extensions.contains(language)
                }
                score += matches ? 6 : -10
            }
            for tag in check.tags where stackTags.contains(tag) {
                score += 3
            }
            for hint in check.fileHints where lowerPaths.contains(where: { $0.contains(hint) }) {
                score += 2
            }
            if !check.patterns.isEmpty {
                score += 1
            }
            if check.category == "Hardening" && !hasConfig {
                score -= 8
            }
            if check.id == "nginx-hsts-missing" && !lowerPaths.contains(where: { $0.contains("nginx") }) {
                score -= 10
            }
            if check.id == "apache-directory-listing" && !lowerPaths.contains(where: {
                $0.contains("apache") || $0.contains("httpd") || $0.contains("htaccess")
            }) {
                score -= 10
            }
            scored.append((check, score))
        }

        return scored
            .sorted { left, right in
                if left.score != right.score { return left.score > right.score }
                if left.check.severity != right.check.severity {
                    return left.check.severity > right.check.severity
                }
                return left.check.id < right.check.id
            }
            .prefix(limit)
            .map(\.check)
    }

    private func inferStackTags(project: ProjectRef, extensions: Set<String>) -> Set<String> {
        var tags = Set<String>()
        for ecosystem in project.ecosystems.map({ $0.lowercased() }) {
            switch ecosystem {
            case "npm":
                tags.formUnion(["js", "ts", "node", "javascript", "typescript", "frontend", "browser"])
            case "pypi":
                tags.formUnion(["py", "python", "django", "flask"])
            case "cargo":
                tags.formUnion(["rust", "rs"])
            case "go":
                tags.formUnion(["go", "golang"])
            case "rubygems":
                tags.formUnion(["rb", "ruby", "rails"])
            case "hex":
                tags.formUnion(["elixir"])
            default:
                break
            }
        }
        for ext in extensions {
            switch ext {
            case "js", "jsx", "mjs", "cjs":
                tags.formUnion(["js", "javascript", "node", "frontend", "browser"])
            case "ts", "tsx":
                tags.formUnion(["ts", "typescript", "node", "frontend", "browser"])
            case "vue", "svelte", "html":
                tags.formUnion(["frontend", "browser", "xss", "dom"])
            case "py":
                tags.formUnion(["py", "python"])
            case "rb":
                tags.formUnion(["rb", "ruby"])
            case "go":
                tags.formUnion(["go", "golang"])
            case "rs":
                tags.formUnion(["rust"])
            case "java", "kt", "kts":
                tags.formUnion(["java", "jvm"])
            case "php":
                tags.formUnion(["php"])
            case "cs":
                tags.formUnion(["dotnet", "csharp"])
            case "swift":
                tags.formUnion(["swift", "apple"])
            case "conf", "yaml", "yml", "toml", "ini", "json", "plist":
                tags.formUnion(["config", "hardening"])
            default:
                break
            }
        }
        let paths = project.lockfiles.joined(separator: " ").lowercased()
        if paths.contains("package-lock") || paths.contains("pnpm-lock") || paths.contains("yarn.lock") {
            tags.formUnion(["node", "js", "ts", "frontend"])
        }
        if paths.contains("requirements.txt") || paths.contains("poetry.lock") {
            tags.formUnion(["python", "py"])
        }
        return tags
    }

    private static func loadBundled() -> PestKnowledgeBase? {
        let candidates: [URL?] = [
            Bundle.module.url(
                forResource: "PestKnowledge",
                withExtension: "json",
                subdirectory: "Resources"
            ),
            Bundle.module.url(forResource: "PestKnowledge", withExtension: "json"),
            Bundle.module.url(
                forResource: "PestKnowledge",
                withExtension: "json",
                subdirectory: "CVECore_CVECore.bundle/Resources"
            )
        ]
        let decoder = JSONDecoder()
        for case let url? in candidates {
            guard let data = try? Data(contentsOf: url),
                  let knowledge = try? decoder.decode(PestKnowledge.self, from: data),
                  !knowledge.checks.isEmpty else {
                continue
            }
            return PestKnowledgeBase(knowledge: knowledge)
        }
        return nil
    }

    private static let fallbackChecks: [PestCheck] = [
        PestCheck(
            id: "hardcoded-secret",
            title: "Segredo ou credencial embutida no código",
            category: "Exposição",
            severity: .high,
            nuclei: "file/js/js-analyse.yaml",
            nucleiID: "js-analyse",
            tags: ["secret", "token", "keys"],
            languages: [],
            fileHints: ["config", "auth", "api"],
            guidance: "Procure chaves, tokens e senhas escritos no código.",
            remediation: "Mova o segredo para variável de ambiente ou gerenciador de segredos e revogue o valor exposto.",
            patterns: ["(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"]
        ),
        PestCheck(
            id: "sqli-concat",
            title: "SQL injection por concatenação",
            category: "Injection",
            severity: .critical,
            nuclei: "dast/vulnerabilities/sqli/sqli-error-based.yaml",
            nucleiID: "sqli-error-based",
            tags: ["sqli", "injection", "database"],
            languages: ["js", "ts", "py", "rb", "go", "java", "php"],
            fileHints: ["sql", "query", "repository", "dao"],
            guidance: "Procure consultas SQL montadas com entrada externa.",
            remediation: "Use consultas parametrizadas.",
            patterns: []
        ),
        PestCheck(
            id: "authorization-idor",
            title: "Autorização ausente ou IDOR",
            category: "Autorização",
            severity: .high,
            nuclei: "",
            nucleiID: "",
            tags: ["auth", "authorization", "idor"],
            languages: [],
            fileHints: ["route", "controller", "api", "user"],
            guidance: "Verifique se cada recurso confirma dono, tenant e permissão.",
            remediation: "Centralize a autorização no servidor e negue por padrão.",
            patterns: []
        )
    ]
}
