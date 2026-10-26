# Changelog

## 1.1.0 — 2026-10-26

- Instalação documentada a partir do fork, com `make install` e geração local do DMG.
- O app agora é um aplicativo regular no macOS, com Dock, Launchpad e ⌘+Tab, mantendo o ícone na barra de menus.
- Clique no ícone do Dock abre o painel rápido; o banner Controle total abre a janela principal.
- Item de login atualizado para iniciar em segundo plano, sem abrir o painel ao ligar o Mac.
- Worktrees do Git são detectadas automaticamente; a varredura usa a pasta principal do repositório e as worktrees ficam pré-ignoradas, com opção de reativar em Ajustes > Pastas.
- A pasta raiz escolhida também é verificada como projeto, mesmo quando o lockfile está no próprio diretório selecionado.

## 1.0.0 — 2026-10-26

- Primeira versão pública do Builders Protect.
- App macOS com varredura de dependências, agendamento local e diagnóstico com IA para assinantes.
- CLI cross-platform para macOS, Linux e Windows.
- GitHub Action com resumo, JSON e SARIF 2.1.0.
- Rotinas diárias, semanais e mensais via cron.
- Red Teaming em preparação, desativado nesta versão.
- Documentação de instalação, action, segurança, arquitetura e FAQ.
- Workflows de CI e release.
