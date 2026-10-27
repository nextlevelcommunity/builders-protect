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
    @Published private(set) var folderPreview: FolderPreview?
    @Published private(set) var isPreviewingFolders = false
    @Published private(set) var redTeamProjects: [ProjectRef] = []
    @Published private(set) var isLoadingRedTeamProjects = false
    @Published var redTeamProjectPath: String?
    @Published private(set) var isRedTeamRunning = false
    @Published private(set) var redTeamProgress: RedTeamProgress?
    @Published private(set) var redTeamReport: RedTeamReport?
    @Published private(set) var redTeamError: String?
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
        self.settings = store.loadSettings()
        self.report = store.loadReport()
        self.authStatus = authStore.status()
        self.launchAtLoginEnabled = LaunchAtLogin.isEnabled
        self.redTeamReports = store.loadRedTeamReports()
        self.pestState = store.loadPestState()
        let networkState = store.loadNetworkState()
        self.networkState = networkState
        self.networkReport = networkState.latest
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
        !isPestRunning && selectedPestProject != nil && authStatus.connected
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
        let excludedPaths = settings.excludedPaths
        if PathExclusions.contains(project.path, in: PathExclusions.normalized(excludedPaths)) {
            redTeamError = RedTeamError.projectExcluded.localizedDescription
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
                let report = try await service.analyze(
                    project: project,
                    excludedPaths: excludedPaths
                ) { [weak self] progress in
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
                self.pestError = discovery.warnings.first
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
        guard authStatus.connected else {
            pestError = "Conecte a conta da Cultura Builder para usar o Pest com IA."
            return
        }
        guard let project = selectedPestProject else {
            pestError = "Selecione um projeto para analisar."
            return
        }
        let resumeState = resume ? selectedPestReport?.resumeState : nil
        if resume, resumeState == nil {
            pestError = "Não há uma análise pausada para retomar."
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
        showToast("Análise Pest cancelada")
    }

    func copyPestFixPrompt(_ finding: PestFinding) {
        copyText(Vocabulary.prompt(finding.fixPrompt), toast: "Prompt de correção copiado")
    }

    func copyPestSummary(_ report: PestReport) {
        let lines = [
            "Pest · \(report.projectName)",
            report.summary,
            "",
            report.findings.map { finding in
                "[\(finding.severity.label.uppercased())] \(finding.title) · \(finding.file)\(finding.line.map { ":\($0)" } ?? "")"
            }.joined(separator: "\n")
        ]
        copyText(lines.joined(separator: "\n"), toast: "Resumo do Pest copiado")
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
        showToast("Relatório do Pest removido")
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
        showToast("Todos os relatórios do Pest foram removidos")
    }

    func startNetworkAnalysis() {
        guard !isNetworkRunning else { return }
        networkTask?.cancel()

        let runID = UUID()
        networkRunID = runID
        isNetworkRunning = true
        networkError = nil
        networkProgress = NetworkProgress(
            phase: "Preparando",
            detail: "Lendo a rede atual sem capturar tráfego.",
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
        showToast("Análise da rede cancelada")
    }

    func copyNetworkFixPrompt(_ finding: NetworkFinding) {
        copyText(Vocabulary.prompt(finding.fixPrompt), toast: "Prompt de correção copiado")
    }

    func copyNetworkGeneralPrompt(_ report: NetworkReport) {
        copyText(
            Vocabulary.prompt(NetworkPromptBuilder.generalPrompt(for: report)),
            toast: "Prompt geral da rede copiado"
        )
    }

    func copyNetworkSummary(_ report: NetworkReport) {
        var lines = [
            "Minha rede",
            report.summary,
            "",
            report.assurance
        ]
        if !report.findings.isEmpty {
            lines.append("")
            lines.append("Pontos de atenção:")
            lines.append(contentsOf: report.findings.map { finding in
                "[\(finding.severity.label.uppercased())] \(finding.title) · \(finding.target)"
            })
        }
        if !report.scenarios.isEmpty {
            lines.append("")
            lines.append("Cenários:")
            lines.append(contentsOf: report.scenarios.map { scenario in
                "\(scenario.status.label): \(scenario.title). \(scenario.explanation)"
            })
        }
        copyText(lines.joined(separator: "\n"), toast: "Resumo da rede copiado")
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
                ? "Rede verificada sem achados"
                : "Rede verificada: \(Vocabulary.quantity(report.findings.count, "ponto de atenção", "pontos de atenção"))"
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
        showToast("Rotina Pest salva")
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
            return "Rotina não encontrada."
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
        showToast(enabled ? "Rotina Pest atualizada" : "Rotina Pest pausada")
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
        showToast("Rotina Pest removida")
    }

    private func performPest(
        project: ProjectRef,
        routine: PestRoutine?,
        resume: PestResumeState?
    ) async {
        guard !isPestRunning else { return }
        guard authStatus.connected else {
            pestError = "Conecte a conta da Cultura Builder para usar o Pest com IA."
            pestProgress = nil
            isPestRunning = false
            return
        }

        let excludedPaths = settings.excludedPaths
        if PathExclusions.contains(project.path, in: PathExclusions.normalized(excludedPaths)) {
            pestError = PestError.projectExcluded.localizedDescription
            pestProgress = nil
            isPestRunning = false
            return
        }

        let runID = UUID()
        pestRunID = runID
        isPestRunning = true
        pestError = nil
        pestProgress = PestProgress(
            phase: resume == nil ? "Preparando" : "Retomando",
            detail: resume == nil
                ? "Mapeando arquivos com orçamento de memória."
                : "Retomando a análise pausada.",
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
            pestError = error.localizedDescription
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
            let reason = report.pauseReason ?? "memória insuficiente"
            pestError = "Pest pausou: \(reason)"
            showToast("Pest pausou. Abra o relatório para retomar.")
            NotificationService.notifyPestPaused(report)
        } else {
            pestError = nil
            showToast(
                report.findings.isEmpty
                    ? "Pest concluído sem achados"
                    : "Pest concluído: \(report.findings.count) achado(s)"
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
                guard let self, self.authStatus.connected else { return }
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
        settings = next
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
            showToast("Ajustes salvos")
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
