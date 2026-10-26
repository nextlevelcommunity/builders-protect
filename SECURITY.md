# Segurança

## Reportar uma vulnerabilidade

Não abra uma issue pública com detalhes exploráveis.

Use **Security > Report a vulnerability** neste repositório para abrir um Security Advisory privado. Inclua:

- versão afetada;
- impacto;
- passos mínimos de reprodução;
- se possível, uma correção sugerida.

Não envie tokens, credenciais, `.env`, dados de clientes ou código proprietário.

## Escopo

Fazem parte do escopo:

- app macOS;
- CLI;
- GitHub Action;
- workflows e scripts de build deste repositório.

Não fazem parte do escopo:

- serviços de terceiros;
- má configuração do ambiente do usuário;
- vulnerabilidades em dependências do projeto escaneado, que devem ser reportadas ao mantenedor do projeto.

## Boas práticas para usuários

- Fixe a Action em um commit completo em produção.
- Use permissões mínimas no workflow.
- Ao instalar o app a partir de um fork, revise o código e use um fork do próprio repositório; `make install` compila e executa código na sua máquina.
- Trate `builders-protect.json` e `builders-protect.sarif` como informação interna.
- Não use a CLI em projetos cujos lockfiles não possam ser compartilhados com a base de vulnerabilidades.
- Mantenha o app e a CLI atualizados.

## Divulgação

A Cultura Builder avalia o relatório e combina a divulgação com quem reportou. Não divulgue detalhes antes de uma correção ou de um prazo acordado.
