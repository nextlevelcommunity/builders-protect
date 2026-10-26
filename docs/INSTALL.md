# Instalação

## App macOS

Requisitos: macOS 13 ou superior.

1. Abra [Releases](https://github.com/nextlevelcommunity/builders-protect/releases).
2. Baixe o `Builders Protect.dmg` mais recente.
3. Abra o DMG e arraste o app para **Aplicativos**.
4. Abra o Builders Protect.
5. Escolha as pastas que deseja monitorar.
6. Ative o agendamento e as notificações nas configurações.

### Primeira abertura

O build público atual usa assinatura ad-hoc e não é notarizado pela Apple. Se o macOS bloquear a abertura:

1. Abra o Finder e localize o app em **Aplicativos**.
2. Clique com o botão direito e escolha **Abrir**.
3. Confirme **Abrir** no diálogo.

Não desative o Gatekeeper globalmente.

### Permissões

O app pede acesso às pastas que você escolher. Ele precisa ler manifests e lockfiles para encontrar dependências. O acesso é limitado às pastas autorizadas.

### Abrir ao iniciar

O app pode registrar um item de login do usuário. Para remover, desative a opção nas configurações do app ou remova o item em **Ajustes do Sistema > Geral > Itens de Login**.

### Atualização

Baixe o DMG mais recente e substitua o app em **Aplicativos**. As configurações ficam em:

```text
~/Library/Application Support/Builders Protect/
```

### Desinstalação

1. Encerre o app.
2. Remova `Builders Protect.app` de **Aplicativos**.
3. Remova o item de login, se existir.
4. Opcionalmente, remova os dados locais:

```bash
rm -rf "$HOME/Library/Application Support/Builders Protect"
```

## CLI

Requisitos: Node.js 20 ou superior.

Sem instalação global:

```bash
npx --yes --package github:nextlevelcommunity/builders-protect builders-protect scan --path .
```

Instalação global a partir do GitHub:

```bash
npm install -g github:nextlevelcommunity/builders-protect
builders-protect scan --path .
```

Com o repositório clonado:

```bash
git clone https://github.com/nextlevelcommunity/builders-protect.git
cd builders-protect
node bin/builders-protect.js scan --path /caminho/do/projeto
```

### Códigos de saída

| Código | Significado |
| ---: | --- |
| 0 | Nenhum achado no limite configurado |
| 1 | Achados no limite configurado |
| 2 | Falha de configuração, leitura ou consulta |

## GitHub Action

Copie um dos exemplos:

- [Varredura em PR e push](../examples/builders-protect.yml)
- [Varredura agendada](../examples/builders-protect-scheduled.yml)

O workflow precisa de:

```yaml
permissions:
  contents: read
  security-events: write
```

`security-events: write` é necessário apenas para enviar o SARIF ao GitHub Code Scanning.

## Windows e Linux

Nesta versão, o modo suportado no Windows e no Linux é a CLI ou a GitHub Action. Não há interface desktop para esses sistemas ainda.

A CLI usa apenas módulos nativos do Node.js. Não há dependências de runtime, scripts de instalação ou binários específicos de plataforma.

## Solução de problemas

### Nenhum projeto encontrado

Confirme que a pasta contém um lockfile suportado. O Builders Protect não cria lockfiles e não executa instalação de dependências.

### A Action não encontra o lockfile

Confira o input `path`. Em monorepos, aponte para a raiz que contém os projetos ou para uma pasta específica.

### O upload do SARIF falha

Confirme que o workflow tem `security-events: write` e que o repositório tem Code Scanning disponível no plano do GitHub.

### A consulta falha

A CLI retorna código 2 quando nenhum lockfile pôde ser analisado. Verifique a conexão e tente novamente. Não inclua tokens ou dados privados em issues públicas.
