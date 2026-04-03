import React, { useState, useEffect, useCallback } from 'react';
import { Wifi, WifiOff, CheckCircle2, XCircle, RefreshCw, Clock } from 'lucide-react';
import { api } from '../api';

const ENDPOINTS = [
  { name: 'Root Ping', key: 'ping', fn: () => api.ping(), method: 'GET', path: '/' },
  { name: 'ML Health', key: 'health', fn: () => api.health(), method: 'GET', path: '/ml/health' },
  { name: 'Epidemic Radar', key: 'outbreak', fn: () => api.predictOutbreak(), method: 'GET', path: '/predict-outbreak' },
];

const ConnectionStatus = () => {
  const [results, setResults] = useState({});
  const [testing, setTesting] = useState(false);
  const [lastChecked, setLastChecked] = useState(null);

  const runTests = useCallback(async () => {
    setTesting(true);
    const newResults = {};

    for (const ep of ENDPOINTS) {
      const start = performance.now();
      try {
        const data = await ep.fn();
        newResults[ep.key] = {
          status: 'ok',
          ms: Math.round(performance.now() - start),
          data,
        };
      } catch (err) {
        newResults[ep.key] = {
          status: 'error',
          ms: Math.round(performance.now() - start),
          error: err.message,
        };
      }
    }

    setResults(newResults);
    setLastChecked(new Date());
    setTesting(false);
  }, []);

  useEffect(() => {
    runTests();
    const interval = setInterval(runTests, 30000);
    return () => clearInterval(interval);
  }, [runTests]);

  const allOk = Object.values(results).length > 0 && Object.values(results).every(r => r.status === 'ok');
  const healthData = results.health?.data;

  return (
    <div className="animate-fade-in" style={{ maxWidth: '800px', margin: '0 auto' }}>
      <div className="flex justify-between items-center" style={{ marginBottom: '1.5rem' }}>
        <h2 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          {allOk ? <Wifi color="var(--accent-success)" /> : <WifiOff color="var(--accent-danger)" />}
          Connection Status
        </h2>
        <div className="flex items-center gap-4">
          {lastChecked && (
            <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
              <Clock size={12} /> {lastChecked.toLocaleTimeString()}
            </span>
          )}
          <button className="btn btn-outline" onClick={runTests} disabled={testing}
            style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}>
            <RefreshCw size={14} className={testing ? 'spin' : ''} /> {testing ? 'Testing...' : 'Test All'}
          </button>
        </div>
      </div>

      {/* Overall Status */}
      <div className="glass-panel" style={{
        marginBottom: '1.5rem',
        borderLeft: `4px solid ${allOk ? 'var(--accent-success)' : 'var(--accent-danger)'}`,
        textAlign: 'center', padding: '2rem',
      }}>
        <div style={{ fontSize: '3rem', marginBottom: '0.5rem' }}>{allOk ? '✅' : '⚠️'}</div>
        <div style={{ fontSize: '1.3rem', fontWeight: 600, fontFamily: 'var(--font-heading)' }}>
          {allOk ? 'All Systems Operational' : 'Connection Issues Detected'}
        </div>
        <div style={{ color: 'var(--text-muted)', marginTop: '0.5rem', fontSize: '0.9rem' }}>
          ML Service: http://localhost:8001
        </div>
      </div>

      {/* Per-Endpoint Results */}
      <div className="glass-panel" style={{ padding: 0, marginBottom: '1.5rem' }}>
        {ENDPOINTS.map((ep, i) => {
          const r = results[ep.key];
          return (
            <div key={ep.key} className="flex justify-between items-center" style={{
              padding: '1rem 1.5rem',
              borderBottom: i !== ENDPOINTS.length - 1 ? '1px solid var(--glass-border)' : 'none',
            }}>
              <div>
                <div style={{ fontWeight: 600 }}>{ep.name}</div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>
                  {ep.method} {ep.path}
                </div>
              </div>
              <div className="flex items-center gap-4">
                {r ? (
                  <>
                    <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>{r.ms}ms</span>
                    {r.status === 'ok' ? (
                      <CheckCircle2 size={20} color="var(--accent-success)" />
                    ) : (
                      <XCircle size={20} color="var(--accent-danger)" />
                    )}
                  </>
                ) : (
                  <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>pending...</span>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Model Details (from health endpoint) */}
      {healthData && (
        <div className="glass-panel">
          <h3 style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            Model Details
          </h3>
          <div className="flex gap-4" style={{ flexWrap: 'wrap' }}>
            <div className="stat-card">
              <div className="stat-label">Status</div>
              <div style={{ color: 'var(--accent-success)', fontWeight: 600 }}>{healthData.status}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Version</div>
              <div style={{ fontWeight: 600 }}>{healthData.model_version}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Trained</div>
              <div style={{ fontSize: '0.85rem' }}>
                {healthData.trained_at !== 'unknown' ? new Date(healthData.trained_at).toLocaleDateString() : '—'}
              </div>
            </div>
            {healthData.metrics?.mae && (
              <div className="stat-card">
                <div className="stat-label">MAE</div>
                <div style={{ fontWeight: 600 }}>{healthData.metrics.mae.toFixed(2)} min</div>
              </div>
            )}
            {healthData.metrics?.r2 && (
              <div className="stat-card">
                <div className="stat-label">R²</div>
                <div style={{ fontWeight: 600 }}>{healthData.metrics.r2.toFixed(3)}</div>
              </div>
            )}
            <div className="stat-card">
              <div className="stat-label">ONNX</div>
              <div>{healthData.onnx_available ? '✅' : '—'}</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ConnectionStatus;
