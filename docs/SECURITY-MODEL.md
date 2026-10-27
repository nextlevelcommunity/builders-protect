# Modelo de segurança

Este documento descreve o que o Builders Protect lê, envia e produz. Ele vale para o app macOS, a CLI e a GitHub Action.

## Princípios

- A varredura de dependências não envia código-fonte.
- O Pest local não envia dados para fora do Mac. O Pest com IA é opt-in por análise e envia somente trechos de código e configuração do projeto escolhido, depois de redaction.
- Minha rede é local e passiva: não envia dados para a Cultura Builder, não captura tráfego, não testa senhas e não entra no painel do roteador.
- O Red Teaming é opt-in, por projeto, e será exclusivo para assinantes ativos.
- Nenhum segredo é incluído nos relatórios.
- A Action não escreve no repositório e não precisa de token de IA.

## Dados por recurso

| Recurso | Lê | Envia | Não envia |
| --- | --- | --- | --- |
| Varredura de dependências | Manifests e lockfiles das pastas autorizadas | Nome e conteúdo do lockfile, nomes e versões de pacotes | Código-fonte, `.env`, chaves, credenciais |
| Diagnóstico de dependências com IA | Achados e metadados do projeto | Achados, nomes de pacotes, versões, caminhos e ecossistemas | Código-fonte, segredos |
| Pest local | Código e configuração de texto do projeto escolhido | Nada | Conteúdo do projeto, segredos, binários |
| Pest com IA | Código e configuração de texto do projeto escolhido | Blocos pequenos de texto, após consentimento e redaction | `.env`, chaves, credenciais reconhecíveis, binários, lockfiles, dependências instaladas, arquivos grandes |
| Minha rede | Configurações de rede do macOS, tabela ARP, DNS, serviços escutando e estado do firewall/FileVault | Nada para a Cultura Builder; uma consulta GET ao endereço local do roteador | Tráfego, senhas, conteúdo de navegação, dados de outros aparelhos |
| Red Teaming | Arquivos selecionados do projeto | Somente arquivos selecionados, após consentimento | Credenciais, arquivos ignorados, arquivos fora do projeto |
| GitHub Action | Workspace do repositório | Lockfiles para a base de vulnerabilidades | Código-fonte, segredos, tokens do GitHub |

Lockfiles podem conter nomes de pacotes internos e URLs de registries privados. Trate o relatório e os artefatos gerados como informação interna. O Pest com IA também pode receber trechos de código; use o consentimento por análise e revise o escopo antes de autorizar.

## Base de vulnerabilidades

A base é operada e validada pela equipe da Cultura Builder. A documentação pública não detalha fornecedores, topologia ou controles internos de infraestrutura.

A consulta usa apenas os dados necessários para identificar vulnerabilidades conhecidas nos pacotes instalados. Ela não executa o projeto, não instala dependências e não lê arquivos de código.

## IA e assinatura

O diagnóstico de dependências com IA, o Pest com IA e o Red Teaming usam os modelos de segurança da Cultura Builder. O acesso é restrito a assinantes ativos.

No Pest, a IA é opcional. A análise local continua disponível sem conta. Quando a IA está conectada, o app pede consentimento antes de enviar blocos de texto; `.env`, chaves, credenciais reconhecíveis, binários, lockfiles, dependências instaladas e arquivos grandes são ignorados ou mascarados. O parser valida os caminhos retornados pela LLM contra os arquivos permitidos.

Quando o Red Teaming for liberado:

- a ativação será manual e por projeto;
- o app mostrará o escopo antes de enviar qualquer arquivo;
- somente arquivos selecionados serão enviados;
- os modelos serão privados e dedicados à segurança, com guardrails específicos;
- os dados não serão enviados para laboratórios de IA nem usados para treinamento;
- o consentimento poderá ser revogado antes de cada análise.

O Red Teaming está em preparação nesta versão e não é executado pela CLI nem pela Action.

## Rede local

Minha rede não é um scanner de vulnerabilidades nem um teste de invasão. Ela usa comandos do macOS para ler configurações, lista a tabela ARP e os serviços TCP escutando e consulta apenas o endereço local do roteador por HTTP e HTTPS. Não há captura de pacotes, brute force, teste de senha, exploração ou acesso autenticado ao painel.

O resultado pode indicar exposição, como uma rede aberta ou um serviço escutando em `0.0.0.0`, mas não confirma que alguém entrou, interceptou tráfego ou capturou uma senha. A lista de dispositivos é parcial.

## Credenciais

No app, a sessão da Cultura Builder é lida do armazenamento local usado pelo produto. Tokens não são gravados em relatórios, prompts, logs de CI ou artefatos.

O repositório público não contém chaves de API, tokens ou credenciais. Endpoints públicos ficam no código; qualquer credencial de assinante permanece no armazenamento local da máquina.

A CLI e a Action não usam a sessão de assinante. Elas não precisam de token de IA para a varredura de dependências.

## GitHub Actions

- Use permissões mínimas: `contents: read` e, apenas para SARIF, `security-events: write`.
- Fixe a Action em um commit completo em produção.
- Não passe segredos para os inputs.
- O JSON e o SARIF podem conter caminhos e nomes de pacotes. Restrinja o acesso aos artefatos em repositórios privados.
- A Action não faz upload de código-fonte para a base de vulnerabilidades.

## Limites

O Builders Protect não substitui:

- revisão de código;
- testes de segurança;
- análise de infraestrutura;
- gestão de segredos;
- um pentest;
- monitoramento contínuo de tráfego ou detecção de invasão.

A varredura cobre vulnerabilidades conhecidas em dependências, o Pest revisa o código de forma estática e Minha rede faz uma leitura local das configurações. Nenhum deles prova que o projeto ou a rede estão livres de falhas ou de invasão.

## Reportar uma vulnerabilidade

Não abra uma issue pública. Use **Security > Report a vulnerability** no repositório para abrir um Security Advisory privado.

Inclua:

- versão afetada;
- impacto;
- passos mínimos de reprodução;
- se possível, uma correção sugerida.

Não inclua tokens, dados de clientes, `.env` ou código proprietário. Veja [SECURITY.md](../SECURITY.md).
