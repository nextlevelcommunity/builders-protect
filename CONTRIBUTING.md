# Contribuições

Este repositório é público para uso e auditoria. Contribuições externas não são aceitas automaticamente.

## Antes de abrir uma issue

- Verifique se o problema já foi reportado.
- Remova caminhos privados, nomes de clientes, tokens e trechos de lockfiles.
- Para falhas de segurança, use um Security Advisory privado. Veja [SECURITY.md](SECURITY.md).

## Pull requests

Pull requests externos podem ser recusados sem revisão. Se houver alinhamento prévio com a Cultura Builder:

- mantenha a mudança pequena e focada;
- não adicione dependências de runtime sem necessidade;
- preserve o comportamento cross-platform da CLI;
- rode `npm test` e `swift test`;
- não inclua segredos, dados de clientes ou artefatos de build.

## Estilo

- JavaScript: CommonJS, 2 espaços, sem dependências externas na CLI.
- Swift: 4 espaços, seguindo o código existente.
- Documentação: português do Brasil, sem emojis, com exemplos executáveis.
- Commits: Conventional Commits, por exemplo `fix(cli): ...`.

## Segurança da supply chain

- Não adicione scripts de pós-instalação.
- Não adicione Actions de terceiros sem revisão.
- Fixe Actions em commits completos quando possível.
- Não inclua credenciais em workflows, exemplos ou testes.
