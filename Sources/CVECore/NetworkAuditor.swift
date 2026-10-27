import Foundation

public struct NetworkAuditor: Sendable {
    public init() {}

    public func findings(
        for snapshot: NetworkSnapshot,
        context: NetworkAuditContext
    ) -> [NetworkFinding] {
        var findings: [NetworkFinding] = []

        if let wifi = wifiFinding(snapshot, context: context) {
            findings.append(wifi)
        }
        if context.isPublicNetwork {
            findings.append(publicNetworkFinding(snapshot))
        }
        findings.append(contentsOf: routerFindings(snapshot))
        findings.append(contentsOf: macFindings(snapshot, context: context))
        findings.append(contentsOf: serviceFindings(snapshot))
        if let devices = devicesFinding(snapshot) {
            findings.append(devices)
        }
        if context.isPublicNetwork, !snapshot.vpnActive {
            findings.append(publicDNSFinding(snapshot))
        }

        return findings.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return lhs.title < rhs.title
        }
    }

    public func scenarios(
        for snapshot: NetworkSnapshot,
        findings: [NetworkFinding],
        context: NetworkAuditContext
    ) -> [NetworkScenario] {
        let openNetwork = isOpenOrWeak(snapshot.securityMode)
        let publicOrOpen = context.isPublicNetwork || openNetwork
        let hasExposedService = findings.contains { $0.checkID == "service-exposed" }
        let routerHTTP = findings.contains {
            $0.checkID == "router-http" || $0.checkID == "router-basic-auth"
        }
        let fileVaultOff = snapshot.fileVaultEnabled == false

        return [
            NetworkScenario(
                id: "same-wifi",
                title: "Alguém na mesma Wi-Fi tentar ver seus dados",
                status: openNetwork ? .confirmed : (context.isPublicNetwork ? .possible : .unverified),
                explanation: openNetwork
                    ? "Sua rede não tem uma proteção moderna por senha. Qualquer pessoa ao alcance pode tentar entrar."
                    : (context.isPublicNetwork
                        ? "Você está numa rede pública. Mesmo com senha, você não controla quem está conectado nem o roteador."
                        : "Sua rede usa \(snapshot.securityLabel). Sem a senha, alguém de fora não entra só por estar perto. Eu não consigo medir a força dessa senha nem saber quem mais a conhece."),
                whatCouldHappen: openNetwork || context.isPublicNetwork
                    ? "Alguém na mesma rede pode observar conexões sem HTTPS, descobrir nomes de sites e tentar redirecionar você para uma página falsa. Sites de banco com HTTPS e certificado válido não entregam a senha só por estarem na mesma Wi-Fi, mas um hotspot falso ou uma página clonada pode enganar você."
                    : "O cenário mais realista não é alguém quebrar a senha do Wi-Fi, e sim uma senha compartilhada, um aparelho infectado ou um golpe de phishing. Com WPA2/WPA3, o tráfego sem fio é criptografado entre seu Mac e o roteador.",
                protection: "Use WPA3 se o roteador permitir, troque a senha do Wi-Fi se ela for antiga ou compartilhada, evite administrar o roteador em rede pública e confira sempre o endereço e o cadeado antes de digitar senha de banco.",
                basedOn: "Proteção informada pelo macOS: \(snapshot.securityLabel)."
            ),
            NetworkScenario(
                id: "bank-password",
                title: "Captura de senha de banco ao digitar",
                status: publicOrOpen ? .possible : .notFound,
                explanation: publicOrOpen
                    ? "Numa rede aberta ou pública, aumenta o risco de phishing e de redirecionamento. Isso não significa que sua senha foi capturada; significa que você não deve digitar dados bancários nessa conexão."
                    : "Não encontrei um caminho direto para alguém ler sua senha de banco pela rede. O risco que continua existindo é o golpe: site falso, aplicativo falso, mensagem pedindo código ou link com endereço parecido.",
                whatCouldHappen: "Um golpista pode criar uma página igual à do banco e convencer você a digitar senha e código. HTTPS sozinho não impede isso, porque o site falso também pode ter HTTPS. O que protege é conferir o endereço, não clicar em link recebido e usar o aplicativo oficial do banco.",
                protection: "Digite senhas de banco só em conexão confiável, prefira o aplicativo oficial, nunca informe código recebido por SMS e desconfie de urgência, bônus ou pedido para atualizar cadastro.",
                basedOn: publicOrOpen
                    ? "Rede aberta, fraca ou marcada como pública."
                    : "Rede com criptografia \(snapshot.securityLabel); nenhum sinal de interceptação foi verificado."
            ),
            NetworkScenario(
                id: "router-control",
                title: "Alguém tentar mexer no seu roteador",
                status: routerHTTP ? .possible : .unverified,
                explanation: routerHTTP
                    ? "O painel do seu roteador respondeu por HTTP, sem criptografia. Se alguém estiver na mesma rede, pode tentar observar a senha do painel ou alterar configurações."
                    : "Não consegui confirmar como o painel do roteador está protegido. Também não testei senha padrão nem versão de firmware.",
                whatCouldHappen: "Com acesso ao painel, uma pessoa poderia mudar o DNS, criar uma rede falsa, liberar portas ou derrubar seu Wi-Fi. Isso exige alguém já estar na rede ou ter a senha do roteador; não é possível provar isso por uma checagem local.",
                protection: "Entre no painel usando HTTPS, troque a senha padrão por uma senha longa e única, atualize o firmware e desative administração remota se não usar.",
                basedOn: routerHTTP
                    ? "O endereço \(snapshot.gateway ?? "do roteador") respondeu em HTTP."
                    : "Painel não verificável sem a senha e o modelo do roteador."
            ),
            NetworkScenario(
                id: "exposed-service",
                title: "Um serviço do seu Mac ficar aberto para a rede",
                status: hasExposedService ? .confirmed : .notFound,
                explanation: hasExposedService
                    ? "Encontrei pelo menos um programa escutando em uma porta que outras pessoas na mesma Wi-Fi podem alcançar. Isso não prova que alguém entrou."
                    : "Nenhum serviço visível do seu Mac estava escutando para a rede local neste momento. Serviços em 127.0.0.1 ficam só no próprio Mac.",
                whatCouldHappen: "Se for um banco de dados, painel de desenvolvimento ou acesso remoto sem senha, alguém na mesma rede pode abrir, ler ou alterar dados. Servidores de desenvolvimento costumam ter dados reais e menos proteção.",
                protection: "Pare servidores que não estiver usando, escute em 127.0.0.1 quando possível, mantenha o firewall ligado e não exponha bancos de dados na rede local.",
                basedOn: "Lista de programas escutando em TCP no momento da análise."
            ),
            NetworkScenario(
                id: "stolen-mac",
                title: "Alguém pegar seu Mac e ler os dados",
                status: fileVaultOff ? .confirmed : (snapshot.fileVaultEnabled == true ? .notFound : .unverified),
                explanation: fileVaultOff
                    ? "O disco do seu Mac não está criptografado pelo FileVault. Se o aparelho for roubado, alguém pode tentar acessar os arquivos fora do sistema."
                    : (snapshot.fileVaultEnabled == true
                        ? "O FileVault está ligado. Sem sua senha, o disco fica criptografado."
                        : "Não consegui confirmar o estado do FileVault."),
                whatCouldHappen: "Isso não depende da internet. É o risco de perder o Mac com documentos, sessões e senhas salvas. A criptografia do disco é a proteção mais importante para esse caso.",
                protection: "Ative FileVault em Ajustes do Sistema > Privacidade e Segurança, use senha forte no login e mantenha o Mac atualizado.",
                basedOn: "Status do FileVault informado pelo macOS."
            ),
            NetworkScenario(
                id: "phishing",
                title: "Site falso ou mensagem pedindo sua senha",
                status: .possible,
                explanation: "Esse risco existe em qualquer rede, inclusive na sua casa. Não depende de alguém invadir o Wi-Fi.",
                whatCouldHappen: "Você pode receber um link com aparência do seu banco, uma cobrança falsa ou um pedido de código por mensagem. Se digitar ali, a senha vai para o golpista mesmo com a rede segura.",
                protection: "Abra o banco pelo aplicativo ou digitando o endereço, confira o domínio, nunca compartilhe código de verificação e desconfie de pressa ou ameaça.",
                basedOn: "Risco geral de golpes; não é uma falha da sua rede."
            )
        ]
    }

    public func summary(
        for snapshot: NetworkSnapshot,
        findings: [NetworkFinding],
        context: NetworkAuditContext
    ) -> String {
        let networkName = snapshot.ssid ?? "sua rede Wi-Fi"
        let critical = findings.filter { $0.severity == .critical }.count
        let high = findings.filter { $0.severity == .high }.count
        let exposed = findings.filter { $0.checkID == "service-exposed" }.count
        var pieces: [String] = [
            "Você está em \(networkName), com proteção \(snapshot.securityLabel)."
        ]
        if let gateway = snapshot.gateway {
            pieces.append("Roteador: \(gateway).")
        }
        if snapshot.vpnActive {
            pieces.append("Há uma VPN ativa, o que ajuda em redes públicas.")
        }
        if critical > 0 {
            pieces.append("Encontrei \(quantity(critical, "ponto crítico", "pontos críticos")) e \(quantity(high, "ponto alto", "pontos altos")). O mais importante agora é: \(findings[0].title).")
        } else if high > 0 {
            pieces.append("Encontrei \(quantity(high, "ponto alto", "pontos altos")) de atenção. O mais importante agora é: \(findings[0].title). Não é uma invasão confirmada, mas vale corrigir.")
        } else if !findings.isEmpty {
            pieces.append("Não encontrei falha grave, mas há \(quantity(findings.count, "ponto de atenção", "pontos de atenção")). O primeiro da lista é: \(findings[0].title).")
        } else {
            pieces.append("Não encontrei falha grave nas configurações que consegui verificar.")
        }
        if exposed > 0 {
            pieces.append("Há \(quantity(exposed, "serviço do Mac visível", "serviços do Mac visíveis")) para a rede local.")
        }
        pieces.append("Não é possível provar que alguém invadiu sua rede com esta checagem.")
        return pieces.joined(separator: " ")
    }

    public func assurance(for snapshot: NetworkSnapshot) -> String {
        let wifi = snapshot.securityMode ?? ""
        if wifi.contains("none") || wifi.contains("wep") {
            return "O ponto mais sério é a proteção da sua Wi-Fi. Isso é uma exposição confirmada, não uma suspeita. Ainda assim, não quer dizer que alguém já entrou."
        }
        return "Esta é uma foto local das configurações e dos serviços visíveis. Ela não captura tráfego, não entra no roteador e não prova que alguém invadiu ou tentou invadir sua rede."
    }

    public func limitations(for snapshot: NetworkSnapshot) -> [String] {
        var items = snapshot.warnings
        items.append(contentsOf: [
            "Não capturo tráfego, não testo senhas, não exploro falhas e não entro no painel do roteador.",
            "A lista de dispositivos vem da tabela ARP do Mac; ela é parcial e não representa todos os aparelhos da casa.",
            "Não consigo medir a força da senha do Wi-Fi nem saber se ela foi compartilhada com outras pessoas.",
            "Não consigo identificar modelo, firmware, WPS ou senha padrão do roteador sem acessar o painel.",
            "Proteções do Mac podem aparecer como não verificadas se o macOS bloquear a leitura.",
            "O resultado é uma foto do momento; dispositivos e configurações podem mudar.",
            "Uma checagem local não confirma invasão, interceptação ou captura de senha."
        ])
        if snapshot.vpnActive {
            items.append("VPN ativa detectada (\(snapshot.vpnInterfaces.joined(separator: ", "))); parte do tráfego pode estar protegida por ela.")
        }
        if snapshot.context.isPublicNetwork {
            items.append("Você marcou esta rede como pública; os cenários de confiança foram tratados como mais arriscados.")
        }
        return Array(NSOrderedSet(array: items)) as? [String] ?? items
    }

    private func wifiFinding(
        _ snapshot: NetworkSnapshot,
        context: NetworkAuditContext
    ) -> NetworkFinding? {
        let mode = (snapshot.securityMode ?? "").lowercased()
        if mode.contains("none") {
            return makeFinding(
                checkID: "wifi-open",
                severity: .critical,
                title: "Sua Wi-Fi está aberta, sem senha",
                category: "Wi-Fi",
                target: snapshot.ssid ?? "Rede Wi-Fi",
                evidence: snapshot.securityLabel,
                whatItMeans: "Qualquer pessoa perto do seu roteador pode tentar se conectar. Não existe uma senha para separar você de um visitante ou de alguém mal-intencionado.",
                scenario: "Numa rede aberta, alguém na mesma Wi-Fi pode observar conexões sem HTTPS, descobrir quais sites você acessa e tentar redirecionar você para uma página falsa. Isso não significa que sua senha de banco será capturada automaticamente: sites com HTTPS e certificado válido protegem a conexão, mas um hotspot falso ou uma página clonada ainda pode enganar você.",
                likelihood: "Confirmado: a rede não tem proteção por senha.",
                recommendation: "Ative WPA2 ou WPA3 no roteador agora, com uma senha longa e única. Se estiver num local público, não use essa rede para banco, compras ou dados pessoais.",
                source: .wifi,
                snapshot: snapshot
            )
        }
        if mode.contains("wep") {
            return makeFinding(
                checkID: "wifi-wep",
                severity: .critical,
                title: "Wi-Fi usa WEP, uma proteção quebrada",
                category: "Wi-Fi",
                target: snapshot.ssid ?? "Rede Wi-Fi",
                evidence: snapshot.securityLabel,
                whatItMeans: "WEP é uma proteção antiga e considerada insegura. Ela dá uma falsa sensação de segurança.",
                scenario: "Uma pessoa com conhecimento técnico e um computador próximo pode tentar quebrar essa proteção e entrar na rede. A partir daí, pode observar tráfego sem HTTPS e tentar acessar aparelhos da casa.",
                likelihood: "Confirmado: a rede usa uma proteção obsoleta.",
                recommendation: "Troque para WPA2 ou WPA3 no painel do roteador. Se o aparelho só oferece WEP, ele está muito antigo e deve ser substituído.",
                source: .wifi,
                snapshot: snapshot
            )
        }
        if mode.contains("wpa_personal") && !mode.contains("wpa2") && !mode.contains("wpa3") {
            return makeFinding(
                checkID: "wifi-wpa1",
                severity: .high,
                title: "Wi-Fi usa WPA antigo",
                category: "Wi-Fi",
                target: snapshot.ssid ?? "Rede Wi-Fi",
                evidence: snapshot.securityLabel,
                whatItMeans: "A rede tem senha, mas usa uma versão antiga de proteção. Ela é mais fácil de atacar do que WPA2 ou WPA3.",
                scenario: "Alguém próximo e com conhecimento técnico pode tentar explorar falhas do WPA antigo para entrar na rede. Com acesso, pode tentar observar serviços e dispositivos.",
                likelihood: "Possível; depende do roteador e de alguém estar ao alcance.",
                recommendation: "Ative WPA2 ou WPA3 no roteador. Se ele não oferecer nenhum dos dois, considere trocar o equipamento.",
                source: .wifi,
                snapshot: snapshot
            )
        }
        if mode.contains("wpa2_personal") || mode.contains("wpa3") {
            if mode.contains("wpa3"), !mode.contains("transition") {
                return nil
            }
            return makeFinding(
                checkID: "wifi-wpa2",
                severity: .low,
                title: "Wi-Fi usa WPA2; proteção boa, mas não é a mais nova",
                category: "Wi-Fi",
                target: snapshot.ssid ?? "Rede Wi-Fi",
                evidence: snapshot.securityLabel,
                whatItMeans: "WPA2 com uma senha forte ainda é uma proteção aceitável. WPA3 é mais moderno, mas a diferença prática depende do roteador e dos aparelhos.",
                scenario: "Com WPA2 e uma senha forte, alguém de fora não entra só por estar perto. O risco aumenta se a senha for curta, compartilhada ou se o roteador estiver sem atualização.",
                likelihood: "Proteção básica ativa; risco depende da senha e do roteador.",
                recommendation: "Se todos os aparelhos suportarem, ative WPA3 ou o modo de transição. Mantenha uma senha longa, troque-a se já foi compartilhada e atualize o firmware do roteador.",
                source: .wifi,
                snapshot: snapshot
            )
        }
        return makeFinding(
            checkID: "wifi-unknown",
            severity: .low,
            title: "Não consegui confirmar a proteção da Wi-Fi",
            category: "Wi-Fi",
            target: snapshot.ssid ?? "Rede Wi-Fi",
            evidence: snapshot.securityLabel,
            whatItMeans: "O macOS não informou o tipo de segurança da rede. Isso pode acontecer em algumas redes ou por permissão do sistema.",
            scenario: "Sem essa informação, não consigo dizer se alguém de fora precisaria de senha para entrar. Não trate isso como uma falha confirmada.",
            likelihood: "Não verificável com os dados disponíveis.",
            recommendation: "Abra as configurações de Wi-Fi do macOS e confira a segurança da rede; no painel do roteador, use WPA2 ou WPA3.",
            source: .wifi,
            snapshot: snapshot
        )
    }

    private func publicNetworkFinding(_ snapshot: NetworkSnapshot) -> NetworkFinding {
        makeFinding(
            checkID: "public-network",
            severity: snapshot.vpnActive ? .medium : .high,
            title: "Você está numa rede pública",
            category: "Confiança",
            target: snapshot.ssid ?? "Rede pública",
            evidence: "Rede marcada como pública pelo usuário.",
            whatItMeans: "Você não controla o roteador nem sabe quem está conectado. Mesmo que a rede tenha senha, isso não garante que ela seja confiável.",
            scenario: "Alguém pode montar um ponto de acesso com o mesmo nome, observar conexões sem HTTPS ou levar você a uma página falsa. Sites de banco com HTTPS e certificado válido protegem a senha na conexão, mas um hotspot falso ou um site clonado ainda pode enganar você.",
            likelihood: "Possível e fora do seu controle.",
            recommendation: "Evite banco, compras e dados pessoais. Use o hotspot do celular ou uma VPN de confiança, confira o endereço e nunca ignore aviso de certificado.",
            source: .wifi,
            snapshot: snapshot
        )
    }

    private func routerFindings(_ snapshot: NetworkSnapshot) -> [NetworkFinding] {
        var findings: [NetworkFinding] = []
        guard let gateway = snapshot.gateway else { return findings }
        let http = snapshot.gatewayHTTP
        let https = snapshot.gatewayHTTPS

        if let http, http.reachable, !http.redirectsToHTTPS {
            let evidence = "HTTP respondeu \(http.statusCode ?? 0)\(http.title.map { " · \($0)" } ?? "")."
            let looksLikeAdmin = http.hasLoginForm || http.statusCode == 401
            if http.usesBasicAuth {
                findings.append(
                    makeFinding(
                        checkID: "router-basic-auth",
                        severity: .high,
                        title: "Painel do roteador pede senha por HTTP",
                        category: "Roteador",
                        target: gateway,
                        evidence: "Autenticação Basic em HTTP.",
                        whatItMeans: "A senha do painel do roteador pode trafegar sem criptografia. Quem estiver na mesma rede e conseguir observar a conexão pode capturá-la.",
                        scenario: "Um visitante com a senha do Wi-Fi ou um aparelho infectado na mesma rede pode tentar capturar a senha do painel e alterar o roteador. Isso não significa que já aconteceu; significa que existe um caminho.",
                        likelihood: "Possível se alguém estiver na mesma rede.",
                        recommendation: "Acesse o painel por HTTPS, troque a senha do roteador por uma senha longa e única e desative administração remota. Se o roteador só oferece HTTP, atualize o firmware ou troque o equipamento.",
                        source: .gateway,
                        snapshot: snapshot
                    )
                )
            } else if https?.reachable == true {
                findings.append(
                    makeFinding(
                        checkID: "router-http",
                        severity: .medium,
                        title: "Roteador também responde por HTTP sem criptografia",
                        category: "Roteador",
                        target: gateway,
                        evidence: "\(evidence) HTTPS também respondeu.",
                        whatItMeans: "O roteador aceita uma versão sem criptografia. Mesmo que também aceite HTTPS, uma pessoa na mesma rede pode tentar usar o endereço HTTP.",
                        scenario: "Se alguém estiver na sua Wi-Fi, pode tentar observar a sessão do painel ou alterar configurações. O risco é maior em rede compartilhada ou pública.",
                        likelihood: "Possível se alguém estiver na mesma rede.",
                        recommendation: "Use sempre o endereço HTTPS do roteador, desative o acesso HTTP no painel e troque a senha padrão.",
                        source: .gateway,
                        snapshot: snapshot
                    )
                )
            } else if looksLikeAdmin {
                findings.append(
                    makeFinding(
                        checkID: "router-http",
                        severity: .high,
                        title: "Painel do roteador aberto sem HTTPS",
                        category: "Roteador",
                        target: gateway,
                        evidence: "\(evidence) A página parece ser de login; HTTPS não respondeu.",
                        whatItMeans: "A administração do roteador está disponível numa conexão sem criptografia. Quem estiver na mesma rede pode tentar observar ou modificar o que passa por ali.",
                        scenario: "Uma pessoa na mesma Wi-Fi poderia capturar a senha do painel, mudar o DNS ou liberar acesso a um aparelho. É necessário alguém já estar na rede ou ter a senha do Wi-Fi; não é possível confirmar isso por aqui.",
                        likelihood: "Possível se alguém estiver na mesma rede.",
                        recommendation: "Atualize o firmware, ative HTTPS no painel, troque a senha padrão e evite administrar o roteador por Wi-Fi pública.",
                        source: .gateway,
                        snapshot: snapshot
                    )
                )
            } else {
                findings.append(
                    makeFinding(
                        checkID: "router-http",
                        severity: .medium,
                        title: "Roteador responde por HTTP sem confirmação do painel",
                        category: "Roteador",
                        target: gateway,
                        evidence: "\(evidence) HTTPS não respondeu.",
                        whatItMeans: "O endereço do roteador aceita conexão sem criptografia, mas não consegui confirmar se essa página é o painel de administração. Pode ser uma tela de aviso, um portal ou o próprio painel.",
                        scenario: "Se for o painel, alguém na mesma Wi-Fi poderia tentar observar a sessão ou alterar configurações. Se for só um portal, o risco é menor. Não trate este achado como uma invasão.",
                        likelihood: "Possível, mas não confirmado como painel administrativo.",
                        recommendation: "Abra o endereço do roteador pelo navegador e confira se aparece um painel. Se aparecer, use HTTPS, troque a senha padrão e atualize o firmware.",
                        source: .gateway,
                        snapshot: snapshot
                    )
                )
            }
        }

        if let https, https.certificateProblem {
            findings.append(
                makeFinding(
                    checkID: "router-certificate",
                    severity: .medium,
                    title: "Certificado HTTPS do roteador não é confiável",
                    category: "Roteador",
                    target: gateway,
                    evidence: "Falha de certificado ao abrir https://\(gateway)/.",
                    whatItMeans: "A conexão pode estar criptografada, mas o navegador não consegue confirmar que o painel é realmente do seu roteador. Não ignore esse aviso.",
                    scenario: "Alguém na mesma rede poderia se passar pelo painel para capturar sua senha. Também pode ser apenas um certificado autoassinado do próprio roteador, o que é comum.",
                    likelihood: "Não verificável sem acessar o painel e ver o certificado.",
                    recommendation: "Atualize o firmware e o certificado do roteador. Se o aviso continuar, acesse apenas pela rede local e não digite a senha em páginas com alerta de certificado.",
                    source: .gateway,
                    snapshot: snapshot
                )
            )
        }

        return findings
    }

    private func macFindings(
        _ snapshot: NetworkSnapshot,
        context: NetworkAuditContext
    ) -> [NetworkFinding] {
        var findings: [NetworkFinding] = []

        if snapshot.firewallEnabled == false {
            findings.append(
                makeFinding(
                    checkID: "mac-firewall",
                    severity: context.isPublicNetwork ? .high : .medium,
                    title: "Firewall do Mac está desligado",
                    category: "Mac",
                    target: "Firewall",
                    evidence: "O macOS informou que o firewall está desativado.",
                    whatItMeans: "O firewall ajuda a bloquear conexões de entrada que você não pediu. Sem ele, outros aparelhos na rede podem alcançar serviços do Mac com mais facilidade.",
                    scenario: "Se outro dispositivo na mesma Wi-Fi estiver infectado, ele pode tentar procurar portas abertas no seu Mac. O firewall reduz esse caminho, mas não substitui senhas fortes e atualizações.",
                    likelihood: "Possível em qualquer rede compartilhada.",
                    recommendation: "Ative o firewall em Ajustes do Sistema > Rede > Firewall e ligue o modo furtivo.",
                    source: .mac,
                    snapshot: snapshot
                )
            )
        }

        if snapshot.firewallEnabled == true, snapshot.firewallStealth == false {
            findings.append(
                makeFinding(
                    checkID: "mac-stealth",
                    severity: .low,
                    title: "Modo furtivo do firewall está desligado",
                    category: "Mac",
                    target: "Firewall",
                    evidence: "Firewall ligado, modo furtivo desligado.",
                    whatItMeans: "O modo furtivo faz o Mac parecer menos visível para testes de descoberta na rede.",
                    scenario: "Sem ele, um programa na mesma rede pode descobrir mais facilmente que existe um Mac conectado. Isso não significa que ele está acessível.",
                    likelihood: "Reduz a visibilidade, mas não é uma falha grave.",
                    recommendation: "Ative o modo furtivo nas opções do firewall do macOS.",
                    source: .mac,
                    snapshot: snapshot
                )
            )
        }

        if snapshot.fileVaultEnabled == false {
            findings.append(
                makeFinding(
                    checkID: "mac-filevault",
                    severity: .high,
                    title: "FileVault está desligado",
                    category: "Dados",
                    target: "Disco do Mac",
                    evidence: "O macOS informou que o FileVault está desativado.",
                    whatItMeans: "O disco não está criptografado. Se o Mac for perdido ou roubado, alguém pode tentar ler os arquivos fora do sistema.",
                    scenario: "Isso não depende da internet. É o risco de perder documentos, sessões e senhas salvas junto com o aparelho.",
                    likelihood: "O risco existe se o Mac sair do seu controle.",
                    recommendation: "Ative FileVault em Ajustes do Sistema > Privacidade e Segurança > FileVault e guarde a chave de recuperação em local seguro.",
                    source: .mac,
                    snapshot: snapshot
                )
            )
        }

        if snapshot.sipEnabled == false {
            findings.append(
                makeFinding(
                    checkID: "mac-sip",
                    severity: .high,
                    title: "System Integrity Protection (SIP) está desligado",
                    category: "Mac",
                    target: "SIP",
                    evidence: "O macOS informou que o SIP está desativado.",
                    whatItMeans: "O SIP protege partes críticas do sistema contra alterações. Desligado, um programa malicioso tem mais facilidade para se instalar de forma persistente.",
                    scenario: "Se você instalar um app ou extensão maliciosa, ela pode alterar componentes do sistema com menos barreiras. Isso não é causado pela rede, mas afeta seus dados.",
                    likelihood: "O risco aumenta se você instalar apps fora da App Store.",
                    recommendation: "Reative o SIP pelo modo de recuperação do macOS, a menos que você tenha um motivo técnico consciente para mantê-lo desligado.",
                    source: .mac,
                    snapshot: snapshot
                )
            )
        }

        if snapshot.gatekeeperEnabled == false {
            findings.append(
                makeFinding(
                    checkID: "mac-gatekeeper",
                    severity: .medium,
                    title: "Gatekeeper está desligado",
                    category: "Mac",
                    target: "Gatekeeper",
                    evidence: "O macOS informou que a avaliação de apps está desativada.",
                    whatItMeans: "O Gatekeeper verifica a assinatura de apps baixados da internet. Desligado, fica mais fácil abrir um programa não confiável sem aviso.",
                    scenario: "Um download falso pode ser aberto com menos barreiras e instalar algo indesejado. A rede não precisa estar comprometida para isso acontecer.",
                    likelihood: "Possível ao abrir downloads de fontes não confiáveis.",
                    recommendation: "Reative o Gatekeeper em Ajustes do Sistema > Privacidade e Segurança e instale apps apenas de fontes confiáveis.",
                    source: .mac,
                    snapshot: snapshot
                )
            )
        }

        if snapshot.automaticUpdatesEnabled == false {
            findings.append(
                makeFinding(
                    checkID: "mac-updates",
                    severity: .medium,
                    title: "Atualizações automáticas do macOS estão desligadas",
                    category: "Mac",
                    target: "Atualizações",
                    evidence: "O macOS informou que a verificação automática está desativada.",
                    whatItMeans: "Atualizações corrigem falhas conhecidas. Sem elas, o Mac fica mais tempo exposto a problemas que já têm correção.",
                    scenario: "Um site ou app malicioso pode explorar uma falha que já foi corrigida pelo fabricante. Manter o sistema atualizado reduz esse risco.",
                    likelihood: "Possível ao usar sites ou apps com falhas já corrigidas.",
                    recommendation: "Ative atualizações automáticas em Ajustes do Sistema > Geral > Atualização de Software.",
                    source: .mac,
                    snapshot: snapshot
                )
            )
        }

        return findings
    }

    private func serviceFindings(_ snapshot: NetworkSnapshot) -> [NetworkFinding] {
        let exposed = snapshot.listeningServices.filter(\.exposedToLAN)
        guard !exposed.isEmpty else { return [] }
        var findings: [NetworkFinding] = []
        for service in exposed.prefix(8) {
            let process = service.process.lowercased()
            let isDatabase = ["postgres", "redis", "mysql", "mariadb", "mongo", "meilisearch", "elastic", "clickhouse", "sql"].contains {
                process.contains($0)
            }
            let isRemote = service.port == 22
                || service.port == 5900
                || service.port == 445
                || process.contains("sshd")
                || process.contains("vnc")
                || process.contains("remotedesktop")
            let isDev = ["node", "python", "ruby", "php", "java", "deno", "bun", "vite", "next", "uvicorn", "gunicorn", "rails"].contains {
                process.contains($0)
            }
            let title: String
            let severity: RiskLevel
            let category: String
            let explanation: String
            let scenario: String
            let recommendation: String
            if isDatabase {
                title = "Banco de dados acessível pela rede local"
                severity = .high
                category = "Serviço"
                explanation = "O programa \(service.process) está escutando na porta \(service.port) e não está restrito ao próprio Mac."
                scenario = "Qualquer pessoa na mesma Wi-Fi pode tentar se conectar ao banco. Se ele não tiver senha ou estiver mal configurado, pode ler ou alterar dados do seu projeto."
                recommendation = "Configure o banco para escutar apenas em 127.0.0.1, use senha forte e mantenha o firewall ligado. Não exponha bancos na rede local sem necessidade."
            } else if isRemote {
                title = "Acesso remoto aberto para a rede local"
                severity = .high
                category = "Serviço"
                explanation = "O serviço \(service.process) está escutando na porta \(service.port) para outros aparelhos da rede."
                scenario = "Alguém na mesma Wi-Fi pode tentar adivinhar senha ou explorar uma falha do serviço. Se for acesso remoto que você não usa, é uma porta desnecessária."
                recommendation = "Desative Login Remoto/Compartilhamento de Tela se não usar. Se precisar, restrinja ao localhost, use chave em vez de senha e limite por firewall."
            } else if isDev {
                title = "Servidor de desenvolvimento aberto para a rede"
                severity = .medium
                category = "Serviço"
                explanation = "O programa \(service.process) está escutando na porta \(service.port) e pode ser acessado por outros aparelhos da mesma Wi-Fi."
                scenario = "Um visitante ou aparelho infectado na rede pode abrir seu app em desenvolvimento, ver dados de teste e testar rotas que talvez não tenham login."
                recommendation = "Pare o servidor quando não estiver usando, escute em 127.0.0.1 e não use dados reais em ambiente de desenvolvimento."
            } else {
                title = "Serviço aberto para a rede local"
                severity = .medium
                category = "Serviço"
                explanation = "O programa \(service.process) está escutando na porta \(service.port) e não está restrito ao próprio Mac."
                scenario = "Outros aparelhos na mesma Wi-Fi podem tentar se conectar. O risco depende do que o serviço faz e de ele exigir autenticação."
                recommendation = "Verifique se esse serviço precisa ficar visível na rede. Se não precisar, configure para escutar apenas em 127.0.0.1 ou bloqueie no firewall."
            }
            findings.append(
                makeFinding(
                    checkID: "service-exposed",
                    severity: severity,
                    title: title,
                    category: category,
                    target: "\(service.process) · porta \(service.port)",
                    evidence: "Escutando em \(service.bind):\(service.port).",
                    whatItMeans: explanation,
                    scenario: scenario,
                    likelihood: "Confirmado: o serviço está aberto agora; não há prova de acesso.",
                    recommendation: recommendation,
                    source: .services,
                    snapshot: snapshot
                )
            )
        }
        return findings
    }

    private func devicesFinding(_ snapshot: NetworkSnapshot) -> NetworkFinding? {
        guard snapshot.devices.count >= 5 else { return nil }
        let known = snapshot.devices
            .prefix(6)
            .map { "\($0.ip) (\($0.macKind))" }
            .joined(separator: ", ")
        return makeFinding(
            checkID: "network-devices",
            severity: .low,
            title: "Vários dispositivos conhecidos na sua rede",
            category: "Dispositivos",
            target: "Rede local",
            evidence: "\(snapshot.devices.count) dispositivos na tabela ARP: \(known).",
            whatItMeans: "O Mac conhece esses aparelhos, mas a lista é parcial. Ver um dispositivo não significa que ele seja confiável ou que alguém invadiu a rede.",
            scenario: "Se você não reconhece um dos aparelhos, pode ser uma visita, um aparelho antigo ou alguém usando a senha do Wi-Fi. Só a lista não permite confirmar.",
            likelihood: "Lista parcial; não é um scan completo da casa.",
            recommendation: "Confira a lista de clientes no painel do roteador. Se houver algo desconhecido, troque a senha do Wi-Fi e ative WPA3.",
            source: .devices,
            snapshot: snapshot
        )
    }

    private func publicDNSFinding(_ snapshot: NetworkSnapshot) -> NetworkFinding {
        makeFinding(
            checkID: "dns-public",
            severity: .medium,
            title: "DNS sem proteção extra em rede pública",
            category: "DNS",
            target: snapshot.dnsServers.joined(separator: ", "),
            evidence: "Servidores DNS: \(snapshot.dnsServers.joined(separator: ", ")).",
            whatItMeans: "O DNS transforma nomes de sites em endereços. Numa rede pública, alguém pode tentar manipular essa resposta para levar você a uma página falsa.",
            scenario: "Um hotspot mal-intencionado pode tentar redirecionar um site para uma cópia. HTTPS e o cadeado ajudam a detectar o site errado, mas nem todo golpe é bloqueado.",
            likelihood: "Possível em rede pública sem VPN.",
            recommendation: "Use VPN de confiança ou DNS criptografado e confira sempre o endereço e o certificado do site.",
            source: .dns,
            snapshot: snapshot
        )
    }

    private func quantity(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }

    private func isOpenOrWeak(_ mode: String?) -> Bool {
        let value = (mode ?? "").lowercased()
        return value.contains("none") || value.contains("wep") || value.contains("wpa_personal")
    }

    private func makeFinding(
        checkID: String,
        severity: RiskLevel,
        title: String,
        category: String,
        target: String,
        evidence: String,
        whatItMeans: String,
        scenario: String,
        likelihood: String,
        recommendation: String,
        source: NetworkFeatureSource,
        snapshot: NetworkSnapshot
    ) -> NetworkFinding {
        NetworkFinding(
            severity: severity,
            title: title,
            checkID: checkID,
            category: category,
            target: target,
            evidence: evidence,
            whatItMeans: whatItMeans,
            scenario: scenario,
            likelihood: likelihood,
            recommendation: recommendation,
            fixPrompt: NetworkPromptBuilder.fixPrompt(
                checkID: checkID,
                title: title,
                target: target,
                evidence: evidence,
                whatItMeans: whatItMeans,
                scenario: scenario,
                recommendation: recommendation,
                snapshot: snapshot
            ),
            source: source
        )
    }
}

