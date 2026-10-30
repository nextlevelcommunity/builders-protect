import AppKit
import Combine
import CVECore
import Foundation
import SwiftUI

struct FolderPreview: Sendable {
    var projectRefs: [ProjectRef]
    var warnings: [String]

    var projectCount: Int { projectRefs.count }
    var lockfileCount: Int { projectRefs.reduce(0) { $0 + $1.lockfiles.count } }
    var projects: [String] { projectRefs.map(\.name) }
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
    @Published private(set) var isTestingLLM = false
    @Published private(set) var llmTestResult: String?
    @Published private(set) var llmTestOK = false
    @Published private(set) var folderPreview: FolderPreview?
    @Published private(set) var isPreviewingFolders = false
    @Published private(set) var redTeamProjects: [ProjectRef] = []
    @Published private(set) var isLoadingRedTeamProjects = false
    @Published var redTeamProjectPath: String?
    @Published private(set) var isRedTeamRunning = false
    @Published private(set) var redTeamProgress: RedTeamProgress?
    @Published private(set) var redTeamReport: RedTeamReport?
    @Published private(set) var redTeamError: String?
    @Published private(set) var redTeamState: RedTeamState
    @Published private(set) var redTeamRoutineError: String?
    @Published private(set) var pestProjects: [ProjectRef] = []
    @Published private(set) var isLoadingPestProjects = false
    @Published var pestProjectPath: String?
    @Published private(set) var pestState: PestState
    @Published private(set) var isPestRunning = false
    @Published private(set) var pestProgress: PestProgress?
    @Published private(set) var pestReport: PestReport?
    @Published private(set) var pestError: String?
    @Published private(set) var networkState: NetworkState
    @Published private(set) var isNetworkRunning = false
    @Published private(set) var networkProgress: NetworkProgress?
    @Published private(set) var networkReport: NetworkReport?
    @Published private(set) var networkError: String?
    @Published var networkIsPublic = false
    @Published var expandedProjectID: String?
    @Published var settingsSection: SettingsSection = .analysis
    @Published private(set) var toast: String?
    @Published private(set) var language: AppLanguage

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
    private let pestService: PestService
    private let networkService: NetworkService
    private var scheduler: ScanScheduler?
    private var pestScheduler: PestScheduler?
    private var redTeamScheduler: RedTeamScheduler?
    private var toastTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var exclusionRescanTask: Task<Void, Never>?
    private var redTeamTask: Task<Void, Never>?
    private var redTeamProjectsTask: Task<Void, Never>?
    private var redTeamReports: [String: RedTeamReport] = [:]
    private var pestProjectsTask: Task<Void, Never>?
    private var pestTask: Task<Void, Never>?
    private var pestRunID = UUID()
    private var networkTask: Task<Void, Never>?
    private var networkRunID = UUID()

    init(
        store: SettingsStore = .shared,
        scanService: ScanService = ScanService(),
        authStore: BuilderAuthStore = .shared,
        redTeamService: RedTeamService = RedTeamService(),
        pestService: PestService = PestService(),
        networkService: NetworkService = NetworkService()
    ) {
        self.store = store
        self.scanService = scanService
        self.authStore = authStore
        self.redTeamService = redTeamService
        self.pestService = pestService
        self.networkService = networkService
        let loadedSettings = store.loadSettings()
        self.settings = loadedSettings
        self.report = store.loadReport()
        self.authStatus = authStore.status()
        self.launchAtLoginEnabled = LaunchAtLogin.isEnabled
        self.redTeamReports = store.loadRedTeamReports()
        self.redTeamState = store.loadRedTeamState()
        self.pestState = store.loadPestState()
        let networkState = store.loadNetworkState()
        self.networkState = networkState
        self.networkReport = networkState.latest
        self.language = loadedSettings.appLanguage
        L10n.language = loadedSettings.appLanguage
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
        if isScanning { return L10n.t("Verificando agora", "Checking now") }
        if let report { return L10n.t("Verificado \(report.finishedAt.relativeShort)", "Checked \(report.finishedAt.relativeShort)") }
        return L10n.t("Ainda não verificado", "Not checked yet")
    }

    var lastScanDate: Date? {
        settings.lastScanAt ?? report?.finishedAt
    }

    var nextRunLabel: String {
        guard settings.scheduleEnabled else { return L10n.t("Rotina desligada", "Routine off") }
        let calendar = Calendar.current
        guard var target = calendar.date(
            bySettingHour: settings.scheduleHour,
            minute: settings.scheduleMinute,
            second: 0,
            of: Date()
        ) else {
            return L10n.t("Rotina diária", "Daily routine")
        }
        if target <= Date() {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: target)
        return calendar.isDateInToday(target)
            ? L10n.t("Hoje às \(time)", "Today at \(time)")
            : L10n.t("Amanhã às \(time)", "Tomorrow at \(time)")
    }

    var authLabel: String {
        authStatus.connected ? L10n.t("IA conectada", "AI connected") : L10n.t("IA desconectada", "AI disconnected")
    }

    /// A IA está utilizável no modo escolhido: sessão do proxy no padrão,
    /// chave dedicada no modo RTX.
    var llmReady: Bool {
        settings.analysisMode.isHack ? settings.hasRTXKey : authStatus.connected
    }

    var isHackMode: Bool { settings.analysisMode.isHack }

    var canScan: Bool {
        !isScanning && !settings.folders.isEmpty
    }

    var selectedRedTeamProject: ProjectRef? {
        guard let redTeamProjectPath else { return nil }
        return redTeamProjects.first { $0.path == redTeamProjectPath }
    }

