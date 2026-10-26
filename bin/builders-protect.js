#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const packageJson = require('../package.json');
const { scan } = require('../lib/scan');
const { normalizeThreshold, meetsThreshold } = require('../lib/severity');
const { toMarkdown, toSarif, toJson, summarize } = require('../lib/report');

function help() {
  return `Builders Protect ${packageJson.version}

Uso:
  builders-protect scan [opções]
  builders-protect --version
  builders-protect --help

Opções de scan:
  --path <pasta>          Pasta raiz da varredura (padrão: diretório atual)
  --exclude <lista>       Pastas a ignorar, separadas por vírgula (pode repetir)
  --max-projects <n>      Limite de projetos por varredura (padrão: 80)
  --fail-on <nível>       none, low, medium, high ou critical (padrão: high)
  --format <formato>      text, markdown ou json (padrão: text)
  --output <arquivo>      Salva o relatório no formato escolhido
  --sarif <arquivo>       Gera um arquivo SARIF 2.1.0
  --endpoint <url>        Sobrescreve o endpoint da base de vulnerabilidades
  --quiet                 Não mostra progresso no stderr

Códigos de saída:
  0  Nenhum achado no limite configurado
  1  Achados no limite configurado
  2  Falha de configuração, leitura ou consulta

Exemplos:
  builders-protect scan --path . --fail-on high
  builders-protect scan --path . --format json --output report.json
  builders-protect scan --path . --sarif builders-protect.sarif

O Red Teaming não é executado pela CLI. Ele é um recurso opt-in do app, disponível para assinantes da Cultura Builder.`;
}

function takeValue(argv, index, option) {
  if (index + 1 >= argv.length || argv[index + 1].startsWith('--')) {
    throw new Error(`Faltou valor para ${option}.`);
  }
  return argv[index + 1];
}

function parseArgs(argv) {
  const options = {
    command: 'scan',
    path: process.cwd(),
    exclude: [],
    maxProjects: 80,
    failOn: 'high',
    format: 'text',
    output: null,
    sarif: null,
    endpoint: null,
    quiet: false
  };
  const positional = [];

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--help' || arg === '-h') {
      options.command = 'help';
      continue;
    }
    if (arg === '--version' || arg === '-v') {
      options.command = 'version';
      continue;
    }
    if (arg === '--quiet') {
      options.quiet = true;
      continue;
    }
    if (arg === '--path') {
      options.path = takeValue(argv, index, arg);
      index += 1;
      continue;
    }
    if (arg === '--exclude') {
      options.exclude.push(takeValue(argv, index, arg));
      index += 1;
      continue;
    }
    if (arg === '--max-projects') {
      options.maxProjects = Number(takeValue(argv, index, arg));
      index += 1;
      continue;
    }
    if (arg === '--fail-on') {
      options.failOn = takeValue(argv, index, arg);
      index += 1;
      continue;
    }
    if (arg === '--format') {
      options.format = takeValue(argv, index, arg).toLowerCase();
      index += 1;
      continue;
    }
    if (arg === '--output') {
      options.output = takeValue(argv, index, arg);
      index += 1;
      continue;
    }
    if (arg === '--sarif') {
      options.sarif = takeValue(argv, index, arg);
      index += 1;
      continue;
    }
    if (arg === '--endpoint') {
      options.endpoint = takeValue(argv, index, arg);
      index += 1;
      continue;
    }
    if (arg.startsWith('--')) throw new Error(`Opção desconhecida: ${arg}`);
    positional.push(arg);
  }

  if (positional.length > 0) options.command = positional[0];
  if (!['scan', 'help', 'version'].includes(options.command)) {
    throw new Error(`Comando desconhecido: ${options.command}`);
  }
  if (!['text', 'markdown', 'json'].includes(options.format)) {
    throw new Error(`Formato inválido: ${options.format}. Use text, markdown ou json.`);
  }
  if (!Number.isInteger(options.maxProjects) || options.maxProjects < 1) {
    throw new Error('--max-projects precisa ser um número inteiro maior que zero.');
  }
  options.threshold = normalizeThreshold(options.failOn);
  return options;
}

function printProgress(event) {
  if (event.phase === 'start') {
    process.stderr.write(
      `Analisando ${event.projectName} (${event.lockfile})...\n`
    );
  }
}

function toText(report) {
  const summary = report.summary || summarize(report.findings);
  const lines = [
    `Builders Protect: ${summary.total} achado(s) em ${report.projects.length} projeto(s).`,
    `Crítica: ${summary.critical} | Alta: ${summary.high} | Média: ${summary.medium} | ` +
      `Baixa: ${summary.low} | Indefinida: ${summary.unknown}`
  ];

  for (const finding of report.findings.slice(0, 25)) {
    lines.push(
      `[${finding.severity.toUpperCase()}] ${finding.projectName} ` +
      `${finding.packageName}@${finding.installedVersion} — ${finding.id} ${finding.title}`
    );
  }
  if (report.findings.length > 25) {
    lines.push(`Mais ${report.findings.length - 25} achado(s).`);
  }
  if (report.errors.length > 0) {
    lines.push('', `${report.errors.length} lockfile(s) não puderam ser analisados.`);
  }
  return `${lines.join('\n')}\n`;
}

function printText(report) {
  process.stdout.write(toText(report));
}

function writeFile(filePath, content) {
  const resolved = path.resolve(filePath);
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  fs.writeFileSync(resolved, content, 'utf8');
  return resolved;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));

  if (options.command === 'help') {
    process.stdout.write(`${help()}\n`);
    return 0;
  }
  if (options.command === 'version') {
    process.stdout.write(`${packageJson.version}\n`);
    return 0;
  }

  const report = await scan({
    root: options.path,
    exclude: options.exclude,
    maxProjects: options.maxProjects,
    endpoint: options.endpoint,
    onProgress: options.quiet ? undefined : printProgress
  });

  let content;
  if (options.format === 'json') content = toJson(report);
  else if (options.format === 'markdown') content = toMarkdown(report);
  else content = toText(report);

  if (options.output) {
    writeFile(options.output, content);
    process.stderr.write(`Relatório salvo em ${path.resolve(options.output)}\n`);
  } else {
    process.stdout.write(content);
  }

  if (options.sarif) {
    writeFile(options.sarif, `${JSON.stringify(toSarif(report), null, 2)}\n`);
    process.stderr.write(`SARIF salvo em ${path.resolve(options.sarif)}\n`);
  }

  if (report.errors.length > 0) return 2;

  const failed = report.findings.some((finding) => {
    return meetsThreshold(finding.severity, options.threshold);
  });
  return failed ? 1 : 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    process.stderr.write(`Erro: ${error.message}\n`);
    process.exitCode = 2;
  });
