import React, { useState, useEffect, useCallback } from 'react';
import { Siren, Ambulance, Users, ShieldAlert, ShieldCheck, X, Radio, Clock } from 'lucide-react';

/**
 * MCIPanel — Mass Casualty Incident control panel.
 * Manages MCI mode activation, simulated ambulance fleet,
 * triage tallies, and incident timeline.
 *
 * Props:
 *   mciActive:     boolean
 *   setMciActive:  fn(bool)
 *   onAmbulances:  fn(ambulances[]) — callback to update map markers
 */

// Simulated ambulance fleet around New Delhi
const INITIAL_AMBULANCES = [
  { id: 'AMB-01', lat: 28.6280, lng: 77.2180, status: 'AVAILABLE', destination: 'Standby', callsign: 'Alpha-1' },
  { id: 'AMB-02', lat: 28.6100, lng: 77.2350, status: 'AVAILABLE', destination: 'Standby', callsign: 'Alpha-2' },
  { id: 'AMB-03', lat: 28.6350, lng: 77.2050, status: 'AVAILABLE', destination: 'Standby', callsign: 'Bravo-1' },
  { id: 'AMB-04', lat: 28.6200, lng: 77.2400, status: 'AVAILABLE', destination: 'Standby', callsign: 'Bravo-2' },
  { id: 'AMB-05', lat: 28.6450, lng: 77.2150, status: 'AVAILABLE', destination: 'Standby', callsign: 'Charlie-1' },
];

// Simulated incident locations
const INCIDENT_LOCATIONS = [
  { name: 'AIIMS Trauma Center', lat: 28.5672, lng: 77.2100 },
  { name: 'Sector 2 Intersection', lat: 28.6200, lng: 77.2200 },
  { name: 'Connaught Place', lat: 28.6315, lng: 77.2167 },
  { name: 'Safdarjung Hospital', lat: 28.5682, lng: 77.2067 },
];

