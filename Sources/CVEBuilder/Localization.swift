import CVECore
import Foundation

/// Textos da interface. O padrão é inglês; o português vem do sistema ou da
/// escolha em Ajustes > Geral. A chave é sempre o texto em português.
enum L10n {
    static var language: AppLanguage = .system

    static var isPortuguese: Bool { language.isPortuguese }

    static func t(_ portuguese: String) -> String {
        guard !isPortuguese else { return portuguese }
        if let exact = english[portuguese] { return exact }
        return dynamicEnglish(portuguese) ?? portuguese
    }

    private static func dynamicEnglish(_ text: String) -> String? {
        if let parts = captures(#"^Analisando bloco (\d+) de (\d+)$"#, text) {
            return "Analyzing chunk \(parts[1]) of \(parts[2])"
        }
        if let parts = captures(#"^Mapeando o projeto com orçamento de (.+)\.$"#, text) {
            return "Mapping the project with a budget of \(parts[1])."
        }
        if let parts = captures(#"^O limite de (\d+) KB de código por análise foi atingido\.$"#, text) {
            return "The \(parts[1]) KB code limit per analysis was reached."
        }
        if let parts = captures(#"^O limite de (\d+) arquivos por análise foi atingido\.$"#, text) {
            return "The \(parts[1]) file limit per analysis was reached."
        }
        if let parts = captures(#"^A pasta (.+) não existe mais\.$"#, text) {
            return "The folder \(parts[1]) no longer exists."
        }
        if let parts = captures(#"^Não consegui abrir a pasta (.+)\.$"#, text) {
            return "Could not open the folder \(parts[1])."
        }
        if let parts = captures(#"^Não consegui ler (.+): (.+)$"#, text) {
            return "Could not read \(parts[1]): \(parts[2])"
        }
        if let parts = captures(#"^O (.+) de (.+) não tinha pacotes legíveis\.$"#, text) {
            return "The \(parts[1]) in \(parts[2]) had no readable packages."
        }
        if let parts = captures(#"^O (.+) em (.+) é grande demais para esta varredura\.$"#, text) {
            return "The \(parts[1]) in \(parts[2]) is too large for this scan."
        }
        if let parts = captures(#"^Sua sessão da Cultura Builder expirou\. Rode `(.+)` e tente de novo\.$"#, text) {
            return "Your Cultura Builder session expired. Run `\(parts[1])` and try again."
        }
        if let parts = captures(#"^Não consegui renovar sua sessão da Cultura Builder\. (.+)$"#, text) {
            return "Could not renew your Cultura Builder session. \(L10n.t(parts[1]))"
        }
        if let parts = captures(#"^Não consegui concluir a análise da rede: (.+)$"#, text) {
            return "Could not finish the network analysis: \(parts[1])"
        }
        if let parts = captures(#"^Já existe uma rotina para este projeto\. Edite ou remova a rotina das (.+)\.$"#, text) {
            return "A routine already exists for this project. Edit or remove the routine at \(parts[1])."
        }
        if let parts = captures(#"^O Pest precisa de pelo menos 30 minutos entre rotinas\. Afaste este horário em (\d+) min da rotina das (.+)\.$"#, text) {
            return "Pest needs at least 30 minutes between routines. Move this time \(parts[1]) min away from the routine at \(parts[2])."
        }
        if let parts = captures(#"^O Red Team precisa de pelo menos (\d+) minutos entre rodadas\. Afaste este horário em (\d+) min da rodada das (.+)\.$"#, text) {
            return "Red Team needs at least \(parts[1]) minutes between runs. Move this time \(parts[2]) min away from the run at \(parts[3])."
        }
        if let parts = captures(#"^(\d+) projetos? encontrados?$"#, text) {
            return "\(parts[1]) projects found"
        }
        if let parts = captures(#"^(\d+) projetos? com achados$"#, text) {
            return "\(parts[1]) projects with findings"
        }
        if let parts = captures(#"^Lote (\d+) de (\d+)$"#, text) {
            return "Batch \(parts[1]) of \(parts[2])"
        }
        if let parts = captures(#"^(\d+) de (\d+)$"#, text) {
            return "\(parts[1]) of \(parts[2])"
        }
        if let parts = captures(#"^(\d+) de (\d+) vulnerabilidades$"#, text) {
            return "\(parts[1]) of \(parts[2]) vulnerabilities"
        }
        if let parts = captures(#"^Lendo a estrutura do projeto com orçamento de (.+)\.$"#, text) {
            return "Reading the project structure with a budget of \(parts[1])."
        }
        if let parts = captures(#"^Bloco (\d+) de (\d+) · (\d+) arquivo\(s\)\.$"#, text) {
            return "Chunk \(parts[1]) of \(parts[2]) · \(parts[3]) file(s)."
        }
        if let parts = captures(#"^Bloco (\d+) de (\d+) · revisão semântica do código\.$"#, text) {
            return "Chunk \(parts[1]) of \(parts[2]) · semantic code review."
        }
        if let parts = captures(#"^(\d+) arquivo\(s\) neste bloco\. Isso pode levar alguns minutos\.$"#, text) {
            return "\(parts[1]) file(s) in this chunk. This may take a few minutes."
        }
        if text.hasPrefix("O Mac está com ") && text.contains(" de memória disponível") {
            return text
                .replacingOccurrences(of: "O Mac está com ", with: "The Mac has ")
                .replacingOccurrences(of: " de memória disponível", with: " of available memory")
                .replacingOccurrences(of: "o mínimo seguro para o Pest é", with: "the safe minimum for Pest is")
                .replacingOccurrences(of: "o mínimo seguro para o Red Teaming é", with: "the safe minimum for Red Teaming is")
        }
        return nil
    }

