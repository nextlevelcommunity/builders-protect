import XCTest
@testable import CVECore

final class RTXConfigurationTests: XCTestCase {
    func testStandardModeUsesBuilderGateway() throws {
        var settings = AppSettings()
        settings.analysisMode = .standard

        let configuration = try settings.llmConfiguration()

        XCTAssertEqual(configuration.mode, .standard)
        XCTAssertEqual(configuration.model, "builder-auto")
        XCTAssertEqual(
            configuration.endpoint.absoluteString,
            "https://hub.culturabuilder.com/api/builder-ai/gateway/v1/chat/completions"
        )
        XCTAssertNil(configuration.token)
    }

    func testRTXModeRequiresKey() {
        var settings = AppSettings()
        settings.analysisMode = .rtx
        settings.rtxAPIKey = ""

        let hasLocalKeyFile = FileManager.default.fileExists(
            atPath: RTXDefaults.keyFileURL().path
        )
        if hasLocalKeyFile {
            XCTAssertNoThrow(try settings.llmConfiguration())
        } else {
            XCTAssertThrowsError(try settings.llmConfiguration()) { error in
                XCTAssertTrue(error is LLMConfigurationError)
            }
        }
    }

    func testRTXModeBuildsDedicatedEndpointAndModel() throws {
        var settings = AppSettings()
        settings.analysisMode = .rtx
        settings.rtxAPIKey = "chave-dedicada"
        settings.rtxEndpoint = "https://llm-rtx.example.com/v1/"

        let configuration = try settings.llmConfiguration()

        XCTAssertEqual(configuration.mode, .rtx)
        XCTAssertEqual(configuration.model, RTXDefaults.model)
        XCTAssertEqual(configuration.token, "chave-dedicada")
        XCTAssertEqual(
            configuration.endpoint.absoluteString,
            "https://llm-rtx.example.com/v1/chat/completions"
        )
    }

    func testLanguageDefaultsToSystemAndFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.system.resolvedCode.hasPrefix("en") || AppLanguage.system.resolvedCode.hasPrefix("pt"), true)
        XCTAssertFalse(AppLanguage.english.isPortuguese)
        XCTAssertTrue(AppLanguage.portuguese.isPortuguese)
    }
}

final class RedTeamRoutinePlannerTests: XCTestCase {
    private func routine(slots: [(Int, Int)], lastRunAt: Date? = nil) -> RedTeamRoutine {
        RedTeamRoutine(
            projectPath: "/tmp/project",
            projectName: "project",
            slots: slots.map { RedTeamSlot(hour: $0.0, minute: $0.1) },
            lastRunAt: lastRunAt
        )
    }

    func testRoutineAcceptsSeveralSlotsPerDay() {
        let routine = routine(slots: [(9, 0), (13, 0), (18, 30), (22, 0)])
        XCTAssertEqual(routine.slots.count, 4)
        XCTAssertEqual(routine.timesLabel, "09:00 · 13:00 · 18:30 · 22:00")
    }

    func testConflictRespectsMinimumSpacing() {
        let routine = routine(slots: [(9, 0)])
        XCTAssertNotNil(RedTeamRoutinePlanner.conflict(hour: 9, minute: 10, routine: routine))
        XCTAssertNil(RedTeamRoutinePlanner.conflict(hour: 9, minute: 20, routine: routine))
    }

    func testDueWhenSlotPassedAndNotRunYet() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!

        XCTAssertTrue(
            RedTeamRoutinePlanner.isDue(
                routine(slots: [(9, 0), (18, 0)]),
                now: now,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            RedTeamRoutinePlanner.isDue(
                routine(slots: [(9, 0), (18, 0)], lastRunAt: morning.addingTimeInterval(60)),
                now: now,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            RedTeamRoutinePlanner.isDue(routine(slots: [(18, 0)]), now: now, calendar: calendar)
        )
    }

    func testNextRunDatePicksUpcomingSlot() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let routine = routine(slots: [(9, 0), (15, 0)])
        let next = RedTeamRoutinePlanner.nextRunDate(for: routine, after: now, calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: next ?? now)

        XCTAssertEqual(components.hour, 15)
        XCTAssertEqual(components.minute, 0)
    }

    func testMemoryGuardRefusesBelowMinimum() {
        let low = PestMemorySnapshot(
            availableBytes: 64 * 1024 * 1024,
            residentBytes: 10,
            physicalBytes: 1,
            diskAvailableBytes: Int64.max
        )
        XCTAssertNil(RedTeamMemoryGuard.budget(for: low))
    }
}
