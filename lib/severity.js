'use strict';

const ORDER = Object.freeze({
  unknown: 0,
  low: 1,
  medium: 2,
  high: 3,
  critical: 4
});

function fromCvss(cvss, isKEV = false) {
  if (isKEV) return 'critical';
  const value = Number(cvss);
  if (!Number.isFinite(value)) return 'unknown';
  if (value >= 9) return 'critical';
  if (value >= 7) return 'high';
  if (value >= 4) return 'medium';
  if (value > 0) return 'low';
  return 'unknown';
}

function rank(severity) {
  const key = String(severity || '').toLowerCase();
  return Object.prototype.hasOwnProperty.call(ORDER, key) ? ORDER[key] : 0;
}

function normalizeThreshold(value) {
  const key = String(value ?? 'high').trim().toLowerCase();
  if (key === 'none' || key === 'off' || key === 'false') return null;
  if (!Object.prototype.hasOwnProperty.call(ORDER, key)) {
    throw new Error(`Valor inválido para fail-on: ${value}. Use none, low, medium, high ou critical.`);
  }
  return key;
}

function meetsThreshold(severity, threshold) {
  if (threshold === null) return false;
  return rank(severity) >= rank(threshold);
}

module.exports = {
  ORDER,
  fromCvss,
  rank,
  normalizeThreshold,
  meetsThreshold
};
