# Instalação

## App macOS

Requisitos: macOS 13 ou superior, Swift 5.10+ e Xcode Command Line Tools.

### Instalar a partir do fork

1. Faça um fork de [nextlevelcommunity/builders-protect](https://github.com/nextlevelcommunity/builders-protect).
2. Clone o seu fork e entre na pasta.
3. Rode `make install`.

```bash
git clone https://github.com/<seu-usuario>/builders-protect.git
cd builders-protect
make install
```

O comando compila o app, assina localmente em modo ad-hoc e copia para `~/Applications/Builders Protect.app`. Depois, abra o app e escolha as pastas que deseja monitorar.

Para gerar um DMG:

```bash
make dmg
```

### Instalar a partir de um build pronto

1. Abra [Releases](https://github.com/nextlevelcommunity/builders-protect/releases).
2. Baixe o `Builders.Protect.dmg` mais recente.
3. Abra o DMG e arraste o app para **Aplicativos**.
4. Abra o Builders Protect.
5. Escolha as pastas que deseja monitorar.
6. Ative o agendamento e as notificações nas configurações.

O app fica em **~/Applications** (ou em **Aplicativos**, se você usou o DMG), aparece no Dock, no Launchpad e no **⌘+Tab**. O ícone na barra de menus abre o painel rápido; o banner **Controle total** abre a janela completa.

### Primeira abertura

O build local e o build público usam assinatura ad-hoc e não são notarizados pela Apple. Se o macOS bloquear a abertura:

1. Abra o Finder e localize o app em **~/Applications** ou **Aplicativos**.
2. Clique com o botão direito e escolha **Abrir**.
3. Confirme **Abrir** no diálogo.

Não desative o Gatekeeper globalmente.

### Permissões

O app pede acesso às pastas que você escolher. Ele precisa ler manifests e lockfiles para encontrar dependências. O acesso é limitado às pastas autorizadas.

Na primeira checagem de **Minha rede**, o macOS pode pedir permissão de rede local. Ela é usada para consultar o endereço do roteador e ler os serviços visíveis. O app não captura tráfego, não testa senhas e não envia dados da rede para a Cultura Builder.

O **Pest** lê apenas o projeto escolhido. A análise local não envia arquivos. Se você ativar a IA e marcar o consentimento, trechos de código e configuração são redigidos e enviados à LLM privada da Cultura Builder.

### Abrir ao iniciar

O app pode registrar um item de login do usuário. Para remover, desative a opção nas configurações do app ou remova o item em **Ajustes do Sistema > Geral > Itens de Login**.

### Atualização

No seu fork, atualize o código e rode `make install` novamente. Se preferir o build pronto, baixe o DMG mais recente e substitua o app na mesma pasta. As configurações ficam em:

```text
~/Library/Application Support/Builders Protect/
```

O diretório contém `settings.json`, `report.json`, `pest.json` e `network.json`, com permissão restrita ao seu usuário.

### Desinstalação

1. Encerre o app.
2. Remova `Builders Protect.app` de **~/Applications** ou **Aplicativos**.
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
