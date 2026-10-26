'use strict';

const { fromCvss } = require('./severity');

const DEFAULT_ENDPOINT = 'https://mcp.cve.now/mcp';
const DEFAULT_TIMEOUT_MS = 90_000;

function resolveEndpoint(explicit) {
  return explicit || process.env.BUILDERS_PROTECT_API_URL || DEFAULT_ENDPOINT;
}

function parseEventStream(text) {
  const lines = String(text).split(/\r?\n/);
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const line = lines[index].trim();
    if (!line.startsWith('data:')) continue;
    const payload = line.slice(5).trim();
    if (!payload || payload === '[DONE]') continue;
    try {
      return JSON.parse(payload);
    } catch {
      // Keep looking for the last valid event.
    }
  }
  return null;
}

function parseRpcResponse(text, contentType) {
  if (String(contentType || '').toLowerCase().includes('text/event-stream')) {
    const event = parseEventStream(text);
    if (!event) throw new Error('A resposta SSE da base de vulnerabilidades não contém um evento válido.');
    return event;
  }

  try {
    return JSON.parse(text);
  } catch {
    const event = parseEventStream(text);
    if (event) return event;
    throw new Error('A base de vulnerabilidades devolveu um JSON inválido.');
  }
}

function extractToolText(result) {
  if (!result || !Array.isArray(result.content)) return null;
  for (const item of result.content) {
    if (item && typeof item.text === 'string' && item.text.trim()) return item.text;
  }
  return null;
}

function normalizeAffected(item) {
  if (!item || typeof item !== 'object') return null;
  const pkg = Array.isArray(item.package) ? item.package[0] : item.package;
  if (!pkg || typeof pkg !== 'object') return null;
  if (typeof pkg.name !== 'string' || typeof pkg.version !== 'string') return null;

  const severityObject = item.severity && typeof item.severity === 'object' ? item.severity : {};
  const cvssValue = severityObject.cvss;
  const cvss = cvssValue === null || cvssValue === undefined ? null : Number(cvssValue);
  const isKEV = Boolean(
    item.kev ||
    item.isKEV ||
    (item.exploitation && item.exploitation.kev)
  );

  return {
    id: typeof item.id === 'string' ? item.id : 'SEM-ID',
    title: typeof item.title === 'string' ? item.title : 'Vulnerabilidade sem título',
    cvss: Number.isFinite(cvss) ? cvss : null,
    severity: fromCvss(Number.isFinite(cvss) ? cvss : null, isKEV),
    url: typeof item.url === 'string' ? item.url : '',
    packageName: pkg.name,
    installedVersion: pkg.version,
    ecosystem: typeof pkg.ecosystem === 'string' ? pkg.ecosystem : 'unknown',
    isKEV
  };
}

async function checkLockfile(lockfile, options = {}) {
  if (!lockfile || typeof lockfile.content !== 'string' || !lockfile.content.trim()) {
    return [];
  }

  const fetchImpl = options.fetchImpl || globalThis.fetch;
  if (typeof fetchImpl !== 'function') {
    throw new Error('Este ambiente não tem fetch disponível. Use Node.js 20 ou superior.');
  }

  const endpoint = resolveEndpoint(options.endpoint);
  const timeoutMs = Number.isInteger(options.timeoutMs) ? options.timeoutMs : DEFAULT_TIMEOUT_MS;
  const body = {
    jsonrpc: '2.0',
    id: Math.floor(Math.random() * 9_000_000) + 1,
    method: 'tools/call',
    params: {
      name: 'check_stack',
      arguments: {
        lockfile_name: lockfile.name,
        lockfile_content: lockfile.content
      }
    }
  };

  const response = await fetchImpl(endpoint, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      accept: 'application/json, text/event-stream',
      'mcp-protocol-version': '2025-06-18'
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs)
  });

  if (!response.ok) {
    throw new Error(`A base de vulnerabilidades respondeu com HTTP ${response.status}.`);
  }

  const text = await response.text();
  const root = parseRpcResponse(text, response.headers.get('content-type'));

  if (root && root.error) {
    const message = root.error.message || 'Erro desconhecido na base de vulnerabilidades.';
    throw new Error(message);
  }

  const result = root && root.result;
  if (!result) throw new Error('A base de vulnerabilidades não devolveu um resultado.');

  if (result.isError === true) {
    throw new Error(extractToolText(result) || 'A ferramenta da base de vulnerabilidades falhou.');
  }

  const toolText = extractToolText(result);
  if (!toolText) return [];

  let payload;
  try {
    payload = JSON.parse(toolText);
  } catch {
    throw new Error('A base de vulnerabilidades devolveu um relatório inválido.');
  }

  if (Array.isArray(payload.errors) && payload.errors.length > 0) {
    throw new Error(payload.errors.filter(Boolean).join(' '));
  }

  if (!Array.isArray(payload.affected)) return [];
  return payload.affected.map(normalizeAffected).filter(Boolean);
}

module.exports = {
  DEFAULT_ENDPOINT,
  DEFAULT_TIMEOUT_MS,
  resolveEndpoint,
  parseEventStream,
  parseRpcResponse,
  extractToolText,
  normalizeAffected,
  checkLockfile
};
