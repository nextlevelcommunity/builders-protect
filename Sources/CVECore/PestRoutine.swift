import Foundation

public struct PestRoutine: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var projectPath: String
    public var projectName: String
    public var hour: Int
    public var minute: Int
    public var useLLM: Bool
    public var enabled: Bool
    public var lastRunAt: Date?
    public var lastReportID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectPath: String,
        projectName: String,
        hour: Int,
        minute: Int,
        useLLM: Bool = true,
        enabled: Bool = true,
        lastRunAt: Date? = nil,
        lastReportID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectPath = projectPath
        self.projectName = projectName
        self.hour = hour
        self.minute = minute
        self.useLLM = useLLM
        self.enabled = enabled
        self.lastRunAt = lastRunAt
        self.lastReportID = lastReportID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var timeLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public var project: ProjectRef {
        ProjectRef(path: projectPath, name: projectName, lockfiles: [], ecosystems: [])
    }
}

public struct PestState: Codable, Sendable {
    public var routines: [PestRoutine]
    public var reports: [PestReport]
    public var lastRunAt: Date?
    public var updatedAt: Date

    public init(
        routines: [PestRoutine] = [],
        reports: [PestReport] = [],
        lastRunAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.routines = routines
        self.reports = reports
        self.lastRunAt = lastRunAt
        self.updatedAt = updatedAt
    }

    public static var empty: PestState { PestState() }

    public mutating func addReport(_ report: PestReport, limit: Int = 20) {
        reports.removeAll { $0.id == report.id }
        reports.insert(report, at: 0)
        if reports.count > limit {
            reports.removeLast(reports.count - limit)
        }
        updatedAt = Date()
    }

    public func report(for routine: PestRoutine) -> PestReport? {
        if let id = routine.lastReportID, let match = reports.first(where: { $0.id == id }) {
            return match
        }
        return reports.first { $0.projectPath == routine.projectPath }
    }

    public func resumeState(for routine: PestRoutine) -> PestResumeState? {
        report(for: routine)?.resumeState
    }
}

public enum PestRoutinePlanner {
    public static let minimumSpacingMinutes = 30

    public static func minutes(hour: Int, minute: Int) -> Int {
        max(0, min(23, hour)) * 60 + max(0, min(59, minute))
    }

    public static func circularDistance(_ first: Int, _ second: Int) -> Int {
        let raw = abs(first - second)
        return min(raw, 1_440 - raw)
    }

    public static func nextRunDate(
        for routine: PestRoutine,
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard routine.enabled else { return nil }
        guard let today = date(for: routine, on: now, calendar: calendar) else {
            return nil
        }
        if now < today { return today }
        if let lastRunAt = routine.lastRunAt, lastRunAt >= today {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        return now
    }

    public static func nextRunDate(
        routines: [PestRoutine],
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        routines.compactMap {
            nextRunDate(for: $0, after: now, calendar: calendar)
        }.min()
    }

    public static func date(
        for routine: PestRoutine,
        on day: Date,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(
            bySettingHour: routine.hour,
            minute: routine.minute,
            second: 0,
            of: day
        )
    }

    public static func conflict(
        hour: Int,
        minute: Int,
        projectPath: String,
        routines: [PestRoutine],
        excluding id: UUID? = nil
    ) -> String? {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return "Escolha um horário válido."
        }
        let candidate = minutes(hour: hour, minute: minute)
        for routine in routines where routine.id != id {
            if routine.projectPath == projectPath {
                return "Já existe uma rotina para este projeto. Edite ou remova a rotina das \(routine.timeLabel)."
            }
            let distance = circularDistance(candidate, minutes(hour: routine.hour, minute: routine.minute))
            if distance < minimumSpacingMinutes {
                let gap = minimumSpacingMinutes - distance
                return "O Pest precisa de pelo menos 30 minutos entre rotinas. Afaste este horário em \(gap) min da rotina das \(routine.timeLabel)."
            }
        }
        return nil
    }

    public static func suggestedSlot(
        desiredHour: Int,
        desiredMinute: Int,
        projectPath: String,
        routines: [PestRoutine],
        excluding id: UUID? = nil,
        step: Int = 5
    ) -> (hour: Int, minute: Int)? {
        let desired = minutes(hour: desiredHour, minute: desiredMinute)
        let safeStep = max(1, step)
        for offset in stride(from: 0, through: 720, by: safeStep) {
            let candidates = offset == 0 ? [desired] : [desired + offset, desired - offset]
            for candidate in candidates {
                let normalized = ((candidate % 1_440) + 1_440) % 1_440
                let hour = normalized / 60
                let minute = normalized % 60
                if conflict(
                    hour: hour,
                    minute: minute,
                    projectPath: projectPath,
                    routines: routines,
                    excluding: id
                ) == nil {
                    return (hour, minute)
                }
            }
        }
        return nil
    }

    public static func isDue(
        _ routine: PestRoutine,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard routine.enabled,
              let today = date(for: routine, on: now, calendar: calendar),
              now >= today else {
            return false
        }
        guard let lastRunAt = routine.lastRunAt else { return true }
        return lastRunAt < today
    }

    public static func dueRoutine(
        routines: [PestRoutine],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PestRoutine? {
        routines
            .filter { isDue($0, now: now, calendar: calendar) }
            .sorted { lhs, rhs in
                let left = date(for: lhs, on: now, calendar: calendar) ?? now
                let right = date(for: rhs, on: now, calendar: calendar) ?? now
                if left != right { return left < right }
                return lhs.timeLabel < rhs.timeLabel
            }
            .first
    }

    public static func canRunNow(
        lastRunAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard let lastRunAt else { return true }
        return now.timeIntervalSince(lastRunAt) >= TimeInterval(minimumSpacingMinutes * 60)
    }

    public static func nextAllowedRun(
        lastRunAt: Date?,
        now: Date = Date()
    ) -> Date {
        guard let lastRunAt else { return now }
        let next = lastRunAt.addingTimeInterval(TimeInterval(minimumSpacingMinutes * 60))
        return max(now, next)
    }
}