public enum NetworkPromptBuilder {
    public static func generalPrompt(for report: NetworkReport) -> String {
        let snapshot = report.snapshot
        let network = snapshot.ssid ?? "rede não identificada"
        let gateway = snapshot.gateway ?? "roteador não identificado"
        let protections = activeProtections(snapshot)
        let findings = report.findings.enumerated().map { index, finding in
            """
            \(index + 1). [\(finding.severity.label.uppercased())] \(finding.title)
            Alvo: \(finding.target)
            Evidência: \(finding.evidence)
            O que significa: \(finding.whatItMeans)
            Cenário possível: \(finding.scenario)
            Chance: \(finding.likelihood)
            Correção recomendada: \(finding.recommendation)
            """
        }.joined(separator: "\n")
        let findingBlock = findings.isEmpty
            ? "Nenhum ponto de atenção foi confirmado nesta checagem. Ainda assim, revise as proteções básicas e os hábitos de segurança."
            : findings

        return """
        Você é um especialista em segurança doméstica e privacidade, explicando para uma pessoa leiga.

        Objetivo: criar um plano único para resolver todos os pontos de atenção da rede abaixo, em ordem de prioridade. Não trate esta checagem como prova de invasão e não use linguagem alarmista.

        Contexto:
        - Rede Wi-Fi: \(network)
        - Proteção: \(snapshot.securityLabel)
        - Roteador: \(gateway)
        - VPN ativa: \(snapshot.vpnActive ? "sim" : "não")
        - Rede marcada como pública: \(report.context.isPublicNetwork ? "sim" : "não")
        - Sistema: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        - Proteções já ativas: \(protections.isEmpty ? "nenhuma confirmada" : protections.joined(separator: ", "))

        Pontos para resolver, já ordenados por prioridade:
        \(findingBlock)

        Limites desta checagem:
        - É uma foto local do momento; não captura tráfego, não testa senhas e não prova que alguém invadiu a rede.
        - A lista de dispositivos é parcial e o painel do roteador não foi acessado com autenticação.

        Tarefa:
        1. Comece com um resumo curto do que é mais importante e do que pode esperar.
        2. Monte um plano único, não uma lista separada por ferramenta. Priorize crítico e alto antes de médio e baixo.
        3. Para cada ponto, explique em linguagem simples: por que importa, o passo a passo da correção e como confirmar que funcionou.
        4. Separe o que a pessoa pode resolver no Mac do que precisa ser feito no roteador. Se precisar do roteador, peça modelo e operadora, mas nunca peça senha.
        5. Não sugira capturar tráfego, testar senhas, explorar falhas, abrir portas ou instalar ferramentas de ataque.
        6. Se uma correção puder interromper a internet, mudar o nome da rede ou desconectar aparelhos, avise o impacto e peça confirmação antes.
        7. Termine com um checklist único, dividido em "hoje", "esta semana" e "quando possível".

        Se não houver nenhum ponto confirmado, diga isso com clareza e entregue apenas uma rotina de prevenção.
        """
    }

