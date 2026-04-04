import React, { useState, useEffect } from 'react';
import { TrendingUp, RefreshCw, AlertTriangle, GitCompare } from 'lucide-react';
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ComposedChart, Line, Bar,
} from 'recharts';
import { api } from '../../api';

// Tactical palette: blues/grays for historical, red/amber for critical indicators
const SYMPTOM_COLORS = {
  'Fever': '#DC2626',
  'Cough': '#64748B',
  'Body Ache': '#475569',
  'Infection': '#B91C1C',
  'Headache': '#94A3B8',
  'Diarrhea': '#6B7280',
  'Fatigue': '#9CA3AF',
  'Nausea': '#D97706',
  'Respiratory Distress': '#EF4444',
};

const PHARMA_COLORS = {
  'Paracetamol': '#DC2626',
  'Cough Syrup': '#64748B',
  'Ibuprofen': '#475569',
  'Amoxicillin': '#B91C1C',
  'General Antibiotic': '#D97706',
};

// Correlation pairs: which pharma product maps to which symptom
const CORRELATION_PAIRS = [
  { symptom: 'Fever', pharma: 'Paracetamol', color: '#DC2626', pharmaColor: '#F87171' },
  { symptom: 'Cough', pharma: 'Cough Syrup', color: '#64748B', pharmaColor: '#94A3B8' },
  { symptom: 'Infection', pharma: 'Amoxicillin', color: '#B91C1C', pharmaColor: '#EF4444' },
  { symptom: 'Respiratory Distress', pharma: 'General Antibiotic', color: '#D97706', pharmaColor: '#FBBF24' },
];

const TIME_RANGES = [
  { label: '7D', days: 7 },
  { label: '14D', days: 14 },
  { label: '30D', days: 30 },
  { label: '90D', days: 90 },
];

const fallbackColor = (name, palette) => {
  if (palette[name]) return palette[name];
  const hash = [...name].reduce((a, c) => a + c.charCodeAt(0), 0);
  const hues = [210, 215, 220, 225, 230];
  const hue = hues[hash % hues.length];
  return `hsl(${hue}, 20%, ${45 + (hash % 20)}%)`;
};

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: '#253349', border: '1px solid #334155',
      borderRadius: '3px', padding: '0.4rem 0.6rem', fontSize: '0.72rem',
      fontFamily: "'JetBrains Mono', monospace",
    }}>
      <div style={{ color: '#94A3B8', marginBottom: '0.2rem', fontSize: '0.65rem' }}>{label}</div>
      {payload.map((p, i) => (
        <div key={i} style={{ color: p.color, display: 'flex', justifyContent: 'space-between', gap: '0.75rem' }}>
          <span style={{ fontFamily: 'Inter, sans-serif' }}>{p.name}</span>
          <strong>{p.value}</strong>
        </div>
      ))}
    </div>
  );
};

const CorrelationTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: '#253349', border: '1px solid #334155',
      borderRadius: '3px', padding: '0.4rem 0.6rem', fontSize: '0.72rem',
      fontFamily: "'JetBrains Mono', monospace",
    }}>
      <div style={{ color: '#94A3B8', marginBottom: '0.3rem', fontSize: '0.65rem' }}>{label}</div>
      {payload.map((p, i) => (
        <div key={i} style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', alignItems: 'center' }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
            <span style={{
              width: 6, height: 6, borderRadius: '50%',
              background: p.color, display: 'inline-block',
            }} />
            <span style={{ fontFamily: 'Inter, sans-serif', color: p.color }}>{p.name}</span>
          </span>
          <strong style={{ color: p.color }}>{p.value}</strong>
        </div>
      ))}
    </div>
  );
};

