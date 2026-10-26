import XCTest
@testable import CVECore

final class ProjectPathHeuristicsTests: XCTestCase {
    func testFlagsArtifactAndPreviewPaths() {
        XCTAssertTrue(ProjectPathHeuristics.isLikelyArtifact(
            path: "/Users/ana/projects/hub/artifacts/releases/20261009/source/app"
        ))
        XCTAssertTrue(ProjectPathHeuristics.isLikelyArtifact(
            path: "/Users/ana/projects/hub/.worktrees/feature"
        ))
        XCTAssertTrue(ProjectPathHeuristics.isLikelyArtifact(
            path: "/Users/ana/projects/hub/preview"
        ))
    }

    func testDoesNotFlagRegularProjectPaths() {
        XCTAssertFalse(ProjectPathHeuristics.isLikelyArtifact(
            path: "/Users/ana/projects/hub/apps/web"
        ))
        XCTAssertFalse(ProjectPathHeuristics.isLikelyArtifact(
            path: "/Users/ana/projects/hub/packages/ui"
        ))
    }

    func testReportsArtifactComponent() {
        XCTAssertEqual(
            ProjectPathHeuristics.artifactComponent(
                in: "/Users/ana/projects/hub/artifacts/releases/20261009/source/app"
            ),
            "artifacts"
        )
    }
}