    private static func activeProtections(_ snapshot: NetworkSnapshot) -> [String] {
        var items: [String] = []
        if snapshot.firewallEnabled == true { items.append("firewall do Mac") }
        if snapshot.firewallStealth == true { items.append("modo furtivo") }
        if snapshot.fileVaultEnabled == true { items.append("FileVault") }
        if snapshot.sipEnabled == true { items.append("SIP") }
        if snapshot.gatekeeperEnabled == true { items.append("Gatekeeper") }
        if snapshot.automaticUpdatesEnabled == true { items.append("atualizações automáticas") }
        if snapshot.vpnActive { items.append("VPN ativa") }
        return items
    }

    public static func fixPrompt(
        checkID: String,
        title: String,
        target: String,
        evidence: String,
        whatItMeans: String,
        scenario: String,
        recommendation: String,
        snapshot: NetworkSnapshot
    ) -> String {
        let network = snapshot.ssid ?? "rede não identificada"
        let gateway = snapshot.gateway ?? "roteador não identificado"
        return """
        Você é um especialista em segurança doméstica e privacidade, explicando para uma pessoa leiga.

        Contexto:
        - Rede Wi-Fi: \(network)
        - Proteção: \(snapshot.securityLabel)
        - Roteador: \(gateway)
        - VPN ativa: \(snapshot.vpnActive ? "sim" : "não")
        - Sistema: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)

        Achado: \(title) [\(checkID)]
        Alvo: \(target)
        Evidência: \(evidence)
        O que significa: \(whatItMeans)
        Cenário possível: \(scenario)
        O que fazer: \(recommendation)

        Tarefa:
        1. Explique o problema em linguagem simples, sem alarmismo e sem afirmar que houve invasão.
        2. Diga o que a pessoa deve fazer primeiro, passo a passo, considerando que ela pode não saber o modelo do roteador.
        3. Para ações no Mac, cite o caminho de Ajustes e o comando de verificação quando existir.
        4. Para ações no roteador, peça o modelo e a operadora se precisar, mas nunca peça senha.
        5. Não sugira capturar tráfego, testar senhas, explorar falhas ou abrir portas.
        6. Diga como confirmar que a correção funcionou.
        7. Termine com um checklist curto de prevenção.

        Se a correção depender de uma escolha (por exemplo, usar VPN, trocar o roteador ou desativar um serviço), explique o impacto de cada opção. Não faça alterações sem confirmação da pessoa.
        """
    }
}
