'use strict';

const crypto = require('node:crypto');
const path = require('node:path');
const { ORDER } = require('./severity');

const PROJECT_URL = 'https://github.com/nextlevelcommunity/builders-protect';
const SARIF_SCHEMA = 'https://json.schemastore.org/sarif-2.1.0.json';

function summarize(findings) {
  const counts = {};
  for (const key of Object.keys(ORDER)) counts[key] = 0;
  for (const finding of findings || []) {
    const key = finding.severity && Object.prototype.hasOwnProperty.call(counts, finding.severity)
      ? finding.severity
      : 'unknown';
    counts[key] += 1;
  }
  return {
    total: (findings || []).length,
    ...counts
  };
}

function markdownEscape(value) {
  return String(value ?? '').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
}

function toMarkdown(report) {
  const summary = report.summary || summarize(report.findings);
  const lines = [
    '# Builders Protect',
    '',
    `Varredura concluída em ${report.finishedAt}.`,
    '',
    '| Severidade | Total |',
    '| --- | ---: |',
    `| Crítica | ${summary.critical} |`,
    `| Alta | ${summary.high} |`,
    `| Média | ${summary.medium} |`,
    `| Baixa | ${summary.low} |`,
    `| Indefinida | ${summary.unknown} |`,
    `| **Total** | **${summary.total}** |`,
    ''
  ];

  if (report.projects.length === 0) {
    lines.push('Nenhum projeto com lockfile foi encontrado.', '');
  } else {
    lines.push(`Projetos verificados: ${report.projects.length}.`, '');
  }

  if (report.findings.length > 0) {
    lines.push('## Achados', '');
    lines.push('| Severidade | Projeto | Pacote | Versão | Vulnerabilidade |');
    lines.push('| --- | --- | --- | --- | --- |');
    for (const finding of report.findings.slice(0, 100)) {
      lines.push(
        `| ${markdownEscape(finding.severity)} | ${markdownEscape(finding.projectName)} | ` +
        `${markdownEscape(finding.packageName)} | ${markdownEscape(finding.installedVersion)} | ` +
        `${markdownEscape(finding.id)} — ${markdownEscape(finding.title)} |`
      );
    }
    if (report.findings.length > 100) {
      lines.push('', `Mais ${report.findings.length - 100} achados não foram listados nesta tabela.`);
    }
    lines.push('');
  }

  if (report.warnings.length > 0) {
    lines.push('## Avisos', '');
    for (const warning of report.warnings.slice(0, 20)) lines.push(`- ${warning}`);
    if (report.warnings.length > 20) lines.push(`- Mais ${report.warnings.length - 20} avisos.`);
    lines.push('');
  }

  if (report.errors.length > 0) {
    lines.push('## Erros', '');
    for (const error of report.errors.slice(0, 20)) {
      lines.push(`- ${error.project || 'projeto'} / ${error.lockfile || 'lockfile'}: ${error.message}`);
    }
    if (report.errors.length > 20) lines.push(`- Mais ${report.errors.length - 20} erros.`);
    lines.push('');
  }

  lines.push(
    '## Privacidade',
    '',
    'A varredura envia nomes e versões de pacotes e o conteúdo dos lockfiles para a base de vulnerabilidades da Cultura Builder. Nenhum arquivo de código-fonte é enviado nesta etapa.',
    ''
  );

  return `${lines.join('\n')}\n`;
}

function sarifLevel(severity) {
  if (severity === 'critical' || severity === 'high') return 'error';
  if (severity === 'medium') return 'warning';
  return 'note';
}

function artifactUri(root, filePath) {
  const relative = path.relative(root, filePath) || path.basename(filePath);
  return relative.split(path.sep).join('/');
}

function toSarif(report) {
  const rules = [];
  const ruleIndex = new Map();

  for (const finding of report.findings) {
    if (ruleIndex.has(finding.id)) continue;
    ruleIndex.set(finding.id, rules.length);
    rules.push({
      id: finding.id,
      name: finding.id,
      shortDescription: { text: finding.title },
      helpUri: finding.url || undefined,
      properties: {
        severity: finding.severity,
        cvss: finding.cvss
      }
    });
  }

  const results = report.findings.map((finding) => {
    const fingerprint = crypto
      .createHash('sha256')
      .update(`${report.root}|${finding.projectPath}|${finding.id}|${finding.packageName}|${finding.installedVersion}`)
      .digest('hex');

    return {
      ruleId: finding.id,
      ruleIndex: ruleIndex.get(finding.id),
      level: sarifLevel(finding.severity),
      message: {
        text: `${finding.packageName}@${finding.installedVersion} (${finding.ecosystem}) — ${finding.title}`
      },
      locations: [
        {
          physicalLocation: {
            artifactLocation: {
              uri: artifactUri(report.root, finding.lockfilePath)
            },
            region: { startLine: 1 }
          }
        }
      ],
      partialFingerprints: {
        'builders-protect/v1': fingerprint
      },
      properties: {
        project: finding.projectName,
        package: finding.packageName,
        installedVersion: finding.installedVersion,
        severity: finding.severity,
        cvss: finding.cvss,
        lockfile: finding.lockfile
      }
    };
  });

  return {
    $schema: SARIF_SCHEMA,
    version: '2.1.0',
    runs: [
      {
        tool: {
          driver: {
            name: 'Builders Protect',
            informationUri: PROJECT_URL,
            rules
          }
        },
        invocations: [
          {
            executionSuccessful: report.errors.length === 0,
            toolExecutionNotifications: report.warnings.map((message) => ({
              level: 'warning',
              message: { text: message }
            }))
          }
        ],
        results,
        properties: {
          summary: report.summary
        }
      }
    ]
  };
}

function toJson(report) {
  return `${JSON.stringify(report, null, 2)}\n`;
}

module.exports = {
  PROJECT_URL,
  summarize,
  toMarkdown,
  toSarif,
  toJson,
  sarifLevel,
  artifactUri
};
