import Foundation
import XCTest
@testable import CVECore

final class ProjectScannerTests: XCTestCase {
    func testRootProjectIsScanned() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("buildersprotect-root-\(UUID().uuidString)", isDirectory: true)

        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try #"{"name":"root-project","dependencies":{"foo":"1.0.0"}}"#
            .write(
                to: root.appendingPathComponent("package.json"),
                atomically: true,
                encoding: .utf8
            )
        try #"{"name":"root-project","lockfileVersion":3,"packages":{"":{"name":"root-project"},"node_modules/foo":{"version":"1.0.0"}}}"#
            .write(
                to: root.appendingPathComponent("package-lock.json"),
                atomically: true,
                encoding: .utf8
            )

        let discovery = ProjectScanner().scan(
            folders: [MonitoredFolder(path: root.path)],
            projectLimit: 10,
            packageLimit: 10
        )

        XCTAssertEqual(discovery.projects.map(\.ref.path), [root.standardizedFileURL.path])
    }

    func testExcludedSubfolderIsSkipped() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("buildersprotect-\(UUID().uuidString)", isDirectory: true)
        let keep = root.appendingPathComponent("keep", isDirectory: true)
        let skip = root.appendingPathComponent("sandbox", isDirectory: true)

        defer { try? fileManager.removeItem(at: root) }

        for directory in [keep, skip] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
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

        let discovery = ProjectScanner().scan(
            folders: [MonitoredFolder(path: root.path)],
            excludedPaths: [skip.path],
            projectLimit: 10,
            packageLimit: 10
        )

        XCTAssertEqual(discovery.projects.map(\.ref.path), [keep.standardizedFileURL.path])
        XCTAssertEqual(discovery.projects.first?.ref.lockfiles, ["package-lock.json"])
    }
}
