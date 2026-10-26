import XCTest
@testable import CVECore

final class PromptBuilderTests: XCTestCase {
    func testCombinedPromptCoversEveryProject() {
        let high = alert(
            name: "app-high",
            path: "/tmp/app-high",
            risk: .high,
            package: "fastify",
            installed: "5.8.5",
            fixed: "5.12.5"
        )
        let medium = alert(
            name: "app-medium",
            path: "/tmp/app-medium",
            risk: .medium,
            package: "playwright",
            installed: "1.54.0",
            fixed: "1.55.1"
        )

        let prompt = PromptBuilder.buildCombined(for: [medium, high])

        XCTAssertTrue(prompt.contains("app-high"))
        XCTAssertTrue(prompt.contains("/tmp/app-high"))
        XCTAssertTrue(prompt.contains("app-medium"))
        XCTAssertTrue(prompt.contains("/tmp/app-medium"))
        XCTAssertTrue(prompt.contains("fastify@5.8.5"))
        XCTAssertTrue(prompt.contains("5.12.5"))
        XCTAssertTrue(prompt.contains("playwright@1.54.0"))
        XCTAssertTrue(prompt.contains("1.55.1"))
        XCTAssertTrue(prompt.contains("## Ordem de trabalho"))
        XCTAssertTrue(prompt.contains("## 1. app-high — ALTA"))
        XCTAssertTrue(prompt.contains("## 2. app-medium — MÉDIA"))
        XCTAssertEqual(prompt.components(separatedBy: "Regras:").count - 1, 1)
        XCTAssertTrue(prompt.contains("Critérios de conclusão:"))
    }

    private func alert(
        name: String,
        path: String,
        risk: RiskLevel,
        package: String,
        installed: String,
        fixed: String
    ) -> ProjectAlert {
        let finding = DependencyFinding(
            projectPath: path,
            cveID: "CVE-2026-0001",
            title: "Falha de teste",
            packageName: package,
            installedVersion: installed,
            ecosystem: "npm",
            cvss: 7.5,
            severity: risk,
            url: "https://example.com/\(package)",
            fixedVersion: fixed
        )
        return ProjectAlert(
            project: ProjectRef(
                path: path,
                name: name,
                lockfiles: ["package-lock.json"],
                ecosystems: ["npm"]
            ),
            findings: [finding],
            risk: risk,
            headline: "Resumo de \(name)",
            diagnosis: "Diagnóstico de \(name)",
            recommendation: "Recomendação de \(name)",
            fixPrompt: "",
            llmUsed: true
        )
    }
}
