import React, { useState, useEffect } from 'react';
import { X, AlertTriangle, MapPin, TrendingUp, Shield, Clock, Activity, Bed } from 'lucide-react';
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
} from 'recharts';
import { api } from '../../api';
import AnimatedCounter from './AnimatedCounter';

const SEVERITY_COLORS = {
  CRITICAL: '#DC2626',
  WARNING: '#D97706',
};

const riskScore = (outbreak) => {
  const spikeScore = Math.min(outbreak.spike_percentage / 200, 1) * 40;
  const confScore = outbreak.ml_confidence * 35;
  const avgScore = Math.min(outbreak.recent_daily_avg / 20, 1) * 25;
  return Math.round(spikeScore + confScore + avgScore);
};

const riskLabel = (score) => {
  if (score >= 80) return { text: 'CRITICAL', color: '#DC2626' };
  if (score >= 60) return { text: 'HIGH', color: '#EF4444' };
  if (score >= 40) return { text: 'MODERATE', color: '#D97706' };
  return { text: 'LOW', color: '#22C55E' };
};

const MiniTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: '#253349', border: '1px solid #334155', borderRadius: '3px',
      padding: '0.3rem 0.5rem', fontSize: '0.65rem', fontFamily: "'JetBrains Mono', monospace",
    }}>
      <div style={{ color: '#94A3B8', fontSize: '0.6rem' }}>{label}</div>
      <div style={{ color: '#E2E8F0', fontWeight: 600 }}>{payload[0].value} cases</div>
    </div>
  );
};

