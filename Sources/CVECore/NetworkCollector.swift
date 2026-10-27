import Foundation

public struct NetworkCollector: Sendable {
    public init() {}

    public func collect(
        context: NetworkAuditContext,
        progress: @escaping @Sendable (NetworkProgress) -> Void
    ) async -> NetworkSnapshot {
        progress(
            NetworkProgress(
                phase: "Lendo Wi-Fi",
                detail: "Identificando a rede conectada, o roteador e o DNS.",
                fraction: 0.08
            )
        )

        async let wifiTask = NetworkCommand.run(
            executable: "/usr/sbin/system_profiler",
            arguments: ["SPAirPortDataType", "-json"],
            timeout: 12,
            maxOutputBytes: 500_000
        )
        async let routeTask = NetworkCommand.run(
            executable: "/sbin/route",
            arguments: ["-n", "get", "default"],
            timeout: 4
        )
        async let arpTask = NetworkCommand.run(
            executable: "/usr/sbin/arp",
            arguments: ["-an"],
            timeout: 4
        )
        async let dnsTask = NetworkCommand.run(
            executable: "/usr/sbin/scutil",
            arguments: ["--dns"],
            timeout: 5,
            maxOutputBytes: 120_000
        )
        async let nwiTask = NetworkCommand.run(
            executable: "/usr/sbin/scutil",
            arguments: ["--nwi"],
            timeout: 4
        )
        async let ifconfigTask = NetworkCommand.run(
            executable: "/sbin/ifconfig",
            timeout: 4,
            maxOutputBytes: 120_000
        )
        async let firewallTask = NetworkCommand.run(
            executable: "/usr/libexec/ApplicationFirewall/socketfilterfw",
            arguments: ["--getglobalstate"],
            timeout: 4
        )
        async let stealthTask = NetworkCommand.run(
            executable: "/usr/libexec/ApplicationFirewall/socketfilterfw",
            arguments: ["--getstealthmode"],
            timeout: 4
        )
        async let fileVaultTask = NetworkCommand.run(
            executable: "/usr/bin/fdesetup",
            arguments: ["status"],
            timeout: 5
        )
        async let sipTask = NetworkCommand.run(
            executable: "/usr/bin/csrutil",
            arguments: ["status"],
            timeout: 4
        )
        async let gatekeeperTask = NetworkCommand.run(
            executable: "/usr/sbin/spctl",
            arguments: ["--status"],
            timeout: 4
        )
        async let updatesTask = NetworkCommand.run(
            executable: "/usr/sbin/softwareupdate",
            arguments: ["--schedule"],
            timeout: 5
        )
        async let updateDefaultsTask = NetworkCommand.run(
            executable: "/usr/bin/defaults",
            arguments: ["read", "/Library/Preferences/com.apple.SoftwareUpdate"],
            timeout: 4
        )
        async let lsofTask = NetworkCommand.run(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"],
            timeout: 6,
            maxOutputBytes: 200_000
        )

        let wifi = await wifiTask
        let route = await routeTask
        let arp = await arpTask
        let dns = await dnsTask
        let nwi = await nwiTask
        let ifconfig = await ifconfigTask
        let firewall = await firewallTask
        let stealth = await stealthTask
        let fileVault = await fileVaultTask
        let sip = await sipTask
        let gatekeeper = await gatekeeperTask
        let updates = await updatesTask
        let updateDefaults = await updateDefaultsTask
        let lsof = await lsofTask

        progress(
            NetworkProgress(
                phase: "Verificando roteador",
                detail: "Consultando apenas o endereço do seu roteador, sem tentar senha.",
                fraction: 0.45
            )
        )

        var warnings: [String] = []
        if !wifi.succeeded {
            warnings.append("Não consegui ler os detalhes do Wi-Fi.")
        }
        if !route.succeeded {
            warnings.append("Não consegui identificar o endereço do roteador.")
        }
        if !arp.succeeded {
            warnings.append("Não consegui listar os dispositivos conhecidos pelo Mac.")
        }
        if !lsof.succeeded {
            warnings.append("Não consegui listar todos os serviços abertos no Mac.")
        }

        let wifiInfo = parseWiFi(wifi.stdout, warnings: &warnings)
        let gateway = parseGateway(route.stdout)
        let dnsServers = parseDNS(dns.stdout)
        let vpnInterfaces = parseVPNInterfaces(ifconfig.stdout, nwi: nwi.stdout)
        let vpnActive = !vpnInterfaces.isEmpty
            || dnsServers.contains(where: { $0.hasPrefix("100.100.100.100") || $0.hasPrefix("fd7a:115c:a1e0") })
        let devices = parseDevices(arp.stdout, gateway: gateway)
        let services = parseListeningServices(lsof.stdout, vpnActive: vpnActive)

        if dnsServers.isEmpty {
            warnings.append("Não consegui identificar os servidores DNS em uso.")
        }

        var gatewayHTTP: NetworkGatewayProbe?
        var gatewayHTTPS: NetworkGatewayProbe?
        if let gateway, isPrivateIPv4(gateway) {
            async let httpProbe = probeGateway(gateway, scheme: "http")
            async let httpsProbe = probeGateway(gateway, scheme: "https")
            gatewayHTTP = await httpProbe
            gatewayHTTPS = await httpsProbe
        } else if gateway == nil {
            warnings.append("A consulta ao painel do roteador foi pulada porque o endereço não foi encontrado.")
        } else {
            warnings.append("A consulta ao painel do roteador foi pulada porque o endereço não é local.")
        }

        progress(
            NetworkProgress(
                phase: "Checando o Mac",
                detail: "Lendo firewall, FileVault, Gatekeeper e atualizações.",
                fraction: 0.75
            )
        )

        let automaticUpdates = parseAutomaticUpdates(
            schedule: updates.stdout,
            defaults: updateDefaults.stdout
        )

        progress(
            NetworkProgress(
                phase: "Montando relatório",
                detail: "Transformando os sinais em explicações simples.",
                fraction: 0.92
            )
        )

        return NetworkSnapshot(
            capturedAt: Date(),
            hostName: ProcessInfo.processInfo.hostName,
            interfaceName: wifiInfo.interfaceName,
            ssid: wifiInfo.ssid,
            bssidMasked: wifiInfo.bssidMasked,
            securityMode: wifiInfo.securityMode,
            securityLabel: wifiInfo.securityLabel,
            channel: wifiInfo.channel,
            signal: wifiInfo.signal,
            countryCode: wifiInfo.countryCode,
            gateway: gateway,
            dnsServers: dnsServers,
            vpnActive: vpnActive,
            vpnInterfaces: vpnInterfaces,
            devices: devices,
            gatewayHTTP: gatewayHTTP,
            gatewayHTTPS: gatewayHTTPS,
            listeningServices: services,
            firewallEnabled: parseYesNo(firewall.stdout, positive: "enabled"),
            firewallStealth: parseYesNo(stealth.stdout, positive: "on"),
            fileVaultEnabled: parseYesNo(fileVault.stdout, positive: "FileVault is On"),
            sipEnabled: parseYesNo(sip.stdout, positive: "enabled"),
            gatekeeperEnabled: parseYesNo(gatekeeper.stdout, positive: "enabled"),
            automaticUpdatesEnabled: automaticUpdates,
            context: context,
            warnings: warnings
        )
    }

