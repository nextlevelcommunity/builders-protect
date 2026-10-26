'use strict';

const path = require('node:path');
const { discoverProjects } = require('./discovery');
const { checkLockfile } = require('./cve');
const { summarize } = require('./report');

const packageJson = require('../package.json');

function deduplicateFindings(findings) {
  const unique = new Map();
  for (const finding of findings) {
    const key = [
      finding.projectPath,
      finding.id,
      finding.packageName,
      finding.installedVersion
    ].join('|');
    if (!unique.has(key)) unique.set(key, finding);
  }
  return [...unique.values()];
}

function sortFindings(findings) {
  const order = { critical: 4, high: 3, medium: 2, low: 1, unknown: 0 };
  return findings.sort((left, right) => {
    const severity = (order[right.severity] || 0) - (order[left.severity] || 0);
    if (severity !== 0) return severity;
    const project = left.projectName.localeCompare(right.projectName, 'pt-BR');
    if (project !== 0) return project;
    const pkg = left.packageName.localeCompare(right.packageName, 'pt-BR');
    if (pkg !== 0) return pkg;
    return left.installedVersion.localeCompare(right.installedVersion, 'pt-BR');
  });
}

async function scan(options = {}) {
  const startedAt = new Date();
  const root = path.resolve(options.root || process.cwd());
  const maxProjects = Number.isInteger(options.maxProjects) ? options.maxProjects : 80;
  const discovery = discoverProjects(root, {
    exclude: options.exclude || [],
    maxProjects
  });

  const findings = [];
  const errors = [];
  const warnings = [...discovery.warnings];
  let completed = 0;
  const total = discovery.projects.reduce((sum, project) => sum + project.lockfiles.length, 0);

  for (const project of discovery.projects) {
    for (const lockfile of project.lockfiles) {
      if (typeof options.onProgress === 'function') {
        options.onProgress({
          phase: 'start',
          completed,
          total,
          projectName: project.name,
          lockfile: lockfile.name
        });
      }

      try {
        const matches = await checkLockfile(lockfile, {
          fetchImpl: options.fetchImpl,
          endpoint: options.endpoint,
          timeoutMs: options.timeoutMs
        });
        for (const match of matches) {
          findings.push({
            ...match,
            projectPath: project.path,
            projectName: project.name,
            lockfile: lockfile.name,
            lockfilePath: lockfile.path
          });
        }
      } catch (error) {
        const message = error && error.message ? error.message : String(error);
        errors.push({
          project: project.path,
          lockfile: lockfile.name,
          message
        });
        warnings.push(`Falha ao analisar ${lockfile.name} em ${project.name}: ${message}`);
      } finally {
        completed += 1;
        if (typeof options.onProgress === 'function') {
          options.onProgress({
            phase: 'done',
            completed,
            total,
            projectName: project.name,
            lockfile: lockfile.name
          });
        }
      }
    }
  }

  const uniqueFindings = sortFindings(deduplicateFindings(findings));
  const finishedAt = new Date();

  return {
    schemaVersion: 1,
    tool: {
      name: 'Builders Protect',
      version: packageJson.version,
      runtime: `node ${process.versions.node}`
    },
    root,
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs: finishedAt.getTime() - startedAt.getTime(),
    projects: discovery.projects.map((project) => ({
      path: project.path,
      name: project.name,
      lockfiles: project.lockfiles.map((lockfile) => lockfile.name)
    })),
    findings: uniqueFindings,
    summary: summarize(uniqueFindings),
    warnings,
    errors
  };
}

module.exports = {
  scan,
  deduplicateFindings,
  sortFindings
};
