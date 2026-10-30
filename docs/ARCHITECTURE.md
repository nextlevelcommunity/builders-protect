# Arquitetura

## Visão geral

O Builders Protect tem três camadas que compartilham o mesmo conceito de varredura:

```text
Projeto local
  ├── manifests e lockfiles
  ├── app macOS (SwiftUI/AppKit)
  ├── CLI (Node.js)
  └── GitHub Action (Node.js)
          │
          ▼
  Base de vulnerabilidades validada pela Cultura Builder
          │
          ├── relatório JSON
          ├── resumo Markdown
          └── SARIF 2.1.0
```

O app e a CLI não compartilham código binário. Eles compartilham o contrato de dados: descoberta de lockfiles, consulta, normalização de achados e formato de relatório.

## Componentes

### App macOS

- SwiftUI para interface.
- AppKit para menu bar, janelas, notificações e ciclo de vida.
- App regular no macOS: Dock, Launchpad e ⌘+Tab, além do ícone na barra de menus.
- Painel rápido (popover) com banner de controle total e janela principal separada.
- Item de login em segundo plano, sem abrir o painel ao iniciar com o Mac.
- `CVECore` para descoberta, parsing, varredura, Pest, Minha rede, prompts e integração com IA.
- Agendamento local e item de login do usuário.
- Pest com análise estática local, orçamento de memória, rotinas por projeto e LLM opcional.
- Minha rede com coleta local passiva de Wi-Fi/LAN e relatório em linguagem leiga.
- Red Teaming ativo por projeto, com consentimento salvo, análise em blocos, orçamento de memória, pausa, retomada e várias rodadas por dia.
- Dois modos de IA: gateway padrão com sessão do proxy e endpoint RTX com chave dedicada e modelo sem censura.
- Idioma da interface em inglês (padrão), português ou automático pelo sistema.
- No Windows e no Linux, o app desktop seguirá o mesmo fluxo: atalho no menu de aplicativos, ícone de bandeja, painel rápido e janela principal.

### CLI e Action

- Node.js 20+, sem dependências de runtime.
- Descoberta de projetos com `fs` e `path`.
- Leitura de lockfiles com limite de tamanho e proteção contra binários.
- Consulta JSON-RPC com suporte a JSON e Server-Sent Events.
- Relatórios em Markdown, JSON e SARIF.
- A Action usa o runtime `node20` do GitHub e não precisa de build.

### Base de vulnerabilidades

A base é operada e validada pela Cultura Builder. A integração é tratada como um serviço externo. Fornecedores, topologia e controles internos não são documentados publicamente.

### Pest

O Pest compartilha o scanner de projetos, mas tem pipeline próprio:

1. O projeto escolhido é inventariado com limites de arquivos, bytes e profundidade.
2. Arquivos de texto são lidos just-in-time; `.env`, chaves, binários, lockfiles, dependências instaladas e arquivos grandes ficam de fora.
3. O catálogo `PestKnowledge.json` seleciona checks por stack, extensão e sinais do projeto.
4. O analisador estático procura padrões de risco e gera achados determinísticos.
5. Com a conta conectada e consentimento na análise manual ou autorização ao salvar a rotina, blocos redigidos são enviados à LLM privada; caminhos retornados são validados contra os arquivos permitidos.
6. Cada achado recebe explicação, recomendação e prompt de correção.
7. O orçamento de memória pode pausar a análise e salvar um estado retomável.

As rotinas do Pest são locais, uma por projeto, com intervalo circular mínimo de 30 minutos. O scheduler não inicia uma rotina se a anterior ainda estiver rodando nem quando a conta está desconectada.

### Minha rede

Minha rede é uma pipeline local e passiva:

1. Comandos do macOS leem Wi-Fi, rota padrão, DNS, interfaces, ARP, firewall, FileVault, SIP, Gatekeeper, atualizações e portas TCP escutando.
2. A presença de VPN/Tailscale é detectada para evitar falsos positivos de DNS.
3. O endereço local do roteador é consultado por HTTP e HTTPS, sem autenticação, sem teste de senha e sem captura de tráfego.
4. O auditor transforma os sinais em achados e em cenários com status confirmado, possível, não encontrado ou não verificável.
5. O relatório inclui o que a checagem não prova e limita a conclusão a uma foto do momento.

