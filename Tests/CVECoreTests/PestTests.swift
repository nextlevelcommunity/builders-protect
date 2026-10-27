import Foundation
import XCTest
@testable import CVECore

final class PestKnowledgeTests: XCTestCase {
    func testBundledCatalogLoads() {
        let knowledge = PestKnowledgeBase()
        XCTAssertGreaterThanOrEqual(knowledge.checks.count, 20)
        XCTAssertTrue(knowledge.checks.contains { $0.id == "sqli-concat" })
        for check in knowledge.checks {
            XCTAssertFalse(check.id.isEmpty)
            XCTAssertFalse(check.title.isEmpty)
            XCTAssertFalse(check.guidance.isEmpty)
            XCTAssertFalse(check.remediation.isEmpty)
        }
    }

    func testSelectChecksPrefersMatchingStack() {
        let project = ProjectRef(
            path: "/tmp/example",
            name: "example",
            lockfiles: ["package-lock.json"],
            ecosystems: ["npm"]
        )
        let checks = PestKnowledgeBase().selectChecks(
            project: project,
            filePaths: ["src/auth/login.ts", "src/routes/payment.ts"],
            limit: 12
        )
        XCTAssertFalse(checks.isEmpty)
        XCTAssertTrue(checks.contains { $0.languages.contains("ts") || $0.tags.contains("js") })
        XCTAssertFalse(checks.contains { $0.id == "nginx-hsts-missing" })
    }
}

final class PestCollectorTests: XCTestCase {
    func testInventorySkipsHeavySensitiveAndLockfiles() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("pest-inventory-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        let modules = root.appendingPathComponent("node_modules/pkg", isDirectory: true)
        try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modules, withIntermediateDirectories: true)

        try "let value = 1\n".write(to: sources.appendingPathComponent("App.swift"), atomically: true, encoding: .utf8)
        try "# Projeto\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try #"{"name":"example"}"#.write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try #"{"lockfileVersion":3}"#.write(to: root.appendingPathComponent("package-lock.json"), atomically: true, encoding: .utf8)
        try "TOKEN=secret\n".write(to: root.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        try "console.log('dependency')\n".write(to: modules.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)

        let inventory = try PestCollector(
            maxFiles: 10,
            maxFileBytes: 10_000,
            maxTotalBytes: 50_000
        ).inventory(projectPath: root.path)

        let paths = inventory.files.map(\.path)
        XCTAssertTrue(paths.contains("Sources/App.swift"))
        XCTAssertTrue(paths.contains("package.json"))
        XCTAssertFalse(paths.contains { $0.contains("node_modules") })
        XCTAssertFalse(paths.contains(".env"))
        XCTAssertFalse(paths.contains("package-lock.json"))
        XCTAssertGreaterThan(inventory.skippedFiles, 0)
    }

    func testReaderRedactsSecretsAndTruncates() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("pest-reader-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let token = "ghp_" + String(repeating: "a", count: 36)
        let content = "\(token)\nlet other = 2\n"
        try content.write(to: root.appendingPathComponent("Config.swift"), atomically: true, encoding: .utf8)

        let ref = PestFileRef(path: "Config.swift", bytes: content.utf8.count, priority: 20)
        let reader = PestReader()
        let source = try XCTUnwrap(reader.read(ref, projectPath: root.path, maxBytes: 45))
        XCTAssertTrue(source.truncated)
        XCTAssertFalse(source.content.contains(token))
        XCTAssertTrue(source.content.contains("[REDACTED]"))
        XCTAssertGreaterThan(source.redactions, 0)
        XCTAssertEqual(source.firstRedactionLine, 1)
    }

    func testChunksRespectCharacterBudget() {
        let refs = (0..<6).map {
            PestFileRef(path: "File\($0).swift", bytes: 900, priority: $0)
        }
        let chunks = PestCollector().chunks(of: refs, maxCharacters: 2_000)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.flatMap { $0 }.count, refs.count)
    }
}

final class PestPlannerTests: XCTestCase {
    func testSpacingConflictAndCircularMidnight() {
        let first = PestRoutine(projectPath: "/a", projectName: "A", hour: 23, minute: 50)
        let second = PestRoutine(projectPath: "/b", projectName: "B", hour: 0, minute: 10)

        XCTAssertNotNil(
            PestRoutinePlanner.conflict(
                hour: 0,
                minute: 20,
                projectPath: "/c",
                routines: [first, second]
            )
        )
        XCTAssertNil(
            PestRoutinePlanner.conflict(
                hour: 0,
                minute: 40,
                projectPath: "/c",
                routines: [first, second]
            )
        )
        XCTAssertNotNil(
            PestRoutinePlanner.conflict(
                hour: 9,
                minute: 0,
                projectPath: "/a",
                routines: [first]
            )
        )
    }

