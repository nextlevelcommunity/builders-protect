'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const cli = path.join(__dirname, '..', 'bin', 'builders-protect.js');

function runCli(args, env) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, args, {
      env,
      stdio: ['ignore', 'pipe', 'pipe']
    });
    let stdout = '';
    let stderr = '';
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('close', (status) => resolve({ status, stdout, stderr }));
  });
}

function startServer() {
  return new Promise((resolve) => {
    const server = http.createServer((request, response) => {
      request.resume();
      request.on('end', () => {
        const body = {
          jsonrpc: '2.0',
          id: 1,
          result: {
            content: [
              {
                type: 'text',
                text: JSON.stringify({
                  affected: [
                    {
                      id: 'CVE-2024-9999',
                      title: 'Falha crítica de teste',
                      severity: { cvss: 9.8 },
                      url: 'https://example.test/CVE-2024-9999',
                      package: { ecosystem: 'npm', name: 'lodash', version: '4.17.20' }
                    }
                  ]
                })
              }
            ]
          }
        };
        response.writeHead(200, { 'content-type': 'application/json' });
        response.end(JSON.stringify(body));
      });
    });
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({ server, url: `http://127.0.0.1:${address.port}/mcp` });
    });
  });
}

test('CLI gera JSON e falha no limite configurado', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-cli-'));
  const { server, url } = await startServer();
  try {
    fs.writeFileSync(path.join(root, 'package.json'), '{"name":"app-cli"}');
    fs.writeFileSync(path.join(root, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');

    const result = await runCli(
      [cli, 'scan', '--path', root, '--format', 'json', '--fail-on', 'high'],
      { ...process.env, BUILDERS_PROTECT_API_URL: url }
    );

    assert.equal(result.status, 1, result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(report.summary.critical, 1);
    assert.equal(report.findings[0].id, 'CVE-2024-9999');
  } finally {
    server.close();
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('CLI com fail-on none não falha', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-cli-none-'));
  const { server, url } = await startServer();
  try {
    fs.writeFileSync(path.join(root, 'package.json'), '{"name":"app-cli"}');
    fs.writeFileSync(path.join(root, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');

    const result = await runCli(
      [cli, 'scan', '--path', root, '--format', 'json', '--fail-on', 'none'],
      { ...process.env, BUILDERS_PROTECT_API_URL: url }
    );

    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).summary.total, 1);
  } finally {
    server.close();
    fs.rmSync(root, { recursive: true, force: true });
  }
});
