import AppKit
import Combine
import CVECore
import Foundation
import SwiftUI

struct FolderPreview: Sendable {
    var projectCount: Int
    var lockfileCount: Int
    var projects: [String]
    var warnings: [String]
}

struct FolderPickResult: Sendable {
    var folders: [MonitoredFolder]
    var autoExcludedPaths: [String]
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var report: ScanReport?
    @Published private(set) var authStatus: BuilderAuthStatus
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: ScanProgress?
    @Published private(set) var scanError: String?
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var isRefreshingAuth = false
    @Published private(set) var folderPreview: FolderPreview?
    @Published private(set) var isPreviewingFolders = false
    @Published private(set) var redTeamProjects: [ProjectRef] = []
    @Published private(set) var isLoadingRedTeamProjects = false
    @Published var redTeamProjectPath: String?
    @Published private(set) var isRedTeamRunning = false
    @Published private(set) var redTeamProgress: RedTeamProgress?
    @Published private(set) var redTeamReport: RedTeamReport?
    @Published private(set) var redTeamError: String?
    @Published var expandedProjectID: String?
    @Published var settingsSection: SettingsSection = .analysis
    @Published private(set) var toast: String?

    var onOpenSettings: (() -> Void)?
    var onOpenAlert: ((ProjectAlert) -> Void)?
    var onOpenReport: (() -> Void)?
    var onOpenOnboarding: (() -> Void)?
    var onShowPanel: (() -> Void)?
    var onQuit: (() -> Void)?

    private let store: SettingsStore
    private let scanService: ScanService
    private let authStore: BuilderAuthStore
    private let redTeamService: RedTeamService
    private var scheduler: ScanScheduler?
    private var toastTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var exclusionRescanTask: Task<Void, Never>?
    private var redTeamTask: Task<Void, Never>?
    private var redTeamProjectsTask: Task<Void, Never>?
    private var redTeamReports: [String: RedTeamReport] = [:]

    init(
        store: SettingsStore = .shared,
        scanService: ScanService = ScanService(),
        authStore: BuilderAuthStore = .shared,
        redTeamService: RedTeamService = RedTeamService()
    ) {
        self.store = store
        self.scanService = scanService
        self.authStore = authStore
        self.redTeamService = redTeamService
        self.settings = store.loadSettings()
        self.report = store.loadReport()
        self.authStatus = authStore.status()
        self.launchAtLoginEnabled = LaunchAtLogin.isEnabled
        self.redTeamReports = store.loadRedTeamReports()
    }

    var isConfigured: Bool {
        settings.hasCompletedOnboarding && !settings.folders.isEmpty
    }

    var totalFindings: Int {
        report?.totalFindings ?? 0
    }

    var criticalCount: Int {
        report?.criticalCount ?? 0
    }

    var highCount: Int {
        report?.highCount ?? 0
    }

    var affectedProjectCount: Int {
        report?.alerts.count ?? 0
    }

    var totalPackages: Int {
        report?.totalPackages ?? 0
    }

    var hasKEV: Bool {
        report?.alerts.contains(where: \.hasKEV) ?? false
    }

    var lastScanLabel: String {
        if isScanning { return "Verificando agora" }
        if let report { return "Verificado \(report.finishedAt.relativeShort)" }
        return "Ainda não verificado"
    }

    var lastScanDate: Date? {
        settings.lastScanAt ?? report?.finishedAt
    }

    var nextRunLabel: String {
        guard settings.scheduleEnabled else { return "Rotina desligada" }
        let calendar = Calendar.current
        guard var target = calendar.date(
            bySettingHour: settings.scheduleHour,
            minute: settings.scheduleMinute,
            second: 0,
            of: Date()
        ) else {
            return "Rotina diária"
        }
        if target <= Date() {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: target)
        return calendar.isDateInToday(target)
            ? "Hoje às \(time)"
            : "Amanhã às \(time)"
    }

    var authLabel: String {
        authStatus.connected ? "IA conectada" : "IA desconectada"
    }

    var canScan: Bool {
        !isScanning && !settings.folders.isEmpty
    }

    var selectedRedTeamProject: ProjectRef? {
        guard let redTeamProjectPath else { return nil }
        return redTeamProjects.first { $0.path == redTeamProjectPath }
    }

    var canRunRedTeam: Bool {
        !isRedTeamRunning && selectedRedTeamProject != nil && authStatus.connected
    }

    func start() {
        LaunchAtLogin.migrateLegacy()
        LaunchAtLogin.refreshIfEnabled()
        authStatus = authStore.status()
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        startScheduler()

        guard settings.hasCompletedOnboarding, !settings.folders.isEmpty else {
            return
        }
        if report == nil {
            scan()
        } else if scheduler?.shouldCatchUp() == true {
            scan()
        }
    }