    private struct WiFiInfo {
        var interfaceName: String?
        var ssid: String?
        var bssidMasked: String?
        var securityMode: String?
        var securityLabel: String
        var channel: String?
        var signal: String?
        var countryCode: String?
    }

    private func parseWiFi(_ json: String, warnings: inout [String]) -> WiFiInfo {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let interfaces = root["SPAirPortDataType"] as? [[String: Any]] else {
            return WiFiInfo(securityLabel: "Não identificada")
        }

        for item in interfaces {
            guard let wifiInterfaces = item["spairport_airport_interfaces"] as? [[String: Any]] else {
                continue
            }
            for wifiInterface in wifiInterfaces {
                guard let current = wifiInterface["spairport_current_network_information"] as? [String: Any] else {
                    continue
                }
                let rawSSID = current["_name"] as? String
                let ssid = rawSSID == "<redacted>" ? nil : rawSSID
                if ssid == nil {
                    warnings.append("O macOS não liberou o nome da rede Wi-Fi para o app.")
                }
                let rawBSSID = current["spairport_network_bssid"] as? String
                let mode = current["spairport_security_mode"] as? String
                return WiFiInfo(
                    interfaceName: wifiInterface["_name"] as? String,
                    ssid: ssid,
                    bssidMasked: rawBSSID.map(maskMACAddress),
                    securityMode: mode,
                    securityLabel: securityLabel(for: mode),
                    channel: current["spairport_network_channel"] as? String,
                    signal: current["spairport_signal_noise"] as? String,
                    countryCode: current["spairport_network_country_code"] as? String
                )
            }
        }
        return WiFiInfo(securityLabel: "Não identificada")
    }

