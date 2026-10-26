import Foundation

public enum CVEMCPError: Error, LocalizedError {
    case transport(String)
    case invalidResponse(String)
    case toolError(String)

    public var errorDescription: String? {
        switch self {
        case .transport(let detail): return detail
        case .invalidResponse(let detail): return detail
        case .toolError(let detail): return detail
        }
    }
}

public struct CVEMatch: Sendable {
    public var id: String
    public var title: String
    public var cvss: Double?
    public var severity: RiskLevel
    public var url: String
    public var packageName: String
    public var installedVersion: String
    public var ecosystem: String

    public init(
        id: String,
        title: String,
        cvss: Double?,
        severity: RiskLevel,
        url: String,
        packageName: String,
        installedVersion: String,
        ecosystem: String
    ) {
        self.id = id
        self.title = title
        self.cvss = cvss
        self.severity = severity
        self.url = url
        self.packageName = packageName
        self.installedVersion = installedVersion
        self.ecosystem = ecosystem
    }
}

public struct CVEAffectedRange: Sendable {
    public var ecosystem: String?
    public var package: String?
    public var introduced: String?
    public var fixed: String?
}

public struct CVEDetail: Sendable {
    public var id: String
    public var title: String
    public var description: String
    public var cvss: Double?
    public var isKEV: Bool
    public var ranges: [CVEAffectedRange]
    public var references: [String]

    public func fixedVersion(
        package: String,
        ecosystem: String,
        installedVersion: String
    ) -> String? {
        let relevant = ranges.filter { range in
            guard let rangePackage = range.package else { return false }
            if rangePackage != package { return false }
            if let rangeEcosystem = range.ecosystem, rangeEcosystem != ecosystem {
                return false
            }
            return true
        }

        let candidates = relevant.compactMap { range -> String? in
            guard let fixed = range.fixed else { return nil }
            if let introduced = range.introduced,
               Semver.compare(installedVersion, introduced) < 0 {
                return nil
            }
            if Semver.compare(installedVersion, fixed) >= 0 {
                return nil
            }
            return fixed
        }

        return candidates.min(by: Semver.lessThan)
    }
}

public struct CVEMCPClient: Sendable {
    public static let defaultEndpoint = URL(string: "https://mcp.cve.now/mcp")!

    private let endpoint: URL
    private let session: URLSession

    public init(
        endpoint: URL = CVEMCPClient.defaultEndpoint,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    public func check(payload: LockfilePayload) async throws -> [CVEMatch] {
        var arguments: [String: Any] = [:]
        if !payload.packages.isEmpty {
            arguments["packages"] = payload.packages.map { package in
                [
                    "ecosystem": package.ecosystem,
                    "name": package.name,
                    "version": package.version
                ]
            }
        } else if let content = payload.content, !content.isEmpty {
            arguments["lockfile_name"] = payload.name
            arguments["lockfile_content"] = content
        } else {
            return []
        }

        let result = try await callTool(name: "check_stack", arguments: arguments)
        guard let text = result else { return [] }
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CVEMCPError.invalidResponse("A base de vulnerabilidades devolveu uma resposta inesperada.")
        }

        if let errors = root["errors"] as? [Any], !errors.isEmpty {
            let message = errors.compactMap { $0 as? String }.joined(separator: " ")
            if !message.isEmpty {
                throw CVEMCPError.toolError(message)
            }
        }

        guard let affected = root["affected"] as? [[String: Any]] else {
            return []
        }

        return affected.compactMap { item in
            guard let id = item["id"] as? String,
                  let title = item["title"] as? String,
                  let package = item["package"] as? [String: Any],
                  let name = package["name"] as? String,
                  let version = package["version"] as? String else {
                return nil
            }
            let ecosystem = package["ecosystem"] as? String ?? "npm"
            let severityObject = item["severity"] as? [String: Any]
            let cvss = (severityObject?["cvss"] as? NSNumber)?.doubleValue
            let url = item["url"] as? String ?? "https://cve.now/\(id)"
            return CVEMatch(
                id: id,
                title: title,
                cvss: cvss,
                severity: RiskLevel.from(cvss: cvss),
                url: url,
                packageName: name,
                installedVersion: version,
                ecosystem: ecosystem
            )
        }
    }

