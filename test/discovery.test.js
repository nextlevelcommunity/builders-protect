'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  discoverProjects,
  findLinkedWorktree,
  isLinkedWorktree,
  registeredWorktrees,
  worktreeMainRoot
} = require('../lib/discovery');

function write(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
}

test('descobre projetos, ignora node_modules e respeita limite', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-discovery-'));
  try {
    write(path.join(root, 'package.json'), JSON.stringify({ name: 'app-principal' }));
    write(path.join(root, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');
    write(path.join(root, 'node_modules', 'ignorado', 'package.json'), '{}');
    write(path.join(root, 'node_modules', 'ignorado', 'package-lock.json'), '{}');
    write(path.join(root, 'servicos', 'api', 'Cargo.toml'), '[package]\nname = "api"');
    write(path.join(root, 'servicos', 'api', 'Cargo.lock'), 'version = 3\n');
    write(path.join(root, 'sem-lockfile', 'package.json'), '{"name":"sem-lock"}');

    const discovery = discoverProjects(root, { maxProjects: 10 });
    assert.equal(discovery.projects.length, 2);
    assert.deepEqual(
      discovery.projects.map((project) => project.name).sort(),
      ['api', 'app-principal']
    );
    assert.ok(discovery.projects.every((project) => project.lockfiles.length === 1));
    assert.ok(discovery.projects.every((project) => !project.path.includes('node_modules')));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('resolve worktree para a pasta principal', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-worktree-'));
  try {
    const main = path.join(root, 'main');
    const worktree = path.join(root, 'worktrees', 'feature');
    write(path.join(main, '.git', 'worktrees', 'feature', 'gitdir'), `${worktree}/.git\n`);
    write(path.join(worktree, '.git'), `gitdir: ${main}/.git/worktrees/feature\n`);

    assert.equal(worktreeMainRoot(worktree), main);
    assert.equal(isLinkedWorktree(worktree), true);
    assert.deepEqual(findLinkedWorktree(path.join(worktree, 'app')), {
      worktree,
      main
    });
    assert.deepEqual(registeredWorktrees(main), [worktree]);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('escaneia a pasta principal e ignora worktree registrada', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-worktree-scan-'));
  try {
    const main = path.join(root, 'main');
    const worktree = path.join(root, 'worktrees', 'feature');
    write(path.join(main, 'package.json'), JSON.stringify({ name: 'main' }));
    write(path.join(main, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');
    write(path.join(main, '.git', 'worktrees', 'feature', 'gitdir'), `${worktree}/.git\n`);
    write(path.join(worktree, '.git'), `gitdir: ${main}/.git/worktrees/feature\n`);
    write(path.join(worktree, 'package.json'), JSON.stringify({ name: 'feature' }));
    write(path.join(worktree, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');

    const fromMain = discoverProjects(main);
    assert.deepEqual(fromMain.projects.map((project) => project.name), ['main']);
    assert.ok(fromMain.warnings.some((warning) => warning.includes('worktree')));

    const fromWorktree = discoverProjects(worktree);
    assert.equal(fromWorktree.root, main);
    assert.deepEqual(fromWorktree.projects.map((project) => project.name), ['main']);
    assert.ok(fromWorktree.warnings.some((warning) => warning.includes('pasta principal')));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('ignora worktree aninhada mesmo sem metadados de registro', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-worktree-nested-'));
  try {
    const main = path.join(root, 'main');
    const worktree = path.join(main, '.worktrees', 'feature');
    write(path.join(main, 'package.json'), JSON.stringify({ name: 'main' }));
    write(path.join(main, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');
    write(path.join(main, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    write(path.join(worktree, '.git'), `gitdir: ${main}/.git/worktrees/feature\n`);
    write(path.join(worktree, 'package.json'), JSON.stringify({ name: 'feature' }));
    write(path.join(worktree, 'package-lock.json'), '{"lockfileVersion":3,"packages":{}}');

    const discovery = discoverProjects(main);
    assert.deepEqual(discovery.projects.map((project) => project.name), ['main']);
    assert.ok(discovery.warnings.some((warning) => warning.includes('worktree ignorada')));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('ignora pasta excluída', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'builders-protect-exclude-'));
  try {
    write(path.join(root, 'a', 'package.json'), '{"name":"a"}');
    write(path.join(root, 'a', 'package-lock.json'), '{}');
    write(path.join(root, 'b', 'package.json'), '{"name":"b"}');
    write(path.join(root, 'b', 'package-lock.json'), '{}');

    const discovery = discoverProjects(root, { exclude: ['b'] });
    assert.equal(discovery.projects.length, 1);
    assert.equal(discovery.projects[0].name, 'a');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
