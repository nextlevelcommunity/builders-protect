'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { fromCvss, normalizeThreshold, meetsThreshold, rank } = require('../lib/severity');

test('classifica CVSS e KEV', () => {
  assert.equal(fromCvss(9.8), 'critical');
  assert.equal(fromCvss(8.1), 'high');
  assert.equal(fromCvss(5.0), 'medium');
  assert.equal(fromCvss(2.0), 'low');
  assert.equal(fromCvss(null), 'unknown');
  assert.equal(fromCvss(4.0, true), 'critical');
});

test('compara severidades e limites', () => {
  assert.ok(rank('critical') > rank('high'));
  assert.equal(normalizeThreshold('none'), null);
  assert.equal(meetsThreshold('high', 'high'), true);
  assert.equal(meetsThreshold('medium', 'high'), false);
  assert.equal(meetsThreshold('critical', 'high'), true);
  assert.equal(meetsThreshold('critical', null), false);
});

test('rejeita limite inválido', () => {
  assert.throws(() => normalizeThreshold('urgent'), /fail-on/);
});