const MCIPanel = ({ mciActive, setMciActive, onAmbulances }) => {
  const [ambulances, setAmbulances] = useState(INITIAL_AMBULANCES);
  const [triageCounts, setTriageCounts] = useState({ CRITICAL: 0, URGENT: 0, MODERATE: 0, LOW: 0, DECEASED: 0 });
  const [incidentLog, setIncidentLog] = useState([]);
  const [elapsedTime, setElapsedTime] = useState(0);
  const [mciStartTime, setMciStartTime] = useState(null);

  // Activate MCI
  const activateMCI = useCallback(() => {
    setMciActive(true);
    setMciStartTime(Date.now());
    setElapsedTime(0);

    // Simulate dispatch: 2 ambulances respond immediately
    const dispatched = [...INITIAL_AMBULANCES];
    const target = INCIDENT_LOCATIONS[Math.floor(Math.random() * INCIDENT_LOCATIONS.length)];

    dispatched[0] = { ...dispatched[0], status: 'RESPONDING', destination: target.name, lat: dispatched[0].lat + 0.003, lng: dispatched[0].lng - 0.002 };
    dispatched[1] = { ...dispatched[1], status: 'EN_ROUTE', destination: target.name, lat: dispatched[1].lat - 0.002, lng: dispatched[1].lng + 0.003 };

    setAmbulances(dispatched);
    onAmbulances(dispatched);

    setTriageCounts({ CRITICAL: 3, URGENT: 7, MODERATE: 12, LOW: 8, DECEASED: 0 });
    setIncidentLog([
      { time: '00:00', event: `MCI DECLARED — ${target.name}`, severity: 'CRITICAL' },
      { time: '00:00', event: `${dispatched[0].callsign} dispatched (Code 3)`, severity: 'INFO' },
      { time: '00:00', event: `${dispatched[1].callsign} en route`, severity: 'INFO' },
    ]);
  }, [setMciActive, onAmbulances]);

  // Deactivate MCI
  const deactivateMCI = () => {
    setMciActive(false);
    setMciStartTime(null);
    setElapsedTime(0);
    setAmbulances(INITIAL_AMBULANCES);
    onAmbulances([]);
    setTriageCounts({ CRITICAL: 0, URGENT: 0, MODERATE: 0, LOW: 0, DECEASED: 0 });
    setIncidentLog([]);
  };

  // Elapsed time counter
  useEffect(() => {
    if (!mciActive || !mciStartTime) return;
    const timer = setInterval(() => {
      setElapsedTime(Math.floor((Date.now() - mciStartTime) / 1000));
    }, 1000);
    return () => clearInterval(timer);
  }, [mciActive, mciStartTime]);

  // Simulate ambulance movement + triage updates
  useEffect(() => {
    if (!mciActive) return;

    const simInterval = setInterval(() => {
      setAmbulances(prev => {
        const updated = prev.map(amb => {
          if (amb.status === 'RESPONDING' || amb.status === 'EN_ROUTE') {
            // Drift toward incident
            return {
              ...amb,
              lat: amb.lat + (Math.random() - 0.5) * 0.002,
              lng: amb.lng + (Math.random() - 0.5) * 0.002,
            };
          }
          return amb;
        });
        onAmbulances(updated);
        return updated;
      });

      // Occasionally update triage counts (simulate incoming patients)
      if (Math.random() > 0.6) {
        setTriageCounts(prev => {
          const cat = ['URGENT', 'MODERATE', 'LOW'][Math.floor(Math.random() * 3)];
          return { ...prev, [cat]: prev[cat] + 1 };
        });
      }
    }, 3000);

    return () => clearInterval(simInterval);
  }, [mciActive, onAmbulances]);

  // Simulate new log entries
  useEffect(() => {
    if (!mciActive) return;
    const events = [
      'Additional unit requested',
      'Patient transported to ER',
      'Triage reassessment complete',
      'Perimeter established',
      'Medical supplies restocked',
      'Helicopter EMS notified',
    ];

    const logInterval = setInterval(() => {
      const mins = Math.floor(elapsedTime / 60);
      const secs = elapsedTime % 60;
      const timeStr = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
      const event = events[Math.floor(Math.random() * events.length)];
      setIncidentLog(prev => [{ time: timeStr, event, severity: 'INFO' }, ...prev].slice(0, 20));
    }, 8000);

    return () => clearInterval(logInterval);
  }, [mciActive, elapsedTime]);

  const formatTime = (secs) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };

  const triageColor = { CRITICAL: '#e11d48', URGENT: '#f59e0b', MODERATE: '#0ea5e9', LOW: '#10b981', DECEASED: '#6b7280' };
  const totalPatients = Object.values(triageCounts).reduce((a, b) => a + b, 0);

  return (
    <div className={`mci-panel glass-panel ${mciActive ? 'mci-active' : ''}`}>
      {/* Header */}
      <div className="flex justify-between items-center" style={{ marginBottom: '1rem' }}>
        <div className="flex items-center gap-2">
          <ShieldAlert size={18} color={mciActive ? '#e11d48' : '#0ea5e9'} />
          <h4 style={{ margin: 0 }}>MCI Operations</h4>
          {mciActive && <span className="mci-live-badge">LIVE</span>}
        </div>
        {!mciActive ? (
          <button className="btn btn-sm mci-declare-btn" onClick={activateMCI}>
            <Siren size={14} /> Declare MCI
          </button>
        ) : (
          <button className="btn btn-sm btn-outline" onClick={deactivateMCI} style={{ borderColor: 'var(--accent-danger)', color: 'var(--accent-danger)' }}>
            <X size={14} /> Stand Down
          </button>
        )}
      </div>

      {!mciActive ? (
        <div className="mci-standby">
          <ShieldCheck size={32} style={{ opacity: 0.3 }} />
          <div>No active incident</div>
          <div style={{ fontSize: '0.75rem' }}>Declare an MCI to activate ambulance tracking, triage counters, and incident logging</div>
        </div>
      ) : (
        <>
          {/* Timer + Fleet Status */}
          <div className="mci-status-bar">
            <div className="mci-timer">
              <Clock size={14} />
              <span className="mci-timer-value">{formatTime(elapsedTime)}</span>
            </div>
            <div className="mci-fleet-status">
              <span title="Responding" style={{ color: '#ef4444' }}>
                🚑 {ambulances.filter(a => a.status === 'RESPONDING').length}
              </span>
              <span title="En Route" style={{ color: '#f59e0b' }}>
                🚐 {ambulances.filter(a => a.status === 'EN_ROUTE').length}
              </span>
              <span title="Available" style={{ color: '#10b981' }}>
                ✅ {ambulances.filter(a => a.status === 'AVAILABLE').length}
              </span>
            </div>
          </div>

          {/* Triage Tallies */}
          <div className="mci-triage-grid">
            {Object.entries(triageCounts).map(([cat, count]) => (
              <div key={cat} className="mci-triage-cell" style={{ borderColor: triageColor[cat] }}>
                <div className="mci-triage-count" style={{ color: triageColor[cat] }}>{count}</div>
                <div className="mci-triage-label">{cat}</div>
              </div>
            ))}
            <div className="mci-triage-cell mci-triage-total">
              <div className="mci-triage-count">{totalPatients}</div>
              <div className="mci-triage-label">TOTAL</div>
            </div>
          </div>

          {/* Incident Timeline */}
          <div className="mci-timeline">
            <div style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
              <Radio size={12} style={{ display: 'inline', verticalAlign: 'text-bottom', marginRight: '0.3rem' }} />
              Incident Log
            </div>
            <div className="mci-log-list">
              {incidentLog.map((entry, i) => (
                <div key={i} className={`mci-log-entry ${entry.severity === 'CRITICAL' ? 'mci-log-critical' : ''}`}>
                  <span className="mci-log-time">{entry.time}</span>
                  <span>{entry.event}</span>
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default MCIPanel;