    func stop() {
        scheduler?.stop()
        toastTask?.cancel()
        previewTask?.cancel()
        exclusionRescanTask?.cancel()
        redTeamTask?.cancel()
        redTeamProjectsTask?.cancel()
    }

    func panelOpened() {
        authStatus = authStore.status()
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func scan() {
        guard !isScanning else { return }
        guard !settings.folders.isEmpty else {
            scanError = "Adicione uma pasta com projetos antes de verificar."
            return
        }

        let previousIDs = Set(report?.alerts.flatMap { $0.findings.map(\.id) } ?? [])
        let folders = settings.folders
        let excludedPaths = settings.excludedPaths
        isScanning = true
        scanError = nil
        expandedProjectID = nil
        scanProgress = ScanProgress(
            phase: "Preparando",
            detail: "Organizando as pastas monitoradas…",
            fraction: 0
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let report = try await self.scanService.scan(
                    folders: folders,
                    excludedPaths: excludedPaths
                ) { progress in
                    Task { @MainActor [weak self] in
                        self?.scanProgress = progress
                    }
                }

                let newIDs = report.alerts
                    .flatMap { $0.findings }
                    .filter { !previousIDs.contains($0.id) }
                self.report = report
                self.store.saveReport(report)
                self.settings.lastScanAt = report.finishedAt
                self.store.saveSettings(self.settings)
                self.scheduler?.update(
                    settings: self.settings,
                    lastScanAt: report.finishedAt
                )
                self.authStatus = self.authStore.status()
                self.isScanning = false
                self.scanProgress = nil

                if self.settings.notifyOnFindings, !newIDs.isEmpty {
                    NotificationService.notify(report: report, newFindings: newIDs.count)
                }
            } catch is CancellationError {
                self.isScanning = false
                self.scanProgress = nil
            } catch {
                self.isScanning = false
                self.scanProgress = nil
                self.scanError = error.localizedDescription
            }
        }
    }

    func completeOnboarding(_ draft: AppSettings) {
        updateSettings(draft)
        if settings.notifyOnFindings {
            NotificationService.requestAuthorization()
        }
        if settings.folders.isEmpty {
            showToast("Adicione uma pasta depois em Ajustes.")
        } else {
            scan()
        }
    }

    func loadRedTeamProjects() {
        guard RedTeamingFeature.isEnabled else { return }
        guard !isLoadingRedTeamProjects else { return }
        isLoadingRedTeamProjects = true
        let folders = settings.folders
        let excludedPaths = settings.excludedPaths
        redTeamProjectsTask?.cancel()
        redTeamProjectsTask = Task { [weak self] in
            let discovery = await Task.detached(priority: .userInitiated) {
                ProjectScanner().preview(folders: folders, excludedPaths: excludedPaths)
            }.value
            guard !Task.isCancelled, let self else { return }

            self.redTeamProjects = discovery.projects
                .map(\.ref)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            self.isLoadingRedTeamProjects = false

            let paths = Set(self.redTeamProjects.map(\.path))
            if let current = self.redTeamProjectPath, !paths.contains(current) {
                self.redTeamProjectPath = nil
            }
            if self.redTeamProjectPath == nil {
                let preferredPath = self.report?.alerts.first?.project.path
                self.redTeamProjectPath = self.redTeamProjects
                    .first(where: { $0.path == preferredPath })?
                    .path ?? self.redTeamProjects.first?.path
            }
            self.redTeamReport = self.redTeamProjectPath.flatMap { self.redTeamReports[$0] }
            if self.redTeamProjects.isEmpty {
                self.redTeamError = discovery.warnings.first
            }
        }
    }

    func selectRedTeamProject(_ path: String) {
        redTeamProjectPath = path
        redTeamReport = redTeamReports[path]
        redTeamError = nil
    }

    func startRedTeam() {
        guard RedTeamingFeature.isEnabled else { return }
        guard !isRedTeamRunning else { return }
        guard let project = selectedRedTeamProject else {
            redTeamError = "Selecione um projeto para analisar."
            return
        }
        guard authStatus.connected else {
            redTeamError = "Conecte sua conta da Cultura Builder para usar o Red Teaming."
            return
        }

        redTeamTask?.cancel()
        isRedTeamRunning = true
        redTeamError = nil
        redTeamProgress = RedTeamProgress(
            phase: "Preparando",
            detail: "Lendo a estrutura do projeto…",
            fraction: 0.02
        )

        let service = redTeamService
        redTeamTask = Task { [weak self] in
            do {
                let report = try await service.analyze(project: project) { [weak self] progress in
                    Task { @MainActor in
                        self?.redTeamProgress = progress
                    }
                }
                guard let self else { return }
                self.redTeamReport = report
                self.redTeamReports[project.path] = report
                self.store.saveRedTeamReport(report)
                self.isRedTeamRunning = false
                self.redTeamProgress = nil
                self.showToast("Análise Red Teaming concluída")
            } catch is CancellationError {
                self?.isRedTeamRunning = false
                self?.redTeamProgress = nil
            } catch {
                self?.isRedTeamRunning = false
                self?.redTeamProgress = nil
                self?.redTeamError = error.localizedDescription
            }
        }
    }

