/**
 * Niramaya-Net API Layer
 * Central config for ML Service (port 8001)
 */

const ML_BASE = 'http://localhost:8001';

// Hardcoded until the dedicated app handles auto-selection
export const DEFAULT_HOSPITAL_ID = 'HOSP-001';

export const DEPARTMENTS = [
  'General',
  'Cardiology',
  'Orthopedics',
  'Neurology',
  'Pediatrics',
  'Emergency',
  'Dermatology',
  'ENT',
  'Ophthalmology',
  'Gynecology',
];

async function request(endpoint, options = {}) {
  const url = `${ML_BASE}${endpoint}`;
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const err = await res.text().catch(() => res.statusText);
    throw new Error(`API ${res.status}: ${err}`);
  }
  return res.json();
}

// ── Endpoint Wrappers ──

export const api = {
  /** POST /calculate-priority */
  calculatePriority(payload) {
    return request('/calculate-priority', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  },

  /** POST /predict */
  predictWaitTime(payload) {
    return request('/predict', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  },

  /** GET /predict-outbreak */
  predictOutbreak() {
    return request('/predict-outbreak');
  },

  /** POST /ml/retrain */
  retrain() {
    return request('/ml/retrain', { method: 'POST' });
  },

  /** GET /ml/health */
  health() {
    return request('/ml/health');
  },

  /** GET / (root ping) */
  ping() {
    return request('/');
  },
};
