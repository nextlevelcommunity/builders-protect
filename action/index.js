'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { scan } = require('../lib/scan');
const { normalizeThreshold, meetsThreshold } = require('../lib/severity');
const { toMarkdown, toSarif } = require('../lib/report');

function readInput(name, fallback) {
  const upper = name.replace(/ /g, '_').toUpperCase();
  const candidates = [
    `INPUT_${upper}`,
    `INPUT_${upper.replace(/-/g, '_')}`,
    `INPUT_${upper.replace(/_/g, '-')}`
  ];
  for (const key of candidates) {
    if (Object.prototype.hasOwnProperty.call(process.env, key)) return process.env[key];
  }
  return fallback;
}

function escapeData(value) {
  return String(value)
    .replace(/%/g, '%25')
    .replace(/\r/g, '%0D')
    .replace(/\n/g, '%0A');
}

function escapeProperty(value) {
  return escapeData(value)
    .replace(/:/g, '%3A')
    .replace(/,/g, '%2C');
}

function appendFile(filePath, content) {
  if (!filePath) return;
  fs.appendFileSync(filePath, content, 'utf8');
}

function setOutput(name, value) {
  appendFile(process.env.GITHUB_OUTPUT, `${name}=${value}\n`);
}

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
}

function resolveWorkspacePath(workspace, value) {
  if (!value) return null;
  return path.isAbsolute(value) ? path.normalize(value) : path.resolve(workspace, value);
}

function annotate(report, workspace) {
  if (process.env.GITHUB_ACTIONS !== 'true') return;

  for (const error of report.errors.slice(0, 20)) {
    const file = path.relative(workspace, error.project || workspace) || error.lockfile || 'lockfile';
    console.log(
      `::error file=${escapeProperty(file)},title=${escapeProperty('Builders Protect')}::` +
      escapeData(`${error.lockfile || 'lockfile'}: ${error.message}`)
    );
  }

  for (const finding of report.findings.slice(0, 20)) {
    const file = path.relative(workspace, finding.lockfilePath || workspace) || finding.lockfile;
    const level = finding.severity === 'critical' || finding.severity === 'high' ? 'error' : 'warning';
    const title = `${finding.severity.toUpperCase()}: ${finding.packageName}@${finding.installedVersion}`;
    const message = `${finding.id} — ${finding.title} (${finding.projectName})`;
    console.log(
      `::${level} file=${escapeProperty(file)},line=1,title=${escapeProperty(title)}::${escapeData(message)}`
    );
  }
}

async function main() {
  const workspace = process.env.GITHUB_WORKSPACE || process.cwd();
  const inputPath = readInput('path', '.') || '.';
  const root = path.isAbsolute(inputPath) ? inputPath : path.resolve(workspace, inputPath);
  const failOn = readInput('fail-on', 'high');
  const threshold = normalizeThreshold(failOn);
  const exclude = String(readInput('exclude', '') || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  const maxProjectsRaw = readInput('max-projects', '80');
  const maxProjects = Number.parseInt(maxProjectsRaw, 10);

  if (!Number.isInteger(maxProjects) || maxProjects < 1) {
    throw new Error(`max-projects inválido: ${maxProjectsRaw}`);
  }

  const sarifPath = resolveWorkspacePath(workspace, readInput('sarif-file', 'builders-protect.sarif'));
  const jsonPath = resolveWorkspacePath(workspace, readInput('json-file', 'builders-protect.json'));

  const report = await scan({
    root,
    exclude,
    maxProjects,
    onProgress: (event) => {
      if (event.phase === 'start') {
        console.log(`Builders Protect: analisando ${event.projectName} (${event.lockfile})`);
      }
    }
  });

  if (sarifPath) {
    writeFile(sarifPath, `${JSON.stringify(toSarif(report), null, 2)}\n`);
  }
  if (jsonPath) {
    writeFile(jsonPath, `${JSON.stringify(report, null, 2)}\n`);
  }

  const markdown = toMarkdown(report);
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFile(process.env.GITHUB_STEP_SUMMARY, markdown);
  } else {
    process.stdout.write(markdown);
  }

  setOutput('findings-count', report.summary.total);
  setOutput('critical-count', report.summary.critical);
  setOutput('high-count', report.summary.high);
  if (sarifPath) setOutput('sarif-file', sarifPath);
  if (jsonPath) setOutput('json-file', jsonPath);

  annotate(report, workspace);

  if (report.errors.length > 0) {
    console.log(
      `::error title=${escapeProperty('Builders Protect')}::` +
      escapeData(`${report.errors.length} lockfile(s) não puderam ser analisados.`)
    );
    return 2;
  }

  const failed = report.findings.some((finding) => meetsThreshold(finding.severity, threshold));
  if (failed) {
    console.log(
      `::error title=${escapeProperty('Builders Protect')}::` +
      escapeData(`${report.summary.total} achado(s). Limite configurado: ${failOn}.`)
    );
    return 1;
  }

  return 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    const message = error && error.message ? error.message : String(error);
    console.log(`::error title=${escapeProperty('Builders Protect')}::${escapeData(message)}`);
    process.exitCode = 2;
  });