    var canRunRedTeam: Bool {
        !isRedTeamRunning && selectedRedTeamProject != nil && llmReady
    }

    var redTeamResumeAvailable: Bool {
        selectedRedTeamReport?.resumeState != nil
    }

    var selectedRedTeamReport: RedTeamReport? {
        guard let path = redTeamProjectPath else { return nil }
        if let redTeamReport, redTeamReport.projectPath == path { return redTeamReport }
        return redTeamReports[path]
    }

    var redTeamRoutineForSelectedProject: RedTeamRoutine? {
        guard let path = redTeamProjectPath else { return nil }
        return redTeamState.routines.first { $0.projectPath == path }
    }

    var redTeamNextRunDate: Date? {
        RedTeamRoutinePlanner.nextRunDate(routines: redTeamState.routines)
    }

    var selectedPestProject: ProjectRef? {
        guard let pestProjectPath else { return nil }
        return pestProjects.first { $0.path == pestProjectPath }
    }

    var activePestProjects: [ProjectRef] {
        let activePaths = Set(pestState.activeProjectPaths)
        return pestProjects.filter { activePaths.contains($0.path) }
    }

    func isPestProjectActive(_ path: String) -> Bool {
        pestState.activeProjectPaths.contains(path)
    }

    var selectedPestReport: PestReport? {
        guard let path = pestProjectPath else { return nil }
        let exclusions = PathExclusions.normalized(settings.excludedPaths)
        guard !PathExclusions.contains(path, in: exclusions) else { return nil }

        if let pestReport, pestReport.projectPath == path {
            return pestReport.excluding(exclusions)
        }
        return pestState.reports.first { $0.projectPath == path }?.excluding(exclusions)
    }

    var canRunPest: Bool {
        !isPestRunning && selectedPestProject != nil && llmReady
    }

    var pestResumeAvailable: Bool {
        selectedPestReport?.resumeState != nil
    }

    var pestRoutineForSelectedProject: PestRoutine? {
        guard let path = pestProjectPath else { return nil }
        return pestState.routines.first { $0.projectPath == path }
    }

    var pestNextRunDate: Date? {
        guard let routine = pestRoutineForSelectedProject else { return nil }
        return PestRoutinePlanner.nextRunDate(for: routine)
    }

    var latestNetworkReport: NetworkReport? {
        networkReport ?? networkState.latest
    }

    var canRunNetwork: Bool {
        !isNetworkRunning
    }

    func start() {
        LaunchAtLogin.migrateLegacy()
        LaunchAtLogin.refreshIfEnabled()
        authStatus = authStore.status()
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        startScheduler()
        startPestScheduler()
        startRedTeamScheduler()
        purgePestFindings(excludedPaths: settings.excludedPaths)

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
        pestScheduler?.stop()
        redTeamScheduler?.stop()
        toastTask?.cancel()
        previewTask?.cancel()
        exclusionRescanTask?.cancel()
        redTeamTask?.cancel()
        redTeamProjectsTask?.cancel()
        pestTask?.cancel()
        pestProjectsTask?.cancel()
        networkTask?.cancel()
    }

    func panelOpened() {
        authStatus = authStore.status()
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func scan() {
        guard !isScanning else { return }
        guard !settings.folders.isEmpty else {
            scanError = L10n.t("Adicione uma pasta com projetos antes de verificar.", "Add a folder with projects before checking.")
            return
        }

        let previousIDs = Set(report?.alerts.flatMap { $0.findings.map(\.id) } ?? [])
        let folders = settings.folders
        let excludedPaths = settings.excludedPaths
        isScanning = true
        scanError = nil
        expandedProjectID = nil
        scanProgress = ScanProgress(
            phase: L10n.t("Preparando", "Preparing"),
            detail: L10n.t("Organizando as pastas monitoradas…"),
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
                self.scanError = L10n.t(error.localizedDescription)
            }
        }
    }

