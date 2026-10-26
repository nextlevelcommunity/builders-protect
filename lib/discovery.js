'use strict';

const fs = require('node:fs');
const path = require('node:path');

const LOCKFILES = Object.freeze({
  'package-lock.json': 'npm',
  'npm-shrinkwrap.json': 'npm',
  'pnpm-lock.yaml': 'npm',
  'yarn.lock': 'npm',
  'bun.lock': 'npm',
  'requirements.txt': 'pypi',
  'poetry.lock': 'pypi',
  'Cargo.lock': 'cargo',
  'go.sum': 'go',
  'Gemfile.lock': 'rubygems',
  'mix.lock': 'hex',
  'flake.lock': 'nix'
});

const MARKERS = new Set([
  'package.json',
  'pnpm-workspace.yaml',
  'pyproject.toml',
  'requirements.txt',
  'Cargo.toml',
  'go.mod',
  'Gemfile',
  'mix.exs',
  'flake.nix',
  'composer.json',
  'deno.json'
]);

const HEAVY_DIRECTORIES = new Set([
  'node_modules', '.git', '.next', 'dist', 'build', '.build', 'vendor',
  'Pods', 'DerivedData', 'Library', '.venv', 'venv', '__pycache__',
  'target', 'coverage', '.turbo', '.cache', '.expo', '.nuxt', '.output',
  'out', 'tmp', 'temp', 'logs', '.idea', '.vscode'
]);

const MAX_LOCKFILE_BYTES = 1_800_000;

function normalizeExclusions(values, root) {
  const list = [];
  for (const raw of values || []) {
    if (!raw) continue;
    for (const part of String(raw).split(',')) {
      const trimmed = part.trim();
      if (!trimmed) continue;
      const resolved = path.isAbsolute(trimmed)
        ? path.normalize(trimmed)
        : path.resolve(root, trimmed);
      if (!list.includes(resolved)) list.push(resolved);
    }
  }
  return list;
}

function isExcluded(absolutePath, exclusions) {
  return exclusions.some((excluded) => {
    return absolutePath === excluded || absolutePath.startsWith(`${excluded}${path.sep}`);
  });
}

function readGitdir(directory) {
  const dotGit = path.join(directory, '.git');
  let stat;
  try {
    stat = fs.statSync(dotGit);
  } catch {
    return null;
  }
  if (!stat.isFile()) return null;

  let content;
  try {
    content = fs.readFileSync(dotGit, 'utf8');
  } catch {
    return null;
  }

  const line = content.split(/\r?\n/).find((item) => /^gitdir:/i.test(item.trim()));
  if (!line) return null;
  const raw = line.trim().slice('gitdir:'.length).trim();
  if (!raw) return null;
  return path.isAbsolute(raw) ? path.normalize(raw) : path.resolve(directory, raw);
}

function worktreeMainRoot(directory) {
  const gitdir = readGitdir(directory);
  if (!gitdir) return null;
  const normalized = gitdir.replace(/\\/g, '/');
  const marker = '/.git/worktrees/';
  const index = normalized.lastIndexOf(marker);
  if (index < 0) return null;
  const main = normalized.slice(0, index);
  return main ? path.normalize(main) : null;
}

function isLinkedWorktree(directory) {
  return worktreeMainRoot(directory) !== null;
}