    func cancelRedTeam() {
        redTeamTask?.cancel()
        redTeamTask = nil
        isRedTeamRunning = false
        redTeamProgress = nil
        showToast("Análise Red Teaming cancelada")
    }

    func updateSettings(_ draft: AppSettings) {
        var next = draft
        next.hasCompletedOnboarding = true
        next.folders = deduplicated(next.folders)
        next.excludedPaths = deduplicatedExclusions(next.excludedPaths)
        next.scheduleHour = min(23, max(0, next.scheduleHour))
        next.scheduleMinute = min(59, max(0, next.scheduleMinute))
        let wasCompleted = settings.hasCompletedOnboarding
        let previousFolders = settings.folders.map(\.path)
        let previousExclusions = settings.excludedPaths
        settings = next
        store.saveSettings(next)
        startScheduler()
        if next.notifyOnFindings {
            NotificationService.requestAuthorization()
        }
        if wasCompleted,
           !isScanning,
           previousFolders != next.folders.map(\.path) || previousExclusions != next.excludedPaths {
            scheduleExclusionRescan()
        }
        showToast("Ajustes salvos")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let ok = LaunchAtLogin.setEnabled(
            enabled,
            bundleURL: Bundle.main.bundleURL
        )
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        if enabled, !ok {
            showToast("Abra o app instalado para ativar a inicialização automática.")
        }
    }

    func refreshAuth(force: Bool = false) async {
        guard !isRefreshingAuth else { return }
        isRefreshingAuth = true
        defer { isRefreshingAuth = false }

        do {
            if force {
                _ = try await authStore.forceRefresh()
            } else if authStatus.connected {
                _ = try await authStore.validAccessToken()
            }
            authStatus = authStore.status()
            if force {
                showToast(authStatus.connected ? "Conta conectada" : "Sessão não encontrada")
            }
        } catch {
            authStatus = authStore.status()
            if force {
                showToast("Não consegui renovar a sessão.")
            }
        }
    }

    func copyLoginCommand() {
        copyText(authStatus.loginCommand, toast: "Comando copiado")
    }

    func copyFixPrompt(_ alert: ProjectAlert) {
        copyText(Vocabulary.prompt(alert.fixPrompt), toast: "Prompt de correção copiado")
    }

    func copyAllFixPrompts(_ alerts: [ProjectAlert]) {
        guard !alerts.isEmpty else { return }
        let prompt = PromptBuilder.buildCombined(for: alerts)
        copyText(Vocabulary.prompt(prompt), toast: "Prompt geral copiado")
    }

    func copyText(_ text: String, toast message: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToast(message)
    }

    func openAlert(_ alert: ProjectAlert) {
        onOpenAlert?(alert)
    }

    func openReport() {
        onOpenReport?()
    }

    func openSettings() {
        onOpenSettings?()
    }

    func openOnboarding() {
        onOpenOnboarding?()
    }

    func showPanel() {
        onShowPanel?()
    }

    func quit() {
        onQuit?()
    }

    func openProjectFolder(_ alert: ProjectAlert) {
        NSWorkspace.shared.open(URL(fileURLWithPath: alert.project.path, isDirectory: true))
    }

    func excludeProject(_ alert: ProjectAlert) {
        let path = standardizedPath(alert.project.path)
        var next = settings
        if !next.excludedPaths.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            next.excludedPaths.append(path)
            settings = next
            store.saveSettings(next)
        }

        if var current = report {
            current.alerts.removeAll { item in
                let projectPath = standardizedPath(item.project.path)
                return projectPath == path || projectPath.hasPrefix(path + "/")
            }
            current.summary = "Atualizando a análise após ignorar uma pasta…"
            current.nextSteps = []
            report = current
            store.saveReport(current)
        }

