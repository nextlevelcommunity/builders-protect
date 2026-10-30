import Foundation

enum Vocabulary {
    private static let englishUnits: [String: (singular: String, plural: String)] = [
        "projeto": ("project", "projects"),
        "projetos": ("project", "projects"),
        "lockfile": ("lockfile", "lockfiles"),
        "pacote": ("package", "packages"),
        "pacotes": ("package", "packages"),
        "pasta": ("folder", "folders"),
        "pastas": ("folder", "folders"),
        "pasta excluída": ("excluded folder", "excluded folders"),
        "pasta selecionada": ("selected folder", "selected folders"),
        "ponto": ("point", "points"),
        "ponto de atenção": ("point of attention", "points of attention"),
        "ponto crítico": ("critical point", "critical points"),
        "ponto alto": ("high point", "high points"),
        "projeto monitorado": ("monitored project", "monitored projects"),
        "ignorado": ("ignored", "ignored"),
        "worktree ignorada": ("worktree ignored", "worktrees ignored"),
        "arquivo": ("file", "files"),
        "arquivos": ("file", "files"),
        "achado": ("finding", "findings"),
        "achados": ("finding", "findings"),
        "rodada": ("run", "runs"),
        "horário": ("time", "times"),
        "bloco": ("chunk", "chunks")
    ]

    static func quantity(_ value: Int, _ singular: String, _ plural: String) -> String {
        if !L10n.isPortuguese,
           let unit = englishUnits[singular.lowercased()] {
            return "\(value) \(value == 1 ? unit.singular : unit.plural)"
        }
        return "\(value) \(value == 1 ? singular : plural)"
    }

    static func clean(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(
            of: "cve.now",
            with: "base de vulnerabilidades",
            options: [.caseInsensitive]
        )
        value = value.replacingOccurrences(of: "CVE Builders", with: "Builders Protect")
        value = value.replacingOccurrences(of: "Builders Protect", with: "\u{1}")
        value = value.replacingOccurrences(of: "nenhum CVE marcado", with: "nenhuma vulnerabilidade marcada")
        value = value.replacingOccurrences(of: "nenhum CVE", with: "nenhuma vulnerabilidade")
        value = value.replacingOccurrences(of: "um CVE", with: "uma vulnerabilidade")
        value = value.replacingOccurrences(of: "o CVE", with: "a vulnerabilidade")
        value = value.replacingOccurrences(of: "do CVE", with: "da vulnerabilidade")
        value = value.replacingOccurrences(of: "no CVE", with: "na vulnerabilidade")
        value = value.replacingOccurrences(of: "ao CVE", with: "à vulnerabilidade")
        value = value.replacingOccurrences(of: "este CVE", with: "esta vulnerabilidade")
        value = value.replacingOccurrences(of: "esse CVE", with: "essa vulnerabilidade")
        value = value.replacingOccurrences(of: "CVE marcado", with: "vulnerabilidade marcada")
        value = value.replacingOccurrences(of: "CVE confirmada", with: "vulnerabilidade confirmada")
        value = value.replacingOccurrences(of: "CVE nova", with: "vulnerabilidade nova")
        value = value.replacingOccurrences(
            of: #"\bCVEs\b"#,
            with: "vulnerabilidades",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\bCVE\b(?!-)"#,
            with: "vulnerabilidade",
            options: .regularExpression
        )
        return value.replacingOccurrences(of: "\u{1}", with: "Builders Protect")
    }

    static func prose(_ text: String) -> String {
        var value = scrub(text)
        value = value.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+([,.;:])"#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #",\s*,"#,
            with: ",",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\(\s*\)"#,
            with: "",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func prompt(_ text: String) -> String {
        var value = text.replacingOccurrences(
            of: #"https?://\S+"#,
            with: "",
            options: .regularExpression
        )
        value = scrub(value).replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"[ \t]+([,.;:])"#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #",\s*,"#,
            with: ",",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\(\s*\)"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?m)[ \t]*\|[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?m)(\|[ \t]*){2,}"#,
            with: "| ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?m)^([ \t]*-[ \t]*)vulnerabilidade[ \t]*\|[ \t]*risco relevante[ \t]*\|[ \t]*"#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?m)[ \t]+$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func scrub(_ text: String) -> String {
        var value = text

        value = value.replacingOccurrences(
            of: #"\(\s*(?:CVE-\d{4}-\d{4,}\s*[,;]?\s*)+\)"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\bCVE-\d{4}-\d{4,}\b"#,
            with: "vulnerabilidade",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\b\d+\s+(?:vulnerabilidades|CVEs?)\b"#,
            with: "vulnerabilidades",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"vulnerabilidade(?:\s*,\s*vulnerabilidade)+(?:\s*e\s*vulnerabilidade)?"#,
            with: "múltiplas vulnerabilidades",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"vulnerabilidade\s+e\s+vulnerabilidade"#,
            with: "vulnerabilidades",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"vulnerabilidades?,\s*incluindo\s+múltiplas vulnerabilidades"#,
            with: "múltiplas vulnerabilidades",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\(CVSS\s*[\d.]+(?:\s*[–-]\s*[\d.]+)?\)"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\b(?:CVSS|risco|score|pontuação)\s*(?:de\s+|até\s+|de\s+até\s+)?\d+(?:[.,]\d+)?"#,
            with: "risco relevante",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\bCVSS\b"#,
            with: "risco",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\bencontrados vulnerabilidades\b"#,
            with: "encontradas vulnerabilidades",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\(\s*(?:vulnerabilidade|risco relevante)(?:\s*,\s*(?:vulnerabilidade|risco relevante))*\s*\)"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\bvulnerabilidade,\s*risco relevante\b"#,
            with: "vulnerabilidade",
            options: .regularExpression
        )

        return clean(value)
    }

    static func headline(_ text: String) -> String {
        var value = prose(text)
        value = value.replacingOccurrences(
            of: #"[;,]?\s*\d+\s+vulnerabilidades?(\s+no total)?"#,
            with: "",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