### Red Teaming

O Red Team tem pipeline próprio:

1. O projeto é inventariado sem ler conteúdo, só com limites de arquivos, bytes e profundidade.
2. A lista de arquivos é dividida em blocos por orçamento de bytes.
3. Cada bloco é lido do disco just-in-time, redigido e enviado à LLM; o conteúdo do bloco é liberado antes do próximo.
4. O orçamento de memória cai junto com a memória livre e pode pausar a análise, salvando um estado retomável.
5. O scheduler aceita vários horários por dia por projeto, com intervalo mínimo de 20 minutos.

### IA

O diagnóstico de dependências com IA, o Pest e o Red Teaming usam um dos dois modos configurados em Ajustes > IA e segurança: o gateway da Cultura Builder com sessão de assinante (`builder-auto`) ou o endpoint RTX com chave dedicada e modelo sem censura. O modo RTX não depende da sessão do proxy. A CLI e a Action não usam IA. Minha rede não usa IA.

## Fluxo de varredura

1. A raiz é resolvida e as exclusões são normalizadas. Se a pasta escolhida for uma worktree do Git, a varredura usa a pasta principal do repositório.
2. O diretório é percorrido com limite de profundidade e projetos.
3. Worktrees registradas ou aninhadas são ignoradas automaticamente. No app, **Gerenciar pastas** lista os projetos encontrados, marca build, preview e artefatos e permite ignorar ou reativar várias pastas em lote.
4. Diretórios pesados, como `node_modules`, `.git`, `dist` e `target`, são ignorados.
5. Cada projeto com lockfile é registrado.
6. Cada lockfile é lido, limitado a 1,8 MB e verificado contra binários.
7. O conteúdo é enviado para a base de vulnerabilidades.
8. Os achados são normalizados, deduplicados e ordenados por severidade.
9. O relatório é gerado em Markdown, JSON e/ou SARIF.

## Estrutura do repositório

```text
Sources/
  CVECore/          núcleo do app macOS (inclui AnalysisMode, RedTeamRoutine e Localization)
  CVEBuilder/       interface SwiftUI/AppKit
bin/
  builders-protect.js
lib/
  discovery.js      descoberta de projetos e lockfiles
  cve.js            cliente da base de vulnerabilidades
  scan.js           orquestração da varredura
  report.js         Markdown, JSON e SARIF
  severity.js       classificação e limites
action/
  index.js          entrada da GitHub Action
action.yml
docs/
examples/
test/
.github/workflows/
```

## Decisões

### Node.js na CLI e na Action

Node.js 20 está disponível em todos os runners do GitHub e não exige compilação. A implementação usa apenas módulos nativos, reduzindo a superfície de supply chain.

### Conteúdo bruto do lockfile

A CLI envia o conteúdo do lockfile em vez de reimplementar todos os parsers. Isso reduz divergências entre ecossistemas e mantém a CLI pequena. O limite de 1,8 MB e a checagem de binários evitam arquivos inadequados.

### Pest e Red Teaming separados

O Pest é uma revisão estática de código, com catálogo local e LLM. O Red Team é uma análise mais profunda, com fluxo, consentimento, orçamento de memória e modelos próprios. Nenhum dos dois é executado pela CLI nem pela Action; ambos ficam no app macOS.

### Minha rede sem varredura ativa

Minha rede não substitui um scanner de rede. As consultas são limitadas ao próprio Mac e ao endereço do roteador. Não há descoberta agressiva, captura de pacotes, teste de credenciais ou exploração. Essa escolha mantém a funcionalidade útil para explicação e prevenção sem transformar o app em uma ferramenta de ataque.

### Windows e Linux

O modo suportado fora do macOS é CLI/Action. Uma interface desktop para Windows e Linux depende de uma reescrita da camada de UI e está no roadmap.

## Distribuição

- App macOS: GitHub Releases com DMG.
- CLI: execução via `npx` a partir do GitHub ou instalação global.
- Action: tag `v1` e releases versionadas.
- Builds futuros: assinatura e notarização do app macOS; checksums nos releases.