const TrendChart = ({ days: initialDays = 14 }) => {
  const [symptomData, setSymptomData] = useState([]);
  const [pharmaData, setPharmaData] = useState([]);
  const [symptomKeys, setSymptomKeys] = useState([]);
  const [pharmaKeys, setPharmaKeys] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState('symptoms'); // 'symptoms' | 'pharma' | 'correlation'
  const [days, setDays] = useState(initialDays);
  const [correlationData, setCorrelationData] = useState([]);

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [symRes, pharRes] = await Promise.all([
        api.symptomTrends(days),
        api.pharmaTrends(days),
      ]);

      // Pivot symptom trends
      const symDateMap = {};
      const symKeys = new Set();
      if (symRes.trends?.length) {
        symRes.trends.forEach(t => {
          if (!symDateMap[t.date]) symDateMap[t.date] = { date: t.date };
          symDateMap[t.date][t.symptom_type] = (symDateMap[t.date][t.symptom_type] || 0) + t.count;
          symKeys.add(t.symptom_type);
        });
        setSymptomData(Object.values(symDateMap).sort((a, b) => a.date.localeCompare(b.date)));
        setSymptomKeys([...symKeys]);
      } else {
        setSymptomData([]); setSymptomKeys([]);
      }

      // Pivot pharma trends
      const pharDateMap = {};
      const pharKeys = new Set();
      if (pharRes.trends?.length) {
        pharRes.trends.forEach(t => {
          if (!pharDateMap[t.date]) pharDateMap[t.date] = { date: t.date };
          pharDateMap[t.date][t.medicine_name] = (pharDateMap[t.date][t.medicine_name] || 0) + t.count;
          pharKeys.add(t.medicine_name);
        });
        setPharmaData(Object.values(pharDateMap).sort((a, b) => a.date.localeCompare(b.date)));
        setPharmaKeys([...pharKeys]);
      } else {
        setPharmaData([]); setPharmaKeys([]);
      }

      // Build correlation data: merge symptom + pharma by date
      if (symRes.trends?.length && pharRes.trends?.length) {
        const mergedMap = {};
        symRes.trends.forEach(t => {
          if (!mergedMap[t.date]) mergedMap[t.date] = { date: t.date };
          mergedMap[t.date][`sym_${t.symptom_type}`] = (mergedMap[t.date][`sym_${t.symptom_type}`] || 0) + t.count;
        });
        pharRes.trends.forEach(t => {
          if (!mergedMap[t.date]) mergedMap[t.date] = { date: t.date };
          mergedMap[t.date][`ph_${t.medicine_name}`] = (mergedMap[t.date][`ph_${t.medicine_name}`] || 0) + t.count;
        });
        setCorrelationData(Object.values(mergedMap).sort((a, b) => a.date.localeCompare(b.date)));
      } else {
        setCorrelationData([]);
      }
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => { fetchData(); }, [days]);

  const chartData = activeTab === 'symptoms' ? symptomData : activeTab === 'pharma' ? pharmaData : correlationData;
  const chartKeys = activeTab === 'symptoms' ? symptomKeys : pharmaKeys;
  const palette = activeTab === 'symptoms' ? SYMPTOM_COLORS : PHARMA_COLORS;

  const renderStandardChart = () => (
    <ResponsiveContainer width="100%" height={220}>
      <AreaChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="2 2" stroke="rgba(51, 65, 85, 0.6)" />
        <XAxis dataKey="date" tick={{ fill: '#64748B', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }} tickFormatter={d => d.slice(5)} />
        <YAxis tick={{ fill: '#64748B', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }} />
        <Tooltip content={<CustomTooltip />} />
        <Legend wrapperStyle={{ fontSize: '0.65rem', color: '#64748B' }} />
        {chartKeys.map(key => (
          <Area
            key={key}
            type="monotone"
            dataKey={key}
            stroke={fallbackColor(key, palette)}
            fill="none"
            strokeWidth={1.5}
            dot={false}
            activeDot={{ r: 2.5, stroke: fallbackColor(key, palette), strokeWidth: 1 }}
          />
        ))}
      </AreaChart>
    </ResponsiveContainer>
  );

  const renderCorrelationChart = () => {
    // Filter to pairs that exist in the data
    const activePairs = CORRELATION_PAIRS.filter(
      p => correlationData.some(d => d[`sym_${p.symptom}`] !== undefined || d[`ph_${p.pharma}`] !== undefined)
    );

    if (!activePairs.length) {
      return (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
          No correlation data available. Need both symptom and pharma data for the same period.
        </div>
      );
    }

    return (
      <>
        <div style={{
          fontSize: '0.6rem', color: '#64748B', marginBottom: '0.4rem',
          fontFamily: "'JetBrains Mono', monospace", display: 'flex', gap: '1rem', flexWrap: 'wrap',
        }}>
          {activePairs.map(p => (
            <span key={p.symptom} style={{ display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
              <span style={{ width: 8, height: 2, background: p.color, display: 'inline-block' }} />
              {p.symptom}
              <span style={{ color: '#475569' }}>↔</span>
              <span style={{ width: 8, height: 2, background: p.pharmaColor, display: 'inline-block', borderBottom: '1px dashed ' + p.pharmaColor }} />
              {p.pharma}
            </span>
          ))}
        </div>
        <ResponsiveContainer width="100%" height={220}>
          <ComposedChart data={correlationData} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="2 2" stroke="rgba(51, 65, 85, 0.6)" />
            <XAxis dataKey="date" tick={{ fill: '#64748B', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }} tickFormatter={d => d.slice(5)} />
            <YAxis yAxisId="symptoms" tick={{ fill: '#64748B', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }} />
            <YAxis yAxisId="pharma" orientation="right" tick={{ fill: '#475569', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }} />
            <Tooltip content={<CorrelationTooltip />} />

            {activePairs.map(p => (
              <React.Fragment key={p.symptom}>
                <Line
                  yAxisId="symptoms"
                  type="monotone"
                  dataKey={`sym_${p.symptom}`}
                  name={`📊 ${p.symptom}`}
                  stroke={p.color}
                  strokeWidth={1.5}
                  dot={false}
                  activeDot={{ r: 2.5 }}
                />
                <Line
                  yAxisId="pharma"
                  type="monotone"
                  dataKey={`ph_${p.pharma}`}
                  name={`💊 ${p.pharma}`}
                  stroke={p.pharmaColor}
                  strokeWidth={1.2}
                  strokeDasharray="4 3"
                  dot={false}
                  activeDot={{ r: 2 }}
                />
              </React.Fragment>
            ))}
          </ComposedChart>
        </ResponsiveContainer>
        <div style={{
          fontSize: '0.55rem', color: '#475569', marginTop: '0.3rem', textAlign: 'center',
          fontFamily: "'JetBrains Mono', monospace",
        }}>
          SOLID = SYMPTOM REPORTS (LEFT AXIS) · DASHED = PHARMA SALES (RIGHT AXIS)
        </div>
      </>
    );
  };

  return (
    <div className="gov-trend-panel glass-panel">
      <div className="flex justify-between items-center" style={{ marginBottom: '0.5rem' }}>
        <div className="flex items-center gap-2">
          <TrendingUp size={14} color="#3B82F6" />
          <h4 style={{ margin: 0, fontSize: '0.85rem' }}>Epidemiological Trends</h4>
        </div>
        <div className="flex gap-2 items-center">
          {/* Time Range Selector */}
          <div className="time-range-selector">
            {TIME_RANGES.map(r => (
              <button
                key={r.days}
                className={`time-range-btn ${days === r.days ? 'active' : ''}`}
                onClick={() => setDays(r.days)}
              >
                {r.label}
              </button>
            ))}
          </div>

          <div style={{ width: 1, height: 16, background: '#334155' }} />

          {/* Tab Selector */}
          <button
            className={`btn btn-sm ${activeTab === 'symptoms' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('symptoms')}
            style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}
          >
            Symptoms
          </button>
          <button
            className={`btn btn-sm ${activeTab === 'pharma' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('pharma')}
            style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}
          >
            Pharma
          </button>
          <button
            className={`btn btn-sm ${activeTab === 'correlation' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('correlation')}
            style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}
            title="Symptom ↔ Pharma Correlation"
          >
            <GitCompare size={10} /> Correlate
          </button>
          <button className="btn btn-sm btn-outline" onClick={fetchData} disabled={loading}
            style={{ padding: '0.25rem 0.4rem' }}>
            <RefreshCw size={10} className={loading ? 'spin' : ''} />
          </button>
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-2" style={{ color: 'var(--accent-danger)', fontSize: '0.75rem', marginBottom: '0.4rem' }}>
          <AlertTriangle size={12} /> {error}
        </div>
      )}

      {chartData.length > 0 ? (
        activeTab === 'correlation' ? renderCorrelationChart() : renderStandardChart()
      ) : (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
          {loading ? 'Loading trend data...' : 'No trend data available for this period.'}
        </div>
      )}
    </div>
  );
};

export default TrendChart;