    func completeOnboarding(_ draft: AppSettings) {
        updateSettings(draft)
        if settings.notifyOnFindings {
            NotificationService.requestAuthorization()
        }
        if settings.folders.isEmpty {
            showToast(L10n.t("Adicione uma pasta depois em Ajustes.", "Add a folder later in Settings."))
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
                self.redTeamError = discovery.warnings.first.map(L10n.t)
            }
        }
    }

    func selectRedTeamProject(_ path: String) {
        redTeamProjectPath = path
        redTeamReport = redTeamReports[path]
        redTeamError = nil
    }

    func startRedTeam() {
        startRedTeam(projectPath: redTeamProjectPath, resume: redTeamResumeAvailable)
    }

    /// Aciona o Red Teaming a partir de qualquer tela. Sem consentimento salvo,
    /// abre Ajustes no Red Teaming para a pessoa autorizar uma vez.
    func requestRedTeam(projectPath: String) {
        settingsSection = .redTeam
        redTeamProjectPath = projectPath
        redTeamReport = redTeamReports[projectPath]
        redTeamError = nil
        openSettings()
        if settings.redTeamConsent {
            startRedTeam(projectPath: projectPath, resume: false)
        }
    }

    func startRedTeam(projectPath: String?, resume: Bool = false) {
        guard RedTeamingFeature.isEnabled else { return }
        guard !isRedTeamRunning else { return }
        guard let path = projectPath, let project = redTeamProjects.first(where: { $0.path == path })
                ?? projectRef(for: path) else {
            redTeamError = L10n.t("Selecione um projeto para analisar.", "Select a project to analyze.")
            return
        }
        guard llmReady else {
            redTeamError = isHackMode
                ? L10n.t("Cole a chave RTX em Ajustes > Análises para usar o Red Teaming.", "Paste the RTX key in Settings > AI and security to use Red Teaming.")
                : L10n.t("Conecte sua conta da Cultura Builder para usar o Red Teaming.", "Connect your Cultura Builder account to use Red Teaming.")
            return
        }
        guard settings.redTeamConsent else {
            redTeamError = L10n.t("Autorize o envio do código deste projeto antes de iniciar.", "Authorize sending this project's code before starting.")
            return
        }
        let resumeState = resume ? redTeamReports[project.path]?.resumeState : nil
        let excludedPaths = settings.excludedPaths
        if PathExclusions.contains(project.path, in: PathExclusions.normalized(excludedPaths)) {
            redTeamError = L10n.t(RedTeamError.projectExcluded.localizedDescription)
            return
        }

        redTeamTask?.cancel()
        isRedTeamRunning = true
        redTeamError = nil
        redTeamProgress = RedTeamProgress(
            phase: resumeState == nil
                ? L10n.t("Preparando", "Preparing")
                : L10n.t("Retomando", "Resuming"),
            detail: resumeState == nil
                ? L10n.t("Lendo a estrutura do projeto…", "Reading the project structure…")
                : L10n.t("Retomando a análise pausada.", "Resuming the paused analysis."),
            fraction: 0.02
        )

        let service = redTeamService
        redTeamTask = Task { [weak self] in
            do {
                let report = try await service.analyze(
                    project: project,
                    resume: resumeState,
                    excludedPaths: excludedPaths
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.redTeamProgress = progress
                    }
                }
                guard let self else { return }
                self.finishRedTeam(report)
            } catch is CancellationError {
                self?.isRedTeamRunning = false
                self?.redTeamProgress = nil
            } catch {
                self?.isRedTeamRunning = false
                self?.redTeamProgress = nil
                self?.redTeamError = L10n.t(error.localizedDescription)
            }
        }
    }

    private func finishRedTeam(_ report: RedTeamReport) {
        redTeamReport = report
        redTeamReports[report.projectPath] = report
        store.saveRedTeamReport(report)
        isRedTeamRunning = false
        redTeamProgress = nil

        var state = redTeamState
        state.lastRunAt = report.startedAt
        for index in state.routines.indices where state.routines[index].projectPath == report.projectPath {
            state.routines[index].lastRunAt = report.startedAt
            state.routines[index].lastReportID = report.id
            state.routines[index].updatedAt = Date()
        }
        redTeamState = state
        persistRedTeamState()

        if report.paused {
            redTeamError = L10n.t("Red Team pausou: \(L10n.t(report.pauseReason ?? "memória insuficiente"))", "Red Team paused: \(L10n.t(report.pauseReason ?? "low memory"))")
            showToast(L10n.t("Red Team pausou. Retome quando quiser.", "Red Team paused. Resume whenever you want."))
            NotificationService.notifyRedTeamPaused(report)
        } else {
            redTeamError = nil
            showToast(
                report.findings.isEmpty
                    ? L10n.t("Red Team concluído sem achados", "Red Team finished with no findings")
                    : L10n.t("Red Team concluído: \(report.findings.count) achado(s)", "Red Team finished: \(report.findings.count) finding(s)")
            )
            if settings.notifyOnFindings, !report.findings.isEmpty {
                NotificationService.notifyRedTeam(report)
            }
        }
    }

    private func projectRef(for path: String?) -> ProjectRef? {
        guard let path else { return nil }
        if let match = redTeamProjects.first(where: { $0.path == path }) { return match }
        if let match = pestProjects.first(where: { $0.path == path }) { return match }
        let url = URL(fileURLWithPath: path)
        return ProjectRef(
            path: path,
            name: url.lastPathComponent,
            lockfiles: [],
            ecosystems: []
        )
    }

    func cancelRedTeam() {
        redTeamTask?.cancel()
        redTeamTask = nil
        isRedTeamRunning = false
        redTeamProgress = nil
        showToast(L10n.t("Análise Red Teaming cancelada", "Red Team analysis canceled"))
    }

    func setRedTeamConsent(_ granted: Bool) {
        guard settings.redTeamConsent != granted else { return }
        var next = settings
        next.redTeamConsent = granted
        updateSettings(next, announce: false)
    }

    func redTeamRoutineConflict(
        hour: Int,
        minute: Int,
        routine: RedTeamRoutine,
        excluding slotID: UUID? = nil
    ) -> String? {
        RedTeamRoutinePlanner.conflict(
            hour: hour,
            minute: minute,
            routine: routine,
            excluding: slotID
        )
    }

    private func routine(
        for projectPath: String,
        projectName: String
    ) -> (state: RedTeamState, index: Int?) {
        var state = redTeamState
        if let index = state.routines.firstIndex(where: { $0.projectPath == projectPath }) {
            return (state, index)
        }
        state.routines.append(
            RedTeamRoutine(projectPath: projectPath, projectName: projectName, slots: [])
        )
        return (state, state.routines.count - 1)
    }

    @discardableResult
    func addRedTeamTime(
        projectPath: String,
        projectName: String,
        hour: Int,
        minute: Int
    ) -> String? {
        var (state, index) = routine(for: projectPath, projectName: projectName)
        guard let index else { return L10n.t("Não consegui criar a rotina.", "Could not create the routine.") }
        guard state.routines[index].slots.count < RedTeamRoutinePlanner.maxSlots else {
            return L10n.t("Esta rotina já tem \(RedTeamRoutinePlanner.maxSlots) horários por dia.", "This routine already has \(RedTeamRoutinePlanner.maxSlots) times a day.")
        }
        if let conflict = RedTeamRoutinePlanner.conflict(
            hour: hour,
            minute: minute,
            routine: state.routines[index]
        ) {
            return conflict
        }
        state.routines[index].slots.append(RedTeamSlot(hour: hour, minute: minute))
        state.routines[index].slots.sort { $0.minutesOfDay < $1.minutesOfDay }
        state.routines[index].enabled = true
        state.routines[index].updatedAt = Date()
        redTeamState = state
        persistRedTeamState()
        showToast(L10n.t("Horário do Red Team salvo", "Red Team time saved"))
        return nil
    }

    func removeRedTeamTime(projectPath: String, slotID: UUID) {
        var state = redTeamState
        guard let index = state.routines.firstIndex(where: { $0.projectPath == projectPath }) else {
            return
        }
        state.routines[index].slots.removeAll { $0.id == slotID }
        state.routines[index].updatedAt = Date()
        redTeamState = state
        persistRedTeamState()
        showToast(L10n.t("Horário do Red Team removido", "Red Team time removed"))
    }

    func setRedTeamRoutineEnabled(projectPath: String, enabled: Bool) {
        var state = redTeamState
        guard let index = state.routines.firstIndex(where: { $0.projectPath == projectPath }) else {
            return
        }
        state.routines[index].enabled = enabled
        state.routines[index].updatedAt = Date()
        redTeamState = state
        persistRedTeamState()
        showToast(enabled ? L10n.t("Rotina do Red Team ativada", "Red Team routine enabled") : L10n.t("Rotina do Red Team pausada", "Red Team routine paused"))
    }

    func removeRedTeamRoutine(projectPath: String) {
        var state = redTeamState
        state.routines.removeAll { $0.projectPath == projectPath }
        redTeamState = state
        persistRedTeamState()
        showToast(L10n.t("Rotina do Red Team removida", "Red Team routine removed"))
    }

    private func persistRedTeamState() {
        store.saveRedTeamState(redTeamState)
        redTeamScheduler?.update(
            routines: redTeamState.routines,
            lastRunAt: redTeamState.lastRunAt
        )
    }

    private func startRedTeamScheduler() {
        if redTeamScheduler == nil {
            redTeamScheduler = RedTeamScheduler(
                routines: redTeamState.routines,
                lastRunAt: redTeamState.lastRunAt
            ) { [weak self] routine in
                guard let self, self.llmReady, self.settings.redTeamConsent else { return }
                self.settingsSection = .redTeam
                self.redTeamProjectPath = routine.projectPath
                self.startRedTeam(projectPath: routine.projectPath, resume: true)
            }
        } else {
            redTeamScheduler?.update(
                routines: redTeamState.routines,
                lastRunAt: redTeamState.lastRunAt
            )
        }
        redTeamScheduler?.start()
    }

    func loadPestProjects() {
        guard !isLoadingPestProjects else { return }
        isLoadingPestProjects = true
        let folders = settings.folders
        let excludedPaths = settings.excludedPaths
        pestProjectsTask?.cancel()
        pestProjectsTask = Task { [weak self] in
            let discovery = await Task.detached(priority: .userInitiated) {
                ProjectScanner().preview(folders: folders, excludedPaths: excludedPaths)
            }.value
            guard !Task.isCancelled else {
                self?.isLoadingPestProjects = false
                return
            }
            guard let self else { return }

            self.pestProjects = discovery.projects
                .map(\.ref)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            self.isLoadingPestProjects = false
            self.reconcilePestProjectSelection()

            let paths = Set(self.pestProjects.map(\.path))
            if let current = self.pestProjectPath,
               !paths.contains(current) || !self.isPestProjectActive(current) {
                self.pestProjectPath = nil
            }
            if self.pestProjectPath == nil {
                let preferredPath = self.pestState.routines.first?.projectPath
                    ?? self.report?.alerts.first?.project.path
                    ?? self.pestState.reports.first?.projectPath
                self.pestProjectPath = self.pestProjects
                    .first(where: {
                        $0.path == preferredPath && self.isPestProjectActive($0.path)
                    })?
                    .path ?? self.activePestProjects.first?.path
            }
            self.pestReport = self.pestProjectPath.flatMap { path in
                self.pestState.reports.first { $0.projectPath == path }
            }
            if self.pestProjects.isEmpty {
                self.pestError = discovery.warnings.first.map(L10n.t)
            }
        }
    }

    private func reconcilePestProjectSelection() {
        guard !pestProjects.isEmpty else { return }
        let available = Set(pestProjects.map(\.path))
        var state = pestState
        var active = state.activeProjectPaths.filter { available.contains($0) }

        if !state.hasCustomizedActiveProjects {
            var seen = Set<String>()
            let seeds = state.routines.map(\.projectPath)
                + state.reports.prefix(5).map(\.projectPath)
                + [pestProjectPath].compactMap { $0 }
            active = seeds.filter {
                available.contains($0) && seen.insert($0).inserted
            }
            if active.isEmpty, let first = pestProjects.first?.path {
                active = [first]
            }
            state.hasCustomizedActiveProjects = true
        }

        guard state.activeProjectPaths != active
                || state.hasCustomizedActiveProjects != pestState.hasCustomizedActiveProjects else {
            return
        }
        state.activeProjectPaths = active
        pestState = state
        persistPestState()
    }

    func selectPestProject(_ path: String) {
        guard pestProjects.contains(where: { $0.path == path }) else { return }
        pestProjectPath = path
        pestReport = pestState.reports.first { $0.projectPath == path }
        pestError = nil
        if !isPestProjectActive(path) {
            setPestProjectActive(path, active: true)
        }
    }

    func setPestProjectActive(_ path: String, active: Bool) {
        guard pestProjects.contains(where: { $0.path == path }) else { return }
        var state = pestState
        state.hasCustomizedActiveProjects = true
        if active {
            if !state.activeProjectPaths.contains(path) {
                state.activeProjectPaths.append(path)
            }
        } else {
            state.activeProjectPaths.removeAll { $0 == path }
        }

        guard state.activeProjectPaths != pestState.activeProjectPaths
                || state.hasCustomizedActiveProjects != pestState.hasCustomizedActiveProjects else {
            return
        }
        pestState = state
        persistPestState()

        if active {
            if pestProjectPath == nil {
                selectPestProject(path)
            }
        } else if pestProjectPath == path {
            if let next = activePestProjects.first?.path {
                selectPestProject(next)
            } else {
                pestProjectPath = nil
                pestReport = nil
                pestError = nil
            }
        }
    }

    func startPest(resume: Bool = false) {
        guard !isPestRunning else { return }
        guard llmReady else {
            pestError = isHackMode
                ? L10n.t("Cole a chave RTX em Ajustes > Análises para usar o Pest.", "Paste the RTX key in Settings > AI and security to use Pest.")
                : L10n.t("Conecte a conta da Cultura Builder para usar o Pest com IA.", "Connect the Cultura Builder account to use Pest with AI.")
            return
        }
        guard let project = selectedPestProject else {
            pestError = L10n.t("Selecione um projeto para analisar.", "Select a project to analyze.")
            return
        }
        let resumeState = resume ? selectedPestReport?.resumeState : nil
        if resume, resumeState == nil {
            pestError = L10n.t("Não há uma análise pausada para retomar.", "There is no paused analysis to resume.")
            return
        }
        pestTask?.cancel()
        pestTask = Task { [weak self] in
            await self?.performPest(
                project: project,
                routine: nil,
                resume: resumeState
            )
        }
    }

    func cancelPest() {
        pestRunID = UUID()
        pestTask?.cancel()
        pestTask = nil
        isPestRunning = false
        pestProgress = nil
        showToast(L10n.t("Análise Pest cancelada", "Pest analysis canceled"))
    }

    func copyPestFixPrompt(_ finding: PestFinding) {
        copyText(Vocabulary.prompt(finding.fixPrompt), toast: L10n.t("Prompt de correção copiado", "Fix prompt copied"))
    }

    func copyPestSummary(_ report: PestReport) {
        let lines = [
            "Pest · \(report.projectName)",
            report.summary,
            "",
            report.findings.map { finding in
                "[\(L10n.t(finding.severity.label).uppercased())] \(finding.title) · \(finding.file)\(finding.line.map { ":\($0)" } ?? "")"
            }.joined(separator: "\n")
        ]
        copyText(lines.joined(separator: "\n"), toast: L10n.t("Resumo do Pest copiado", "Pest summary copied"))
    }

    func clearSelectedPestReport() {
        guard let path = pestProjectPath else { return }
        var state = pestState
        let before = state.reports.count
        state.reports.removeAll { $0.projectPath == path }
        guard state.reports.count != before else { return }
        for index in state.routines.indices where state.routines[index].projectPath == path {
            state.routines[index].lastReportID = nil
        }
        pestState = state
        pestReport = nil
        persistPestState()
        showToast(L10n.t("Relatório do Pest removido", "Pest report removed"))
    }

    func clearAllPestReports() {
        guard !pestState.reports.isEmpty else { return }
        var state = pestState
        state.reports.removeAll()
        for index in state.routines.indices {
            state.routines[index].lastReportID = nil
        }
        pestState = state
        pestReport = nil
        persistPestState()
        showToast(L10n.t("Todos os relatórios do Pest foram removidos", "All Pest reports were removed"))
    }

    func startNetworkAnalysis() {
        guard !isNetworkRunning else { return }
        networkTask?.cancel()

        let runID = UUID()
        networkRunID = runID
        isNetworkRunning = true
        networkError = nil
        networkProgress = NetworkProgress(
            phase: L10n.t("Preparando", "Preparing"),
            detail: L10n.t("Lendo a rede atual sem capturar tráfego."),
            fraction: 0.01
        )

        let context = NetworkAuditContext(isPublicNetwork: networkIsPublic)
        let service = networkService
        networkTask = Task { [weak self] in
            let report = await service.analyze(context: context) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.networkRunID == runID else { return }
                    self.networkProgress = progress
                }
            }
            guard let self, self.networkRunID == runID else { return }
            self.finishNetwork(report)
        }
    }

    func cancelNetworkAnalysis() {
        networkRunID = UUID()
        networkTask?.cancel()
        networkTask = nil
        isNetworkRunning = false
        networkProgress = nil
        showToast(L10n.t("Análise da rede cancelada", "Network analysis canceled"))
    }

    func copyNetworkFixPrompt(_ finding: NetworkFinding) {
        copyText(Vocabulary.prompt(finding.fixPrompt), toast: L10n.t("Prompt de correção copiado", "Fix prompt copied"))
    }

    func copyNetworkGeneralPrompt(_ report: NetworkReport) {
        copyText(
            Vocabulary.prompt(NetworkPromptBuilder.generalPrompt(for: report)),
            toast: L10n.t("Prompt geral da rede copiado", "General network prompt copied")
        )
    }

    func copyNetworkSummary(_ report: NetworkReport) {
        var lines = [
            L10n.t("Minha rede", "My network"),
            report.summary,
            "",
            report.assurance
        ]
        if !report.findings.isEmpty {
            lines.append("")
            lines.append(L10n.t("Pontos de atenção:", "Points of attention:"))
            lines.append(contentsOf: report.findings.map { finding in
                "[\(L10n.t(finding.severity.label).uppercased())] \(finding.title) · \(finding.target)"
            })
        }
        if !report.scenarios.isEmpty {
            lines.append("")
            lines.append(L10n.t("Cenários:", "Scenarios:"))
            lines.append(contentsOf: report.scenarios.map { scenario in
                "\(L10n.t(scenario.status.label)): \(scenario.title). \(scenario.explanation)"
            })
        }
        copyText(lines.joined(separator: "\n"), toast: L10n.t("Resumo da rede copiado", "Network summary copied"))
    }

    private func finishNetwork(_ report: NetworkReport) {
        var state = networkState
        state.addReport(report)
        networkState = state
        store.saveNetworkState(state)
        networkReport = report
        isNetworkRunning = false
        networkProgress = nil
        networkError = nil

        showToast(
            report.findings.isEmpty
                ? L10n.t("Rede verificada sem achados", "Network checked with no findings")
                : L10n.t("Rede verificada: \(Vocabulary.quantity(report.findings.count, "ponto de atenção", "pontos de atenção"))", "Network checked: \(Vocabulary.quantity(report.findings.count, "point of attention", "points of attention"))")
        )
        if settings.notifyOnFindings, !report.findings.isEmpty {
            NotificationService.notifyNetwork(report)
        }
    }

    func pestRoutineConflict(
        hour: Int,
        minute: Int,
        projectPath: String,
        excluding id: UUID? = nil
    ) -> String? {
        PestRoutinePlanner.conflict(
            hour: hour,
            minute: minute,
            projectPath: projectPath,
            routines: pestState.routines,
            excluding: id
        )
    }

    @discardableResult
    func savePestRoutine(
        project: ProjectRef,
        hour: Int,
        minute: Int
    ) -> String? {
        let normalizedHour = min(23, max(0, hour))
        let normalizedMinute = min(59, max(0, minute))
        let existing = pestState.routines.first { $0.projectPath == project.path }
        if let conflict = pestRoutineConflict(
            hour: normalizedHour,
            minute: normalizedMinute,
            projectPath: project.path,
            excluding: existing?.id
        ) {
            return conflict
        }

        var state = pestState
        if let index = state.routines.firstIndex(where: { $0.projectPath == project.path }) {
            state.routines[index].projectName = project.name
            state.routines[index].hour = normalizedHour
            state.routines[index].minute = normalizedMinute
            state.routines[index].useLLM = true
            state.routines[index].enabled = true
            state.routines[index].updatedAt = Date()
        } else {
            state.routines.append(
                PestRoutine(
                    projectPath: project.path,
                    projectName: project.name,
                    hour: normalizedHour,
                    minute: normalizedMinute,
                    useLLM: true
                )
            )
        }
        state.routines.sort { $0.timeLabel < $1.timeLabel }
        pestState = state
        persistPestState()
        showToast(L10n.t("Rotina Pest salva", "Pest routine saved"))
        return nil
    }

    @discardableResult
    func updatePestRoutine(
        id: UUID,
        hour: Int,
        minute: Int,
        enabled: Bool
    ) -> String? {
        guard let index = pestState.routines.firstIndex(where: { $0.id == id }) else {
            return L10n.t("Rotina não encontrada.", "Routine not found.")
        }
        let current = pestState.routines[index]
        let normalizedHour = min(23, max(0, hour))
        let normalizedMinute = min(59, max(0, minute))
        if enabled,
           let conflict = pestRoutineConflict(
               hour: normalizedHour,
               minute: normalizedMinute,
               projectPath: current.projectPath,
               excluding: id
           ) {
            return conflict
        }

        var state = pestState
        state.routines[index].hour = normalizedHour
        state.routines[index].minute = normalizedMinute
        state.routines[index].useLLM = true
        state.routines[index].enabled = enabled
        state.routines[index].updatedAt = Date()
        state.routines.sort { $0.timeLabel < $1.timeLabel }
        pestState = state
        persistPestState()
        showToast(enabled ? L10n.t("Rotina Pest atualizada", "Pest routine updated") : L10n.t("Rotina Pest pausada", "Pest routine paused"))
        return nil
    }

    func setPestRoutineEnabled(id: UUID, enabled: Bool) {
        guard let routine = pestState.routines.first(where: { $0.id == id }) else { return }
        _ = updatePestRoutine(
            id: id,
            hour: routine.hour,
            minute: routine.minute,
            enabled: enabled
        )
    }

    func removePestRoutine(id: UUID) {
        var state = pestState
        state.routines.removeAll { $0.id == id }
        pestState = state
        persistPestState()
        showToast(L10n.t("Rotina Pest removida", "Pest routine removed"))
    }

    private func performPest(
        project: ProjectRef,
        routine: PestRoutine?,
        resume: PestResumeState?
    ) async {
        guard !isPestRunning else { return }
        guard llmReady else {
            pestError = isHackMode
                ? L10n.t("Cole a chave RTX em Ajustes > Análises para usar o Pest.", "Paste the RTX key in Settings > AI and security to use Pest.")
                : L10n.t("Conecte a conta da Cultura Builder para usar o Pest com IA.", "Connect the Cultura Builder account to use Pest with AI.")
            pestProgress = nil
            isPestRunning = false
            return
        }

        let excludedPaths = settings.excludedPaths
        if PathExclusions.contains(project.path, in: PathExclusions.normalized(excludedPaths)) {
            pestError = L10n.t(PestError.projectExcluded.localizedDescription)
            pestProgress = nil
            isPestRunning = false
            return
        }

        let runID = UUID()
        pestRunID = runID
        isPestRunning = true
        pestError = nil
        pestProgress = PestProgress(
            phase: resume == nil
                ? L10n.t("Preparando", "Preparing")
                : L10n.t("Retomando", "Resuming"),
            detail: resume == nil
                ? L10n.t("Mapeando arquivos com orçamento de memória.", "Mapping files with a memory budget.")
                : L10n.t("Retomando a análise pausada.", "Resuming the paused analysis."),
            fraction: 0.01
        )

        let startedAt = Date()
        var state = pestState
        state.lastRunAt = startedAt
        if let routine,
           let index = state.routines.firstIndex(where: { $0.id == routine.id }) {
            state.routines[index].lastRunAt = startedAt
            state.routines[index].updatedAt = startedAt
        }
        pestState = state
        persistPestState()

        let service = pestService
        let routineID = routine?.id
        do {
            let report = try await service.analyze(
                project: project,
                useLLM: true,
                routineID: routineID,
                resume: resume,
                excludedPaths: excludedPaths
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.pestProgress = progress
                }
            }
            guard pestRunID == runID else { return }
            finishPest(report, routineID: routineID)
        } catch is CancellationError {
            guard pestRunID == runID else { return }
            isPestRunning = false
            pestProgress = nil
        } catch {
            guard pestRunID == runID else { return }
            isPestRunning = false
            pestProgress = nil
            pestError = L10n.t(error.localizedDescription)
        }
    }

    private func finishPest(_ report: PestReport, routineID: UUID?) {
        var state = pestState
        state.addReport(report)
        if let routineID,
           let index = state.routines.firstIndex(where: { $0.id == routineID }) {
            state.routines[index].lastReportID = report.id
            state.routines[index].lastRunAt = report.startedAt
            state.routines[index].updatedAt = Date()
        }
        pestState = state
        persistPestState()

        if pestProjectPath == nil || pestProjectPath == report.projectPath {
            pestReport = report
        }
        isPestRunning = false
        pestProgress = nil

        if report.paused {
            let reason = report.pauseReason ?? L10n.t("memória insuficiente", "low memory")
            pestError = L10n.t("Pest pausou: \(L10n.t(reason))", "Pest paused: \(L10n.t(reason))")
            showToast(L10n.t("Pest pausou. Abra o relatório para retomar.", "Pest paused. Open the report to resume."))
            NotificationService.notifyPestPaused(report)
        } else {
            pestError = nil
            showToast(
                report.findings.isEmpty
                    ? L10n.t("Pest concluído sem achados", "Pest finished with no findings")
                    : L10n.t("Pest concluído: \(report.findings.count) achado(s)", "Pest finished: \(report.findings.count) finding(s)")
            )
            if settings.notifyOnFindings, !report.findings.isEmpty {
                NotificationService.notifyPest(report)
            }
        }
    }

    private func persistPestState() {
        store.savePestState(pestState)
        pestScheduler?.update(
            routines: pestState.routines,
            lastRunAt: pestState.lastRunAt
        )
    }

    private func startPestScheduler() {
        if pestScheduler == nil {
            pestScheduler = PestScheduler(
                routines: pestState.routines,
                lastRunAt: pestState.lastRunAt
            ) { [weak self] routine in
                guard let self, self.llmReady else { return }
                await self.performPest(
                    project: routine.project,
                    routine: routine,
                    resume: nil
                )
            }
        } else {
            pestScheduler?.update(
                routines: pestState.routines,
                lastRunAt: pestState.lastRunAt
            )
        }
        pestScheduler?.start()
    }

    func updateSettings(_ draft: AppSettings, announce: Bool = true) {
        var next = draft
        next.hasCompletedOnboarding = true
        next.folders = deduplicated(next.folders)
        next.excludedPaths = deduplicatedExclusions(next.excludedPaths)
        next.scheduleHour = min(23, max(0, next.scheduleHour))
        next.scheduleMinute = min(59, max(0, next.scheduleMinute))
        let wasCompleted = settings.hasCompletedOnboarding
        let previousFolders = settings.folders.map(\.path)
        let previousExclusions = settings.excludedPaths
        let previousLanguage = settings.appLanguage
        settings = next
        if next.appLanguage != previousLanguage {
            language = next.appLanguage
            L10n.language = next.appLanguage
        }
        store.saveSettings(next)
        startScheduler()
        if next.notifyOnFindings {
            NotificationService.requestAuthorization()
        }
        if previousExclusions != next.excludedPaths {
            purgePestFindings(excludedPaths: next.excludedPaths)
        }
        if wasCompleted,
           !isScanning,
           previousFolders != next.folders.map(\.path) || previousExclusions != next.excludedPaths {
            scheduleExclusionRescan()
        }
        if announce {
            showToast(L10n.t("Ajustes salvos", "Settings saved"))
        }
    }

    private func purgePestFindings(excludedPaths: [String]) {
        let exclusions = PathExclusions.normalized(excludedPaths)
        guard !exclusions.isEmpty else { return }

        var state = pestState
        var changed = false
        for index in state.reports.indices {
            let report = state.reports[index]
            let filtered = report.excluding(exclusions)
            if filtered.findings.count != report.findings.count
                || filtered.resumeState?.processedPaths.count != report.resumeState?.processedPaths.count {
                state.reports[index] = filtered
                changed = true
            }
        }
        if changed {
            pestState = state
            persistPestState()
        }
        pestReport = pestReport?.excluding(exclusions)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let ok = LaunchAtLogin.setEnabled(
            enabled,
            bundleURL: Bundle.main.bundleURL
        )
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        if enabled, !ok {
            showToast(L10n.t("Abra o app instalado para ativar a inicialização automática.", "Open the installed app to enable launch at login."))
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
                showToast(authStatus.connected ? L10n.t("Conta conectada", "Account connected") : L10n.t("Sessão não encontrada", "Session not found"))
            }
        } catch {
            authStatus = authStore.status()
            if force {
                showToast(L10n.t("Não consegui renovar a sessão.", "Could not renew the session."))
            }
        }
    }

    func copyLoginCommand() {
        copyText(authStatus.loginCommand, toast: L10n.t("Comando copiado", "Command copied"))
    }

    func testLLMConnection() async {
        guard !isTestingLLM else { return }
        isTestingLLM = true
        llmTestResult = nil
        llmTestOK = false
        defer { isTestingLLM = false }

        if !isHackMode {
            do {
                _ = try await authStore.validAccessToken()
                llmTestOK = true
                llmTestResult = L10n.t("Sessão da Cultura Builder válida.", "Valid Cultura Builder session.")
            } catch {
                llmTestResult = L10n.t(error.localizedDescription)
            }
            return
        }

        guard settings.hasRTXKey else {
            llmTestResult = LLMConfigurationError.missingKey.localizedDescription
            return
        }
        guard var components = URLComponents(string: settings.rtxEndpointValue) else {
            llmTestResult = LLMConfigurationError.invalidEndpoint.localizedDescription
            return
        }
        var path = components.path
        if !path.hasSuffix("/models") {
            path += path.hasSuffix("/") ? "models" : "/models"
        }
        components.path = path
        guard let url = components.url else {
            llmTestResult = LLMConfigurationError.invalidEndpoint.localizedDescription
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("Bearer \(settings.rtxKey)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                llmTestResult = L10n.t("O endpoint respondeu com erro \((response as? HTTPURLResponse)?.statusCode ?? 0). Confira a chave.", "The endpoint answered with error \((response as? HTTPURLResponse)?.statusCode ?? 0). Check the key.")
                return
            }
            let models = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["data"] as? [[String: Any]] }?
                .compactMap { $0["id"] as? String } ?? []
            if models.contains(settings.rtxModelValue) {
                llmTestOK = true
                llmTestResult = L10n.t("Endpoint e chave válidos. Modelo \(settings.rtxModelValue) disponível.", "Endpoint and key valid. Model \(settings.rtxModelValue) available.")
            } else if models.isEmpty {
                llmTestOK = true
                llmTestResult = L10n.t("Endpoint e chave responderam, mas sem lista de modelos.", "Endpoint and key answered, but with no model list.")
            } else {
                llmTestResult = L10n.t("A chave funciona, mas o modelo configurado não aparece na lista.", "The key works, but the configured model is not in the list.")
            }
        } catch {
            llmTestResult = L10n.t("Não consegui falar com o endpoint RTX. Confira a URL e a rede.", "Could not reach the RTX endpoint. Check the URL and the network.")
        }
    }

    func copyFixPrompt(_ alert: ProjectAlert) {
        copyText(Vocabulary.prompt(alert.fixPrompt), toast: L10n.t("Prompt de correção copiado", "Fix prompt copied"))
    }

    func copyAllFixPrompts(_ alerts: [ProjectAlert]) {
        guard !alerts.isEmpty else { return }
        let prompt = PromptBuilder.buildCombined(for: alerts)
        copyText(Vocabulary.prompt(prompt), toast: L10n.t("Prompt geral copiado", "General prompt copied"))
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
            current.summary = L10n.t("Atualizando a análise após ignorar uma pasta…", "Updating the analysis after ignoring a folder…")
            current.nextSteps = []
            report = current
            store.saveReport(current)
        }

        showToast(L10n.t("Pasta ignorada. Atualizando a análise…", "Folder ignored. Updating the analysis…"))
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
        showToast(L10n.t("Pasta monitorada novamente", "Folder monitored again"))
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
        panel.title = L10n.t("Escolher pastas de projetos", "Choose project folders")
        panel.message = L10n.t("A varredura lê apenas manifests e lockfiles. Worktrees do Git são ignoradas automaticamente e podem ser reativadas em Ajustes > Pastas.", "The scan reads only manifests and lockfiles. Git worktrees are ignored automatically and can be reactivated in Settings > Folders.")
        panel.prompt = L10n.t("Monitorar", "Monitor")
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
        excludedPaths: [String] = [],
        projectLimit: Int = 40
    ) async -> FolderPreview {
        await Task.detached(priority: .userInitiated) {
            let discovery = ProjectScanner().preview(
                folders: folders,
                excludedPaths: excludedPaths,
                projectLimit: projectLimit
            )
            let refs = discovery.projects
                .map(\.ref)
                .sorted { left, right in
                    if left.name != right.name {
                        return left.name.localizedStandardCompare(right.name) == .orderedAscending
                    }
                    return left.path.localizedStandardCompare(right.path) == .orderedAscending
                }
            return FolderPreview(projectRefs: refs, warnings: discovery.warnings)
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
