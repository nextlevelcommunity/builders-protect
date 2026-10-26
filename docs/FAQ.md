# Perguntas frequentes

## O Builders Protect é um instalador ou uma GitHub Action?

Os dois. O app macOS é distribuído como DMG. A CLI e a GitHub Action são para quem prefere rodar a varredura no terminal ou no CI, sem instalar interface gráfica.

## Preciso ser assinante da Cultura Builder?

Para a varredura de dependências, CLI e GitHub Action, não. Para o diagnóstico com IA e o Red Teaming no app, sim.

## O que é enviado?

A varredura de dependências envia nomes, versões e o conteúdo dos lockfiles. Não envia código-fonte, `.env`, chaves ou credenciais.

O diagnóstico com IA envia os achados e metadados do projeto, não o código.

O Red Teaming, quando liberado, enviará somente os arquivos selecionados após consentimento explícito.

## O Red Teaming já está disponível?

Está em preparação. Quando for liberado, será opt-in por projeto, exclusivo para assinantes ativos, com modelos privados dedicados à segurança e guardrails específicos. Os dados não serão enviados para laboratórios de IA nem usados para treinamento.

## Por que GitHub em vez de um instalador padrão?

Porque o público principal são desenvolvedores. A GitHub Action entra no fluxo de PR e cron sem instalação local. O app macOS continua disponível para quem quer a interface, o agendamento local e os recursos de IA.

## Funciona no Windows e no Linux?

A CLI e a GitHub Action funcionam nos três sistemas. A interface desktop para Windows e Linux está no roadmap.

## Qual a diferença entre o app e a Action?

| App | Action |
| --- | --- |
| Interface, agendamento local, notificações | Execução em PR, push ou cron |
| Diagnóstico com IA para assinantes | Varredura de dependências |
| Red Teaming em preparação | SARIF e resumo no job |
| macOS | Linux, Windows e macOS |

## A Action altera meu repositório?

Não. Ela lê os lockfiles, escreve `builders-protect.sarif` e `builders-protect.json` no workspace e publica o resumo do job. Não faz commit, não abre PR e não corrige dependências.

## A Action precisa de token?

Para a varredura, não. Para enviar o SARIF ao Code Scanning, o workflow precisa de `security-events: write` e das permissões do GitHub.

## O que é KEV?

KEV indica vulnerabilidade com exploração ativa conhecida. O Builders Protect trata KEV como prioridade máxima.

## O Builders Protect corrige automaticamente?

Não. Ele identifica, prioriza e gera relatórios e prompts. A correção é feita pelo desenvolvedor ou por um agente de código, com revisão e testes.

## Com que frequência devo rodar?

Depende do projeto. Uma configuração comum:

- diária para projetos em produção;
- semanal para projetos internos;
- mensal para arquivos e projetos de baixa criticidade;
- em todo pull request que altere manifests ou lockfiles.

## O app macOS pediu permissão para acessar minhas pastas. É seguro?

Sim. O app só lê as pastas que você autorizar. O acesso é usado para encontrar manifests e lockfiles. Você pode remover a autorização a qualquer momento.

## Por que o macOS bloqueou a primeira abertura?

O build público atual não é notarizado pela Apple. Use **Abrir** pelo menu de contexto do Finder. Builds assinados e notarizados estão no roadmap.

## O código é open source?

O código é disponibilizado publicamente para uso e auditoria, sujeito à [licença de uso](../LICENSE). Isso não concede direitos sobre marcas, serviços ou modelos da Cultura Builder.

## Como reporto uma vulnerabilidade?

Use **Security > Report a vulnerability** no repositório. Não abra issue pública com detalhes exploráveis. Veja [SECURITY.md](../SECURITY.md).
