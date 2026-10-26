'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { discoverProjects } = require('../lib/discovery');

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
