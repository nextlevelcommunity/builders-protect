# Modelo de segurança

Este documento descreve o que o Builders Protect lê, envia e produz. Ele vale para o app macOS, a CLI e a GitHub Action.

## Princípios

- A varredura de dependências não envia código-fonte.
- O diagnóstico com IA não envia código-fonte.
- O Red Teaming é opt-in, por projeto, e será exclusivo para assinantes ativos.
- Nenhum segredo é incluído nos relatórios.
- A Action não escreve no repositório e não precisa de token de IA.

## Dados por recurso

| Recurso | Lê | Envia | Não envia |
| --- | --- | --- | --- |
| Varredura de dependências | Manifests e lockfiles das pastas autorizadas | Nome e conteúdo do lockfile, nomes e versões de pacotes | Código-fonte, `.env`, chaves, credenciais |
| Diagnóstico com IA | Achados e metadados do projeto | Achados, nomes de pacotes, versões, caminhos e ecossistemas | Código-fonte, segredos |
| Red Teaming | Arquivos selecionados do projeto | Somente arquivos selecionados, após consentimento | Credenciais, arquivos ignorados, arquivos fora do projeto |
| GitHub Action | Workspace do repositório | Lockfiles para a base de vulnerabilidades | Código-fonte, segredos, tokens do GitHub |

Lockfiles podem conter nomes de pacotes internos e URLs de registries privados. Trate o relatório e os artefatos gerados como informação interna.

## Base de vulnerabilidades

A base é operada e validada pela equipe da Cultura Builder. A documentação pública não detalha fornecedores, topologia ou controles internos de infraestrutura.

A consulta usa apenas os dados necessários para identificar vulnerabilidades conhecidas nos pacotes instalados. Ela não executa o projeto, não instala dependências e não lê arquivos de código.

## IA e assinatura

O diagnóstico com IA e o Red Teaming usam os modelos de segurança da Cultura Builder. O acesso é restrito a assinantes ativos.

Quando o Red Teaming for liberado:

- a ativação será manual e por projeto;
- o app mostrará o escopo antes de enviar qualquer arquivo;
- somente arquivos selecionados serão enviados;
- os modelos serão privados e dedicados à segurança, com guardrails específicos;
- os dados não serão enviados para laboratórios de IA nem usados para treinamento;
- o consentimento poderá ser revogado antes de cada análise.

O Red Teaming está em preparação nesta versão e não é executado pela CLI nem pela Action.

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
- um pentest.

A varredura cobre vulnerabilidades conhecidas em dependências. Ela não prova que o projeto está livre de falhas.

## Reportar uma vulnerabilidade

Não abra uma issue pública. Use **Security > Report a vulnerability** no repositório para abrir um Security Advisory privado.

Inclua:

- versão afetada;
- impacto;
- passos mínimos de reprodução;
- se possível, uma correção sugerida.

Não inclua tokens, dados de clientes, `.env` ou código proprietário. Veja [SECURITY.md](../SECURITY.md).
