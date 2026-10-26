'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { checkLockfile, parseEventStream, normalizeAffected } = require('../lib/cve');

function rpcResponse(payload, contentType = 'application/json') {
  return new Response(
    JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      result: {
        content: [{ type: 'text', text: JSON.stringify(payload) }]
      }
    }),
    { status: 200, headers: { 'content-type': contentType } }
  );
}

test('consulta lockfile e normaliza achados', async () => {
  let requestedBody;
  const fetchImpl = async (url, options) => {
    requestedBody = JSON.parse(options.body);
    return rpcResponse({
      affected: [
        {
          id: 'CVE-2024-0001',
          title: 'Falha de teste',
          severity: { cvss: 9.8 },
          url: 'https://example.test/CVE-2024-0001',
          package: { ecosystem: 'npm', name: 'lodash', version: '4.17.20' }
        }
      ]
    });
  };

  const findings = await checkLockfile(
    { name: 'package-lock.json', content: '{"lockfileVersion":3}' },
    { fetchImpl, endpoint: 'https://example.test/mcp' }
  );

  assert.equal(findings.length, 1);
  assert.equal(findings[0].severity, 'critical');
  assert.equal(findings[0].packageName, 'lodash');
  assert.equal(requestedBody.params.name, 'check_stack');
  assert.equal(requestedBody.params.arguments.lockfile_name, 'package-lock.json');
});

test('entende resposta SSE', async () => {
  const event = JSON.stringify({ result: { content: [{ text: '{"affected":[]}' }] } });
  const fetchImpl = async () => new Response(`event: message\ndata: ${event}\n\n`, {
    status: 200,
    headers: { 'content-type': 'text/event-stream' }
  });

  const findings = await checkLockfile(
    { name: 'yarn.lock', content: 'lodash@4.17.20:' },
    { fetchImpl, endpoint: 'https://example.test/mcp' }
  );

  assert.deepEqual(findings, []);
});

test('normaliza pacote em formato de lista e KEV', () => {
  const finding = normalizeAffected({
    id: 'CVE-2024-0002',
    title: 'KEV',
    severity: { cvss: 4.0 },
    exploitation: { kev: true },
    package: [{ ecosystem: 'pypi', name: 'django', version: '1.0.0' }]
  });

  assert.equal(finding.severity, 'critical');
  assert.equal(finding.isKEV, true);
  assert.equal(finding.ecosystem, 'pypi');
});

test('extrai o último evento SSE válido', () => {
  const parsed = parseEventStream('data: {"a":1}\ndata: {"b":2}\n');
  assert.deepEqual(parsed, { b: 2 });
});