const OutbreakDrawer = ({ outbreak, onClose }) => {
  const [timelineData, setTimelineData] = useState([]);
  const [bedData, setBedData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!outbreak) return;

    const fetchDetails = async () => {
      setLoading(true);
      try {
        const [trendRes, bedRes] = await Promise.all([
          api.symptomTrends(14, outbreak.district),
          api.bedStatus(),
        ]);

        // Build timeline for this specific indicator
        if (trendRes.trends?.length) {
          const dateMap = {};
          trendRes.trends
            .filter(t => t.symptom_type === outbreak.indicator)
            .forEach(t => {
              dateMap[t.date] = (dateMap[t.date] || 0) + t.count;
            });

          // Fill gaps
          const dates = Object.keys(dateMap).sort();
          if (dates.length >= 2) {
            const start = new Date(dates[0]);
            const end = new Date(dates[dates.length - 1]);
            const filled = [];
            for (let dt = new Date(start); dt <= end; dt.setDate(dt.getDate() + 1)) {
              const ds = dt.toISOString().split('T')[0];
              filled.push({ date: ds, count: dateMap[ds] || 0 });
            }
            setTimelineData(filled);
          } else {
            setTimelineData(dates.map(d => ({ date: d, count: dateMap[d] })));
          }
        }

        // Group bed data by hospital_id, sum per hospital
        if (bedRes.departments?.length) {
          const hospitalMap = {};
          bedRes.departments.forEach(d => {
            if (!hospitalMap[d.hospital_id]) {
              hospitalMap[d.hospital_id] = {
                id: d.hospital_id.slice(0, 8),
                total: 0, available: 0, depts: [],
              };
            }
            hospitalMap[d.hospital_id].total += d.total_beds;
            hospitalMap[d.hospital_id].available += d.available_beds;
            hospitalMap[d.hospital_id].depts.push(d);
          });
          const hospitals = Object.values(hospitalMap).map(h => ({
            ...h,
            utilization: h.total > 0 ? (h.total - h.available) / h.total : 0,
          }));
          hospitals.sort((a, b) => a.utilization - b.utilization); // Least utilized first
          setBedData(hospitals);
        }
      } catch (err) {
        console.error('Drawer fetch error:', err);
      }
      setLoading(false);
    };

    fetchDetails();
  }, [outbreak]);

  if (!outbreak) return null;

  const score = riskScore(outbreak);
  const risk = riskLabel(score);
  const sevColor = SEVERITY_COLORS[outbreak.severity] || '#D97706';

  const actionLog = [
    { time: 'T-0', label: 'Outbreak detected by ML classifier', icon: AlertTriangle },
    { time: 'T+1m', label: `Alert dispatched to ${outbreak.district} district HQ`, icon: Activity },
    { time: 'T+5m', label: 'Surveillance data snapshot captured', icon: Shield },
  ];

  const utilColor = (u) => {
    if (u >= 0.9) return '#DC2626';
    if (u >= 0.7) return '#D97706';
    return '#22C55E';
  };

  return (
    <>
      {/* Backdrop */}
      <div className="outbreak-drawer-overlay" onClick={onClose} />

      {/* Drawer */}
      <div className="outbreak-drawer">
        {/* Header */}
        <div className="drawer-header">
          <div>
            <span className="gov-severity-tag" style={{ background: sevColor, marginBottom: '0.3rem', display: 'inline-block' }}>
              {outbreak.severity}
            </span>
            <h3 style={{ margin: '0.2rem 0 0', fontSize: '1.1rem' }}>{outbreak.indicator}</h3>
            <div className="flex items-center gap-2" style={{ color: 'var(--text-muted)', fontSize: '0.8rem', marginTop: '0.25rem' }}>
              <MapPin size={12} /> {outbreak.district}
            </div>
          </div>
          <button className="drawer-close" onClick={onClose}><X size={16} /></button>
        </div>

        {/* Risk Score */}
        <div className="drawer-section">
          <div className="drawer-section-title">Composite Risk Score</div>
          <div className="risk-score-display">
            <div className="risk-score-number" style={{ color: risk.color }}>
              <AnimatedCounter value={score} />
            </div>
            <div className="risk-score-label" style={{ color: risk.color }}>{risk.text}</div>
            <div className="risk-score-bar">
              <div className="risk-score-fill" style={{ width: `${score}%`, background: risk.color }} />
            </div>
            <div style={{ fontSize: '0.55rem', color: '#475569', marginTop: '0.25rem', fontFamily: "'JetBrains Mono', monospace" }}>
              SPIKE({Math.round(Math.min(outbreak.spike_percentage / 200, 1) * 40)}) + CONF({Math.round(outbreak.ml_confidence * 35)}) + AVG({Math.round(Math.min(outbreak.recent_daily_avg / 20, 1) * 25)})
            </div>
          </div>
        </div>

        {/* Key Metrics Grid */}
        <div className="drawer-section">
          <div className="drawer-section-title">Key Metrics</div>
          <div className="drawer-metrics-grid">
            <div className="drawer-metric">
              <div className="drawer-metric-label">Spike</div>
              <div className="drawer-metric-value" style={{ color: sevColor }}>
                +<AnimatedCounter value={parseFloat(outbreak.spike_percentage.toFixed(0))} />%
              </div>
            </div>
            <div className="drawer-metric">
              <div className="drawer-metric-label">ML Confidence</div>
              <div className="drawer-metric-value">
                <AnimatedCounter value={parseFloat((outbreak.ml_confidence * 100).toFixed(0))} />%
              </div>
            </div>
            <div className="drawer-metric">
              <div className="drawer-metric-label">Daily Avg</div>
              <div className="drawer-metric-value">{outbreak.recent_daily_avg}/day</div>
            </div>
            <div className="drawer-metric">
              <div className="drawer-metric-label">Baseline</div>
              <div className="drawer-metric-value" style={{ color: '#64748B' }}>{outbreak.baseline_daily_avg}/day</div>
            </div>
          </div>
        </div>

        {/* 14-Day Timeline */}
        <div className="drawer-section">
          <div className="drawer-section-title">14-Day District Timeline</div>
          {timelineData.length > 0 ? (
            <ResponsiveContainer width="100%" height={120}>
              <AreaChart data={timelineData} margin={{ top: 5, right: 5, left: -30, bottom: 5 }}>
                <CartesianGrid strokeDasharray="2 2" stroke="rgba(51, 65, 85, 0.4)" />
                <XAxis dataKey="date" tick={{ fill: '#64748B', fontSize: 8, fontFamily: "'JetBrains Mono', monospace" }}
                  tickFormatter={d => d.slice(5)} />
                <YAxis tick={{ fill: '#64748B', fontSize: 8, fontFamily: "'JetBrains Mono', monospace" }} />
                <Tooltip content={<MiniTooltip />} />
                <Area type="monotone" dataKey="count" stroke={sevColor} fill={sevColor}
                  fillOpacity={0.15} strokeWidth={1.5} dot={false}
                  activeDot={{ r: 2.5, fill: sevColor }} />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ textAlign: 'center', padding: '1rem', color: 'var(--text-muted)', fontSize: '0.75rem' }}>
              {loading ? 'Loading timeline...' : 'No district-level data available'}
            </div>
          )}
        </div>

        {/* Nearest Hospitals */}
        <div className="drawer-section">
          <div className="drawer-section-title">
            <Bed size={12} /> Hospital Capacity
          </div>
          {bedData.length > 0 ? (
            <div className="drawer-hospital-list">
              {bedData.slice(0, 4).map((h, i) => (
                <div key={i} className="drawer-hospital-card">
                  <div className="flex justify-between items-center" style={{ marginBottom: '0.25rem' }}>
                    <span style={{ fontSize: '0.7rem', fontFamily: "'JetBrains Mono', monospace", color: 'var(--text-secondary)' }}>
                      HOSP-{h.id}
                    </span>
                    <span style={{ fontSize: '0.65rem', fontWeight: 600, color: utilColor(h.utilization) }}>
                      {h.available}/{h.total} beds
                    </span>
                  </div>
                  <div className="resource-bar-bg resource-bar-sm">
                    <div className="resource-bar-fill" style={{
                      width: `${Math.min(h.utilization * 100, 100)}%`,
                      background: utilColor(h.utilization),
                    }} />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '0.75rem', color: 'var(--text-muted)', fontSize: '0.75rem' }}>
              {loading ? 'Loading...' : 'No bed data'}
            </div>
          )}
        </div>

        {/* Action Log */}
        <div className="drawer-section">
          <div className="drawer-section-title"><Clock size={12} /> Action Log</div>
          <div className="drawer-action-log">
            {actionLog.map((a, i) => (
              <div key={i} className="drawer-action-item">
                <span className="drawer-action-time">{a.time}</span>
                <a.icon size={10} style={{ color: '#64748B', flexShrink: 0 }} />
                <span className="drawer-action-text">{a.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
};

export default OutbreakDrawer;