    private func securityLabel(for mode: String?) -> String {
        guard let mode else { return "Não identificada" }
        switch mode {
        case "spairport_security_mode_none":
            return "Aberta, sem senha"
        case "spairport_security_mode_wep":
            return "WEP, proteção obsoleta"
        case "spairport_security_mode_wpa_personal":
            return "WPA Pessoal, proteção antiga"
        case "spairport_security_mode_wpa2_personal":
            return "WPA2 Pessoal"
        case "spairport_security_mode_wpa2_personal_mixed":
            return "WPA/WPA2 misto"
        case "spairport_security_mode_wpa3_personal":
            return "WPA3 Pessoal"
        case "spairport_security_mode_wpa3_transition":
            return "WPA3 em transição"
        case "spairport_security_mode_wpa2_enterprise":
            return "WPA2 Empresarial"
        case "spairport_security_mode_wpa3_enterprise":
            return "WPA3 Empresarial"
        default:
            return mode
                .replacingOccurrences(of: "spairport_security_mode_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    func parseGateway(_ text: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?m)^\s*gateway:\s*([0-9.]+)"#
        ) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }

    func parseDNS(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?m)^\s*nameserver\[\d+\]\s*:\s*(\S+)"#
        ) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var values: [String] = []
        var seen = Set<String>()
        for match in regex.matches(in: text, range: range) {
            guard let valueRange = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[valueRange])
            if seen.insert(value).inserted {
                values.append(value)
            }
        }
        return values
    }

    func parseVPNInterfaces(_ ifconfig: String, nwi: String) -> [String] {
        var interfaces: [String] = []
        var current: String?
        for line in ifconfig.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            if let match = text.range(of: #"^utun\d+:"#, options: .regularExpression) {
                current = String(text[match]).replacingOccurrences(of: ":", with: "")
                continue
            }
            if text.hasPrefix(" ") || text.hasPrefix("\t") {
                if text.contains("inet "), let current {
                    interfaces.append(current)
                }
            } else if !text.isEmpty {
                current = nil
            }
        }
        if nwi.lowercased().contains("utun") {
            for line in nwi.split(separator: "\n") where line.lowercased().contains("utun") {
                let lineText = String(line)
                if let match = lineText.range(of: #"utun\d+"#, options: .regularExpression) {
                    interfaces.append(String(lineText[match]))
                }
            }
        }
        return Array(Set(interfaces)).sorted()
    }

    func parseDevices(_ text: String, gateway: String?) -> [NetworkDevice] {
        guard let regex = try? NSRegularExpression(
            pattern: #"^\S+\s+\(([0-9]{1,3}(?:\.[0-9]{1,3}){3})\)\s+at\s+([0-9a-fA-F:]+)\s+on\s+\S+"#,
            options: [.anchorsMatchLines]
        ) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var devices: [NetworkDevice] = []
        var seen = Set<String>()
        for match in regex.matches(in: text, range: range) {
            guard let ipRange = Range(match.range(at: 1), in: text),
                  let macRange = Range(match.range(at: 2), in: text) else { continue }
            let ip = String(text[ipRange])
            let mac = String(text[macRange]).lowercased()
            guard !ip.hasPrefix("224."), !ip.hasPrefix("239."),
                  !mac.hasPrefix("ff:ff:ff") else { continue }
            guard seen.insert("\(ip)|\(mac)").inserted else { continue }
            let isGateway = ip == gateway
            devices.append(
                NetworkDevice(
                    ip: ip,
                    mac: mac,
                    isGateway: isGateway,
                    macKind: isGateway ? "roteador" : macKind(mac)
                )
            )
        }
        return devices.sorted { lhs, rhs in
            if lhs.isGateway != rhs.isGateway { return lhs.isGateway }
            return numericIP(lhs.ip) < numericIP(rhs.ip)
        }
    }

    func parseListeningServices(
        _ text: String,
        vpnActive: Bool
    ) -> [NetworkListeningService] {
        var services: [NetworkListeningService] = []
        var seen = Set<String>()
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let tcpIndex = parts.firstIndex(where: { $0 == "TCP" }),
                  parts.count > tcpIndex + 1 else { continue }
            let name = String(parts[tcpIndex + 1])
            guard let colon = name.lastIndex(of: ":") else { continue }
            let bind = String(name[..<colon])
            let portText = String(name[name.index(after: colon)...])
            guard let port = Int(portText) else { continue }

            let process = String(parts[0])
                .replacingOccurrences(of: "\\x20", with: " ")
            let lower = process.lowercased()
            if lower == "rapportd" || lower == "controlcenter" { continue }
            if (lower.contains("ipnextens") || lower.contains("tailscale")), vpnActive {
                continue
            }

            let loopback = bind == "127.0.0.1"
                || bind == "::1"
                || bind == "[::1]"
                || bind == "localhost"
                || bind.hasPrefix("127.")
            let exposed = !loopback
            let key = "\(process)|\(port)|\(bind)"
            guard seen.insert(key).inserted else { continue }
            services.append(
                NetworkListeningService(
                    process: process,
                    port: port,
                    bind: bind,
                    exposedToLAN: exposed
                )
            )
        }
        return services.sorted { lhs, rhs in
            if lhs.exposedToLAN != rhs.exposedToLAN { return lhs.exposedToLAN }
            if lhs.port != rhs.port { return lhs.port < rhs.port }
            return lhs.process < rhs.process
        }
    }

    private func probeGateway(_ gateway: String, scheme: String) async -> NetworkGatewayProbe {
        guard let url = URL(string: "\(scheme)://\(gateway)/") else {
            return NetworkGatewayProbe(
                scheme: scheme,
                reachable: false,
                error: "Endereço inválido."
            )
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3
        request.setValue("BuildersProtect/1.0", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 5
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count >= 64_000 { break }
            }
            let http = response as? HTTPURLResponse
            let body = String(data: data, encoding: .utf8) ?? ""
            let finalScheme = response.url?.scheme?.lowercased()
            return NetworkGatewayProbe(
                scheme: scheme,
                reachable: true,
                statusCode: http?.statusCode,
                server: http?.value(forHTTPHeaderField: "Server"),
                title: extractTitle(body),
                finalURL: response.url?.absoluteString,
                hasLoginForm: hasPasswordField(body),
                usesBasicAuth: http?
                    .value(forHTTPHeaderField: "WWW-Authenticate")?
                    .lowercased()
                    .contains("basic") == true,
                redirectsToHTTPS: scheme == "http" && finalScheme == "https",
                certificateProblem: false
            )
        } catch {
            let nsError = error as NSError
            let certificateProblem = nsError.domain == NSURLErrorDomain
                && [
                    NSURLErrorServerCertificateUntrusted,
                    NSURLErrorServerCertificateHasBadDate,
                    NSURLErrorServerCertificateHasUnknownRoot,
                    NSURLErrorServerCertificateNotYetValid,
                    NSURLErrorSecureConnectionFailed
                ].contains(nsError.code)
            return NetworkGatewayProbe(
                scheme: scheme,
                reachable: false,
                certificateProblem: certificateProblem,
                error: error.localizedDescription
            )
        }
    }

    private func extractTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?is)<title[^>]*>(.*?)</title>"#
        ) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let valueRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        var title = String(html[valueRange])
        title = title.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        title = title
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(120))
    }

    private func hasPasswordField(_ html: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?is)<input[^>]+type\s*=\s*["']?password"#
        ) else { return false }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.firstMatch(in: html, range: range) != nil
    }

    private func parseAutomaticUpdates(schedule: String, defaults: String) -> Bool? {
        let lower = schedule.lowercased()
        if lower.contains("turned on") || lower.contains("is on") {
            return true
        }
        if lower.contains("turned off") || lower.contains("is off") {
            return false
        }
        if let regex = try? NSRegularExpression(
            pattern: #"(?m)^\s*AutomaticallyInstallMacOSUpdates\s*=\s*([01]);"#
        ) {
            let range = NSRange(defaults.startIndex..<defaults.endIndex, in: defaults)
            if let match = regex.firstMatch(in: defaults, range: range),
               let valueRange = Range(match.range(at: 1), in: defaults) {
                return String(defaults[valueRange]) == "1"
            }
        }
        return nil
    }

    private func parseYesNo(_ text: String, positive: String) -> Bool? {
        let lower = text.lowercased()
        if lower.contains(positive.lowercased()) { return true }
        if lower.contains("disabled") || lower.contains(" off") || lower.contains("not enabled") {
            return false
        }
        return nil
    }

    private func macKind(_ mac: String) -> String {
        let first = mac.split(separator: ":").first.map(String.init) ?? ""
        guard let value = Int(first, radix: 16) else { return "desconhecido" }
        return (value & 0x02) == 0 ? "fixo" : "aleatório/privado"
    }

    private func maskMACAddress(_ mac: String) -> String {
        let parts = mac.split(separator: ":")
        guard parts.count >= 3 else { return "••:••:••" }
        return parts.prefix(3).joined(separator: ":") + ":••:••:••"
    }

    private func numericIP(_ ip: String) -> UInt32 {
        ip.split(separator: ".")
            .compactMap { UInt32($0) }
            .reduce(0) { ($0 << 8) + $1 }
    }

    private func isPrivateIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 172, (16...31).contains(parts[1]) { return true }
        if parts[0] == 192, parts[1] == 168 { return true }
        if parts[0] == 169, parts[1] == 254 { return true }
        return false
    }
}
