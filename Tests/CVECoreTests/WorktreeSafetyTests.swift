import Foundation
import XCTest
@testable import CVECore

final class WorktreeSafetyTests: XCTestCase {
    private var root: URL!
    private var main: URL!
    private var worktree: URL!

    override func setUpWithError() throws {
        let fileManager = FileManager.default
        root = fileManager.temporaryDirectory
            .appendingPathComponent("buildersprotect-worktree-\(UUID().uuidString)", isDirectory: true)
        main = root.appendingPathComponent("main", isDirectory: true)
        worktree = root.appendingPathComponent("worktrees/feature", isDirectory: true)

        try fileManager.createDirectory(
            at: main.appendingPathComponent(".git/worktrees/feature", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: worktree.appendingPathComponent("app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "gitdir: \(main.path)/.git/worktrees/feature\n"
            .write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        try "\(worktree.path)/.git\n"
            .write(
                to: main.appendingPathComponent(".git/worktrees/feature/gitdir"),
                atomically: true,
                encoding: .utf8
            )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testResolvesMainRootFromWorktreeSubfolder() {
        let location = WorktreeSafety.worktreeLocation(
            containing: worktree.appendingPathComponent("app", isDirectory: true)
        )

        XCTAssertEqual(location?.worktreeRoot.path, worktree.standardizedFileURL.path)
        XCTAssertEqual(location?.mainRoot.path, main.standardizedFileURL.path)
        XCTAssertNil(WorktreeSafety.worktreeLocation(containing: main))
    }

    func testFindsRegisteredWorktree() {
        let found = WorktreeSafety.registeredWorktrees(in: main)
        XCTAssertEqual(found.map(\.path), [worktree.standardizedFileURL.path])
    }

    func testFindsNestedWorktree() {
        let nested = main.appendingPathComponent(".worktrees/feature", isDirectory: true)
        try? FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try? "gitdir: \(main.path)/.git/worktrees/feature\n"
            .write(to: nested.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let found = WorktreeSafety.linkedWorktrees(under: main)
        XCTAssertEqual(found.map(\.path), [worktree.standardizedFileURL.path, nested.standardizedFileURL.path])
    }

    func testScannerSkipsExcludedWorktree() throws {
        try writeProject(at: main)
        try writeProject(at: worktree)

        let discovery = ProjectScanner().scan(
            folders: [MonitoredFolder(path: main.path)],
            excludedPaths: [worktree.path],
            projectLimit: 10,
            packageLimit: 10
        )

        XCTAssertEqual(discovery.projects.map(\.ref.path), [main.standardizedFileURL.path])
    }

    private func writeProject(at directory: URL) throws {
        try #"{"name":"project","dependencies":{"foo":"1.0.0"}}"#
            .write(
                to: directory.appendingPathComponent("package.json"),
                atomically: true,
                encoding: .utf8
            )
        try #"{"name":"project","lockfileVersion":3,"packages":{"":{"name":"project"},"node_modules/foo":{"version":"1.0.0"}}}"#
            .write(
                to: directory.appendingPathComponent("package-lock.json"),
                atomically: true,
                encoding: .utf8
            )
    }
}
