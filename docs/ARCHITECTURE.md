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
- `CVECore` para descoberta, parsing, varredura, prompts e integração com IA.
- Agendamento local e item de login do usuário.
- Red Teaming em preparação, desativado nesta versão.
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

### IA

O diagnóstico e o Red Teaming usam os modelos de segurança da Cultura Builder. O acesso exige sessão de assinante. A CLI e a Action não usam IA.

## Fluxo de varredura

1. A raiz é resolvida e as exclusões são normalizadas. Se a pasta escolhida for uma worktree do Git, a varredura usa a pasta principal do repositório.
2. O diretório é percorrido com limite de profundidade e projetos.
3. Worktrees registradas ou aninhadas são ignoradas automaticamente. No app, elas ficam visíveis em Ajustes > Pastas e podem ser reativadas.
4. Diretórios pesados, como `node_modules`, `.git`, `dist` e `target`, são ignorados.
5. Cada projeto com lockfile é registrado.
6. Cada lockfile é lido, limitado a 1,8 MB e verificado contra binários.
7. O conteúdo é enviado para a base de vulnerabilidades.
8. Os achados são normalizados, deduplicados e ordenados por severidade.
9. O relatório é gerado em Markdown, JSON e/ou SARIF.

## Estrutura do repositório

```text
Sources/
  CVECore/          núcleo do app macOS
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

### Red Teaming separado

O Red Teaming é uma análise de código, não de dependências. Ele tem fluxo, consentimento e modelos próprios. Por isso não é executado pela CLI nem pela Action e permanece em preparação nesta versão.

### Windows e Linux

O modo suportado fora do macOS é CLI/Action. Uma interface desktop para Windows e Linux depende de uma reescrita da camada de UI e está no roadmap.

## Distribuição

- App macOS: GitHub Releases com DMG.
- CLI: execução via `npx` a partir do GitHub ou instalação global.
- Action: tag `v1` e releases versionadas.
- Builds futuros: assinatura e notarização do app macOS; checksums nos releases.
