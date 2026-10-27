# Changelog

## 1.2.0 — 2026-10-27

- Novo Pest: análise de segurança de código por projeto, guiada por um catálogo destilado de templates do Nuclei.
- O Pest combina análise estática local com revisão opcional da LLM privada da Cultura Builder, sempre com consentimento explícito.
- O envio para IA usa blocos pequenos, redaction de segredos, orçamento de memória e validação de caminhos; `.env`, chaves, binários e dependências instaladas ficam de fora.
- Cada achado do Pest inclui impacto, recomendação e um prompt de correção pronto para um agente.
- Rotinas Pest diárias por projeto, com intervalo mínimo de 30 minutos, retomada após pausa por memória baixa e notificações.
- Nova seção Minha rede: uma checagem local e passiva da Wi-Fi, do roteador, dos dispositivos conhecidos e dos serviços do Mac visíveis na rede.
- O relatório de rede usa linguagem leiga e separa o que está confirmado agora, o que é possível no cenário e o que não pôde ser verificado.
- Um prompt geral no topo do relatório reúne todas as correções da rede em um plano único e priorizado, além dos prompts por achado.
- Minha rede não captura tráfego, não testa senhas, não entra no painel do roteador e deixa claro que uma checagem local não prova invasão.
- O app agora inclui permissões de rede local e ATS restrito ao endereço local do roteador.
- Textos de privacidade foram atualizados para diferenciar a varredura de dependências, o Pest e o Red Teaming.

## 1.1.3 — 2026-10-26

- Painel rápido redesenhado, com tipografia maior, mais respiro e hierarquia mais clara.
- O resumo agora mostra apenas o total de projetos afetados, com descrição curta; clicar no bloco abre a central completa.
- Cartão de resumo com fundo sólido e banner Controle total sem borda e com menos contraste.
- Indicador de IA encurtado para "IA", com o estado completo no tooltip.
- "Verificar agora" passa a abrir a central completa e iniciar a verificação.
- Principais riscos com mais espaçamento entre título, itens e padding vertical.

## 1.1.2 — 2026-10-26

- Nova tela Gerenciar pastas: lista todos os projetos encontrados, com busca, seleção múltipla e ações em lote.
- Pastas de build, preview e artefatos são marcadas automaticamente para facilitar a revisão.
- É possível ignorar ou reativar várias pastas de uma vez, com regras de exclusão normalizadas.

## 1.1.1 — 2026-10-26

- Ajustes são salvos automaticamente após uma pequena pausa. O botão Salvar alterações continua disponível para confirmação.
- Salvar ajustes preserva o horário da última varredura e evita sobrescrever estado atualizado pelo agendador.

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
