import AppKit
import Foundation

@MainActor
public final class ScanScheduler {
    private var settings: AppSettings
    private var lastScanAt: Date?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var lastFireAt: Date?
    private let onFire: @MainActor @Sendable () -> Void
    private let calendar: Calendar

    public init(
        settings: AppSettings,
        lastScanAt: Date?,
        calendar: Calendar = .current,
        onFire: @escaping @MainActor @Sendable () -> Void
    ) {
        self.settings = settings
        self.lastScanAt = lastScanAt
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
        reschedule()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    public func update(settings: AppSettings, lastScanAt: Date?) {
        self.settings = settings
        self.lastScanAt = lastScanAt
        reschedule()
    }

    public func reschedule() {
        timer?.invalidate()
        timer = nil

        guard settings.scheduleEnabled, let fireDate = nextFireDate() else { return }
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fireIfNeeded()
                self?.reschedule()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func nextFireDate(after now: Date = Date()) -> Date? {
        guard settings.scheduleEnabled else { return nil }
        guard var target = calendar.date(
            bySettingHour: settings.scheduleHour,
            minute: settings.scheduleMinute,
            second: 0,
            of: now
        ) else {
            return nil
        }
        if target <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: target) else {
                return nil
            }
            target = tomorrow
        }
        return target
    }

    public func shouldCatchUp(now: Date = Date()) -> Bool {
        guard settings.scheduleEnabled, let lastScanAt else { return false }
        guard let todayTarget = calendar.date(
            bySettingHour: settings.scheduleHour,
            minute: settings.scheduleMinute,
            second: 0,
            of: now
        ) else {
            return false
        }
        return now >= todayTarget && lastScanAt < todayTarget
    }

    private func installWakeObserver() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.shouldCatchUp() {
                    self.fireIfNeeded()
                }
                self.reschedule()
            }
        }
    }

    private func fireIfNeeded() {
        let now = Date()
        if let lastFireAt, now.timeIntervalSince(lastFireAt) < 60 {
            return
        }
        lastFireAt = now
        onFire()
    }
}
