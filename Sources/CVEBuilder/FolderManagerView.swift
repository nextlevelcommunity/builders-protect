import AppKit
import CVECore
import SwiftUI

struct FolderManagerView: View {
    @ObservedObject var model: AppModel
    var folders: [MonitoredFolder]
    var onApply: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var projectRefs: [ProjectRef] = []
    @State private var draftExclusions: [String]
    @State private var selection = Set<String>()
    @State private var query = ""
    @State private var isLoading = true
    @State private var loadError: String?

    init(
        model: AppModel,
        folders: [MonitoredFolder],
        excludedPaths: [String],
        onApply: @escaping ([String]) -> Void
    ) {
        self.model = model
        self.folders = folders
        self.onApply = onApply
        _draftExclusions = State(initialValue: excludedPaths)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CBTheme.hairline)
            toolbar
            Divider().overlay(CBTheme.hairline)

            Group {
                if isLoading {
                    loadingState
                } else if let loadError {
                    errorState(loadError)
                } else if filteredCandidates.isEmpty {
                    emptyState
                } else {
                    candidateList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(CBTheme.hairline)
            footer
        }
        .frame(minWidth: 820, minHeight: 640)
        .background(CBTheme.background)
        .preferredColorScheme(.dark)
        .task {
            await load()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CBTheme.limeMuted)
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CBTheme.lime)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Gerenciar pastas")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                Text("Selecione uma ou várias pastas para ignorar. A escolha vale para a varredura, o Pest e o Red Teaming. Pastas de build, preview e artefatos costumam não ser projetos reais.")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle(size: 27))
            .help("Fechar")
        }
        .padding(20)
    }

    private var toolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CBTheme.textTertiary)
                TextField("Buscar por nome ou caminho", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CBTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(CBTheme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            HStack(spacing: 7) {
                Button {
                    selection = Set(
                        filteredCandidates
                            .filter { $0.isLikelyArtifact && !isIgnored($0.path) }
                            .map(\.path)
                    )
                } label: {
                    Label("Selecionar artefatos", systemImage: "wand.and.stars")
                }
                .buttonStyle(GhostButtonStyle(tint: CBTheme.lime))
                .help("Seleciona artefatos que ainda entram na varredura")
                .disabled(
                    isLoading || !filteredCandidates.contains {
                        $0.isLikelyArtifact && !isIgnored($0.path)
                    }
                )

                Button {
                    selection = Set(filteredCandidates.filter { isIgnored($0.path) }.map(\.path))
                } label: {
                    Label("Selecionar ignoradas", systemImage: "eye.slash")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(isLoading || !filteredCandidates.contains { isIgnored($0.path) })

                Button {
                    selection = Set(filteredCandidates.map(\.path))
                } label: {
                    Label("Selecionar todas", systemImage: "checkmark.circle")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(isLoading || filteredCandidates.isEmpty)

                if !selection.isEmpty {
                    Button {
                        selection.removeAll()
                    } label: {
                        Label("Limpar seleção", systemImage: "xmark.circle")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Spacer()

                Button {
                    addExclusion()
                } label: {
                    Label("Adicionar pasta", systemImage: "folder.badge.plus")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var candidateList: some View {
        List(selection: $selection) {
            ForEach(filteredCandidates) { candidate in
                candidateRow(candidate)
                    .tag(candidate.path)
                    .contextMenu {
                        if isIgnored(candidate.path) {
                            Button("Reativar pasta") {
                                reactivate([candidate.path])
                            }
                        } else {
                            Button("Ignorar pasta") {
                                ignore([candidate.path])
                            }
                        }
                        Divider()
                        Button("Abrir no Finder") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: candidate.path, isDirectory: true))
                        }
                    }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(CBTheme.background)
    }

    private func candidateRow(_ candidate: FolderCandidate) -> some View {
        let ignored = isIgnored(candidate.path)
        let parent = ignoredBy(candidate.path)
        let selected = selection.contains(candidate.path)

        return HStack(spacing: 10) {
            Button {
                if selected {
                    selection.remove(candidate.path)
                } else {
                    selection.insert(candidate.path)
                }
            } label: {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? CBTheme.lime : CBTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(selected ? "Remover da seleção" : "Selecionar pasta")

            Image(systemName: ignored ? "eye.slash.fill" : "folder.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ignored ? CBTheme.textTertiary : CBTheme.lime.opacity(0.85))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(candidate.name)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(ignored ? CBTheme.textSecondary : CBTheme.text)
                    if candidate.isLikelyArtifact {
                        badge("artefato", tint: CBTheme.high)
                    }
                    if candidate.isWorktree {
                        badge("worktree", tint: CBTheme.lime)
                    }
                    if !candidate.isProject {
                        badge("pasta", tint: CBTheme.textTertiary)
                    }
                }

                Text(candidate.displayPath(in: folders))
                    .font(.system(size: 8.8, weight: .regular, design: .monospaced))
                    .foregroundStyle(CBTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let parent, parent != candidate.path {
                    Text("Ignorada por \(URL(fileURLWithPath: parent).lastPathComponent)")
                        .font(.system(size: 8.5, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                } else if !candidate.lockfiles.isEmpty {
                    Text(candidate.lockfiles.prefix(3).joined(separator: " · "))
                        .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(CBTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            Text(ignored ? "IGNORADA" : "MONITORADA")
                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(ignored ? CBTheme.high : CBTheme.mint)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    (ignored ? CBTheme.high : CBTheme.mint).opacity(0.10),
                    in: Capsule()
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Vocabulary.quantity(monitoredCount, "projeto monitorado", "projetos monitorados")) · \(Vocabulary.quantity(ignoredProjectCount, "ignorado", "ignorados"))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(CBTheme.text)
                if !selection.isEmpty {
                    Text(Vocabulary.quantity(selection.count, "pasta selecionada", "pastas selecionadas"))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(CBTheme.textTertiary)
                }
            }

            Spacer()

            Button("Cancelar") {
                dismiss()
            }
            .buttonStyle(GhostButtonStyle())

            Button {
                ignore(selection)
            } label: {
                Label("Ignorar selecionadas", systemImage: "eye.slash")
            }
            .buttonStyle(GhostButtonStyle(tint: CBTheme.high))
            .disabled(selection.isEmpty || !selection.contains { !isIgnored($0) })

            Button {
                reactivate(selection)
            } label: {
                Label("Reativar selecionadas", systemImage: "eye")
            }
            .buttonStyle(GhostButtonStyle(tint: CBTheme.mint))
            .disabled(selection.isEmpty || !selection.contains { isIgnored($0) })

            Button {
                onApply(normalizedExclusions(draftExclusions))
                dismiss()
            } label: {
                Text("Aplicar")
            }
            .buttonStyle(LimeButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Procurando projetos…")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CBTheme.high)
            Text(message)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(CBTheme.textTertiary)
            Text(query.isEmpty ? "Nenhuma pasta encontrada." : "Nenhuma pasta corresponde à busca.")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(CBTheme.textSecondary)
        }
        .padding(30)
    }

    private var candidates: [FolderCandidate] {
        var items = projectRefs.map { ref in
            FolderCandidate(
                path: ref.path,
                name: ref.name,
                lockfiles: ref.lockfiles,
                isProject: true,
                isWorktree: WorktreeSafety.isLinkedWorktree(ref.url)
            )
        }
        let projectPaths = Set(items.map(\.path))
        for path in draftExclusions where !projectPaths.contains(path) {
            items.append(
                FolderCandidate(
                    path: path,
                    name: URL(fileURLWithPath: path).lastPathComponent,
                    lockfiles: [],
                    isProject: false,
                    isWorktree: WorktreeSafety.isLinkedWorktree(URL(fileURLWithPath: path, isDirectory: true))
                )
            )
        }

        return items.sorted { left, right in
            if left.isLikelyArtifact != right.isLikelyArtifact {
                return left.isLikelyArtifact
            }
            if left.isProject != right.isProject {
                return left.isProject
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    private var filteredCandidates: [FolderCandidate] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return candidates
        }
        let needle = query.localizedLowercase
        return candidates.filter {
            $0.name.localizedLowercase.contains(needle)
                || $0.path.localizedLowercase.contains(needle)
                || $0.displayPath(in: folders).localizedLowercase.contains(needle)
        }
    }

    private var monitoredCount: Int {
        candidates.filter { $0.isProject && !isIgnored($0.path) }.count
    }

    private var ignoredProjectCount: Int {
        candidates.filter { $0.isProject && isIgnored($0.path) }.count
    }

    private func isIgnored(_ path: String) -> Bool {
        ignoredBy(path) != nil
    }

    private func ignoredBy(_ path: String) -> String? {
        FolderExclusionPlanner.nearestExclusion(for: path, in: draftExclusions)
    }

    private func ignore(_ paths: Set<String>) {
        let monitored = paths.filter { !isIgnored($0) }
        draftExclusions = FolderExclusionPlanner.ignoring(
            Array(monitored),
            exclusions: draftExclusions
        )
        selection.removeAll()
    }

    private func reactivate(_ paths: Set<String>) {
        draftExclusions = FolderExclusionPlanner.reactivating(
            paths,
            exclusions: draftExclusions,
            candidates: candidates.map(\.path)
        )
        selection.removeAll()
    }

    private func normalizedExclusions(_ paths: [String]) -> [String] {
        FolderExclusionPlanner.normalized(paths)
    }

    private func addExclusion() {
        let panel = NSOpenPanel()
        panel.title = "Ignorar pasta"
        panel.message = "Escolha uma ou várias pastas que não devem entrar nas próximas varreduras."
        panel.prompt = "Ignorar pastas"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let path = url.standardizedFileURL.path
            if !draftExclusions.contains(path) {
                draftExclusions.append(path)
            }
        }
        draftExclusions = normalizedExclusions(draftExclusions)
    }

    private func load() async {
        isLoading = true
        loadError = nil
        let preview = await model.previewFolders(
            folders,
            excludedPaths: [],
            projectLimit: 200
        )
        projectRefs = preview.projectRefs
        if preview.projectRefs.isEmpty, preview.warnings.contains(where: { $0.contains("não existe") }) {
            loadError = "Não consegui ler as pastas monitoradas. Verifique se elas ainda existem."
        }
        isLoading = false
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 7, weight: .heavy, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct FolderCandidate: Identifiable {
    var path: String
    var name: String
    var lockfiles: [String]
    var isProject: Bool
    var isWorktree: Bool

    var id: String { path }

    var isLikelyArtifact: Bool {
        ProjectPathHeuristics.isLikelyArtifact(path: path)
    }

    func displayPath(in folders: [MonitoredFolder]) -> String {
        for folder in folders {
            if path == folder.path {
                return folder.displayName
            }
            if path.hasPrefix(folder.path + "/") {
                return String(path.dropFirst(folder.path.count + 1))
            }
        }
        return path.homeAbbreviated
    }
}
