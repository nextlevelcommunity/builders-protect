# Builders Protect

[![CI](https://github.com/nextlevelcommunity/builders-protect/actions/workflows/ci.yml/badge.svg)](https://github.com/nextlevelcommunity/builders-protect/actions/workflows/ci.yml)

Segurança contínua para projetos da **Cultura Builder Community**.

O Builders Protect encontra vulnerabilidades conhecidas nas dependências de um projeto, prioriza o que deve ser corrigido primeiro e gera um relatório pronto para o desenvolvedor ou para um agente de código. Ele pode rodar como app no macOS, como CLI ou como GitHub Action.

## O que ele faz

- Lê lockfiles de npm, pnpm, Yarn, Bun, pip, Poetry, Cargo, Go, RubyGems, Hex e Nix.
- Cruza os pacotes com uma base de vulnerabilidades operada e validada pela equipe da Cultura Builder.
- Gera resumo em Markdown, relatório JSON e SARIF 2.1.0.
- Pode falhar o job quando encontra achados acima do limite configurado.
- Pode rodar em rotinas diárias, semanais ou mensais no GitHub Actions.
- No app, pode gerar diagnóstico com IA e prompts de correção para agentes.

## Como funciona

| Camada | O que faz | Onde roda |
| --- | --- | --- |
| App | Interface, agendamento local, diagnóstico com IA e Red Teaming | macOS 13+ |
| CLI | Varredura de dependências e relatórios | macOS, Linux e Windows |
| GitHub Action | Varredura em PR, push ou cron, com resumo e SARIF | Runners do GitHub |

A base de vulnerabilidades e os modelos de segurança são operados e validados pela equipe da Cultura Builder. Fornecedores e detalhes internos de infraestrutura não fazem parte desta documentação pública.

## Quem pode usar

| Recurso | Acesso |
| --- | --- |
| Varredura de dependências, CLI e GitHub Action | Cultura Builder Community |
| Diagnóstico com IA no app | Assinantes ativos da Cultura Builder |
| Red Teaming | Assinantes ativos, opt-in por projeto; em preparação |

A CLI e a GitHub Action não usam IA nem Red Teaming. Elas não exigem assinatura para a varredura de dependências.

## Instalação rápida

### GitHub Action

Adicione um workflow ao repositório:

```yaml
name: Builders Protect
on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: '0 9 * * 1'
permissions:
  contents: read
  security-events: write
jobs:
  protect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nextlevelcommunity/builders-protect@v1
        with:
          path: .
          fail-on: high
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: builders-protect.sarif
```

Veja [docs/ACTION.md](docs/ACTION.md) para entradas, saídas, cron e permissões.

### App macOS

1. Baixe o `.dmg` mais recente em [Releases](https://github.com/nextlevelcommunity/builders-protect/releases).
2. Abra o DMG e arraste o Builders Protect para Aplicativos.
3. Na primeira abertura, escolha as pastas que deseja monitorar.

O build público atual não é notarizado pela Apple. Se o macOS bloquear a primeira abertura, use **Abrir** pelo menu de contexto do Finder. Veja [docs/INSTALL.md](docs/INSTALL.md).

### CLI

Requer Node.js 20 ou superior.

```bash
npx --yes --package github:nextlevelcommunity/builders-protect builders-protect scan --path .
```

Ou, com o repositório clonado:

```bash
node bin/builders-protect.js scan --path . --fail-on high
```

Saídas disponíveis:

```bash
builders-protect scan --path . --format markdown
builders-protect scan --path . --format json --output report.json
builders-protect scan --path . --sarif builders-protect.sarif
```

## Rotinas

O GitHub Actions aceita cron. Exemplos:

```yaml
on:
  schedule:
    - cron: '0 9 * * *'    # diário, 09:00 UTC
    - cron: '0 9 * * 1'    # semanal, segunda-feira
    - cron: '0 9 1 * *'    # mensal, dia 1
  workflow_dispatch:
```

O app macOS tem agendamento local próprio e notificações. Veja [docs/ACTION.md](docs/ACTION.md) e [docs/INSTALL.md](docs/INSTALL.md).

## Privacidade e segurança

- A varredura de dependências envia nomes, versões e o conteúdo dos lockfiles. Não envia código-fonte.
- O diagnóstico com IA usa os achados e metadados do projeto; não envia código-fonte.
- O Red Teaming, quando liberado, será opt-in por projeto, com modelos privados dedicados à segurança e guardrails específicos. Os arquivos selecionados não são enviados para laboratórios de IA nem usados para treinamento.
- Credenciais de assinante ficam no armazenamento local da Cultura Builder e não entram nos relatórios.
- A Action não precisa de token de IA e não escreve no repositório.

Leia [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md) antes de usar em repositórios privados.

## O que está em preparação

- Red Teaming no app, após a estabilização do consumo de recursos.
- Interface desktop para Windows e Linux. Nesta versão, o modo suportado fora do macOS é CLI/GitHub Action.
- Build macOS assinado e notarizado.

## Documentação

- [Instalação](docs/INSTALL.md)
- [GitHub Action](docs/ACTION.md)
- [Modelo de segurança](docs/SECURITY-MODEL.md)
- [Arquitetura](docs/ARCHITECTURE.md)
- [Perguntas frequentes](docs/FAQ.md)
- [Roadmap](docs/ROADMAP.md)

## Desenvolvimento

```bash
npm test
swift test
swift build
./scripts/build-app.sh release
```

Requisitos: Node.js 20+ para CLI/Action e Swift 5.10+ para o app macOS.

## Licença e suporte

O código é disponibilizado para uso e auditoria, sujeito à [licença de uso](LICENSE). Marcas e serviços da Cultura Builder têm termos próprios.

Para vulnerabilidades, use um Security Advisory privado. Para dúvidas de uso, abra uma issue sem dados sensíveis.