    func testSuggestedSlotFindsThirtyMinuteGap() {
        let routine = PestRoutine(projectPath: "/a", projectName: "A", hour: 10, minute: 0)
        let slot = PestRoutinePlanner.suggestedSlot(
            desiredHour: 10,
            desiredMinute: 0,
            projectPath: "/b",
            routines: [routine]
        )
        XCTAssertEqual(slot?.hour, 10)
        XCTAssertEqual(slot?.minute, 30)
    }

    func testNextRunAndDueWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9, minute: 0))
        )
        let routine = PestRoutine(
            projectPath: "/a",
            projectName: "A",
            hour: 10,
            minute: 0
        )
        let next = try XCTUnwrap(
            PestRoutinePlanner.nextRunDate(for: routine, after: now, calendar: calendar)
        )
        XCTAssertEqual(calendar.component(.day, from: next), 5)
        XCTAssertEqual(calendar.component(.hour, from: next), 10)

        var ran = routine
        ran.lastRunAt = next
        XCTAssertFalse(PestRoutinePlanner.isDue(ran, now: next.addingTimeInterval(60), calendar: calendar))
        XCTAssertTrue(PestRoutinePlanner.isDue(routine, now: next.addingTimeInterval(60), calendar: calendar))

        let tomorrow = try XCTUnwrap(
            PestRoutinePlanner.nextRunDate(for: ran, after: next.addingTimeInterval(60), calendar: calendar)
        )
        XCTAssertEqual(calendar.component(.day, from: tomorrow), 6)
    }

    func testRuntimeSpacing() throws {
        let now = Date()
        XCTAssertTrue(PestRoutinePlanner.canRunNow(lastRunAt: nil, now: now))
        XCTAssertFalse(
            PestRoutinePlanner.canRunNow(lastRunAt: now.addingTimeInterval(-600), now: now)
        )
        XCTAssertTrue(
            PestRoutinePlanner.canRunNow(lastRunAt: now.addingTimeInterval(-1_800), now: now)
        )
    }
}

final class PestStaticAnalyzerTests: XCTestCase {
    func testStaticAnalyzerFindsSQLInjectionAndBuildsFixPrompt() throws {
        let check = try XCTUnwrap(
            PestKnowledgeBase().checks.first { $0.id == "sqli-concat" }
        )
        let source = PestSourceFile(
            path: "Sources/Repository.swift",
            content: """
            func find(_ request: Request) {
                let sql = "SELECT * FROM users WHERE id = " + request.query.id
                database.execute(sql)
            }
            """,
            bytes: 180,
            truncated: false,
            redactions: 0,
            firstRedactionLine: nil
        )
        let project = ProjectRef(
            path: "/tmp/example",
            name: "example",
            lockfiles: [],
            ecosystems: ["Swift"]
        )
        let findings = PestStaticAnalyzer().analyze(
            files: [source],
            checks: [check],
            project: project
        )
        let finding = try XCTUnwrap(findings.first)
        XCTAssertEqual(finding.checkID, "sqli-concat")
        XCTAssertEqual(finding.file, "Sources/Repository.swift")
        XCTAssertEqual(finding.line, 2)
        XCTAssertFalse(finding.fixPrompt.isEmpty)
        XCTAssertTrue(finding.fixPrompt.contains("/tmp/example/Sources/Repository.swift:2"))
    }
}

final class PestServiceTests: XCTestCase {
    func testLocalPipelineProducesReportWithFixPromptForEveryFinding() async throws {
        let snapshot = PestMemoryGuard.snapshot()
        try XCTSkipIf(
            PestMemoryGuard.budget(for: snapshot) == nil,
            "Sem memória/disco mínimos para rodar o Pest neste ambiente."
        )

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("pest-service-\(UUID().uuidString)", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let code = """
        func find(_ request: Request) {
            let sql = "SELECT * FROM users WHERE id = " + request.query.id
            database.execute(sql)
        }
        """
        try code.write(to: sources.appendingPathComponent("Repository.swift"), atomically: true, encoding: .utf8)

        let project = ProjectRef(
            path: root.path,
            name: "fixture",
            lockfiles: [],
            ecosystems: ["Swift"]
        )
        let report = try await PestService().analyze(
            project: project,
            useLLM: false,
            progress: { _ in }
        )

        XCTAssertFalse(report.paused)
        XCTAssertEqual(report.projectPath, root.path)
        XCTAssertGreaterThan(report.filesAnalyzed, 0)
        XCTAssertFalse(report.findings.isEmpty)
        XCTAssertTrue(report.findings.allSatisfy { !$0.fixPrompt.isEmpty })
        XCTAssertTrue(report.findings.allSatisfy { $0.file == "Sources/Repository.swift" })
    }
}
