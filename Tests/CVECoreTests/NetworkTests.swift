import Foundation
import XCTest
@testable import CVECore

final class NetworkCollectorTests: XCTestCase {
    func testParsesGatewayDNSAndVPN() {
        let collector = NetworkCollector()

        let route = """
           route to: default
        destination: default
               mask: default
            gateway: 192.168.68.1
        interface: en0
        """
        XCTAssertEqual(collector.parseGateway(route), "192.168.68.1")

        let dns = """
        DNS configuration

        resolver #1
          search domain[0] : local
          nameserver[0] : 192.168.68.1
          nameserver[1] : 100.100.100.100

        resolver #2
          nameserver[0] : 192.168.68.1
          nameserver[1] : fd7a:115c:a1e0::1
        """
        XCTAssertEqual(
            collector.parseDNS(dns),
            ["192.168.68.1", "100.100.100.100", "fd7a:115c:a1e0::1"]
        )

        let interfaces = """
        utun4: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280
            inet 100.100.100.100 --> 100.100.100.100 netmask 0xffffffff
        en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            inet 192.168.68.10 netmask 0xffffff00 broadcast 192.168.68.255
        """
        let nwi = """
        Network information
           utun4 : flags 0x5
        """
        XCTAssertEqual(collector.parseVPNInterfaces(interfaces, nwi: nwi), ["utun4"])
    }

    func testParsesDevicesAndIgnoresMulticast() {
        let arp = """
        ? (192.168.68.10) at a:b:c:d:e:f on en0 ifscope [ethernet]
        ? (192.168.68.1) at 0:11:22:33:44:55 on en0 ifscope [ethernet]
        ? (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]
        """
        let devices = NetworkCollector().parseDevices(arp, gateway: "192.168.68.1")

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices.first?.ip, "192.168.68.1")
        XCTAssertEqual(devices.first?.isGateway, true)
        XCTAssertEqual(devices.first?.macKind, "roteador")
        XCTAssertEqual(devices.last?.ip, "192.168.68.10")
        XCTAssertEqual(devices.last?.macKind, "aleatório/privado")
    }

    func testParsesListeningServicesAndHidesLoopback() {
        let lsof = """
        node      123 user   23u  IPv6 0x123      0t0  TCP *:3000 (LISTEN)
        rapportd   93 user   10u  IPv4 0x456      0t0  TCP *:1234 (LISTEN)
        python    456 user   12u  IPv4 0x789      0t0  TCP 127.0.0.1:8000 (LISTEN)
        """
        let services = NetworkCollector().parseListeningServices(lsof, vpnActive: false)

        XCTAssertEqual(services.count, 2)
        let node = services.first { $0.process == "node" }
        XCTAssertEqual(node?.port, 3000)
        XCTAssertEqual(node?.exposedToLAN, true)
        let python = services.first { $0.process == "python" }
        XCTAssertEqual(python?.exposedToLAN, false)
        XCTAssertFalse(services.contains { $0.process == "rapportd" })
    }
}

final class NetworkAuditorTests: XCTestCase {
    private let auditor = NetworkAuditor()

