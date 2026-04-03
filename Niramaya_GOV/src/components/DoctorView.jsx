import React, { useState, useEffect } from 'react';
import { ListChecks, AlertTriangle, UserCheck, RefreshCw, Cpu, Database, CheckCircle2, XCircle } from 'lucide-react';
import { api } from '../api';

const DoctorView = () => {
  const [delayMins, setDelayMins] = useState('');
  const [mlHealth, setMlHealth] = useState(null);
  const [healthLoading, setHealthLoading] = useState(true);
  const [retrainResult, setRetrainResult] = useState(null);
  const [retrainLoading, setRetrainLoading] = useState(false);

  useEffect(() => {
    fetchHealth();
  }, []);

  const fetchHealth = async () => {
    setHealthLoading(true);
    try {
      const data = await api.health();
      setMlHealth(data);
    } catch {
      setMlHealth(null);
    }
    setHealthLoading(false);
  };

  const handleRetrain = async () => {
    setRetrainLoading(true);
    setRetrainResult(null);
    try {
      const data = await api.retrain();
      setRetrainResult(data);
      fetchHealth(); // Refresh health after retrain
    } catch (err) {
      setRetrainResult({ status: 'error', message: err.message });
    }
    setRetrainLoading(false);
  };

  const reportDelay = () => {
    if (delayMins) {
      alert(`Delay reported: ${delayMins} min. Queue times recalibrating...`);
      setDelayMins('');
    }
  };

  const nextPatient = () => {
    alert('Moving to next patient. Logging completion time for ML retraining.');
  };

  return (
    <div className="animate-fade-in" style={{ maxWidth: '1000px', margin: '0 auto' }}>
      <div className="flex justify-between items-center" style={{ marginBottom: '1.5rem' }}>
        <h2 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <ListChecks color="#0ea5e9" /> Doctor Dashboard
        </h2>
        <div className="flex gap-2">
          <input type="number" placeholder="Min Delay..." className="form-input" style={{ width: '120px' }}
            value={delayMins} onChange={e => setDelayMins(e.target.value)} />
          <button className="btn btn-outline" onClick={reportDelay}>
            <AlertTriangle size={18} /> Report Delay
          </button>
        </div>
      </div>

      {/* ML Model Status Panel */}
      <div className="glass-panel" style={{ marginBottom: '2rem', borderLeft: '4px solid var(--accent-secondary)' }}>
        <div className="flex justify-between items-center" style={{ marginBottom: '1rem' }}>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Cpu size={20} color="var(--accent-secondary)" /> ML Model Status
          </h3>
          <button className="btn btn-outline" onClick={fetchHealth} style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}>
            <RefreshCw size={14} /> Refresh
          </button>
        </div>

        {healthLoading ? (
          <div style={{ color: 'var(--text-muted)', padding: '1rem' }}>Loading model info...</div>
        ) : mlHealth ? (
          <div className="flex gap-4" style={{ flexWrap: 'wrap' }}>
            <div className="stat-card">
              <div className="stat-label">Status</div>
              <div className="flex items-center gap-2">
                <CheckCircle2 size={18} color="var(--accent-success)" />
                <span style={{ color: 'var(--accent-success)', fontWeight: 600 }}>{mlHealth.status}</span>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Version</div>
              <div style={{ fontWeight: 600 }}>{mlHealth.model_version}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Trained</div>
              <div style={{ fontSize: '0.85rem' }}>{mlHealth.trained_at !== 'unknown' ? new Date(mlHealth.trained_at).toLocaleDateString() : '—'}</div>
            </div>
            {mlHealth.metrics?.mae && (
              <div className="stat-card">
                <div className="stat-label">MAE</div>
                <div style={{ fontWeight: 600 }}>{mlHealth.metrics.mae.toFixed(2)} min</div>
              </div>
            )}
            {mlHealth.metrics?.r2 && (
              <div className="stat-card">
                <div className="stat-label">R² Score</div>
                <div style={{ fontWeight: 600 }}>{mlHealth.metrics.r2.toFixed(3)}</div>
              </div>
            )}
            <div className="stat-card">
              <div className="stat-label">ONNX</div>
              <div>{mlHealth.onnx_available ? '✅ Ready' : '—'}</div>
            </div>
          </div>
        ) : (
          <div className="flex items-center gap-2" style={{ color: 'var(--accent-danger)', padding: '1rem' }}>
            <XCircle size={18} /> ML Service Offline
          </div>
        )}

        {/* Retrain Button */}
        <div style={{ marginTop: '1.5rem', borderTop: '1px solid var(--glass-border)', paddingTop: '1rem' }}>
          <div className="flex items-center gap-4">
            <button className="btn btn-primary" onClick={handleRetrain} disabled={retrainLoading}
              style={{ padding: '0.6rem 1.2rem', fontSize: '0.9rem' }}>
              <Database size={16} /> {retrainLoading ? 'Retraining...' : 'Retrain Model'}
            </button>
            {retrainResult && (
              <div className="animate-fade-in" style={{ fontSize: '0.85rem' }}>
                {retrainResult.status === 'completed' ? (
                  <span style={{ color: 'var(--accent-success)' }}>
                    ✅ Retrained ({retrainResult.model}) — MAE: {retrainResult.new_mae?.toFixed(2)} | Source: {retrainResult.data_source} | {retrainResult.training_records} records
                  </span>
                ) : (
                  <span style={{ color: 'var(--accent-danger)' }}>❌ {retrainResult.message || 'Retrain failed'}</span>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Current Patient */}
      <div className="glass-panel" style={{ marginBottom: '2rem', borderLeft: '4px solid var(--accent-primary)' }}>
        <div className="flex justify-between items-center">
          <div>
            <div style={{ color: 'var(--text-secondary)' }}>Current Patient</div>
            <h3 style={{ fontSize: '1.8rem', marginTop: '0.5rem' }}>TCK-4812</h3>
            <p className="mt-1" style={{ color: 'var(--text-muted)' }}>Follow-up • Arrived 10 mins ago</p>
          </div>
          <div>
            <button className="btn btn-primary" onClick={nextPatient} style={{ padding: '1rem 2rem' }}>
              <UserCheck size={20} /> Mark Done & Next
            </button>
          </div>
        </div>
      </div>

      {/* Queue */}
      <h3 style={{ marginBottom: '1rem', color: 'var(--text-secondary)' }}>Upcoming Queue</h3>
      <div className="glass-panel" style={{ padding: '0' }}>
        {[
          { id: 'TCK-4813', type: 'ROUTINE', ETA: '10:45 AM' },
          { id: 'TCK-4814', type: 'CRITICAL', ETA: '10:55 AM' },
          { id: 'TCK-4815', type: 'ROUTINE', ETA: '11:15 AM' },
        ].map((p, i) => (
          <div key={i} className="flex justify-between items-center" style={{
            padding: '1rem 1.5rem',
            borderBottom: i !== 2 ? '1px solid var(--glass-border)' : 'none',
            background: p.type === 'CRITICAL' ? 'rgba(225, 29, 72, 0.05)' : 'transparent',
          }}>
            <div className="flex items-center gap-4">
              <div style={{ fontSize: '1.2rem', fontWeight: 600 }}>{p.id}</div>
              {p.type === 'CRITICAL' && (
                <span style={{ padding: '0.2rem 0.6rem', background: 'rgba(225, 29, 72, 0.2)', color: 'var(--accent-danger)', borderRadius: '1rem', fontSize: '0.8rem', fontWeight: 600 }}>
                  CRITICAL
                </span>
              )}
            </div>
            <div style={{ color: 'var(--text-secondary)' }}>Est: {p.ETA}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default DoctorView;
