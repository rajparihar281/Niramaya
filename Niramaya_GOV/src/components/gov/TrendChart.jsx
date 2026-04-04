import React, { useState, useEffect } from 'react';
import { TrendingUp, RefreshCw, AlertTriangle } from 'lucide-react';
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, BarChart, Bar,
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

const fallbackColor = (name, palette) => {
  if (palette[name]) return palette[name];
  const hash = [...name].reduce((a, c) => a + c.charCodeAt(0), 0);
  // Muted steel blues/grays
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

const TrendChart = ({ days = 14 }) => {
  const [symptomData, setSymptomData] = useState([]);
  const [pharmaData, setPharmaData] = useState([]);
  const [symptomKeys, setSymptomKeys] = useState([]);
  const [pharmaKeys, setPharmaKeys] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState('symptoms');

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [symRes, pharRes] = await Promise.all([
        api.symptomTrends(days),
        api.pharmaTrends(days),
      ]);

      // Pivot symptom trends: group by date, spread symptom_type as columns
      if (symRes.trends?.length) {
        const dateMap = {};
        const keys = new Set();
        symRes.trends.forEach(t => {
          if (!dateMap[t.date]) dateMap[t.date] = { date: t.date };
          dateMap[t.date][t.symptom_type] = (dateMap[t.date][t.symptom_type] || 0) + t.count;
          keys.add(t.symptom_type);
        });
        const sorted = Object.values(dateMap).sort((a, b) => a.date.localeCompare(b.date));
        setSymptomData(sorted);
        setSymptomKeys([...keys]);
      } else {
        setSymptomData([]);
        setSymptomKeys([]);
      }

      // Pivot pharma trends
      if (pharRes.trends?.length) {
        const dateMap = {};
        const keys = new Set();
        pharRes.trends.forEach(t => {
          if (!dateMap[t.date]) dateMap[t.date] = { date: t.date };
          dateMap[t.date][t.medicine_name] = (dateMap[t.date][t.medicine_name] || 0) + t.count;
          keys.add(t.medicine_name);
        });
        const sorted = Object.values(dateMap).sort((a, b) => a.date.localeCompare(b.date));
        setPharmaData(sorted);
        setPharmaKeys([...keys]);
      } else {
        setPharmaData([]);
        setPharmaKeys([]);
      }
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => { fetchData(); }, [days]);

  const chartData = activeTab === 'symptoms' ? symptomData : pharmaData;
  const chartKeys = activeTab === 'symptoms' ? symptomKeys : pharmaKeys;
  const palette = activeTab === 'symptoms' ? SYMPTOM_COLORS : PHARMA_COLORS;

  return (
    <div className="gov-trend-panel glass-panel">
      <div className="flex justify-between items-center" style={{ marginBottom: '0.5rem' }}>
        <div className="flex items-center gap-2">
          <TrendingUp size={14} color="#3B82F6" />
          <h4 style={{ margin: 0, fontSize: '0.85rem' }}>Epidemiological Trends</h4>
        </div>
        <div className="flex gap-2">
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
            Pharma Sales
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
      ) : (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
          {loading ? 'Loading trend data...' : 'No trend data available for this period.'}
        </div>
      )}
    </div>
  );
};

export default TrendChart;