        showToast("Pasta ignorada. Atualizando a análise…")
        scheduleExclusionRescan()
    }

    func restoreExcludedPath(_ path: String) {
        var next = settings
        next.excludedPaths.removeAll { $0 == path }
        if WorktreeSafety.isLinkedWorktree(URL(fileURLWithPath: path, isDirectory: true)),
           !next.folders.contains(where: { path == $0.path || path.hasPrefix($0.path + "/") }),
           let folder = makeFolder(url: URL(fileURLWithPath: path, isDirectory: true)) {
            next.folders.append(folder)
        }
        settings = next
        store.saveSettings(next)
        showToast("Pasta monitorada novamente")
    }

    private func scheduleExclusionRescan() {
        exclusionRescanTask?.cancel()
        exclusionRescanTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.scan()
        }
    }

    private func standardizedPath(_ path: String) -> String {
        var normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        if normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    private func deduplicatedExclusions(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.compactMap { raw in
            let path = standardizedPath(raw)
            guard !path.isEmpty, seen.insert(path).inserted else { return nil }
            return path
        }
    }

    func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    func openHub() {
        openURL("https://hub.culturabuilder.com")
    }

    func pickFolders() -> FolderPickResult {
        let panel = NSOpenPanel()
        panel.title = "Escolher pastas de projetos"
        panel.message = "A varredura lê apenas manifests e lockfiles. Worktrees do Git são ignoradas automaticamente e podem ser reativadas em Ajustes > Pastas."
        panel.prompt = "Monitorar"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        guard panel.runModal() == .OK else {
            return FolderPickResult(folders: [], autoExcludedPaths: [])
        }
        return prepareFolders(panel.urls)
    }

    func prepareFolders(_ urls: [URL]) -> FolderPickResult {
        var folders: [MonitoredFolder] = []
        var autoExcludedPaths: [String] = []
        var seenFolders = Set<String>()
        var seenExclusions = Set<String>()

        func appendFolder(_ url: URL) {
            let path = standardizedPath(url.path)
            guard seenFolders.insert(path).inserted,
                  let folder = makeFolder(url: URL(fileURLWithPath: path, isDirectory: true)) else {
                return
            }
            folders.append(folder)
        }

        func appendExclusion(_ url: URL) {
            let path = standardizedPath(url.path)
            guard seenExclusions.insert(path).inserted else { return }
            autoExcludedPaths.append(path)
        }

        for url in urls {
            let selected = url.standardizedFileURL

            if let location = WorktreeSafety.worktreeLocation(containing: selected) {
                appendFolder(location.mainRoot)
                appendExclusion(location.worktreeRoot)
                for worktree in WorktreeSafety.registeredWorktrees(in: location.mainRoot) {
                    appendExclusion(worktree)
                }
                continue
            }

            appendFolder(selected)
            for worktree in WorktreeSafety.linkedWorktrees(under: selected) {
                appendExclusion(worktree)
            }
        }

        return FolderPickResult(folders: folders, autoExcludedPaths: autoExcludedPaths)
    }

    func makeFolder(url: URL) -> MonitoredFolder? {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        let bookmark = try? standardized.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return MonitoredFolder(
            path: standardized.path,
            bookmarkData: bookmark
        )
    }

    func previewFolders(
        _ folders: [MonitoredFolder],
        excludedPaths: [String] = []
    ) async -> FolderPreview {
        await Task.detached(priority: .userInitiated) {
            let discovery = ProjectScanner().preview(
                folders: folders,
                excludedPaths: excludedPaths
            )
            return FolderPreview(
                projectCount: discovery.projects.count,
                lockfileCount: discovery.projects.reduce(0) { $0 + $1.ref.lockfiles.count },
                projects: discovery.projects.map(\.ref.name).sorted(),
                warnings: discovery.warnings
            )
        }.value
    }

    func refreshFolderPreview(_ folders: [MonitoredFolder]) {
        previewTask?.cancel()
        guard !folders.isEmpty else {
            folderPreview = nil
            isPreviewingFolders = false
            return
        }
        isPreviewingFolders = true
        previewTask = Task { [weak self] in
            guard let self else { return }
            let preview = await self.previewFolders(
                folders,
                excludedPaths: self.settings.excludedPaths
            )
            guard !Task.isCancelled else { return }
            self.folderPreview = preview
            self.isPreviewingFolders = false
        }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            toast = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func startScheduler() {
        let lastScan = settings.lastScanAt ?? report?.finishedAt
        if scheduler == nil {
            scheduler = ScanScheduler(
                settings: settings,
                lastScanAt: lastScan
            ) { [weak self] in
                self?.scan()
            }
        } else {
            scheduler?.update(settings: settings, lastScanAt: lastScan)
        }
        scheduler?.start()
    }

    private func deduplicated(_ folders: [MonitoredFolder]) -> [MonitoredFolder] {
        var seen = Set<String>()
        var result: [MonitoredFolder] = []
        for folder in folders {
            let path = URL(fileURLWithPath: folder.path).standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            var normalized = folder
            normalized.path = path
            result.append(normalized)
        }
        return result
    }
}
