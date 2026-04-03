import React, { useState, useEffect, useRef } from 'react';
import { Radio, AlertTriangle, RefreshCw, MapPin, TrendingUp, Shield } from 'lucide-react';
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { api } from '../api';

// Default center: New Delhi region (matching backend DISTRICT_COORDS)
const DEFAULT_CENTER = [28.6139, 77.2090];
const DEFAULT_ZOOM = 12;

// Dynamically fit map bounds when outbreaks change
const FitBounds = ({ outbreaks }) => {
  const map = useMap();
  useEffect(() => {
    if (outbreaks && outbreaks.length > 0) {
      const bounds = outbreaks.map(o => [o.location.lat, o.location.lng]);
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 14 });
    }
  }, [outbreaks, map]);
  return null;
};

const EpidemicRadar = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedOutbreak, setSelectedOutbreak] = useState(null);

  const fetchOutbreaks = async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await api.predictOutbreak();
      setData(result);
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => { fetchOutbreaks(); }, []);

  const severityStyle = (severity) => {
    if (severity === 'CRITICAL') return { bg: 'rgba(225, 29, 72, 0.1)', border: 'rgba(225, 29, 72, 0.3)', color: 'var(--accent-danger)', mapColor: '#e11d48', mapFill: 'rgba(225, 29, 72, 0.35)' };
    return { bg: 'rgba(245, 158, 11, 0.1)', border: 'rgba(245, 158, 11, 0.3)', color: 'var(--accent-warning)', mapColor: '#f59e0b', mapFill: 'rgba(245, 158, 11, 0.35)' };
  };

  const getMarkerRadius = (spike) => {
    if (spike > 1000) return 45;
    if (spike > 500) return 35;
    if (spike > 200) return 25;
    return 18;
  };

  return (
    <div className="animate-fade-in" style={{ maxWidth: '1200px', margin: '0 auto' }}>
      {/* Header */}
      <div className="flex justify-between items-center" style={{ marginBottom: '1.5rem' }}>
        <h2 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <Radio color="#0ea5e9" /> Epidemic Radar
        </h2>
        <button className="btn btn-outline" onClick={fetchOutbreaks} disabled={loading}>
          <RefreshCw size={16} className={loading ? 'spin' : ''} /> {loading ? 'Scanning...' : 'Refresh Scan'}
        </button>
      </div>

      {/* Error State */}
      {error && (
        <div className="glass-panel" style={{ borderLeft: '4px solid var(--accent-danger)', marginBottom: '1.5rem', color: 'var(--accent-danger)' }}>
          <div className="flex items-center gap-2">
            <AlertTriangle size={18} /> ML Service Error: {error}
          </div>
          <p style={{ color: 'var(--text-muted)', marginTop: '0.5rem', fontSize: '0.85rem' }}>
            Make sure the ML service is running on port 8001.
          </p>
        </div>
      )}

      {data && (
        <>
          {/* Summary Stats */}
          <div className="flex gap-4" style={{ marginBottom: '1.5rem', flexWrap: 'wrap' }}>
            <div className="stat-card">
              <div className="stat-label">Districts Analyzed</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{data.analyzed_districts}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Anomalies Detected</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700, color: data.total_anomalies_detected > 0 ? 'var(--accent-danger)' : 'var(--accent-success)' }}>
                {data.total_anomalies_detected}
              </div>
            </div>
            {data.total_surge_alerts > 0 && (
              <div className="stat-card" style={{ borderColor: 'var(--accent-danger)' }}>
                <div className="stat-label" style={{ color: 'var(--accent-danger)' }}>🚨 Surge Alerts</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--accent-danger)' }}>{data.total_surge_alerts}</div>
              </div>
            )}
          </div>

          {/* Surge Banner */}
          {data.outbreaks?.some(o => o.surge_alert_triggered) && (
            <div className="pulse-emergency" style={{
              padding: '1rem 1.5rem', marginBottom: '1.5rem', borderRadius: 'var(--radius-lg)',
              background: 'linear-gradient(135deg, rgba(225, 29, 72, 0.2), rgba(239, 68, 68, 0.1))',
              border: '2px solid var(--accent-danger)', color: 'var(--accent-danger)', fontWeight: 600,
              display: 'flex', alignItems: 'center', gap: '0.75rem',
            }}>
              <Shield size={24} />
              <div>
                <div>⚠️ SURGE ALERT — Critical outbreak detected with high ML confidence!</div>
                <div style={{ fontSize: '0.85rem', fontWeight: 400, marginTop: '0.25rem' }}>
                  {data.outbreaks.filter(o => o.surge_alert_triggered).map(o => `${o.indicator} in ${o.district}`).join(' | ')}
                </div>
              </div>
            </div>
          )}

          {/* === MAP === */}
          <div className="glass-panel epidemic-map-container" style={{ padding: 0, marginBottom: '1.5rem', overflow: 'hidden' }}>
            <MapContainer
              center={DEFAULT_CENTER}
              zoom={DEFAULT_ZOOM}
              className="epidemic-map"
              scrollWheelZoom={true}
              zoomControl={true}
            >
              <TileLayer
                attribution='&copy; <a href="https://carto.com/">CARTO</a>'
                url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
              />

              {data.outbreaks?.length > 0 && <FitBounds outbreaks={data.outbreaks} />}

              {data.outbreaks?.map((outbreak, i) => {
                const style = severityStyle(outbreak.severity);
                const radius = getMarkerRadius(outbreak.spike_percentage);
                return (
                  <React.Fragment key={i}>
                    {/* Outer glow ring */}
                    <CircleMarker
                      center={[outbreak.location.lat, outbreak.location.lng]}
                      radius={radius + 8}
                      pathOptions={{
                        color: 'transparent',
                        fillColor: style.mapColor,
                        fillOpacity: 0.12,
                      }}
                      className={outbreak.severity === 'CRITICAL' ? 'map-marker-pulse' : ''}
                    />
                    {/* Main marker */}
                    <CircleMarker
                      center={[outbreak.location.lat, outbreak.location.lng]}
                      radius={radius}
                      pathOptions={{
                        color: style.mapColor,
                        fillColor: style.mapFill,
                        fillOpacity: 0.6,
                        weight: 2,
                      }}
                      eventHandlers={{
                        click: () => setSelectedOutbreak(i),
                      }}
                    >
                      <Popup className="epidemic-popup">
                        <div style={{ minWidth: '200px' }}>
                          <div style={{ fontWeight: 700, fontSize: '1rem', marginBottom: '0.25rem' }}>
                            {outbreak.district}
                          </div>
                          <div style={{ fontSize: '0.85rem', color: '#94a3b8', marginBottom: '0.5rem' }}>
                            {outbreak.type} — {outbreak.indicator}
                          </div>
                          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', marginBottom: '0.25rem' }}>
                            <span>Spike:</span>
                            <strong style={{ color: style.mapColor }}>+{outbreak.spike_percentage.toFixed(0)}%</strong>
                          </div>
                          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', marginBottom: '0.25rem' }}>
                            <span>Confidence:</span>
                            <strong>{(outbreak.ml_confidence * 100).toFixed(0)}%</strong>
                          </div>
                          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem' }}>
                            <span>Recent Avg:</span>
                            <strong>{outbreak.recent_daily_avg}/day</strong>
                          </div>
                        </div>
                      </Popup>
                    </CircleMarker>
                  </React.Fragment>
                );
              })}

              {/* If no outbreaks, show a calm center marker */}
              {(!data.outbreaks || data.outbreaks.length === 0) && (
                <CircleMarker
                  center={DEFAULT_CENTER}
                  radius={15}
                  pathOptions={{
                    color: '#10b981',
                    fillColor: 'rgba(16, 185, 129, 0.25)',
                    fillOpacity: 0.5,
                    weight: 2,
                  }}
                >
                  <Popup>
                    <div style={{ textAlign: 'center' }}>
                      <div style={{ fontWeight: 600, marginBottom: '0.25rem' }}>All Clear</div>
                      <div style={{ fontSize: '0.8rem', color: '#64748b' }}>No anomalies detected in this region</div>
                    </div>
                  </Popup>
                </CircleMarker>
              )}
            </MapContainer>
          </div>

          {/* Outbreak Detail Cards */}
          {data.outbreaks?.length > 0 ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1rem' }}>
              {data.outbreaks.map((outbreak, i) => {
                const style = severityStyle(outbreak.severity);
                return (
                  <div key={i}
                    className={`glass-panel animate-fade-in ${selectedOutbreak === i ? 'outbreak-card-selected' : ''}`}
                    style={{
                      borderLeft: `4px solid ${style.color}`,
                      background: style.bg,
                      animationDelay: `${i * 0.1}s`,
                      cursor: 'pointer',
                      transition: 'all 0.2s ease',
                    }}
                    onClick={() => setSelectedOutbreak(i)}
                  >
                    <div className="flex justify-between items-center" style={{ marginBottom: '0.75rem' }}>
                      <span style={{ background: style.color, color: 'white', padding: '0.2rem 0.6rem', borderRadius: '1rem', fontSize: '0.8rem', fontWeight: 600 }}>
                        {outbreak.severity}
                      </span>
                      {outbreak.surge_alert_triggered && (
                        <span style={{ color: 'var(--accent-danger)', fontSize: '0.8rem', fontWeight: 600 }}>🚨 SURGE</span>
                      )}
                    </div>

                    <h4 style={{ marginBottom: '0.5rem' }}>{outbreak.type}</h4>
                    <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '0.75rem' }}>
                      {outbreak.indicator}
                    </div>

                    <div className="flex gap-4" style={{ fontSize: '0.85rem', color: 'var(--text-muted)', flexWrap: 'wrap' }}>
                      <div className="flex items-center gap-2">
                        <MapPin size={14} /> {outbreak.district}
                      </div>
                      <div className="flex items-center gap-2">
                        <TrendingUp size={14} /> +{outbreak.spike_percentage.toFixed(0)}% spike
                      </div>
                    </div>

                    <div style={{ marginTop: '0.75rem', padding: '0.5rem 0.75rem', background: 'var(--bg-tertiary)', borderRadius: '0.5rem', fontSize: '0.8rem' }}>
                      <div className="flex justify-between">
                        <span>Recent Avg: <strong>{outbreak.recent_daily_avg}/day</strong></span>
                        <span>Baseline: <strong>{outbreak.baseline_daily_avg}/day</strong></span>
                      </div>
                      <div style={{ marginTop: '0.25rem' }}>
                        ML Confidence: <strong style={{ color: outbreak.ml_confidence >= 0.8 ? 'var(--accent-danger)' : 'var(--accent-warning)' }}>
                          {(outbreak.ml_confidence * 100).toFixed(0)}%
                        </strong>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="glass-panel text-center" style={{ padding: '3rem', color: 'var(--text-muted)' }}>
              <Shield size={48} style={{ opacity: 0.4, marginBottom: '1rem' }} />
              <p>No outbreaks detected. All districts are within normal parameters.</p>
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default EpidemicRadar;
