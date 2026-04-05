import React, { useState } from 'react';
import { UserPlus, ShieldAlert, Clock, Thermometer, Heart, Gauge } from 'lucide-react';
import { api, DEFAULT_HOSPITAL_ID, DEPARTMENTS } from '../api';

const StaffView = () => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    abha: '',
    symptoms: '',
    pain_level: 5,
    temperature: 98.6,
    heart_rate: 75,
    systolic_bp: 120,
    is_emergency: false,
    department_type: 'General',
  });
  const [result, setResult] = useState(null);
  const [apiStatus, setApiStatus] = useState(null);

  const handleWalkIn = async (e) => {
    e.preventDefault();
    setLoading(true);
    setResult(null);
    setApiStatus(null);

    const priorityPayload = {
      symptoms: formData.symptoms ? formData.symptoms.split(',').map(s => s.trim()).filter(Boolean) : [],
      pain_level: parseInt(formData.pain_level),
      age: 30, // Default for walk-in if not collected
      temperature: parseFloat(formData.temperature),
      heart_rate: parseInt(formData.heart_rate),
      systolic_bp: parseInt(formData.systolic_bp),
      is_emergency: formData.is_emergency,
    };

    try {
      const priority = await api.calculatePriority(priorityPayload);
      const prediction = await api.predictWaitTime({
        hospital_id: DEFAULT_HOSPITAL_ID,
        department_type: formData.department_type,
      });

      setResult({
        ticketId: 'WLK-' + Math.floor(Math.random() * 9000 + 1000),
        category: priority.category,
        priorityScore: priority.priority_score,
        overrideToFront: priority.override_to_front,
        predictedWait: prediction.predicted_wait_minutes,
        department: formData.department_type,
      });
      setApiStatus('live');
    } catch (err) {
      console.error('ML Service Error:', err);
      setResult({
        ticketId: 'WLK-' + Math.floor(Math.random() * 9000 + 1000),
        category: formData.is_emergency ? 'CRITICAL' : 'ROUTINE',
        priorityScore: formData.is_emergency ? 10 : 3,
        overrideToFront: formData.is_emergency,
        predictedWait: formData.is_emergency ? 0 : 20,
        department: formData.department_type,
      });
      setApiStatus('fallback');
    }
    setLoading(false);
  };

  const categoryColor = (cat) => {
    switch (cat) {
      case 'CRITICAL': return 'var(--accent-danger)';
      case 'URGENT': return 'var(--accent-warning)';
      case 'MODERATE': return 'var(--accent-primary)';
      default: return 'var(--accent-success)';
    }
  };

  return (
    <div className="animate-fade-in" style={{ maxWidth: '900px', margin: '0 auto' }}>
      <h2 style={{ marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
        <UserPlus color="#0ea5e9" /> Reception Walk-in Check-in
      </h2>

      <div className="glass-panel text-center" style={{ padding: '1rem 2rem', color: 'var(--text-muted)', marginBottom: '2rem', fontSize: '0.9rem' }}>
        Check-in walk-in patients. The system will auto-calculate triage priority and predict wait time via ML.
      </div>

      <div className="flex gap-4" style={{ flexWrap: 'wrap' }}>
        {/* Form */}
        <div className="glass-panel" style={{ flex: 1, minWidth: '320px' }}>
          <form onSubmit={handleWalkIn}>
            <div className="flex gap-4" style={{ marginBottom: '1rem' }}>
              <div style={{ flex: 1 }}>
                <label className="form-label">Full Name</label>
                <input type="text" className="form-input" required
                  value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
              </div>
              <div style={{ flex: 1 }}>
                <label className="form-label">ABHA ID / Phone</label>
                <input type="text" className="form-input" required
                  value={formData.abha} onChange={e => setFormData({...formData, abha: e.target.value})} />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Department</label>
              <select className="form-input" value={formData.department_type}
                onChange={e => setFormData({...formData, department_type: e.target.value})}>
                {DEPARTMENTS.map(d => <option key={d} value={d}>{d}</option>)}
              </select>
            </div>

            <div className="form-group">
              <label className="form-label">Symptoms (comma separated, optional)</label>
              <input type="text" className="form-input" placeholder="e.g. Fever, Cough"
                value={formData.symptoms} onChange={e => setFormData({...formData, symptoms: e.target.value})} />
            </div>

            {/* Vitals */}
            <div className="vitals-section">
              <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', marginBottom: '0.75rem' }}>
                <Heart size={16} color="var(--accent-danger)" /> Vitals
              </label>
              <div className="flex gap-4">
                <div style={{ flex: 1 }}>
                  <label className="form-label" style={{ fontSize: '0.8rem' }}><Thermometer size={14} /> Temp °F</label>
                  <input type="number" step="0.1" className="form-input" value={formData.temperature}
                    onChange={e => setFormData({...formData, temperature: e.target.value})} />
                </div>
                <div style={{ flex: 1 }}>
                  <label className="form-label" style={{ fontSize: '0.8rem' }}><Heart size={14} /> HR</label>
                  <input type="number" className="form-input" value={formData.heart_rate}
                    onChange={e => setFormData({...formData, heart_rate: e.target.value})} />
                </div>
                <div style={{ flex: 1 }}>
                  <label className="form-label" style={{ fontSize: '0.8rem' }}><Gauge size={14} /> BP</label>
                  <input type="number" className="form-input" value={formData.systolic_bp}
                    onChange={e => setFormData({...formData, systolic_bp: e.target.value})} />
                </div>
              </div>
            </div>

            <div className="flex gap-4 items-center" style={{ marginBottom: '1.5rem' }}>
              <div style={{ flex: 1 }}>
                <label className="form-label">Pain Level</label>
                <input type="range" min="0" max="10" style={{ width: '100%', accentColor: 'var(--accent-primary)' }}
                  value={formData.pain_level} onChange={e => setFormData({...formData, pain_level: e.target.value})} />
                <div className="text-center" style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>{formData.pain_level}/10</div>
              </div>
              <div style={{ flex: 1, background: 'rgba(239, 68, 68, 0.1)', padding: '1rem', borderRadius: '0.5rem', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
                <label className="form-label" style={{ color: 'var(--accent-danger)', display: 'flex', alignItems:'center', gap:'0.5rem', marginBottom: 0, cursor: 'pointer' }}>
                  <input type="checkbox" checked={formData.is_emergency}
                    onChange={e => setFormData({...formData, is_emergency: e.target.checked})}
                    style={{ transform: 'scale(1.2)' }}/>
                  <ShieldAlert size={18} /> Emergency Override
                </label>
              </div>
            </div>

            <button type="submit" className={`btn ${formData.is_emergency ? 'btn-danger pulse-emergency' : 'btn-primary'}`} style={{ width: '100%' }} disabled={loading}>
              {loading ? 'Processing...' : 'Register Walk-in to Queue'}
            </button>
          </form>
        </div>

        {/* Result */}
        {result && (
          <div className="glass-panel animate-fade-in" style={{ flex: 1, minWidth: '280px', borderLeft: `4px solid ${categoryColor(result.category)}` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3>Triage Result</h3>
              <span className={`status-badge ${apiStatus === 'live' ? 'status-live' : 'status-offline'}`}>
                {apiStatus === 'live' ? '● ML Live' : '● Offline'}
              </span>
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <span style={{ background: categoryColor(result.category), color: 'white', padding: '0.3rem 0.8rem', borderRadius: '1rem', fontWeight: 600, fontSize: '0.85rem' }}>
                {result.category}
              </span>
              <span style={{ marginLeft: '0.75rem', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                Score: {result.priorityScore}/10
              </span>
            </div>

            <div style={{ padding: '1.5rem', background: 'var(--bg-tertiary)', borderRadius: '0.5rem', marginBottom: '1rem' }}>
              <div style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>Ticket</div>
              <div style={{ fontSize: '1.8rem', fontWeight: 700, fontFamily: 'var(--font-heading)' }}>{result.ticketId}</div>
              <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '0.25rem' }}>{result.department}</div>
            </div>

            <div className="flex items-center gap-4" style={{ padding: '1rem', background: 'rgba(16, 185, 129, 0.1)', borderRadius: '0.5rem', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
              <Clock size={28} color="var(--accent-success)" />
              <div>
                <div style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>Predicted Wait</div>
                <div style={{ fontSize: '1.3rem', fontWeight: 600 }}>{result.predictedWait} min</div>
              </div>
            </div>

            {result.overrideToFront && (
              <div style={{ marginTop: '1rem', padding: '0.75rem 1rem', background: 'rgba(239, 68, 68, 0.1)', borderRadius: '0.5rem', border: '1px solid rgba(239, 68, 68, 0.2)', fontSize: '0.85rem', color: 'var(--accent-danger)' }}>
                ⚡ Emergency Override — moved to front of queue
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default StaffView;