    public func vulnerability(id: String) async throws -> CVEDetail? {
        let result = try await callTool(
            name: "get_vulnerability",
            arguments: ["id": id]
        )
        guard let text = result,
              let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let detailID = root["id"] as? String else { return nil }
        let title = root["title"] as? String ?? detailID
        let description = (root["originalDescription"] as? String)
            ?? (root["summary"] as? String)
            ?? ""
        let severityObject = root["severity"] as? [String: Any]
        let cvss = (severityObject?["cvss"] as? NSNumber)?.doubleValue

        var isKEV = false
        if let exploitation = root["exploitation"] as? [String: Any],
           let kev = exploitation["kev"],
           !(kev is NSNull) {
            isKEV = true
        }

        var ranges: [CVEAffectedRange] = []
        if let affected = root["affected"] as? [[String: Any]] {
            for entry in affected {
                guard let rawRanges = entry["ranges"] as? [[String: Any]] else { continue }
                let ecosystem = entry["ecosystem"] as? String
                let package = entry["package"] as? String
                for rawRange in rawRanges {
                    ranges.append(
                        CVEAffectedRange(
                            ecosystem: ecosystem,
                            package: package,
                            introduced: rawRange["introduced"] as? String,
                            fixed: rawRange["fixed"] as? String
                        )
                    )
                }
            }
        }

        var references: [String] = []
        if let rawReferences = root["references"] as? [[String: Any]] {
            for reference in rawReferences {
                if let url = reference["url"] as? String, !url.isEmpty {
                    references.append(url)
                }
                if references.count >= 3 { break }
            }
        }

        return CVEDetail(
            id: detailID,
            title: title,
            description: description,
            cvss: cvss,
            isKEV: isKEV,
            ranges: ranges,
            references: references
        )
    }

    private func callTool(
        name: String,
        arguments: [String: Any]
    ) async throws -> String? {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1...9_999_999),
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "application/json, text/event-stream",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw CVEMCPError.transport("Não consegui falar com a base de vulnerabilidades.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw CVEMCPError.invalidResponse("Resposta inválida da base de vulnerabilidades.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CVEMCPError.invalidResponse("A base de vulnerabilidades respondeu com erro \(http.statusCode).")
        }

        let root = try decodeJSONRPC(
            data: responseData,
            contentType: http.value(forHTTPHeaderField: "Content-Type") ?? ""
        )

        if let error = root["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Erro desconhecido na base de vulnerabilidades."
            throw CVEMCPError.toolError(message)
        }

        guard let result = root["result"] as? [String: Any] else {
            throw CVEMCPError.invalidResponse("A base de vulnerabilidades não devolveu um resultado.")
        }

        if result["isError"] as? Bool == true {
            let message = toolText(from: result) ?? "A ferramenta da base de vulnerabilidades falhou."
            throw CVEMCPError.toolError(message)
        }

        return toolText(from: result)
    }

    private func toolText(from result: [String: Any]) -> String? {
        guard let content = result["content"] as? [[String: Any]] else { return nil }
        for item in content {
            if let text = item["text"] as? String, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    private func decodeJSONRPC(
        data: Data,
        contentType: String
    ) throws -> [String: Any] {
        if contentType.contains("text/event-stream") {
            guard let text = String(data: data, encoding: .utf8) else {
                throw CVEMCPError.invalidResponse("Resposta SSE inválida da base de vulnerabilidades.")
            }
            for line in text.split(separator: "\n").reversed() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("data:") else { continue }
                let jsonText = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard let jsonData = jsonText.data(using: .utf8),
                      let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                return root
            }
            throw CVEMCPError.invalidResponse("A base de vulnerabilidades não devolveu um evento válido.")
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CVEMCPError.invalidResponse("A base de vulnerabilidades devolveu um JSON inválido.")
        }
        return root
    }
}