    private static func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
    }

    static func t(_ portuguese: String, _ english: String) -> String {
        isPortuguese ? portuguese : english
    }

    static func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: return t("Sistema", "System")
        case .english: return "English"
        case .portuguese: return "Português (Brasil)"
        }
    }

    static var locale: Locale {
        Locale(identifier: isPortuguese ? "pt_BR" : "en_US")
    }

    private static let english: [String: String] = [
        ":": ":",
        "·": "·",
        "Builders ": "Builders ",
        "Builders Protect": "Builders Protect",
        "Protect": "Protect",
        "KEV": "KEV",
        "Pest": "Pest",
        "IA": "AI",
        "NUCLEI GUIDE": "NUCLEI GUIDE",
        "NAVEGAÇÃO": "NAVIGATION",
        "IMPORTANTE": "IMPORTANT",
        "OBRIGATÓRIO": "REQUIRED",
        "PRIVACIDADE POR PADRÃO": "PRIVACY BY DEFAULT",
        "POR CULTURA BUILDER": "BY CULTURA BUILDER",
        "CONTROLE TOTAL": "FULL CONTROL",
        "CHECAGEM LOCAL": "LOCAL CHECK",
        "ALERTA DE SEGURANÇA": "SECURITY ALERT",
        "ATIVA": "ACTIVE",
        "NA LISTA": "LISTED",
        "EM BREVE": "SOON",
        "A IA prioriza o que reduz risco mais rápido e escreve o plano por projeto.": "The AI prioritizes what cuts risk fastest and writes the plan per project.",
        "A análise de dependências continua funcionando normalmente.": "Dependency analysis keeps working normally.",
        "A análise não altera seus arquivos e não faz commit. Você pode continuar usando o app enquanto ela roda.": "The analysis does not change your files or commit. You can keep using the app while it runs.",
        "A análise não terminou": "The analysis did not finish",
        "A análise profunda de código está temporariamente indisponível enquanto investigamos um problema de consumo de memória. Nenhum código é enviado nesta versão.": "Deep code analysis is temporarily unavailable while we investigate a memory issue. No code is sent in this version.",
        "A checagem não terminou": "The check did not finish",
        "A checagem usa comandos do macOS, consulta o endereço do roteador por HTTP/HTTPS e não envia dados da rede para a Cultura Builder. Nenhuma senha é testada. Nenhum tráfego é gravado.": "The check uses macOS commands, queries the router address over HTTP/HTTPS and sends no network data to Cultura Builder. No password is tested. No traffic is recorded.",
        "A conta libera o diagnóstico da IA e o prompt de correção. A verificação de vulnerabilidades funciona mesmo sem login.": "The account unlocks the AI diagnosis and the fix prompt. Vulnerability scanning works even without signing in.",
        "Prefere o modo RTX? A chave dedicada substitui o login e é configurada depois em Ajustes > IA e segurança.": "Prefer RTX mode? The dedicated key replaces sign-in and is set later in Settings > AI and security.",
        "A primeira varredura começa assim que você concluir. O resultado aparece no menu bar e no painel do app.": "The first scan starts as soon as you finish. The result shows in the menu bar and the app panel.",
        "A revisão usa a LLM privada da Cultura Builder. O consentimento é pedido antes de cada análise manual; salvar uma rotina autoriza a execução diária.": "The review uses Cultura Builder's private LLM. Consent is requested before every manual analysis; saving a routine authorizes the daily run.",
        "A rotina usa a IA da Cultura Builder e só roda com a conta conectada. Salvar a rotina autoriza o envio recorrente dos mesmos arquivos redigidos para a LLM privada, uma vez ao dia.": "The routine uses Cultura Builder's AI and only runs with an account connected. Saving the routine authorizes recurring sends of the same redacted files to the private LLM, once a day.",
        "A troca de idioma vale na hora para as telas do app. Relatórios já gerados mantêm o texto original.": "The language change applies right away to the app screens. Existing reports keep their original text.",
        "A varredura acontece quando o Mac acordar. Ao abrir o app, o Builders Protect também recupera uma rotina perdida.": "The scan happens when the Mac wakes. On launch, Builders Protect also recovers a missed routine.",
        "A varredura de dependências envia apenas nomes, versões e lockfiles. O Pest tem consentimento próprio para código.": "The dependency scan sends only names, versions and lockfiles. Pest has its own consent for code.",
        "A varredura de dependências envia nomes, versões e lockfiles, sem código-fonte. O Pest e o Red Teaming têm consentimento próprio.": "The dependency scan sends names, versions and lockfiles, with no source code. Pest and Red Teaming have their own consent.",
        "A varredura de vulnerabilidades continua. Entre na Cultura Builder para receber a análise e o prompt de correção.": "Vulnerability scanning continues. Sign in to Cultura Builder to get the analysis and fix prompt.",
        "A varredura ignora node_modules, .git, builds, caches e ambientes virtuais. Ela lê apenas manifests e lockfiles.": "The scan skips node_modules, .git, builds, caches and virtual environments. It only reads manifests and lockfiles.",
        "A varredura não terminou": "The scan did not finish",
        "Abra a central completa": "Open the full control center",
        "Abre a central completa e inicia uma nova verificação": "Opens the full control center and starts a new scan",
        "Abrir Pastas": "Open Folders",
        "Abrir a central com os detalhes": "Open the control center with details",
        "Abrir ajustes": "Open settings",
        "Abrir ao iniciar o Mac": "Open at Mac login",
        "Abrir detalhes": "Open details",
        "Abrir detalhes da vulnerabilidade": "Open vulnerability details",
        "Abrir no Finder": "Open in Finder",
        "Abrir o Hub": "Open the Hub",
        "Abrir pasta": "Open folder",
        "Abrir pasta no Finder": "Open folder in Finder",
        "Achados reais, não ruído": "Real findings, not noise",
        "Acionar Red Team": "Run Red Team",
        "Acionar o Red Team neste projeto": "Run Red Team on this project",
        "Adicionar horário": "Add time",
        "Adicionar pasta": "Add folder",
        "Adicionar pasta de projetos": "Add projects folder",
        "Adicione a raiz onde ficam seus repositórios para que o app encontre os lockfiles.": "Add the root where your repositories live so the app can find lockfiles.",
        "Adicione as pastas onde ficam seus projetos para começar a verificar as dependências.": "Add the folders where your projects live to start checking dependencies.",
        "Adicione as pastas que contêm seus repositórios. O app desce até 8 níveis, ignora node_modules e procura lockfiles de npm, Python, Rust, Go, Ruby, Elixir e Nix.": "Add the folders that hold your repositories. The app goes 8 levels deep, skips node_modules and looks for npm, Python, Rust, Go, Ruby, Elixir and Nix lockfiles.",
        "Adicione uma pasta com lockfiles em Ajustes > Pastas para liberar a análise profunda.": "Add a folder with lockfiles in Settings > Folders to unlock deep analysis.",
        "Adicione uma pasta com manifests ou código em Ajustes > Pastas para liberar o Pest.": "Add a folder with manifests or code in Settings > Folders to unlock Pest.",
        "Agende quantas rodadas quiser no dia. Cada horário precisa de 20 minutos de diferença dos outros.": "Schedule as many runs a day as you want. Each time must be 20 minutes apart from the others.",
        "Ainda não verificado": "Not checked yet",
        "Ajustes": "Settings",
        "Ajustes e relatórios ficam em ~/Library/Application Support/Builders Protect.": "Settings and reports live in ~/Library/Application Support/Builders Protect.",
        "Ajustes salvos": "Settings saved",
        "Analisar com Pest": "Analyze with Pest",
        "Analisar este projeto agora": "Analyze this project now",
        "Analisar minha rede": "Analyze my network",
        "Antes de verificar": "Before checking",
        "Análise pausada": "Analysis paused",
        "Análise pausada para proteger a memória": "Analysis paused to protect memory",
        "Análise profunda de código, um projeto por vez": "Deep code analysis, one project at a time",
        "Análises": "Analysis",
        "Ao escolher este modo, todas as análises (Pest, Red Team e diagnóstico) usam o RTX no lugar do modelo padrão.": "When you pick this mode, every analysis (Pest, Red Team and diagnosis) uses RTX instead of the default model.",
        "Aplicar": "Apply",
        "Arquivos de texto do projeto serão enviados para a LLM privada": "Project text files will be sent to the private LLM",
        "As alterações são salvas automaticamente neste Mac.": "Changes are saved automatically on this Mac.",
        "As análises ficam salvas neste Mac.": "Analyses are saved on this Mac.",
        "Atualizar projetos": "Refresh projects",
        "Autorizo o envio do código deste projeto para a LLM privada da Cultura Builder.": "I authorize sending this project's code to Cultura Builder's private LLM.",
        "Autorizo uma consulta local à minha rede": "I authorize a local query of my network",
        "Avançado": "Advanced",
        "Avisar sobre novas vulnerabilidades": "Warn about new vulnerabilities",
        "Avisos da varredura": "Scan warnings",
        "Cada cenário mostra o que foi confirmado agora, o que é possível no seu tipo de rede e o que não foi possível verificar.": "Each scenario shows what was confirmed now, what is possible on your network type and what could not be checked.",
        "Cada projeto pode ter a própria rotina diária. O Pest respeita pelo menos 30 minutos entre rotinas e pausa se a memória ficar baixa.": "Each project can have its own daily routine. Pest keeps at least 30 minutes between routines and pauses if memory runs low.",
        "Cancelar": "Cancel",
        "Cancelar análise": "Cancel analysis",
        "Cancelar checagem": "Cancel check",
        "Chave dedicada": "Dedicated key",
        "Clique em um projeto para abrir o relatório e ajustar a rotina. O botão de play analisa na hora; cada rotina usa um horário próprio, com pelo menos 30 minutos de diferença.": "Click a project to open the report and adjust the routine. The play button analyzes right away; each routine uses its own time, at least 30 minutes apart.",
        "Concluir": "Finish",
        "Conecte sua conta Cultura Builder.": "Connect your Cultura Builder account.",
        "Configurar rotina deste projeto": "Configure this project's routine",
        "Consentimento": "Consent",
        "Consentimento autorizado para esta análise.": "Consent granted for this analysis.",
        "Consentimento do Pest": "Pest consent",
        "Conta": "Account",
        "Copia um único prompt para corrigir todos os projetos afetados, inclusive os filtrados": "Copies a single prompt to fix every affected project, including filtered ones",
        "Copiar": "Copy",
        "Copiar comando": "Copy command",
        "Copiar comando de login": "Copy login command",
        "Copiar prompt": "Copy prompt",
        "Copiar prompt de correção": "Copy fix prompt",
        "Copiar prompt geral": "Copy general prompt",
        "Copiar resumo": "Copy summary",
        "Copie um prompt completo e cole no Claude Code, Codex ou Cursor.": "Copy a complete prompt and paste it into Claude Code, Codex or Cursor.",
        "Correção em um clique": "One-click fix",
        "Dados locais": "Local data",
        "Dependência antiga não precisa ser uma surpresa.": "An outdated dependency need not be a surprise.",
        "Detalhes técnicos": "Technical details",
        "Diagnóstico": "Diagnosis",
        "Diagnóstico da Cultura Builder": "Cultura Builder diagnosis",
        "Diagnóstico da IA desligado": "AI diagnosis off",
        "Diagnóstico gerado pela Cultura Builder": "Diagnosis generated by Cultura Builder",
        "Diferente da chave local. Fica só neste Mac, em Ajustes.": "Different from the local key. It stays only on this Mac, in Settings.",
        "Editar": "Edit",
        "Endpoint": "Endpoint",
        "Entendi e autorizo esta checagem local.": "I understand and authorize this local check.",
        "Entre pelo terminal para liberar a análise da IA.": "Sign in through the terminal to unlock AI analysis.",
        "Envia uma notificação quando uma vulnerabilidade nova aparece.": "Sends a notification when a new vulnerability appears.",
        "Escolha como as análises consultam a IA e qual modelo responde.": "Choose how analyses call the AI and which model answers.",
        "Escolha os projetos que ficam na lista de acesso rápido. Você pode analisar e configurar a rotina de cada um sem procurar a pasta novamente.": "Choose the projects in the quick-access list. You can analyze and schedule each one without finding the folder again.",
        "Escolha os projetos que você acompanha no Pest. Eles ficam à mão para analisar e configurar a rotina sem procurar a pasta de novo.": "Choose the projects you track in Pest. They stay at hand to analyze and schedule without finding the folder again.",
        "Escolha suas pastas, conecte a conta da Cultura Builder e defina a rotina diária.": "Choose your folders, connect your Cultura Builder account and set the daily routine.",
        "Escolha um projeto para agendar rodadas.": "Choose a project to schedule runs.",
        "Escolher projetos": "Choose projects",
        "Estou numa rede pública": "I am on a public network",
        "Faça a primeira leitura para ver a proteção da Wi-Fi, o estado do roteador e os serviços do Mac visíveis para a rede. Nenhuma alteração será feita.": "Run the first read to see Wi-Fi protection, router state and Mac services visible to the network. Nothing will be changed.",
        "Faça login no proxy da Cultura Builder pelo terminal e o app usa essa sessão.": "Sign in to the Cultura Builder proxy through the terminal and the app uses that session.",
        "Fechar": "Close",
        "Feche navegadores, Docker ou apps pesados e volte ao Pest. A análise não começa até haver espaço para trabalhar sem travar o Mac.": "Close browsers, Docker or heavy apps and return to Pest. The analysis does not start until there is room to work without freezing the Mac.",
        "Feito pela Cultura Builder.": "Made by Cultura Builder.",
        "Fonte: base de vulnerabilidades · análise: Cultura Builder": "Source: vulnerability database · analysis: Cultura Builder",
        "Fontes": "Sources",
        "Gerenciar": "Manage",
        "Gerenciar pastas": "Manage folders",
        "Guia": "Guide",
        "Hora": "Hour",
        "Horário": "Time",
        "Horário da varredura": "Scan time",
        "Horário indisponível": "Time unavailable",
        "Hotel, aeroporto, café, coworking ou uma rede que você não controla. Isso torna os cenários de confiança mais rigorosos.": "Hotel, airport, café, coworking or a network you do not control. This makes trust scenarios stricter.",
        "IA e segurança": "AI and security",
        "Idioma": "Language",
        "Ignorar pasta": "Ignore folder",
        "Ignorar selecionadas": "Ignore selected",
        "Janela": "Window",
        "Lendo a rede atual sem capturar tráfego.": "Reading the current network without capturing traffic.",
        "Limites desta análise": "Limits of this analysis",
        "Limpar": "Clear",
        "Limpar filtros": "Clear filters",
        "Limpar seleção": "Clear selection",
        "Limpar tudo": "Clear all",
        "Mantém o radar ativo sem abrir o app manualmente.": "Keeps the radar active without opening the app manually.",
        "Memória abaixo do mínimo seguro": "Memory below the safe minimum",
        "Memória e espaço": "Memory and space",
        "Memória em primeiro lugar": "Memory first",
        "Meus projetos": "My projects",
        "Minha rede": "My network",
        "Minha rede: leitura local. Não captura tráfego, não testa senhas e não prova invasão.": "My network: local read. No traffic capture, no password testing, no proof of intrusion.",
        "Minuto": "Minute",
        "Modelo": "Model",
        "Modelo sem censura para revisão agressiva de código.": "Uncensored model for aggressive code review.",
        "Modelo servido pelo endpoint RTX.": "Model served by the RTX endpoint.",
        "Modo de análise": "Analysis mode",
        "Nenhum lockfile encontrado nessas pastas. Adicione a raiz onde ficam os repositórios, não uma pasta interna.": "No lockfile found in these folders. Add the root where repositories live, not an inner folder.",
        "Nenhum lockfile encontrado. Tente adicionar a pasta raiz dos repositórios.": "No lockfile found. Try adding the repositories root folder.",
        "Nenhum ponto de atenção visível": "No visible point of attention",
        "Nenhum projeto com esses filtros": "No project with these filters",
        "Nenhum projeto corresponde à busca.": "No project matches the search.",
        "Nenhum projeto encontrado": "No project found",
        "Nenhum projeto na lista": "No project in the list",
        "Nenhuma falha de código encontrada": "No code flaw found",
        "Nenhuma pasta adicionada ainda.": "No folder added yet.",
        "Nenhuma pasta monitorada": "No monitored folder",
        "Nenhuma vulnerabilidade conhecida nas versões instaladas": "No known vulnerability in installed versions",
        "Nesta varredura, apenas nomes, versões e lockfiles saem deste Mac.": "In this scan, only names, versions and lockfiles leave this Mac.",
        "Nesta varredura, só nomes, versões e lockfiles saem deste Mac.": "In this scan, only names, versions and lockfiles leave this Mac.",
        "Notificações": "Notifications",
        "Nova análise": "New analysis",
        "Não encontrei falha grave nas configurações que consegui verificar. Isso não prova que a rede é invulnerável, mas não há nada urgente para corrigir nesta foto.": "I found no serious flaw in the settings I could check. That does not prove the network is invulnerable, but nothing is urgent to fix in this snapshot.",
        "O Builders Protect lê as configurações que o macOS mostra, consulta apenas o endereço do seu roteador e lista os aparelhos e serviços visíveis. Ele não captura tráfego, não testa senhas, não entra no painel do roteador e não consegue provar que alguém invadiu sua rede. O objetivo é explicar o que está exposto e o que vale corrigir primeiro.": "Builders Protect reads the settings macOS exposes, queries only your router address and lists visible devices and services. It does not capture traffic, test passwords, enter the router panel or prove an intrusion. The goal is to explain what is exposed and what is worth fixing first.",
        "O Builders Protect lê os lockfiles dos seus projetos, compara cada versão com a base de vulnerabilidades e explica o que corrigir — com um prompt pronto para o seu agente de código.": "Builders Protect reads your projects' lockfiles, compares each version with the vulnerability database and explains what to fix — with a prompt ready for your coding agent.",
        "O Builders Protect lê seus lockfiles, compara com a base de vulnerabilidades e explica o que corrigir.": "Builders Protect reads your lockfiles, compares them with the vulnerability database and explains what to fix.",
        "O Builders Protect transforma lockfiles em um plano de correção claro. Ele compara as versões instaladas com a base de vulnerabilidades e usa a LLM da Cultura Builder para priorizar o que realmente importa.": "Builders Protect turns lockfiles into a clear fix plan. It compares installed versions with the vulnerability database and uses Cultura Builder's LLM to prioritize what really matters.",
        "O Builders Protect verifica suas dependências no horário escolhido e avisa quando aparece uma vulnerabilidade nova.": "Builders Protect checks your dependencies at the chosen time and warns when a new vulnerability appears.",
        "O Mac precisa estar ligado ou acordar depois do horário.": "The Mac must be on or wake after the time.",
        "O Pest não altera seus arquivos e não faz commit. Você pode continuar usando o app enquanto ele roda.": "Pest does not change your files or commit. You can keep using the app while it runs.",
        "O Pest não terminou": "Pest did not finish",
        "O Pest usa um checklist destilado do catálogo de templates do Nuclei para revisar autenticação, injection, exposição de dados, configuração e outros riscos do projeto escolhido. A varredura é estática: não executa o projeto, não instala dependências e não faz requisições ao alvo. A revisão semântica usa a LLM privada da Cultura Builder; os arquivos são redigidos e enviados em blocos pequenos após o seu consentimento.": "Pest uses a checklist distilled from the Nuclei template catalog to review authentication, injection, data exposure, configuration and other risks in the chosen project. The scan is static: it does not run the project, install dependencies or request the target. Semantic review uses Cultura Builder's private LLM; files are redacted and sent in small chunks after your consent.",
        "O Red Teaming revisa o código do projeto escolhido em busca de falhas de autenticação, injection, exposição de dados e outras vulnerabilidades que não aparecem no lockfile. A análise usa uma LLM privada da Cultura Builder: os dados não são enviados para laboratórios de IA nem usados para treinamento. Pode levar vários minutos.": "Red Teaming reviews the chosen project's code for authentication flaws, injection, data exposure and other vulnerabilities that do not show in the lockfile. The analysis uses a private Cultura Builder LLM: data is not sent to AI labs or used for training. It can take several minutes.",
        "O Red Teaming usa a LLM privada da Cultura Builder e não altera seus arquivos.": "Red Teaming uses Cultura Builder's private LLM and does not change your files.",
        "O consentimento vale apenas para esta execução. Na próxima análise, o app pergunta de novo.": "Consent applies to this run only. On the next analysis, the app asks again.",
        "O código deste projeto será enviado para a LLM privada da Cultura Builder": "This project's code will be sent to Cultura Builder's private LLM",
        "O diagnóstico de dependências envia nomes, versões, vulnerabilidades e caminhos, sem código-fonte. Pest e Red Team só enviam código após sua autorização, com redaction de segredos. No modo RTX, o destino é o endpoint RTX.": "The dependency diagnosis sends names, versions, vulnerabilities and paths, with no source code. Pest and Red Team only send code after your authorization, with secret redaction. In RTX mode, the destination is the RTX endpoint.",
        "O diagnóstico de dependências recebe nomes, versões, vulnerabilidades e caminhos dos projetos, sem código-fonte. Pest e Red Team só enviam código e configuração após sua autorização, com redaction de segredos.": "The dependency diagnosis receives names, versions, vulnerabilities and project paths, with no source code. Pest and Red Team only send code and configuration after your authorization, with secret redaction.",
        "O endpoint já tem o acesso do túnel. Só mude se a Cultura Builder indicar outro.": "The endpoint already has tunnel access. Only change it if Cultura Builder points to another one.",
        "O padrão é inglês; o sistema em português já abre em português.": "The default is English; a Portuguese system already opens in Portuguese.",
        "O que acontece agora": "What happens now",
        "O que fazer": "What to do",
        "O que pode acontecer": "What can happen",
        "O que vai para a IA": "What goes to the AI",
        "Onde estão seus projetos?": "Where are your projects?",
        "Organizando as pastas monitoradas…": "Organizing monitored folders…",
        "Os achados salvos serão removidos deste Mac. A próxima análise começa do zero.": "Saved findings will be removed from this Mac. The next analysis starts from scratch.",
        "Pacotes afetados": "Affected packages",
        "Padrão": "Standard",
        "Para entrar ou trocar de conta, rode no terminal:": "To sign in or switch accounts, run in the terminal:",
        "Para uma análise confortável, deixe pelo menos 2 GB de memória livre e 500 MB de disco. O Pest pausa e salva o progresso se o Mac ficar abaixo do mínimo; você pode retomar depois.": "For a comfortable analysis, leave at least 2 GB of free memory and 500 MB of disk. Pest pauses and saves progress if the Mac drops below the minimum; you can resume later.",
        "Pastas de build, preview e artefatos aparecem marcadas para facilitar a revisão. As worktrees continuam sendo detectadas automaticamente.": "Build, preview and artifact folders appear flagged for easier review. Worktrees are still detected automatically.",
        "Permitir notificações": "Allow notifications",
        "Pest com IA": "Pest with AI",
        "Pest e Red Team rodam em blocos, com orçamento de memória e pausa automática. Se a análise pausar, retome quando o Mac estiver mais livre.": "Pest and Red Team run in chunks, with a memory budget and automatic pause. If the analysis pauses, resume when the Mac is freer.",
        "Pest pausou para proteger a memória": "Pest paused to protect memory",
        "Pest: análise estática guiada pelo catálogo Nuclei. Não executa o projeto nem faz requisições ao alvo.": "Pest: static analysis guided by the Nuclei catalog. Does not run the project or request the target.",
        "Pontos de atenção": "Points of attention",
        "Principais riscos": "Top risks",
        "Privacidade": "Privacy",
        "Procurando projetos e lockfiles…": "Looking for projects and lockfiles…",
        "Procurando projetos nas pastas monitoradas…": "Looking for projects in monitored folders…",
        "Procurando projetos…": "Looking for projects…",
        "Projeto": "Project",
        "Projetos afetados": "Affected projects",
        "Projetos do Pest": "Pest projects",
        "Projetos, riscos e correções em uma janela só.": "Projects, risks and fixes in one window.",
        "Prompt de correção": "Fix prompt",
        "Prompt geral": "General prompt",
        "Pronto para a primeira varredura": "Ready for the first scan",
        "Próximos passos": "Next steps",
        "RTX · sem censura": "RTX · uncensored",
        "Reativar pasta": "Reactivate folder",
        "Reativar selecionadas": "Reactivate selected",
        "Red Team pausou para proteger a memória": "Red Team paused to protect memory",
        "Red Teaming": "Red Teaming",
        "Red Teaming está desativado por enquanto": "Red Teaming is disabled for now",
        "Remover": "Remove",
        "Remover horário": "Remove time",
        "Remover pasta": "Remove folder",
        "Remover rotina": "Remove routine",
        "Resultados da última varredura": "Last scan results",
        "Retomar análise pausada": "Resume paused analysis",
        "Retomar configuração": "Resume setup",
        "Rever configuração": "Review setup",
        "Revisar": "Review",
        "Revisar pastas": "Review folders",
        "Revise o prompt antes de aplicar. Ele foi escrito para um agente de código e não faz commit sozinho.": "Review the prompt before applying. It is written for a coding agent and does not commit on its own.",
        "Revise, selecione várias e reative de uma vez.": "Review, select several and reactivate at once.",
        "Rodadas por dia": "Runs per day",
        "Rode este comando no terminal:": "Run this command in the terminal:",
        "Rotina ativa": "Routine active",
        "Rotina diária": "Daily routine",
        "Rotina não salva": "Routine not saved",
        "Rotinas configuradas": "Configured routines",
        "Sair do Builders Protect": "Quit Builders Protect",
        "Salvar alterações": "Save changes",
        "Se o Mac estiver dormindo": "If the Mac is asleep",
        "Se o Mac estiver dormindo no horário, a varredura acontece quando ele acordar. Ao abrir o app, o Builders Protect também recupera uma rotina perdida.": "If the Mac is asleep at the time, the scan happens when it wakes. On launch, Builders Protect also recovers a missed routine.",
        "Segurança de código, um projeto por vez": "Code security, one project at a time",
        "Seleciona artefatos que ainda entram na varredura": "Selects artifacts that still enter the scan",
        "Selecionar artefatos": "Select artifacts",
        "Selecionar ignoradas": "Select ignored",
        "Selecionar todas": "Select all",
        "Selecione um projeto para configurar a rotina.": "Select a project to configure the routine.",
        "Selecione uma ou várias pastas para ignorar. A escolha vale para a varredura, o Pest e o Red Teaming. Pastas de build, preview e artefatos costumam não ser projetos reais.": "Select one or more folders to ignore. The choice applies to the scan, Pest and Red Teaming. Build, preview and artifact folders are usually not real projects.",
        "Sem reiniciar": "No restart",
        "Sem rotina": "No routine",
        "Sem rotina para este projeto. O Pest também pode ser executado manualmente a qualquer momento.": "No routine for this project. Pest can also be run manually at any time.",
        "Somente arquivos de código e configuração do projeto escolhido são enviados, em blocos pequenos, para a LLM privada da Cultura Builder. Sem o consentimento, a análise não começa.": "Only code and configuration files from the chosen project are sent, in small chunks, to Cultura Builder's private LLM. Without consent, the analysis does not start.",
        "Somente os arquivos de texto do projeto escolhido são enviados para a LLM privada da Cultura Builder. .env, chaves, credenciais, binários, lockfiles, dependências instaladas e arquivos grandes são ignorados. Segredos reconhecíveis são redigidos antes do envio. No modo RTX, o destino é o endpoint RTX. A análise roda em blocos, pode pausar por memória e pode ser retomada.": "Only text files from the chosen project are sent to Cultura Builder's private LLM. .env, keys, credentials, binaries, lockfiles, installed dependencies and large files are skipped. Recognizable secrets are redacted before sending. In RTX mode, the destination is the RTX endpoint. The analysis runs in chunks, may pause for memory and can be resumed.",
        "Sua Wi-Fi, seu roteador e seus dados, sem alarmismo": "Your Wi-Fi, your router and your data, without alarmism",
        "Sugerir horário": "Suggest time",
        "Tentar de novo": "Try again",
        "Tente outro termo ou remova os filtros.": "Try another term or remove the filters.",
        "Todas as pastas encontradas entram na varredura. Use Gerenciar pastas para ver a lista completa, selecionar várias e ignorar builds, previews ou artefatos. O que você ignorar vale para a varredura, o Pest e o Red Teaming.": "Every folder found enters the scan. Use Manage folders to see the full list, select several and ignore builds, previews or artifacts. What you ignore applies to the scan, Pest and Red Teaming.",
        "Tudo pronto para começar.": "All set to start.",
        "Um caçador de brechas, não um scanner de rede": "A flaw hunter, not a network scanner",
        "Um radar de dependências para quem constrói.": "A dependency radar for people who build.",
        "Uma foto da rede, não uma prova de invasão": "A network snapshot, not proof of intrusion",
        "Uma notificação por varredura, sem repetir achados antigos.": "One notification per scan, without repeating old findings.",
        "Uma varredura por dia, sem lembrar de nada.": "One scan a day, with nothing to remember.",
        "Vai além das dependências": "Goes beyond dependencies",
        "Vamos configurar o Builders Protect": "Let's set up Builders Protect",
        "Verifica todos os projetos uma vez por dia.": "Checks every project once a day.",
        "Verificar agora": "Check now",
        "Você pode continuar sem login e entrar depois em Ajustes. Nesse caso, o diagnóstico da IA fica desligado.": "You can continue without signing in and do it later in Settings. In that case, AI diagnosis stays off.",
        "Você pode revisar tudo depois em Ajustes. O prompt de correção fica em cada alerta do painel.": "You can review everything later in Settings. The fix prompt sits in each panel alert.",
        "Voltar": "Back",
        "Vulnerabilidade": "Vulnerability",
        "Vulnerabilidades": "Vulnerabilities",
        "Vulnerabilidades confirmadas para as versões instaladas, com KEV e versão corrigida.": "Vulnerabilities confirmed for installed versions, with KEV and fixed version.",
        "Vulnerabilidades sob controle": "Vulnerabilities under control",
        "análise da Cultura Builder": "Cultura Builder analysis",
        "análise da IA": "AI analysis",
        "cole a chave RTX": "paste the RTX key",
        "com IA": "with AI",
        "hub.culturabuilder.com para vulnerabilidades e análise.": "hub.culturabuilder.com for vulnerabilities and analysis.",
        "hub.culturabuilder.com para vulnerabilidades e análise. Endpoint RTX opcional em IA e segurança.": "hub.culturabuilder.com for vulnerabilities and analysis. Optional RTX endpoint in AI and security.",
        "sem rotina": "no routine",
        "Última checagem": "Last check",
        "Último relatório": "Last report",
        "⌘ O": "⌘ O",
        "Red Team": "Red Team",
        "Pastas": "Folders",
        "Rotina": "Routine",
        "Geral": "General",
        "Sobre": "About",
        "Modo padrão com login no proxy ou modo RTX com chave dedicada.": "Standard mode with proxy sign-in or RTX mode with a dedicated key.",
        "Resultados da última varredura e o que corrigir primeiro.": "Last scan results and what to fix first.",
        "Análise de segurança do código, guiada pelo catálogo Nuclei.": "Code security analysis guided by the Nuclei catalog.",
        "Uma leitura local da sua Wi-Fi, do roteador e dos serviços visíveis.": "A local read of your Wi-Fi, router and visible services.",
        "Análise profunda de um projeto, com consentimento explícito.": "Deep analysis of one project, with explicit consent.",
        "Sua sessão da Cultura Builder libera o modo padrão da IA.": "Your Cultura Builder session unlocks the standard AI mode.",
        "Estas são as pastas que o Builders Protect varre em busca de lockfiles.": "These are the folders Builders Protect scans for lockfiles.",
        "Defina quando verificar e como o app avisa você.": "Set when to check and how the app warns you.",
        "Idioma e preferências gerais deste Mac.": "Language and general preferences for this Mac.",
        "Um app da Cultura Builder para acompanhar dependências.": "A Cultura Builder app to track dependencies.",
        "Boas-vindas": "Welcome",
        "Pronto": "Ready",
        "Começar a monitorar": "Start monitoring",
        "Continuar": "Continue",

        "agora": "just now",
        "Conta conectada": "Connected account",
        "Sessão não encontrada": "Session not found",
        "Sessão ativa": "Active session",
        "Sessão da Cultura Builder ativa": "Cultura Builder session active",
        "A verificação de vulnerabilidades continua, mas sem diagnóstico da IA.": "Vulnerability scanning continues, but without AI diagnosis.",
        "Renovando…": "Renewing…",
        "Já fiz login": "I signed in",
        "Verificando…": "Checking…",
        "Testando…": "Testing…",
        "Testar": "Test",
        "Testar conexão": "Test connection",
        "CHAVE OK": "KEY OK",
        "SEM CHAVE": "NO KEY",
        "Adicione ao menos uma pasta": "Add at least one folder",
        "O Mac precisa estar ligado no horário": "The Mac must be on at the scheduled time",
        "pastas": "folders",
        "rotina diária": "daily routine",
        "diagnóstico IA": "AI diagnosis",
        "ligado": "on",
        "desligado": "off",
        "projeto": "project",
        "projetos": "projects",
        "afetado": "affected",
        "afetados": "affected",
        "verificado": "checked",
        "verificados": "checked",
        "LIMPO": "CLEAN",
        "Verificando dependências": "Checking dependencies",
        "Verificando dependências agora": "Checking dependencies now",
        "Modo RTX ativo — modelo sem censura em todas as análises": "RTX mode active — uncensored model in every analysis",
        "IA conectada à Cultura Builder — análise inteligente ativa": "AI connected to Cultura Builder — smart analysis active",
        "Chave RTX ausente — configure em Ajustes > IA e segurança": "RTX key missing — set it in Settings > AI and security",
        "IA desconectada — entre na Cultura Builder em Ajustes para ativar a análise": "AI disconnected — sign in to Cultura Builder in Settings to enable analysis",
        "Crítica": "Critical",
        "Alta": "High",
        "Média": "Medium",
        "Baixa": "Low",
        "Indefinida": "Undefined",
        "Todos": "All",
        "Verificando": "Checking",
        "Resultado da análise": "Analysis result",
        "Tudo limpo": "All clear",
        "projetos afetados": "affected projects",
        "projetos verificados": "projects checked",
        "Projetos": "Projects",
        "Pacotes": "Packages",
        "Ignorar pasta?": "Ignore folder?",
        "Buscar projeto, pacote ou caminho": "Search project, package or path",
        "Buscar por nome ou caminho": "Search by name or path",
        "Remover da seleção": "Remove from selection",
        "Selecionar pasta": "Select folder",
        "artefato": "artifact",
        "pasta": "folder",
        "IGNORADA": "IGNORED",
        "MONITORADA": "MONITORED",
        "Nenhuma pasta encontrada.": "No folder found.",
        "Nenhuma pasta corresponde à busca.": "No folder matches the search.",
        "Ignorar pastas": "Ignore folders",
        "Sem achados": "No findings",
        "Sua Wi-Fi": "Your Wi-Fi",
        "SEM ACHADOS": "NO FINDINGS",
        "PONTO": "POINT",
        "PONTOS": "POINTS",
        "Roteador": "Router",
        "Dispositivos": "Devices",
        "Serviços expostos": "Exposed services",
        "ativa": "active",
        "não detectada": "not detected",
        "rede marcada como pública": "network marked as public",
        "rede tratada como confiável": "network treated as trusted",
        "Ocultar": "Hide",
        "Mostrar": "Show",
        "Proteção": "Protection",
        "Interface": "Interface",
        "Canal": "Channel",
        "Sinal": "Signal",
        "Interfaces VPN": "VPN interfaces",
        "Serviço exposto": "Exposed service",
        "Serviço local": "Local service",
        "não identificado": "not identified",
        "não identificada": "not identified",
        "não informado": "not provided",
        "Aberta, sem senha": "Open, no password",
        "WEP, proteção obsoleta": "WEP, obsolete protection",
        "WPA Pessoal, proteção antiga": "WPA Personal, older protection",
        "WPA2 Pessoal": "WPA2 Personal",
        "WPA/WPA2 misto": "WPA/WPA2 mixed",
        "WPA3 Pessoal": "WPA3 Personal",
        "WPA3 em transição": "WPA3 transition",
        "WPA2 Empresarial": "WPA2 Enterprise",
        "WPA3 Empresarial": "WPA3 Enterprise",
        "O que poderia acontecer": "What could happen",
        "Como se proteger": "How to protect yourself",
        "O que significa": "What it means",
        "No seu cenário": "In your scenario",
        "Chance": "Likelihood",
        "Como corrigir": "How to fix",
        "Confirmado agora": "Confirmed now",
        "Possível no seu cenário": "Possible in your scenario",
        "Não encontrado": "Not found",
        "Não foi possível verificar": "Could not verify",
        "Wi-Fi": "Wi-Fi",
        "Confiança": "Confidence",
        "Mac": "Mac",
        "Dados": "Data",
        "DNS": "DNS",
        "alta": "high",
        "media": "medium",
        "média": "medium",
        "baixa": "low",
        "este projeto": "this project",
        "Limpar todos os relatórios do Pest?": "Clear all Pest reports?",
        "Limpar este relatório do Pest?": "Clear this Pest report?",
        "Limpar todos": "Clear all",
        "Limpar relatório": "Clear report",
        "IA conectada": "AI connected",
        "IA desconectada": "AI disconnected",
        "rotina pausada": "routine paused",
        "Memória livre": "Free memory",
        "Disco livre": "Free disk",
        "Orçamento": "Budget",
        "indisponível": "unavailable",
        "feche apps pesados": "close heavy apps",
        "Cole a chave RTX para usar o Pest": "Paste the RTX key to use Pest",
        "Conecte a conta para usar o Pest": "Connect your account to use Pest",
        "Abrir IA e segurança": "Open AI and security",
        "Abrir Conta": "Open Account",
        "pausada": "paused",
        "sem próxima data": "no next date",
        "assim que possível": "as soon as possible",
        "O Pest pausou para proteger a memória do Mac.": "Pest paused to protect the Mac's memory.",
        "Retomar agora": "Resume now",
        "Nenhum achado nos blocos já analisados": "No findings in the chunks analyzed so far",
        "Nenhuma brecha confirmada": "No confirmed flaw",
        "Relatório parcial": "Partial report",
        "local": "local",
        "Rotina pausada": "Routine paused",
        "Agora não": "Not now",
        "Autorizar e retomar": "Authorize and resume",
        "Autorizar e analisar": "Authorize and analyze",
        "Analisar com IA": "Analyze with AI",
        "Retomar a análise com IA": "Resume the AI analysis",
        "Impacto": "Impact",
        "Selecionar projeto": "Select project",
        "Escolha um projeto da lista": "Choose a project from the list",
        "Cole a chave RTX para usar o Red Team": "Paste the RTX key to use Red Team",
        "Conecte a conta para usar o Red Teaming": "Connect your account to use Red Teaming",
        "A análise profunda depende da LLM da Cultura Builder.": "Deep analysis depends on Cultura Builder's LLM.",
        "Retome quando o Mac estiver mais livre.": "Resume when the Mac is freer.",
        "Nova análise do zero": "New analysis from scratch",
        "Iniciar análise profunda": "Start deep analysis",
        "Preparando": "Preparing",
        "Retomando": "Resuming",
        "Prompt geral copiado": "General prompt copied",
        "Pasta ignorada. Atualizando a análise…": "Folder ignored. Updating the analysis…",
        "Pasta monitorada novamente": "Folder monitored again",
        "Escolher pastas de projetos": "Choose project folders",
        "Monitorar": "Monitor",
        "Corrigir agora": "Fix now",
        "Priorizar": "Prioritize",
        "Planejar correção": "Plan the fix",
        "Acompanhar": "Monitor",

        "Descobrindo projetos": "Discovering projects",
        "Lendo as pastas monitoradas…": "Reading monitored folders…",
        "Concluído": "Done",
        "Lendo manifestos": "Reading manifests",
        "Cruzando com a base de vulnerabilidades": "Comparing with the vulnerability database",
        "Lendo lockfiles": "Reading lockfiles",
        "Buscando detalhes": "Fetching details",
        "Analisando com a Cultura Builder": "Analyzing with Cultura Builder",
        "Mapeando": "Mapping",
        "Analisando": "Analyzing",
        "Consultando IA": "Querying AI",
        "Aguardando memória": "Waiting for memory",
        "Consolidando": "Consolidating",
        "Lendo arquivos": "Reading files",
        "Pausado": "Paused",
        "Lendo Wi-Fi": "Reading Wi-Fi",
        "Verificando roteador": "Checking router",
        "Checando o Mac": "Checking the Mac",
        "Montando relatório": "Building report",
        "Transformando os sinais em explicações simples.": "Turning signals into simple explanations.",
        "Lendo firewall, FileVault, Gatekeeper e atualizações.": "Reading firewall, FileVault, Gatekeeper and updates.",
        "Consultando apenas o endereço do seu roteador, sem tentar senha.": "Querying only your router address, without trying passwords.",
        "Lendo a estrutura do projeto…": "Reading the project structure…",
        "Mapeando arquivos com orçamento de memória.": "Mapping files with a memory budget.",
        "O macOS não liberou o nome da rede Wi-Fi para o app.": "macOS did not release the Wi-Fi network name to the app.",
        "Endereço inválido.": "Invalid address.",
        "A pasta deste projeto não está mais monitorada.": "This project's folder is no longer monitored.",
        "Não encontrei um horário livre com 30 minutos de intervalo.": "I could not find a free time with a 30-minute gap.",
        "Atualizando a análise após ignorar uma pasta…": "Updating the analysis after ignoring a folder…",
        "A pasta do projeto não existe mais.": "The project folder no longer exists.",
        "Este projeto está ignorado em Ajustes > Pastas. Reative a pasta para analisar.": "This project is ignored in Settings > Folders. Reactivate the folder to analyze it.",
        "Nenhum arquivo de código legível foi encontrado neste projeto.": "No readable code file was found in this project.",
        "O modo RTX precisa de uma chave dedicada. Cole a chave em Ajustes > Análises.": "RTX mode needs a dedicated key. Paste the key in Settings > Analysis.",
        "O endpoint RTX configurado não é uma URL válida.": "The configured RTX endpoint is not a valid URL.",
        "Análise da rede cancelada.": "Network analysis canceled.",
        "Não encontrei uma conexão de rede ativa neste Mac.": "I could not find an active network connection on this Mac.",
        "Não encontrei uma sessão da Cultura Builder neste Mac.": "I could not find a Cultura Builder session on this Mac.",
        "A sessão da Cultura Builder está em um formato inesperado.": "The Cultura Builder session is in an unexpected format.",
        "Verifique sua conexão.": "Check your connection.",
        "Resposta inválida do servidor.": "Invalid server response.",
        "O servidor não devolveu um token válido.": "The server did not return a valid token.",
        "A análise parou antes do fim do orçamento de blocos.": "The analysis stopped before the chunk budget ended.",
        "O Red Teaming pausou para proteger a memória do Mac antes de concluir.": "Red Teaming paused to protect the Mac's memory before finishing.",
        "A análise não encontrou falhas de segurança no código enviado.": "The analysis found no security flaws in the sent code.",
        "Escolha um horário válido.": "Choose a valid time.",
        "Não consegui ler os detalhes do Wi-Fi.": "Could not read the Wi-Fi details.",
        "Não consegui identificar o endereço do roteador.": "Could not identify the router address.",
        "Não consegui listar os dispositivos conhecidos pelo Mac.": "Could not list the devices known to the Mac.",
        "Não consegui listar todos os serviços abertos no Mac.": "Could not list all open services on the Mac.",
        "Não consegui identificar os servidores DNS em uso.": "Could not identify the DNS servers in use.",
        "A consulta ao painel do roteador foi pulada porque o endereço não foi encontrado.": "The router panel query was skipped because the address was not found.",
        "A consulta ao painel do roteador foi pulada porque o endereço não é local.": "The router panel query was skipped because the address is not local.",
        "Conteúdo mascarado como [REDACTED] antes de sair do Mac.": "Content masked as [REDACTED] before leaving the Mac.",
        "O Mac está com pouca memória disponível.": "The Mac has little available memory.",
        "O disco está com pouco espaço livre.": "The disk has little free space.",
        "Gerando diagnóstico e plano de correção…": "Generating diagnosis and fix plan…",
        "Identificando a rede conectada, o roteador e o DNS.": "Identifying the connected network, router and DNS.",
        "Removendo duplicatas e ordenando os achados…": "Removing duplicates and sorting findings…",
    ]
}


extension BuilderAuthStatus {
    var localizedExpiryLabel: String? {
        guard let expiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expiresAt)
    }
}
