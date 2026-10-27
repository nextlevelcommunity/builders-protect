import Foundation

public struct NetworkService: Sendable {
    private let collector: NetworkCollector
    private let auditor: NetworkAuditor

    public init(
        collector: NetworkCollector = NetworkCollector(),
        auditor: NetworkAuditor = NetworkAuditor()
    ) {
        self.collector = collector
        self.auditor = auditor
    }

    public func analyze(
        context: NetworkAuditContext,
        progress: @escaping @Sendable (NetworkProgress) -> Void
    ) async -> NetworkReport {
        let startedAt = Date()
        let snapshot = await collector.collect(context: context, progress: progress)
        let findings = auditor.findings(for: snapshot, context: context)
        let scenarios = auditor.scenarios(
            for: snapshot,
            findings: findings,
            context: context
        )
        return NetworkReport(
            startedAt: startedAt,
            finishedAt: Date(),
            context: context,
            snapshot: snapshot,
            summary: auditor.summary(
                for: snapshot,
                findings: findings,
                context: context
            ),
            assurance: auditor.assurance(for: snapshot),
            findings: findings,
            scenarios: scenarios,
            limitations: auditor.limitations(for: snapshot)
        )
    }
}
