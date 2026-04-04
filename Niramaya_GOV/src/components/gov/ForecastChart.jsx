import React, { useState, useEffect } from 'react';
import { TrendingUp, RefreshCw, AlertTriangle, Calendar } from 'lucide-react';
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ReferenceLine,
} from 'recharts';
import { api } from '../../api';

/**
 * ForecastChart — fetches 14 days of symptom data, then extrapolates
 * a 7-day linear trend forecast per symptom type.
 */

// Tactical palette: critical indicators in red/amber, rest in steel blues
const FORECAST_COLORS = ['#DC2626', '#D97706', '#64748B', '#3B82F6', '#475569', '#94A3B8', '#6B7280'];

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  const isForecast = payload[0]?.payload?._forecast;
  return (
    <div style={{
      background: '#253349', border: '1px solid #334155',
      borderRadius: '3px', padding: '0.4rem 0.6rem', fontSize: '0.72rem',
      fontFamily: "'JetBrains Mono', monospace",
    }}>
      <div style={{ color: isForecast ? '#D97706' : '#94A3B8', marginBottom: '0.2rem', fontSize: '0.65rem' }}>
        {label} {isForecast ? '(FORECAST)' : ''}
      </div>
      {payload.map((p, i) => (
        <div key={i} style={{ color: p.color, display: 'flex', justifyContent: 'space-between', gap: '0.75rem' }}>
          <span style={{ fontFamily: 'Inter, sans-serif' }}>{p.name}</span>
          <strong>{Math.round(p.value)}</strong>
        </div>
      ))}
    </div>
  );
};

const ForecastChart = () => {
  const [chartData, setChartData] = useState([]);
  const [symptomKeys, setSymptomKeys] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [todayLabel, setTodayLabel] = useState('');

  const fetchAndForecast = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.symptomTrends(21);

      if (!res.trends?.length) {
        setChartData([]);
        setLoading(false);
        return;
      }

      const dateMap = {};
      const keys = new Set();
      res.trends.forEach(t => {
        if (!dateMap[t.date]) dateMap[t.date] = { date: t.date, _forecast: false };
        dateMap[t.date][t.symptom_type] = (dateMap[t.date][t.symptom_type] || 0) + t.count;
        keys.add(t.symptom_type);
      });

      const sortedDates = Object.values(dateMap).sort((a, b) => a.date.localeCompare(b.date));
      const symptomList = [...keys];
      setSymptomKeys(symptomList);

      const forecastDays = 7;
      const recentDays = Math.min(sortedDates.length, 14);
      const recentData = sortedDates.slice(-recentDays);

      const slopes = {};
      const intercepts = {};
      symptomList.forEach(sym => {
        const ys = recentData.map(d => d[sym] || 0);
        const n = ys.length;
        if (n < 2) { slopes[sym] = 0; intercepts[sym] = ys[0] || 0; return; }

        const xs = Array.from({ length: n }, (_, i) => i);
        const sumX = xs.reduce((a, b) => a + b, 0);
        const sumY = ys.reduce((a, b) => a + b, 0);
        const sumXY = xs.reduce((a, x, i) => a + x * ys[i], 0);
        const sumXX = xs.reduce((a, x) => a + x * x, 0);

        const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX || 1);
        const intercept = (sumY - slope * sumX) / n;

        slopes[sym] = slope;
        intercepts[sym] = intercept + slope * (n - 1);
      });

      const lastDate = new Date(sortedDates[sortedDates.length - 1].date);
      const todayStr = lastDate.toISOString().split('T')[0];
      setTodayLabel(todayStr);

      const forecastPoints = [];
      for (let i = 1; i <= forecastDays; i++) {
        const fDate = new Date(lastDate);
        fDate.setDate(fDate.getDate() + i);
        const dateStr = fDate.toISOString().split('T')[0];
        const point = { date: dateStr, _forecast: true };

        symptomList.forEach(sym => {
          const predicted = intercepts[sym] + slopes[sym] * i;
          point[sym] = Math.max(0, Math.round(predicted));
        });

        forecastPoints.push(point);
      }

      setChartData([...sortedDates, ...forecastPoints]);
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => { fetchAndForecast(); }, []);

  return (
    <div className="gov-forecast-panel glass-panel">
      <div className="flex justify-between items-center" style={{ marginBottom: '0.5rem' }}>
        <div className="flex items-center gap-2">
          <Calendar size={14} color="#D97706" />
          <h4 style={{ margin: 0, fontSize: '0.85rem' }}>7-Day Epidemic Forecast</h4>
          <span className="forecast-badge">AI PROJECTION</span>
        </div>
        <button className="btn btn-sm btn-outline" onClick={fetchAndForecast} disabled={loading}
          style={{ padding: '0.25rem 0.4rem' }}>
          <RefreshCw size={10} className={loading ? 'spin' : ''} />
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2" style={{ color: 'var(--accent-danger)', fontSize: '0.75rem', marginBottom: '0.4rem' }}>
          <AlertTriangle size={12} /> {error}
        </div>
      )}

      {chartData.length > 0 ? (
        <>
          <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', marginBottom: '0.4rem', display: 'flex', alignItems: 'center', gap: '0.75rem', fontFamily: "'JetBrains Mono', monospace" }}>
            <span>
              <span style={{ display: 'inline-block', width: 10, height: 2, background: '#64748B', marginRight: 4, verticalAlign: 'middle' }}></span>
              HISTORICAL
            </span>
            <span>
              <span style={{ display: 'inline-block', width: 10, height: 2, background: '#D97706', marginRight: 4, verticalAlign: 'middle' }}></span>
              FORECAST
            </span>
          </div>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
              <CartesianGrid strokeDasharray="2 2" stroke="rgba(51, 65, 85, 0.6)" />
              <XAxis
                dataKey="date"
                tick={{ fill: '#64748B', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }}
                tickFormatter={d => d.slice(5)}
              />
              <YAxis tick={{ fill: '#64748B', fontSize: 10, fontFamily: "'JetBrains Mono', monospace" }} />
              <Tooltip content={<CustomTooltip />} />
              <Legend wrapperStyle={{ fontSize: '0.6rem', color: '#64748B' }} />

              {todayLabel && (
                <ReferenceLine
                  x={todayLabel}
                  stroke="#D97706"
                  strokeDasharray="4 3"
                  strokeWidth={1.5}
                  label={{
                    value: 'TODAY',
                    fill: '#D97706',
                    fontSize: 9,
                    fontWeight: 700,
                    fontFamily: "'JetBrains Mono', monospace",
                    position: 'top',
                  }}
                />
              )}

              {symptomKeys.map((key, i) => (
                <Area
                  key={key}
                  type="monotone"
                  dataKey={key}
                  stroke={FORECAST_COLORS[i % FORECAST_COLORS.length]}
                  fill="none"
                  strokeWidth={1.5}
                  dot={false}
                  activeDot={{ r: 2.5, strokeWidth: 1 }}
                  connectNulls
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
          <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', marginTop: '0.3rem', textAlign: 'center', fontFamily: "'JetBrains Mono', monospace" }}>
            LINEAR REGRESSION · 14-DAY WINDOW · NOT A CLINICAL PREDICTION
          </div>
        </>
      ) : (
        <div style={{ textAlign: 'center', padding: '1.5rem', color: 'var(--text-muted)', fontSize: '0.8rem' }}>
          {loading ? 'Generating forecast...' : 'Insufficient data for forecast. Need at least 7 days of symptom logs.'}
        </div>
      )}
    </div>
  );
};

export default ForecastChart;
