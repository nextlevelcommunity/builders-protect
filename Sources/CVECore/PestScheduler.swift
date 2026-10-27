import AppKit
import Foundation

@MainActor
public final class PestScheduler {
    private var routines: [PestRoutine]
    private var lastRunAt: Date?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var isRunning = false
    private var lastDispatchedAt: Date?
    private let calendar: Calendar
    private let onFire: @MainActor @Sendable (PestRoutine) async -> Void

    public init(
        routines: [PestRoutine] = [],
        lastRunAt: Date? = nil,
        calendar: Calendar = .current,
        onFire: @escaping @MainActor @Sendable (PestRoutine) async -> Void
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

    public func update(routines: [PestRoutine], lastRunAt: Date?) {
        self.routines = routines
        self.lastRunAt = lastRunAt
    }

    public var isBusy: Bool { isRunning }

    public func nextRunDate(after now: Date = Date()) -> Date? {
        var next = PestRoutinePlanner.nextRunDate(
            routines: routines.filter(\.enabled),
            after: now,
            calendar: calendar
        )
        if let lastRunAt {
            let allowed = PestRoutinePlanner.nextAllowedRun(lastRunAt: lastRunAt, now: now)
            if let candidate = next, candidate < allowed {
                next = allowed
            } else if next == nil, !routines.filter(\.enabled).isEmpty {
                next = allowed
            }
        }
        return next
    }

    private func tick() {
        guard !isRunning else { return }
        let now = Date()
        let last = [lastRunAt, lastDispatchedAt].compactMap { $0 }.max()
        if let last, !PestRoutinePlanner.canRunNow(lastRunAt: last, now: now) {
            return
        }
        guard let routine = PestRoutinePlanner.dueRoutine(
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
