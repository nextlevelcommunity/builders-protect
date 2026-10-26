import XCTest
@testable import CVECore

final class FolderExclusionPlannerTests: XCTestCase {
    func testNormalizationRemovesDescendants() {
        let paths = [
            "/repo/artifacts/",
            "/repo/artifacts/releases/one",
            "/repo/apps/web"
        ]

        XCTAssertEqual(
            FolderExclusionPlanner.normalized(paths),
            ["/repo/apps/web", "/repo/artifacts"]
        )
    }

    func testIgnoringKeepsOnlySelectedRoots() {
        let exclusions = FolderExclusionPlanner.ignoring(
            ["/repo/artifacts/releases/one", "/repo/artifacts"],
            exclusions: ["/repo/apps/legacy"]
        )

        XCTAssertEqual(exclusions, ["/repo/apps/legacy", "/repo/artifacts"])
    }

    func testIgnoringSkipsAlreadyExcludedPaths() {
        let exclusions = FolderExclusionPlanner.ignoring(
            ["/repo/artifacts/releases/one"],
            exclusions: ["/repo/artifacts"]
        )

        XCTAssertEqual(exclusions, ["/repo/artifacts"])
    }

    func testReactivatingChildKeepsSiblingsExcluded() {
        let exclusions = FolderExclusionPlanner.reactivating(
            ["/repo/artifacts/releases/one"],
            exclusions: ["/repo/artifacts"],
            candidates: [
                "/repo/artifacts",
                "/repo/artifacts/releases/one",
                "/repo/artifacts/releases/two"
            ]
        )

        XCTAssertEqual(exclusions, ["/repo/artifacts/releases/two"])
    }

    func testReactivatingExclusionRootRemovesIt() {
        let exclusions = FolderExclusionPlanner.reactivating(
            ["/repo/artifacts"],
            exclusions: ["/repo/artifacts"],
            candidates: [
                "/repo/artifacts",
                "/repo/artifacts/releases/one"
            ]
        )

        XCTAssertEqual(exclusions, [])
    }
}
