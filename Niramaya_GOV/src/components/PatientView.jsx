import React, { useState } from 'react';
import { Clock, Plus, AlertTriangle, ShieldAlert, Stethoscope, Thermometer, Heart, Gauge } from 'lucide-react';
import { api, DEFAULT_HOSPITAL_ID, DEPARTMENTS } from '../api';

const PatientView = () => {
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    age: '',
    symptoms: '',
    pain_level: 5,
    temperature: 98.6,
    heart_rate: 75,
    systolic_bp: 120,
    is_emergency: false,
    department_type: 'General',
  });
  const [ticket, setTicket] = useState(null);
  const [loading, setLoading] = useState(false);
  const [apiStatus, setApiStatus] = useState(null); // 'live' | 'fallback' | null

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setApiStatus(null);

    const priorityPayload = {
      symptoms: formData.symptoms.split(',').map(s => s.trim()).filter(Boolean),
      pain_level: parseInt(formData.pain_level),
      age: parseInt(formData.age),
      temperature: parseFloat(formData.temperature),
      heart_rate: parseInt(formData.heart_rate),
      systolic_bp: parseInt(formData.systolic_bp),
      is_emergency: formData.is_emergency,
    };

    try {
      // Step 1: Calculate Priority
      const priority = await api.calculatePriority(priorityPayload);

      // Step 2: Predict Wait Time
      const prediction = await api.predictWaitTime({
        hospital_id: DEFAULT_HOSPITAL_ID,
        department_type: formData.department_type,
      });

      setTicket({
        id: 'TCK-' + Math.floor(Math.random() * 9000 + 1000),
        predictedWaitMinutes: prediction.predicted_wait_minutes,
        category: priority.category,
        priorityScore: priority.priority_score,
        starvationEscalated: priority.starvation_escalated,
        overrideToFront: priority.override_to_front,
        queuePosition: priority.override_to_front ? 1 : Math.max(1, Math.ceil(prediction.predicted_wait_minutes / 8)),
        modelVersion: prediction.model_version,
        department: formData.department_type,
      });
      setApiStatus('live');
    } catch (err) {
      console.error('ML Service Error:', err);
      // Fallback for UI when ML service is offline
      setTicket({
        id: 'TCK-' + Math.floor(Math.random() * 9000 + 1000),
        predictedWaitMinutes: formData.is_emergency ? 0 : 25,
        category: formData.is_emergency ? 'CRITICAL' : 'ROUTINE',
        priorityScore: formData.is_emergency ? 10 : 3,
        starvationEscalated: false,
        overrideToFront: formData.is_emergency,
        queuePosition: formData.is_emergency ? 1 : 5,
        modelVersion: 'offline_fallback',
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
    <div className="flex gap-4" style={{ flexWrap: 'wrap' }}>

      <div className="glass-panel" style={{ flex: 1, minWidth: '340px', maxWidth: '620px' }}>
        <h2 style={{ marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <Plus color="#0ea5e9" /> New Patient Appointment
        </h2>

        <form onSubmit={handleSubmit}>
          {/* Name + Age */}
          <div className="flex gap-4" style={{ marginBottom: '1rem' }}>
            <div style={{ flex: 1 }}>
              <label className="form-label">Full Name</label>
              <input type="text" className="form-input" required
                value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
            </div>
            <div style={{ flex: 1 }}>
              <label className="form-label">Age</label>
              <input type="number" className="form-input" required
                value={formData.age} onChange={e => setFormData({...formData, age: e.target.value})} />
            </div>
          </div>

          {/* Department Selector */}
          <div className="form-group">
            <label className="form-label">Department</label>
            <select className="form-input" value={formData.department_type}
              onChange={e => setFormData({...formData, department_type: e.target.value})}>
              {DEPARTMENTS.map(d => <option key={d} value={d}>{d}</option>)}
            </select>
          </div>

          {/* Symptoms */}
          <div className="form-group">
            <label className="form-label">Primary Symptoms (comma separated)</label>
            <input type="text" className="form-input" placeholder="e.g. Fever, Chest Pain, Breathing Difficulty" required
              value={formData.symptoms} onChange={e => setFormData({...formData, symptoms: e.target.value})} />
          </div>

          {/* Vitals Row */}
          <div className="vitals-section">
            <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', marginBottom: '0.75rem' }}>
              <Heart size={16} color="var(--accent-danger)" /> Vitals
            </label>
            <div className="flex gap-4">
              <div style={{ flex: 1 }}>
                <label className="form-label" style={{ fontSize: '0.8rem' }}>
                  <Thermometer size={14} style={{ verticalAlign: 'text-bottom' }} /> Temp (°F)
                </label>
                <input type="number" step="0.1" className="form-input" value={formData.temperature}
                  onChange={e => setFormData({...formData, temperature: e.target.value})} />
              </div>
              <div style={{ flex: 1 }}>
                <label className="form-label" style={{ fontSize: '0.8rem' }}>
                  <Heart size={14} style={{ verticalAlign: 'text-bottom' }} /> Heart Rate
                </label>
                <input type="number" className="form-input" value={formData.heart_rate}
                  onChange={e => setFormData({...formData, heart_rate: e.target.value})} />
              </div>
              <div style={{ flex: 1 }}>
                <label className="form-label" style={{ fontSize: '0.8rem' }}>
                  <Gauge size={14} style={{ verticalAlign: 'text-bottom' }} /> Systolic BP
                </label>
                <input type="number" className="form-input" value={formData.systolic_bp}
                  onChange={e => setFormData({...formData, systolic_bp: e.target.value})} />
              </div>
            </div>
          </div>

          {/* Pain Level + Emergency */}
          <div className="flex gap-4 items-center" style={{ marginBottom: '1.5rem' }}>
            <div style={{ flex: 1 }}>
              <label className="form-label">Pain Level (0-10)</label>
              <input type="range" min="0" max="10"
                style={{ width: '100%', accentColor: 'var(--accent-primary)' }}
                value={formData.pain_level}
                onChange={e => setFormData({...formData, pain_level: e.target.value})} />
              <div className="text-center mt-1" style={{ color: 'var(--text-secondary)' }}>{formData.pain_level}/10</div>
            </div>

            <div style={{ flex: 1, background: 'rgba(239, 68, 68, 0.1)', padding: '1rem', borderRadius: '0.5rem', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
              <label className="form-label" style={{ color: 'var(--accent-danger)', display: 'flex', alignItems:'center', gap:'0.5rem', marginBottom: 0, cursor: 'pointer' }}>
                <input type="checkbox" checked={formData.is_emergency}
                  onChange={e => setFormData({...formData, is_emergency: e.target.checked})}
                  style={{ transform: 'scale(1.2)' }}/>
                <ShieldAlert size={18} /> Emergency SOS
              </label>
            </div>
          </div>

          <button type="submit" className={`btn ${formData.is_emergency ? 'btn-danger pulse-emergency' : 'btn-primary'}`} style={{ width: '100%' }} disabled={loading}>
            {loading ? 'Processing...' : 'Request Triage & Book'}
          </button>
        </form>
      </div>

      {/* Ticket Result */}
      <div style={{ flex: 1, minWidth: '300px' }}>
        {ticket ? (
          <div className="glass-panel animate-fade-in" style={{ borderLeft: `4px solid ${categoryColor(ticket.category)}` }}>
            {/* API Status Badge */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3>Your Queue Ticket</h3>
              <span className={`status-badge ${apiStatus === 'live' ? 'status-live' : 'status-offline'}`}>
                {apiStatus === 'live' ? '● ML Live' : '● Offline Mode'}
              </span>
            </div>

            {/* Category Badge */}
            <div style={{ marginBottom: '1rem' }}>
              <span className="severity-badge" style={{ background: categoryColor(ticket.category), color: 'white', padding: '0.3rem 0.8rem', borderRadius: '1rem', fontWeight: 600, fontSize: '0.85rem' }}>
                {ticket.category}
              </span>
              <span style={{ marginLeft: '0.75rem', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                Priority Score: {ticket.priorityScore}/10 • {ticket.department}
              </span>
            </div>

            {/* Ticket + Queue */}
            <div className="flex items-center justify-between" style={{ padding: '1.5rem', background: 'var(--bg-tertiary)', borderRadius: '0.5rem', marginBottom: '1rem' }}>
              <div>
                <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Ticket Number</div>
                <div style={{ fontSize: '1.8rem', fontWeight: 700, fontFamily: 'var(--font-heading)' }}>{ticket.id}</div>
              </div>
              <div className="text-center">
                <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Queue Pos</div>
                <div style={{ fontSize: '1.8rem', fontWeight: 700, color: 'var(--accent-primary)' }}>#{ticket.queuePosition}</div>
              </div>
            </div>

            {/* Wait Time */}
            <div className="flex items-center gap-4" style={{ padding: '1.5rem', background: 'rgba(16, 185, 129, 0.1)', borderRadius: '0.5rem', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
              <Clock size={32} color={ticket.predictedWaitMinutes > 60 ? 'var(--accent-danger)' : 'var(--accent-success)'} />
              <div>
                <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Predicted Wait Time</div>
                <div style={{ fontSize: '1.4rem', fontWeight: 600, color: 'var(--text-primary)' }}>
                  {ticket.predictedWaitMinutes} Minutes
                </div>
                {ticket.predictedWaitMinutes > 60 && (
                  <div style={{ color: 'var(--accent-danger)', fontSize: '0.8rem', marginTop: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                    <AlertTriangle size={14} /> Urgent Delay Detected
                  </div>
                )}
              </div>
            </div>

            {/* Override / Starvation Flags */}
            {(ticket.overrideToFront || ticket.starvationEscalated) && (
              <div style={{ marginTop: '1rem', padding: '0.75rem 1rem', background: 'rgba(239, 68, 68, 0.1)', borderRadius: '0.5rem', border: '1px solid rgba(239, 68, 68, 0.2)', fontSize: '0.85rem', color: 'var(--accent-danger)' }}>
                {ticket.overrideToFront && <div>⚡ Emergency Override — moved to front of queue</div>}
                {ticket.starvationEscalated && <div>⬆ Priority escalated due to long wait time</div>}
              </div>
            )}

            {/* Model info */}
            <div style={{ marginTop: '1rem', color: 'var(--text-muted)', fontSize: '0.75rem' }}>
              Model: {ticket.modelVersion}
            </div>
          </div>
        ) : (
          <div className="flex items-center justify-center" style={{ color: 'var(--text-muted)', minHeight: '300px' }}>
            <div className="text-center">
              <Stethoscope size={48} style={{ opacity: 0.5, marginBottom: '1rem' }} />
              <p>Fill out the form to receive your dynamic queue ticket.</p>
            </div>
          </div>
        )}
      </div>

    </div>
  );
};

export default PatientView;
