import XCTest
@testable import CVECore

final class RedTeamCollectorTests: XCTestCase {
    func testCollectorSkipsSecretsDependenciesAndBinaries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("builders-protect-redteam-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("src"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("node_modules/pkg"),
            withIntermediateDirectories: true
        )

        try """
        const apiKey = "super-secret-value";
        export function handler(req, res) {
            const id = req.query.id;
            return database.query("select * from users where id = " + id);
        }
        """.write(
            to: root.appendingPathComponent("src/app.js"),
            atomically: true,
            encoding: .utf8
        )

        try "TOKEN=abc123\n".write(
            to: root.appendingPathComponent(".env"),
            atomically: true,
            encoding: .utf8
        )
        try "module.exports = 1\n".write(
            to: root.appendingPathComponent("node_modules/pkg/index.js"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(
            to: root.appendingPathComponent("package-lock.json"),
            atomically: true,
            encoding: .utf8
        )
        try Data([0, 1, 2, 3]).write(to: root.appendingPathComponent("image.png"))

        let collection = try RedTeamCollector().collect(projectPath: root.path)
        let paths = collection.files.map(\.path)

        XCTAssertEqual(paths, ["src/app.js"])
        XCTAssertFalse(collection.files[0].content.contains("super-secret-value"))
        XCTAssertTrue(collection.files[0].content.contains("[REDACTED]"))
        XCTAssertTrue(collection.warnings.contains { $0.contains("redigidos") })
    }
}
