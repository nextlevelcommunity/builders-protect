# GitHub Action

A Action executa a mesma varredura de dependências da CLI e publica um resumo no job. Ela é adequada para pull requests, pushes e rotinas agendadas.

## Uso mínimo

```yaml
name: Builders Protect
on:
  pull_request:
  push:
    branches: [main]
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

## Entradas

| Entrada | Padrão | Descrição |
| --- | --- | --- |
| `path` | `.` | Pasta raiz da varredura, relativa ao workspace |
| `fail-on` | `high` | Nível mínimo que falha o job: `none`, `low`, `medium`, `high` ou `critical` |
| `exclude` | vazio | Pastas a ignorar, separadas por vírgula |
| `max-projects` | `80` | Limite de projetos por varredura |
| `sarif-file` | `builders-protect.sarif` | Caminho do SARIF. Deixe vazio para não gerar |
| `json-file` | `builders-protect.json` | Caminho do JSON. Deixe vazio para não gerar |

## Saídas

| Saída | Descrição |
| --- | --- |
| `findings-count` | Total de achados |
| `critical-count` | Total de achados críticos |
| `high-count` | Total de achados altos |
| `sarif-file` | Caminho absoluto do SARIF gerado |
| `json-file` | Caminho absoluto do JSON gerado |

Exemplo:

```yaml
- uses: nextlevelcommunity/builders-protect@v1
  id: protect
  with:
    fail-on: critical
- run: echo "Achados: ${{ steps.protect.outputs.findings-count }}"
```

## Rotinas

### Diária

```yaml
on:
  schedule:
    - cron: '0 9 * * *'
  workflow_dispatch:
```

### Semanal

```yaml
on:
  schedule:
    - cron: '0 9 * * 1'
  workflow_dispatch:
```

### Mensal

```yaml
on:
  schedule:
    - cron: '0 9 1 * *'
  workflow_dispatch:
```

Os horários usam UTC. O GitHub pode desativar schedules de repositórios sem atividade por longos períodos; mantenha um `workflow_dispatch` para execução manual.

## Pull requests

Para evitar execuções duplicadas:

```yaml
concurrency:
  group: builders-protect-${{ github.ref }}
  cancel-in-progress: true
```

Para comentar o resultado no PR, use o resumo do job e o SARIF. A Action não escreve comentários nem altera arquivos do repositório.

## Code Scanning

O SARIF usa a versão 2.1.0 e aponta cada achado para o lockfile correspondente. O upload é feito por uma Action oficial do GitHub:

```yaml
permissions:
  contents: read
  security-events: write
steps:
  - uses: actions/checkout@v4
  - uses: nextlevelcommunity/builders-protect@v1
  - uses: github/codeql-action/upload-sarif@v3
    if: always()
    with:
      sarif_file: builders-protect.sarif
```

Code Scanning depende do plano e das configurações do repositório no GitHub.

## Segurança da supply chain

- Fixe a Action em um commit completo em produção:

```yaml
- uses: nextlevelcommunity/builders-protect@<commit-sha>
```

- `@v1` é um alias de conveniência para a última versão compatível.
- A Action não tem dependências de runtime e não executa scripts de pós-instalação.
- Use permissões mínimas. `contents: read` é suficiente para a varredura; `security-events: write` é necessário apenas para o upload do SARIF.
- Não coloque tokens, `.env` ou dados de clientes nos inputs.

## Falhas

| Situação | Resultado |
| --- | --- |
| Achados abaixo de `fail-on` | Job passa |
| Achados no limite ou acima | Job falha com código 1 |
| Lockfile não pôde ser analisado | Job falha com código 2 |
| Nenhum projeto encontrado | Job passa, com aviso no resumo |

O `fail-on: none` nunca falha por achados, mas ainda falha por erro de leitura ou consulta.
