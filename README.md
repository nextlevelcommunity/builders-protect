# Builders Protect

[![CI](https://github.com/nextlevelcommunity/builders-protect/actions/workflows/ci.yml/badge.svg)](https://github.com/nextlevelcommunity/builders-protect/actions/workflows/ci.yml)

Segurança contínua para projetos da **Cultura Builder Community**.

O Builders Protect encontra vulnerabilidades conhecidas nas dependências de um projeto, revisa o código com o Pest, explica os riscos da rede local e gera um relatório pronto para o desenvolvedor ou para um agente de código. Ele pode rodar como app no macOS, como CLI ou como GitHub Action.

## O que ele faz

- Lê lockfiles de npm, pnpm, Yarn, Bun, pip, Poetry, Cargo, Go, RubyGems, Hex e Nix.
- Cruza os pacotes com uma base de vulnerabilidades operada e validada pela equipe da Cultura Builder.
- Gera resumo em Markdown, relatório JSON e SARIF 2.1.0.
- Pode falhar o job quando encontra achados acima do limite configurado.
- Pode rodar em rotinas diárias, semanais ou mensais no GitHub Actions.
- Detecta worktrees do Git e usa a pasta principal do repositório; no app, Gerenciar pastas lista todos os projetos encontrados, marca build, preview e artefatos e permite ignorar ou reativar várias pastas de uma vez. O que for ignorado vale para todas as análises, inclusive Pest e Red Teaming.
- No app, o Pest revisa o código do projeto com um catálogo destilado de templates do Nuclei, mantém uma lista de projetos escolhidos e permite analisar ou configurar a rotina de cada um sem procurar a pasta novamente.
- A seção Minha rede faz uma leitura local da Wi-Fi, do roteador, dos dispositivos conhecidos e dos serviços do Mac visíveis na rede.
- No app, pode gerar diagnóstico com IA e prompts de correção para agentes.

## Pest e Minha rede

O **Pest** é uma revisão de segurança do código, não um scanner de rede. Ele usa um checklist destilado do catálogo de templates do Nuclei para procurar problemas de autenticação, injection, exposição de dados e configuração. A varredura de arquivos é estática: não executa o projeto, não instala dependências e não faz requisições ao alvo. O Pest usa a IA da Cultura Builder em todas as análises, com consentimento pedido em um modal antes de cada análise manual; a autorização vale apenas para aquela análise e volta a ser solicitada na próxima. Ao salvar uma rotina, você autoriza a execução diária daquele projeto. Na área do Pest, escolha os projetos que quer acompanhar; eles ficam listados com o horário da rotina, e cada um pode ser analisado ou configurado diretamente na linha. As rotinas continuam respeitando pelo menos 30 minutos entre si e só rodam com a conta conectada. Você pode limpar o relatório do projeto atual ou todos os relatórios salvos na própria área do Pest, com confirmação.

A seção **Minha rede** é uma leitura local e passiva da conexão. Ela consulta o endereço do roteador, lê a segurança do Wi-Fi, lista dispositivos conhecidos e verifica serviços do Mac escutando na rede. O relatório explica o que está confirmado agora, o que é possível no seu cenário e o que não foi possível verificar. Ele não prova que alguém invadiu a rede. No topo do relatório, um prompt geral reúne todas as correções em um plano único; cada achado também tem seu próprio prompt.

## Como funciona

| Camada | O que faz | Onde roda |
| --- | --- | --- |
| App | Interface, agendamento local, Pest, Minha rede, diagnóstico com IA e Red Teaming | macOS 13+ |
| CLI | Varredura de dependências e relatórios | macOS, Linux e Windows |
| GitHub Action | Varredura em PR, push ou cron, com resumo e SARIF | Runners do GitHub |

A base de vulnerabilidades e os modelos de segurança são operados e validados pela equipe da Cultura Builder. Fornecedores e detalhes internos de infraestrutura não fazem parte desta documentação pública.

## Quem pode usar

| Recurso | Acesso |
| --- | --- |
| Varredura de dependências, CLI e GitHub Action | Cultura Builder Community |
| Minha rede | Cultura Builder Community |
| Diagnóstico com IA e Pest no app | Assinantes ativos da Cultura Builder |
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

### App macOS a partir do fork

O app é instalado a partir do código-fonte, na sua máquina:

1. Faça um fork de [nextlevelcommunity/builders-protect](https://github.com/nextlevelcommunity/builders-protect).
2. Clone o seu fork e entre na pasta.
3. Rode `make install`.

```bash
git clone https://github.com/<seu-usuario>/builders-protect.git
cd builders-protect
make install
```

O `make install` compila o app, assina localmente em modo ad-hoc e copia para `~/Applications/Builders Protect.app`. Requisitos: macOS 13+, Swift 5.10+ e Xcode Command Line Tools. Para gerar um DMG, use `make dmg`.

O app fica disponível no Dock, no Launchpad e no **⌘+Tab**. O ícone na barra de menus abre o painel rápido; o banner **Controle total** abre a janela principal.

O build local não é notarizado pela Apple. Se o macOS bloquear a primeira abertura, use **Abrir** pelo menu de contexto do Finder. Veja [docs/INSTALL.md](docs/INSTALL.md).

Também é possível baixar um build pronto em [Releases](https://github.com/nextlevelcommunity/builders-protect/releases).

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
- O Pest não altera seus arquivos. Com a conta conectada e consentimento explícito em cada análise, ele envia trechos de código e configuração do projeto escolhido, em blocos pequenos e com segredos reconhecíveis mascarados.
- Minha rede é uma checagem local: não envia dados da rede, não captura tráfego, não testa senhas e não entra no painel do roteador.
- O diagnóstico de dependências com IA usa os achados e metadados do projeto; não envia código-fonte.
- O Red Teaming, quando liberado, será opt-in por projeto, com modelos privados dedicados à segurança e guardrails específicos. Os arquivos selecionados não são enviados para laboratórios de IA nem usados para treinamento.
- Credenciais de assinante ficam no armazenamento local da Cultura Builder e não entram nos relatórios.
- O repositório público não contém chaves de API, tokens ou credenciais. O código usa apenas endpoints públicos e a sessão local para recursos de assinante.
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