function findLinkedWorktree(start) {
  let current = path.resolve(start);
  while (true) {
    const main = worktreeMainRoot(current);
    if (main) return { worktree: current, main };

    const dotGit = path.join(current, '.git');
    try {
      if (fs.statSync(dotGit).isDirectory()) return null;
    } catch {
      // Keep walking up until a repository or the filesystem root is found.
    }

    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function registeredWorktrees(mainRoot) {
  const worktreesDirectory = path.join(mainRoot, '.git', 'worktrees');
  let entries;
  try {
    entries = fs.readdirSync(worktreesDirectory, { withFileTypes: true });
  } catch {
    return [];
  }

  const found = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const entryDirectory = path.join(worktreesDirectory, entry.name);
    let raw;
    try {
      raw = fs.readFileSync(path.join(entryDirectory, 'gitdir'), 'utf8').trim();
    } catch {
      continue;
    }
    if (!raw) continue;
    const gitdir = path.isAbsolute(raw) ? path.normalize(raw) : path.resolve(entryDirectory, raw);
    const worktree = path.dirname(gitdir);
    if (!fs.existsSync(worktree) || !isLinkedWorktree(worktree)) continue;
    if (path.resolve(worktree) === path.resolve(mainRoot)) continue;
    if (!found.includes(worktree)) found.push(worktree);
  }
  return found;
}

function looksBinary(buffer) {
  const sample = buffer.subarray(0, Math.min(buffer.length, 8192));
  return sample.includes(0);
}

function readProjectName(directory, entries) {
  if (!entries.has('package.json')) return path.basename(directory);
  try {
    const raw = fs.readFileSync(path.join(directory, 'package.json'), 'utf8');
    const parsed = JSON.parse(raw);
    if (typeof parsed.name === 'string' && parsed.name.trim()) return parsed.name.trim();
  } catch {
    // A malformed manifest should not stop the scan.
  }
  return path.basename(directory);
}

function readLockfile(lockfilePath, name, ecosystem, warnings) {
  let stat;
  try {
    stat = fs.statSync(lockfilePath);
  } catch (error) {
    warnings.push(`Não consegui ler ${name}: ${error.message}`);
    return null;
  }

  if (stat.size > MAX_LOCKFILE_BYTES) {
    warnings.push(`${name} tem ${stat.size} bytes e foi ignorado (limite de ${MAX_LOCKFILE_BYTES}).`);
    return null;
  }

  let buffer;
  try {
    buffer = fs.readFileSync(lockfilePath);
  } catch (error) {
    warnings.push(`Não consegui ler ${name}: ${error.message}`);
    return null;
  }

  if (looksBinary(buffer)) {
    warnings.push(`${name} parece binário e foi ignorado.`);
    return null;
  }

  return {
    name,
    path: lockfilePath,
    ecosystem,
    content: buffer.toString('utf8')
  };
}

function discoverProjects(root, options = {}) {
  let absoluteRoot = path.resolve(root);
  const maxDepth = Number.isInteger(options.maxDepth) ? options.maxDepth : 8;
  const maxProjects = Number.isInteger(options.maxProjects) ? options.maxProjects : 80;
  const warnings = [];
  const projects = [];
  const seen = new Set();

  if (!fs.existsSync(absoluteRoot)) {
    throw new Error(`A pasta não existe: ${absoluteRoot}`);
  }

  const rootStat = fs.statSync(absoluteRoot);
  if (!rootStat.isDirectory()) {
    throw new Error(`O caminho não é uma pasta: ${absoluteRoot}`);
  }

  const linked = findLinkedWorktree(absoluteRoot);
  if (linked && fs.existsSync(linked.main)) {
    warnings.push(`Worktree detectada; usando a pasta principal ${linked.main}.`);
    absoluteRoot = path.resolve(linked.main);
  }

  const registered = registeredWorktrees(absoluteRoot);
  const exclusions = normalizeExclusions(
    [...(options.exclude || []), ...registered],
    absoluteRoot
  );
  let autoIgnoredWorktrees = registered.length;

  function walk(directory, depth) {
    if (projects.length >= maxProjects) return;
    if (depth > maxDepth || isExcluded(directory, exclusions)) return;
    if (isLinkedWorktree(directory)) {
      autoIgnoredWorktrees += 1;
      return;
    }

    let entries;
    try {
      entries = fs.readdirSync(directory, { withFileTypes: true });
    } catch (error) {
      warnings.push(`Não consegui ler ${directory}: ${error.message}`);
      return;
    }

    const names = new Set(entries.map((entry) => entry.name));
    const lockfileNames = Object.keys(LOCKFILES).filter((name) => names.has(name));
    const isProject = lockfileNames.length > 0 || [...MARKERS].some((name) => names.has(name));

    if (isProject && lockfileNames.length > 0) {
      const projectPath = path.resolve(directory);
      if (!seen.has(projectPath)) {
        const lockfiles = [];
        for (const name of lockfileNames) {
          const lockfile = readLockfile(
            path.join(directory, name),
            name,
            LOCKFILES[name],
            warnings
          );
          if (lockfile) lockfiles.push(lockfile);
        }

        if (lockfiles.length > 0) {
          seen.add(projectPath);
          projects.push({
            path: projectPath,
            name: readProjectName(directory, names),
            lockfiles
          });
        }
      }
    }

    if (projects.length >= maxProjects) return;

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.') && entry.name !== '.worktrees') continue;
      if (HEAVY_DIRECTORIES.has(entry.name)) continue;
      walk(path.join(directory, entry.name), depth + 1);
      if (projects.length >= maxProjects) return;
    }
  }

  walk(absoluteRoot, 0);

  if (autoIgnoredWorktrees > 0) {
    const noun = autoIgnoredWorktrees === 1 ? 'worktree ignorada' : 'worktrees ignoradas';
    warnings.push(`${autoIgnoredWorktrees} ${noun} automaticamente.`);
  }
  if (projects.length === 0) {
    warnings.push('Nenhum projeto com lockfile foi encontrado.');
  } else if (projects.length >= maxProjects) {
    warnings.push(`Limite de ${maxProjects} projetos por varredura atingido.`);
  }

  return {
    root: absoluteRoot,
    projects,
    warnings
  };
}

module.exports = {
  LOCKFILES,
  MARKERS,
  HEAVY_DIRECTORIES,
  MAX_LOCKFILE_BYTES,
  discoverProjects,
  findLinkedWorktree,
  isLinkedWorktree,
  normalizeExclusions,
  registeredWorktrees,
  worktreeMainRoot,
  isExcluded
};
