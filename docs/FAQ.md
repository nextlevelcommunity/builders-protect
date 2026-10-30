# Perguntas frequentes

## O Builders Protect é um instalador ou uma GitHub Action?

Os dois. O app macOS é distribuído como DMG. A CLI e a GitHub Action são para quem prefere rodar a varredura no terminal ou no CI, sem instalar interface gráfica.

## Preciso ser assinante da Cultura Builder?

Para a varredura de dependências, CLI, GitHub Action e Minha rede, não. Para o diagnóstico com IA, o Pest e o Red Teaming no app, sim.

## O que é enviado?

A varredura de dependências envia nomes, versões e o conteúdo dos lockfiles. Não envia código-fonte, `.env`, chaves ou credenciais.

O diagnóstico de dependências com IA envia os achados e metadados do projeto, não o código.

O Pest sempre usa a IA da Cultura Builder e só envia trechos de código e configuração do projeto escolhido depois de consentimento explícito na análise manual ou ao salvar uma rotina, em blocos pequenos e com segredos reconhecíveis mascarados. `.env`, chaves, binários, lockfiles e dependências instaladas ficam de fora.

Minha rede não envia dados para a Cultura Builder. Ela faz uma consulta local ao endereço do roteador e não captura tráfego.

O Red Teaming envia somente arquivos de texto elegíveis do projeto escolhido, em blocos, após consentimento explícito e com segredos reconhecíveis mascarados. `.env`, chaves, binários, lockfiles e dependências instaladas ficam de fora.

## O que é o Pest?

É uma revisão de segurança do código do projeto, guiada por um catálogo destilado de templates do Nuclei. A varredura de arquivos é estática: não executa o projeto, não instala dependências e não faz requisições ao alvo. Cada achado vem com explicação, recomendação e um prompt de correção. O Pest usa a IA da Cultura Builder em todas as análises e exige consentimento em um modal antes de cada análise manual; a autorização vale apenas para aquela análise. Ao salvar uma rotina, você autoriza a execução diária daquele projeto. Sem a conta conectada, a análise não começa. Na área do Pest, você escolhe os projetos que quer acompanhar e eles ficam listados com o horário da rotina, prontos para analisar ou configurar. As rotinas respeitam pelo menos 30 minutos entre si. Você também pode limpar o relatório do projeto atual ou todos os relatórios salvos.

## O que é Minha rede?

É uma checagem local da Wi-Fi, do roteador, dos dispositivos conhecidos e dos serviços do Mac visíveis na rede. Ela explica o que está confirmado, o que é possível e o que não pôde ser verificado. Não é um scanner de vulnerabilidades nem um teste de invasão: não captura tráfego, não testa senhas e não entra no painel do roteador.

## Minha rede consegue saber se alguém invadiu meu Wi-Fi?

Não. Ela tira uma foto das configurações e dos serviços visíveis naquele momento. Pode mostrar uma exposição, como uma rede aberta ou um serviço escutando para a rede, mas não prova que alguém entrou, interceptou tráfego ou capturou uma senha. Para investigação de incidente, é necessário um trabalho específico de resposta a incidentes.

## O Red Teaming já está disponível?

Está disponível. É opt-in por projeto, com consentimento salvo, análise em blocos com pausa por memória e retomada. Você pode acionar pelo Pest ou pelo alerta do projeto e agendar várias rodadas por dia, com pelo menos 20 minutos entre elas.

## Por que GitHub em vez de um instalador padrão?

Porque o público principal são desenvolvedores. A GitHub Action entra no fluxo de PR e cron sem instalação local. O app macOS continua disponível para quem quer a interface, o agendamento local e os recursos de IA.

## Funciona no Windows e no Linux?

A CLI e a GitHub Action funcionam nos três sistemas. A interface desktop para Windows e Linux está no roadmap.

## Qual a diferença entre o app e a Action?

| App | Action |
| --- | --- |
| Interface, agendamento local, notificações | Execução em PR, push ou cron |
| Pest, Minha rede, diagnóstico com IA | Varredura de dependências |
| Red Teaming | SARIF e resumo no job |
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

## O app varre worktrees do Git?

Não por padrão. Ao adicionar uma pasta, as worktrees são detectadas, a varredura usa a pasta principal do repositório e as worktrees ficam pré-ignoradas. Em **Ajustes > Pastas > Gerenciar pastas**, selecione uma ou várias pastas e use **Reativar selecionadas** para incluí-las novamente. A mesma tela mostra todos os projetos encontrados, marca pastas de build, preview e artefatos e permite ignorar várias de uma vez. A lista de pastas ignoradas é global: vale para a varredura de dependências, o Pest e o Red Teaming. A CLI e a Action também usam a pasta principal e ignoram worktrees automaticamente.

## Por que o macOS bloqueou a primeira abertura?

O build público atual não é notarizado pela Apple. Use **Abrir** pelo menu de contexto do Finder. Builds assinados e notarizados estão no roadmap.

## O código é open source?

O código é disponibilizado publicamente para uso e auditoria, sujeito à [licença de uso](../LICENSE). Isso não concede direitos sobre marcas, serviços ou modelos da Cultura Builder.

## Como reporto uma vulnerabilidade?

Use **Security > Report a vulnerability** no repositório. Não abra issue pública com detalhes exploráveis. Veja [SECURITY.md](../SECURITY.md).