    func testOpenNetworkIsCriticalAndConfirmed() {
        let snapshot = makeSnapshot(
            ssid: "Cafe",
            securityMode: "spairport_security_mode_none",
            securityLabel: "Aberta, sem senha"
        )
        let context = NetworkAuditContext()

        let findings = auditor.findings(for: snapshot, context: context)
        let open = findings.first { $0.checkID == "wifi-open" }
        XCTAssertEqual(open?.severity, .critical)
        XCTAssertEqual(open?.source, .wifi)
        XCTAssertFalse(open?.fixPrompt.isEmpty ?? true)

        let scenarios = auditor.scenarios(
            for: snapshot,
            findings: findings,
            context: context
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "same-wifi" }?.status,
            .confirmed
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "bank-password" }?.status,
            .possible
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "stolen-mac" }?.status,
            .notFound
        )
        XCTAssertTrue(auditor.assurance(for: snapshot).contains("exposição confirmada"))
    }

    func testSecureNetworkHasNoFindings() {
        let snapshot = makeSnapshot()
        let findings = auditor.findings(
            for: snapshot,
            context: NetworkAuditContext()
        )

        XCTAssertTrue(findings.isEmpty)
        let summary = auditor.summary(
            for: snapshot,
            findings: findings,
            context: NetworkAuditContext()
        )
        XCTAssertTrue(summary.contains("Não encontrei falha grave"))
        XCTAssertTrue(summary.contains("Não é possível provar"))

        let scenarios = auditor.scenarios(
            for: snapshot,
            findings: findings,
            context: NetworkAuditContext()
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "exposed-service" }?.status,
            .notFound
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "router-control" }?.status,
            .unverified
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "phishing" }?.status,
            .possible
        )
    }

    func testExposedDevelopmentServiceBecomesConfirmedScenario() {
        let snapshot = makeSnapshot(
            listeningServices: [
                NetworkListeningService(
                    process: "python3",
                    port: 8000,
                    bind: "*",
                    exposedToLAN: true
                )
            ]
        )
        let findings = auditor.findings(
            for: snapshot,
            context: NetworkAuditContext()
        )

        let service = findings.first { $0.checkID == "service-exposed" }
        XCTAssertEqual(service?.severity, .medium)
        XCTAssertEqual(
            service?.evidence,
            "Escutando em *:8000."
        )

        let scenarios = auditor.scenarios(
            for: snapshot,
            findings: findings,
            context: NetworkAuditContext()
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "exposed-service" }?.status,
            .confirmed
        )
        XCTAssertTrue(
            auditor.summary(
                for: snapshot,
                findings: findings,
                context: NetworkAuditContext()
            ).contains("1 serviço do Mac visível")
        )
    }

    func testPublicNetworkRaisesTrustRisks() {
        let snapshot = makeSnapshot(
            ssid: "Hotel",
            dnsServers: ["8.8.8.8"]
        )
        let context = NetworkAuditContext(isPublicNetwork: true)
        let findings = auditor.findings(for: snapshot, context: context)

        XCTAssertTrue(findings.contains { $0.checkID == "public-network" && $0.severity == .high })
        XCTAssertTrue(findings.contains { $0.checkID == "dns-public" })
        let scenarios = auditor.scenarios(
            for: snapshot,
            findings: findings,
            context: context
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "same-wifi" }?.status,
            .possible
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "bank-password" }?.status,
            .possible
        )
    }

    func testRouterBasicAuthIsHighRisk() {
        let snapshot = makeSnapshot(
            gateway: "192.168.1.1",
            gatewayHTTP: NetworkGatewayProbe(
                scheme: "http",
                reachable: true,
                statusCode: 401,
                usesBasicAuth: true
            )
        )
        let findings = auditor.findings(
            for: snapshot,
            context: NetworkAuditContext()
        )

        let router = findings.first { $0.checkID == "router-basic-auth" }
        XCTAssertEqual(router?.severity, .high)
        let scenarios = auditor.scenarios(
            for: snapshot,
            findings: findings,
            context: NetworkAuditContext()
        )
        XCTAssertEqual(
            scenarios.first { $0.id == "router-control" }?.status,
            .possible
        )
    }

    func testRouterWithoutConfirmedPanelIsMediumRisk() {
        let snapshot = makeSnapshot(
            gateway: "192.168.1.1",
            gatewayHTTP: NetworkGatewayProbe(
                scheme: "http",
                reachable: true,
                statusCode: 200,
                title: "Opening...",
                hasLoginForm: false
            )
        )
        let findings = auditor.findings(
            for: snapshot,
            context: NetworkAuditContext()
        )

        let router = findings.first { $0.checkID == "router-http" }
        XCTAssertEqual(router?.severity, .medium)
        XCTAssertTrue(router?.title.contains("sem confirmação") == true)
    }

    func testFixPromptKeepsPassiveBoundaries() {
        let prompt = NetworkPromptBuilder.fixPrompt(
            checkID: "test",
            title: "Teste",
            target: "Wi-Fi",
            evidence: "Evidência",
            whatItMeans: "Significado",
            scenario: "Cenário",
            recommendation: "Recomendação",
            snapshot: makeSnapshot()
        )

        XCTAssertTrue(prompt.contains("nunca peça senha"))
        XCTAssertTrue(prompt.contains("Não sugira capturar tráfego"))
        XCTAssertTrue(prompt.contains("sem afirmar que houve invasão"))
    }

    func testGeneralPromptConsolidatesAllFindingsAndKeepsBoundaries() {
        let snapshot = makeSnapshot(gateway: "192.168.68.1")
        let findings = [
            NetworkFinding(
                severity: .high,
                title: "Roteador em HTTP",
                checkID: "router-http",
                category: "Roteador",
                target: "192.168.68.1",
                evidence: "Painel responde sem HTTPS.",
                whatItMeans: "A configuração pode ser vista por outras pessoas da rede.",
                scenario: "Alguém na mesma Wi-Fi poderia observar o painel.",
                likelihood: "Possível no seu cenário",
                recommendation: "Ative HTTPS no roteador e troque a senha padrão.",
                fixPrompt: "Prompt individual",
                source: .gateway
            ),
            NetworkFinding(
                severity: .medium,
                title: "Serviço exposto",
                checkID: "service-exposed",
                category: "Serviços",
                target: "Python na porta 4174",
                evidence: "Um serviço escuta em todas as interfaces.",
                whatItMeans: "Outros aparelhos da rede podem alcançar esse serviço.",
                scenario: "Um aparelho comprometido poderia tentar acessar a porta.",
                likelihood: "Possível no seu cenário",
                recommendation: "Limite o serviço a 127.0.0.1 ou feche a porta.",
                fixPrompt: "Prompt individual",
                source: .services
            )
        ]
        let report = NetworkReport(
            startedAt: Date(),
            finishedAt: Date(),
            context: NetworkAuditContext(),
            snapshot: snapshot,
            summary: "Resumo",
            assurance: "Garantia",
            findings: findings,
            scenarios: [],
            limitations: []
        )

        let prompt = NetworkPromptBuilder.generalPrompt(for: report)

        XCTAssertTrue(prompt.contains("Roteador em HTTP"))
        XCTAssertTrue(prompt.contains("Serviço exposto"))
        XCTAssertTrue(prompt.contains("plano único"))
        XCTAssertTrue(prompt.contains("nunca peça senha"))
        XCTAssertTrue(prompt.contains("Não sugira capturar tráfego"))
        XCTAssertTrue(prompt.contains("prova de invasão"))
        XCTAssertTrue(prompt.contains("hoje"))
        XCTAssertTrue(prompt.contains("esta semana"))
    }

    func testNetworkStateKeepsLimitedHistory() {
        var state = NetworkState.empty
        var reports: [NetworkReport] = []

        for index in 0..<12 {
            let finishedAt = Date(timeIntervalSince1970: TimeInterval(index))
            let report = makeReport(finishedAt: finishedAt)
            reports.append(report)
            state.addReport(report, limit: 10)
        }

        XCTAssertEqual(state.reports.count, 10)
        XCTAssertEqual(state.latest?.id, reports.last?.id)
        XCTAssertEqual(state.lastRunAt, reports.last?.finishedAt)

        let encoded = try? JSONEncoder().encode(state)
        XCTAssertNotNil(encoded)
        let decoded = encoded.flatMap {
            try? JSONDecoder().decode(NetworkState.self, from: $0)
        }
        XCTAssertEqual(decoded?.reports.count, 10)
        XCTAssertEqual(decoded?.latest?.id, reports.last?.id)
    }

    private func makeSnapshot(
        ssid: String = "Casa",
        securityMode: String = "spairport_security_mode_wpa3_personal",
        securityLabel: String = "WPA3 Pessoal",
        gateway: String? = nil,
        dnsServers: [String] = ["192.168.68.1"],
        vpnActive: Bool = false,
        listeningServices: [NetworkListeningService] = [],
        gatewayHTTP: NetworkGatewayProbe? = nil
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            hostName: "mac-teste",
            ssid: ssid,
            securityMode: securityMode,
            securityLabel: securityLabel,
            gateway: gateway,
            dnsServers: dnsServers,
            vpnActive: vpnActive,
            gatewayHTTP: gatewayHTTP,
            listeningServices: listeningServices,
            firewallEnabled: true,
            firewallStealth: true,
            fileVaultEnabled: true,
            sipEnabled: true,
            gatekeeperEnabled: true,
            automaticUpdatesEnabled: true
        )
    }

    private func makeReport(finishedAt: Date) -> NetworkReport {
        let snapshot = makeSnapshot()
        return NetworkReport(
            id: UUID(),
            startedAt: finishedAt.addingTimeInterval(-5),
            finishedAt: finishedAt,
            context: NetworkAuditContext(),
            snapshot: snapshot,
            summary: "Resumo",
            assurance: "Garantia",
            findings: [],
            scenarios: [],
            limitations: []
        )
    }
}
