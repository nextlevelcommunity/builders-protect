'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { toMarkdown, toSarif, summarize } = require('../lib/report');

function sampleReport() {
  return {
    schemaVersion: 1,
    tool: { name: 'Builders Protect', version: '1.0.0' },
    root: '/workspace',
    startedAt: '2026-10-26T12:00:00.000Z',
    finishedAt: '2026-10-26T12:00:01.000Z',
    durationMs: 1000,
    projects: [{ path: '/workspace/app', name: 'app', lockfiles: ['package-lock.json'] }],
    findings: [
      {
        id: 'CVE-2024-0001',
        title: 'Falha de teste',
        cvss: 9.8,
        severity: 'critical',
        url: 'https://example.test/CVE-2024-0001',
        packageName: 'lodash',
        installedVersion: '4.17.20',
        ecosystem: 'npm',
        projectPath: '/workspace/app',
        projectName: 'app',
        lockfile: 'package-lock.json',
        lockfilePath: '/workspace/app/package-lock.json'
      }
    ],
    summary: summarize([
      { severity: 'critical' },
      { severity: 'high' },
      { severity: 'low' }
    ]),
    warnings: [],
    errors: []
  };
}

test('gera resumo markdown com privacidade', () => {
  const markdown = toMarkdown(sampleReport());
  assert.match(markdown, /Builders Protect/);
  assert.match(markdown, /Crítica \| 1/);
  assert.match(markdown, /Nenhum arquivo de código-fonte/);
  assert.match(markdown, /CVE-2024-0001/);
});

test('gera SARIF 2.1.0 com localização relativa', () => {
  const sarif = toSarif(sampleReport());
  assert.equal(sarif.version, '2.1.0');
  assert.equal(sarif.runs[0].tool.driver.name, 'Builders Protect');
  assert.equal(sarif.runs[0].results[0].level, 'error');
  assert.equal(sarif.runs[0].results[0].ruleId, 'CVE-2024-0001');
  assert.equal(
    sarif.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri,
    'app/package-lock.json'
  );
});
