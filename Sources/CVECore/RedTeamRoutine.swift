import AppKit
import Foundation

public struct RedTeamSlot: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var hour: Int
    public var minute: Int

    public init(id: UUID = UUID(), hour: Int, minute: Int) {
        self.id = id
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }

    public var minutesOfDay: Int { hour * 60 + minute }

    public var label: String { String(format: "%02d:%02d", hour, minute) }
}

public struct RedTeamRoutine: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var projectPath: String
    public var projectName: String
    public var slots: [RedTeamSlot]
    public var enabled: Bool
    public var lastRunAt: Date?
    public var lastReportID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectPath: String,
        projectName: String,
        slots: [RedTeamSlot],
        enabled: Bool = true,
        lastRunAt: Date? = nil,
        lastReportID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectPath = projectPath
        self.projectName = projectName
        self.slots = slots.sorted { $0.minutesOfDay < $1.minutesOfDay }
        self.enabled = enabled
        self.lastRunAt = lastRunAt
        self.lastReportID = lastReportID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var timesLabel: String {
        slots.map(\.label).joined(separator: " · ")
    }

    public var project: ProjectRef {
        ProjectRef(path: projectPath, name: projectName, lockfiles: [], ecosystems: [])
    }
}

public struct RedTeamState: Codable, Sendable {
    public var routines: [RedTeamRoutine]
    public var lastRunAt: Date?
    public var updatedAt: Date

    public init(
        routines: [RedTeamRoutine] = [],
        lastRunAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.routines = routines
        self.lastRunAt = lastRunAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case routines
        case lastRunAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routines = try container.decodeIfPresent([RedTeamRoutine].self, forKey: .routines) ?? []
        lastRunAt = try container.decodeIfPresent(Date.self, forKey: .lastRunAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public static var empty: RedTeamState { RedTeamState() }
}

public enum RedTeamRoutinePlanner {
    public static let minimumSpacingMinutes = 20
    public static let maxSlots = 12

    public static func minutes(hour: Int, minute: Int) -> Int {
        max(0, min(23, hour)) * 60 + max(0, min(59, minute))
    }

    public static func circularDistance(_ first: Int, _ second: Int) -> Int {
        let raw = abs(first - second)
        return min(raw, 1_440 - raw)
    }

    public static func conflict(
        hour: Int,
        minute: Int,
        routine: RedTeamRoutine,
        excluding slotID: UUID? = nil
    ) -> String? {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return "Escolha um horário válido."
        }
        let candidate = minutes(hour: hour, minute: minute)
        for slot in routine.slots where slot.id != slotID {
            let distance = circularDistance(candidate, slot.minutesOfDay)
            if distance < minimumSpacingMinutes {
                let gap = minimumSpacingMinutes - distance
                return "O Red Team precisa de pelo menos \(minimumSpacingMinutes) minutos entre rodadas. Afaste este horário em \(gap) min da rodada das \(slot.label)."
            }
        }
        return nil
    }

    public static func date(
        for slot: RedTeamSlot,
        on day: Date,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day)
    }

    public static func nextRunDate(
        for routine: RedTeamRoutine,
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard routine.enabled, !routine.slots.isEmpty else { return nil }
        let today = routine.slots.compactMap { slot -> Date? in
            guard let date = date(for: slot, on: now, calendar: calendar) else { return nil }
            if now < date { return date }
            if let lastRunAt = routine.lastRunAt, lastRunAt < date { return date }
            return calendar.date(byAdding: .day, value: 1, to: date)
        }
        return today.min()
    }

    public static func nextRunDate(
        routines: [RedTeamRoutine],
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        routines.compactMap { nextRunDate(for: $0, after: now, calendar: calendar) }.min()
    }

    public static func isDue(
        _ routine: RedTeamRoutine,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard routine.enabled else { return false }
        return routine.slots.contains { slot in
            guard let date = date(for: slot, on: now, calendar: calendar), now >= date else {
                return false
            }
            guard let lastRunAt = routine.lastRunAt else { return true }
            return lastRunAt < date
        }
    }

    public static func dueRoutine(
        routines: [RedTeamRoutine],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RedTeamRoutine? {
        routines.filter { isDue($0, now: now, calendar: calendar) }.first
    }

    public static func canRunNow(lastRunAt: Date?, now: Date = Date()) -> Bool {
        guard let lastRunAt else { return true }
        return now.timeIntervalSince(lastRunAt) >= TimeInterval(minimumSpacingMinutes * 60)
    }
}

@MainActor
public final class RedTeamScheduler {
    private var routines: [RedTeamRoutine]
    private var lastRunAt: Date?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var isRunning = false
    private var lastDispatchedAt: Date?
    private let calendar: Calendar
    private let onFire: @MainActor @Sendable (RedTeamRoutine) async -> Void

    public init(
        routines: [RedTeamRoutine] = [],
        lastRunAt: Date? = nil,
        calendar: Calendar = .current,
        onFire: @escaping @MainActor @Sendable (RedTeamRoutine) async -> Void
    ) {
        self.routines = routines
        self.lastRunAt = lastRunAt
        self.calendar = calendar
        self.onFire = onFire
    }

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    public func start() {
        installWakeObserver()
        timer?.invalidate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    public func update(routines: [RedTeamRoutine], lastRunAt: Date?) {
        self.routines = routines
        self.lastRunAt = lastRunAt
    }

    public var isBusy: Bool { isRunning }

    public func nextRunDate(after now: Date = Date()) -> Date? {
        RedTeamRoutinePlanner.nextRunDate(
            routines: routines.filter(\.enabled),
            after: now,
            calendar: calendar
        )
    }

    private func tick() {
        guard !isRunning else { return }
        let now = Date()
        let last = [lastRunAt, lastDispatchedAt].compactMap { $0 }.max()
        if let last, !RedTeamRoutinePlanner.canRunNow(lastRunAt: last, now: now) {
            return
        }
        guard let routine = RedTeamRoutinePlanner.dueRoutine(
            routines: routines,
            now: now,
            calendar: calendar
        ) else {
            return
        }

        isRunning = true
        lastDispatchedAt = now
        Task { @MainActor in
            await onFire(routine)
            self.isRunning = false
            self.lastDispatchedAt = Date()
        }
    }

    private func installWakeObserver() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
}
