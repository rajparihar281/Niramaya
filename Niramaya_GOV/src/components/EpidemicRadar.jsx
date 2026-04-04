import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Radio, AlertTriangle, RefreshCw, MapPin, TrendingUp,
  Shield, Activity, Bed, Siren, Eye, Building2
} from 'lucide-react';
import { MapContainer, TileLayer, CircleMarker, Popup, Tooltip as LeafletTooltip, useMap } from 'react-leaflet';
import HeatmapLayer from './gov/HeatmapLayer';
import TrendChart from './gov/TrendChart';
import ResourcePanel from './gov/ResourcePanel';
import AlertSystem from './gov/AlertSystem';
import ForecastChart from './gov/ForecastChart';
import HospitalLayer from './gov/HospitalLayer';
import AmbulanceLayer from './gov/AmbulanceLayer';
import MCIPanel from './gov/MCIPanel';
import AnimatedCounter from './gov/AnimatedCounter';
import Sparkline from './gov/Sparkline';
import LiveClock from './gov/LiveClock';
import ExportButton from './gov/ExportButton';
import OutbreakDrawer from './gov/OutbreakDrawer';
import 'leaflet/dist/leaflet.css';
import { api } from '../api';

// Default center: New Delhi (matching backend DISTRICT_COORDS)
const DEFAULT_CENTER = [28.6180, 77.2200];
const DEFAULT_ZOOM = 12;

// Base heatmap grid for ambient glow even when no outbreaks
const AMBIENT_POINTS = [
  [28.6139, 77.2090, 0.15],
  [28.6200, 77.2200, 0.12],
  [28.6300, 77.2300, 0.10],
  [28.6400, 77.2400, 0.08],
  [28.6050, 77.1950, 0.06],
  [28.6250, 77.2050, 0.09],
  [28.6350, 77.2150, 0.07],
  [28.6100, 77.2350, 0.05],
  [28.6450, 77.2100, 0.06],
  [28.6180, 77.2280, 0.08],
];

// Auto-fit map bounds — only on first data load
const FitBounds = ({ outbreaks }) => {
  const map = useMap();
  const hasFitted = useRef(false);
  useEffect(() => {
    if (!hasFitted.current && outbreaks && outbreaks.length > 0) {
      const bounds = outbreaks.map(o => [o.location.lat, o.location.lng]);
      map.fitBounds(bounds, { padding: [60, 60], maxZoom: 13 });
      hasFitted.current = true;
    }
  }, [outbreaks, map]);
  return null;
};

// Fly to a specific target when triggered
const FlyToTarget = ({ target }) => {
  const map = useMap();
  useEffect(() => {
    if (target) {
      map.flyTo([target.lat, target.lng], target.zoom || 15, { duration: 0.8 });
    }
  }, [target, map]);
  return null;
};

const GovDashboard = () => {
  const [data, setData] = useState(null);
  const [prevData, setPrevData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastRefresh, setLastRefresh] = useState(null);
  const [selectedOutbreak, setSelectedOutbreak] = useState(null);
  const [viewMode, setViewMode] = useState('heatmap'); // 'heatmap' | 'markers'
  const [mciActive, setMciActive] = useState(false);
  const [ambulances, setAmbulances] = useState([]);
  const [flyTarget, setFlyTarget] = useState(null);
  const [trendCache, setTrendCache] = useState({}); // { symptom_type: [val, val, ...] }
  const [detailOutbreak, setDetailOutbreak] = useState(null);
  const [hospitals, setHospitals] = useState([]);
  const [showHospitals, setShowHospitals] = useState(false);

  const handleAmbulanceUpdate = useCallback((ambs) => {
    setAmbulances(ambs);
  }, []);

  const handleZoomToOutbreak = (outbreak) => {
    setFlyTarget({ lat: outbreak.location.lat, lng: outbreak.location.lng, zoom: 15 });
  };

  const fetchOutbreaks = async () => {
    setLoading(true);
    setError(null);
    try {
      const [result, trendRes, hospRes] = await Promise.all([
        api.predictOutbreak(),
        api.symptomTrends(7),
        api.hospitals(),
      ]);
      setPrevData(data); // Store previous for alert diff
      setData(result);
      if (hospRes?.hospitals) setHospitals(hospRes.hospitals);
      setLastRefresh(new Date());

      // Build sparkline data per symptom type from 7-day trends
      if (trendRes.trends?.length) {
        const bySymptom = {};
        trendRes.trends.forEach(t => {
          if (!bySymptom[t.symptom_type]) bySymptom[t.symptom_type] = {};
          bySymptom[t.symptom_type][t.date] = (bySymptom[t.symptom_type][t.date] || 0) + t.count;
        });
        const cache = {};
        Object.entries(bySymptom).forEach(([sym, dateMap]) => {
          cache[sym] = Object.entries(dateMap)
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([, v]) => v);
        });
        setTrendCache(cache);
      }
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchOutbreaks();
    // Auto-refresh every 30s
    const interval = setInterval(fetchOutbreaks, 30000);
    return () => clearInterval(interval);
  }, []);

  // Build heatmap points from outbreak data + ambient grid
  const buildHeatPoints = () => {
    const points = [...AMBIENT_POINTS];
    if (data?.outbreaks) {
      data.outbreaks.forEach(o => {
        // Intensity scales with spike severity (normalized 0-1)
        const intensity = Math.min(1.0, o.spike_percentage / 1000);
        points.push([o.location.lat, o.location.lng, intensity]);
        // Add surrounding glow points for spread effect
        const spread = 0.005;
        points.push([o.location.lat + spread, o.location.lng, intensity * 0.6]);
        points.push([o.location.lat - spread, o.location.lng, intensity * 0.6]);
        points.push([o.location.lat, o.location.lng + spread, intensity * 0.6]);
        points.push([o.location.lat, o.location.lng - spread, intensity * 0.6]);
        points.push([o.location.lat + spread, o.location.lng + spread, intensity * 0.4]);
        points.push([o.location.lat - spread, o.location.lng - spread, intensity * 0.4]);
      });
    }
    return points;
  };

  const severityStyle = (severity) => {
    if (severity === 'CRITICAL') return { color: 'var(--accent-danger)', mapColor: '#e11d48', fill: 'rgba(225, 29, 72, 0.35)' };
    return { color: 'var(--accent-warning)', mapColor: '#f59e0b', fill: 'rgba(245, 158, 11, 0.35)' };
  };

  const getMarkerRadius = (spike) => {
    if (spike > 1000) return 40;
    if (spike > 500) return 30;
    if (spike > 200) return 22;
    return 16;
  };

  const anomalyCount = data?.total_anomalies_detected || 0;
  const surgeCount = data?.total_surge_alerts || 0;

  return (
    <div className="animate-fade-in gov-dashboard">
      {/* ── Alert System ── */}
      <AlertSystem data={data} prevData={prevData} />

      {/* ── Header ── */}
      <div className="gov-header">
        <div className="flex items-center gap-2">
          <Siren color="#3B82F6" size={18} />
          <h2 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, letterSpacing: '-0.01em' }}>Government Surveillance Dashboard</h2>
          <LiveClock />
        </div>
        <div className="flex items-center gap-4">
          {lastRefresh && (
            <span className="gov-timestamp" style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: '0.65rem' }}>
              <Activity size={10} className={loading ? 'spin' : ''} />
              {loading ? 'SCANNING...' : `LAST: ${lastRefresh.toLocaleTimeString()}`}
            </span>
          )}
          <div className="flex gap-2">
            <button
              className={`btn btn-sm ${viewMode === 'heatmap' ? 'btn-primary' : 'btn-outline'}`}
              onClick={() => setViewMode('heatmap')}
              style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}
            >
              <Eye size={12} /> Heatmap
            </button>
            <button
              className={`btn btn-sm ${viewMode === 'markers' ? 'btn-primary' : 'btn-outline'}`}
              onClick={() => setViewMode('markers')}
              style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}
            >
              <MapPin size={12} /> Markers
            </button>
            <div style={{ width: '1px', background: 'var(--glass-border)', margin: '0 4px' }} />
            <button
              className={`btn btn-sm ${showHospitals ? 'btn-primary' : 'btn-outline'}`}
              onClick={() => setShowHospitals(!showHospitals)}
              style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}
            >
              <Building2 size={12} /> Hospitals
            </button>
          </div>
          <ExportButton data={data} />
          <button className="btn btn-outline btn-sm" onClick={fetchOutbreaks} disabled={loading}
            style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}>
            <RefreshCw size={12} className={loading ? 'spin' : ''} /> Refresh
          </button>
        </div>
      </div>

      {/* ── Error ── */}
      {error && (
        <div className="glass-panel" style={{ borderLeft: '4px solid var(--accent-danger)', marginBottom: '1rem', color: 'var(--accent-danger)' }}>
          <div className="flex items-center gap-2">
            <AlertTriangle size={18} /> ML Service Error: {error}
          </div>
        </div>
      )}

      {/* ── Surge Alert Banner ── */}
      {data?.outbreaks?.some(o => o.surge_alert_triggered) && (
        <div className="surge-banner">
          <Shield size={16} />
          <div>
            <strong>⚠️ SURGE ALERT — Critical outbreak detected!</strong>
            <div style={{ fontSize: '0.85rem', fontWeight: 400, marginTop: '0.15rem' }}>
              {data.outbreaks.filter(o => o.surge_alert_triggered).map(o => `${o.indicator} in ${o.district}`).join(' · ')}
            </div>
          </div>
        </div>
      )}

      {data && (
        <>
        {/* ── Top: Executive Summary Stats ── */}
        <div className="gov-stats-row gov-stats-header">
          <div className={`gov-stat ${anomalyCount > 0 ? 'gov-stat-danger' : 'gov-stat-ok'}`}>
            <div className="stat-label">Threat Level</div>
            <div className="gov-stat-value">
              {surgeCount > 0 ? '🔴 CRITICAL' : anomalyCount > 0 ? '🟡 ELEVATED' : '🟢 NORMAL'}
            </div>
          </div>
          <div className="gov-stat">
            <div className="stat-label">Districts</div>
            <div className="gov-stat-value"><AnimatedCounter value={data.analyzed_districts} /></div>
          </div>
          <div className={`gov-stat ${anomalyCount > 0 ? 'gov-stat-danger' : ''}`}>
            <div className="stat-label">Anomalies</div>
            <div className="gov-stat-value" style={{ color: anomalyCount > 0 ? 'var(--accent-danger)' : 'var(--accent-success)' }}>
              <AnimatedCounter value={anomalyCount} />
            </div>
          </div>
          {surgeCount > 0 && (
            <div className="gov-stat gov-stat-danger">
              <div className="stat-label">🚨 Surges</div>
              <div className="gov-stat-value" style={{ color: 'var(--accent-danger)' }}><AnimatedCounter value={surgeCount} /></div>
            </div>
          )}
        </div>

        <div className="gov-grid">
          {/* ── Left: Map ── */}
          <div className="gov-map-panel">
            <div className="epidemic-map-container" style={{ padding: 0 }}>
              <MapContainer
                center={DEFAULT_CENTER}
                zoom={DEFAULT_ZOOM}
                className="epidemic-map gov-map"
                scrollWheelZoom={true}
                zoomControl={true}
              >
                <TileLayer
                  attribution='&copy; <a href="https://carto.com/">CARTO</a>'
                  url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                />

                {data.outbreaks?.length > 0 && <FitBounds outbreaks={data.outbreaks} />}
                <FlyToTarget target={flyTarget} />

                {viewMode === 'heatmap' && (
                  <HeatmapLayer
                    points={buildHeatPoints()}
                    options={{
                      radius: anomalyCount > 0 ? 40 : 30,
                      blur: anomalyCount > 0 ? 20 : 30,
                      max: 1.0,
                    }}
                  />
                )}

                {/* Heatmap mode: invisible click targets — hover shows tooltip, click zooms */}
                {viewMode === 'heatmap' && data.outbreaks?.map((outbreak, i) => (
                  <CircleMarker
                    key={`heat-click-${i}`}
                    center={[outbreak.location.lat, outbreak.location.lng]}
                    radius={getMarkerRadius(outbreak.spike_percentage) + 10}
                    pathOptions={{ color: 'transparent', fillColor: 'transparent', fillOpacity: 0, weight: 0 }}
                    eventHandlers={{
                      click: () => { handleZoomToOutbreak(outbreak); setDetailOutbreak(outbreak); },
                    }}
                  >
                    <LeafletTooltip direction="top" offset={[0, -10]} className="tactical-tooltip" permanent={false}>
                      <div style={{ fontWeight: 700, fontSize: '0.8rem' }}>{outbreak.district}</div>
                      <div style={{ fontSize: '0.7rem', color: '#94a3b8' }}>{outbreak.indicator} — +{outbreak.spike_percentage.toFixed(0)}%</div>
                      <div style={{ fontSize: '0.65rem', color: '#64748B' }}>Confidence: {(outbreak.ml_confidence * 100).toFixed(0)}%</div>
                    </LeafletTooltip>
                  </CircleMarker>
                ))}

                {viewMode === 'markers' && data.outbreaks?.map((outbreak, i) => {
                  const style = severityStyle(outbreak.severity);
                  const radius = getMarkerRadius(outbreak.spike_percentage);
                  return (
                    <React.Fragment key={i}>
                      <CircleMarker
                        center={[outbreak.location.lat, outbreak.location.lng]}
                        radius={radius + 8}
                        pathOptions={{ color: 'transparent', fillColor: style.mapColor, fillOpacity: 0.12 }}
                        className={outbreak.severity === 'CRITICAL' ? 'map-marker-pulse' : ''}
                      />
                      <CircleMarker
                        center={[outbreak.location.lat, outbreak.location.lng]}
                        radius={radius}
                        pathOptions={{ color: style.mapColor, fillColor: style.fill, fillOpacity: 0.6, weight: 2 }}
                        eventHandlers={{
                          click: () => {
                            setSelectedOutbreak(i);
                            handleZoomToOutbreak(outbreak);
                            setDetailOutbreak(outbreak);
                          }
                        }}
                      >
                        <LeafletTooltip direction="top" offset={[0, -10]} className="tactical-tooltip" permanent={false}>
                          <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.15rem' }}>{outbreak.district}</div>
                          <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginBottom: '0.3rem' }}>{outbreak.type} — {outbreak.indicator}</div>
                          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', gap: '0.5rem' }}>
                            <span>Spike: <strong style={{ color: style.mapColor }}>+{outbreak.spike_percentage.toFixed(0)}%</strong></span>
                            <span>Conf: <strong>{(outbreak.ml_confidence * 100).toFixed(0)}%</strong></span>
                          </div>
                          <div style={{ fontSize: '0.7rem', marginTop: '0.15rem' }}>
                            Avg: {outbreak.recent_daily_avg}/day vs {outbreak.baseline_daily_avg}/day
                          </div>
                        </LeafletTooltip>
                      </CircleMarker>
                    </React.Fragment>
                  );
                })}

                {viewMode === 'markers' && (!data.outbreaks || data.outbreaks.length === 0) && (
                  <CircleMarker center={DEFAULT_CENTER} radius={15}
                    pathOptions={{ color: '#10b981', fillColor: 'rgba(16, 185, 129, 0.25)', fillOpacity: 0.5, weight: 2 }}>
                    <Popup><div style={{ textAlign: 'center' }}><strong>All Clear</strong><br /><span style={{ fontSize: '0.8rem', color: '#64748b' }}>No anomalies in region</span></div></Popup>
                  </CircleMarker>
                )}

                {/* MCI Ambulance Markers */}
                <AmbulanceLayer ambulances={ambulances} active={mciActive} />

                {/* Hospital Layer */}
                <HospitalLayer hospitals={hospitals} active={showHospitals} />
              </MapContainer>
            </div>
          </div>

          {/* ── Right: Intel Panel ── */}
          <div className="gov-intel-panel">
            <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.6rem', display: 'flex', alignItems: 'center', gap: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.05em', flexShrink: 0 }}>
              <Activity size={14} /> Active Anomalies detected
            </div>
            <div className="gov-outbreak-list">
            {data.outbreaks?.length > 0 ? (
              data.outbreaks.map((outbreak, i) => {
                const style = severityStyle(outbreak.severity);
                return (
                  <div key={i}
                    className={`gov-outbreak-card ${selectedOutbreak === i ? 'outbreak-card-selected' : ''}`}
                    style={{ borderLeftColor: style.color }}
                    onClick={() => { setSelectedOutbreak(i); handleZoomToOutbreak(outbreak); setDetailOutbreak(outbreak); }}
                  >
                    <div className="flex justify-between items-center" style={{ marginBottom: '0.4rem' }}>
                      <span className="gov-severity-tag" style={{ background: style.color }}>{outbreak.severity}</span>
                      {outbreak.surge_alert_triggered && <span style={{ color: 'var(--accent-danger)', fontSize: '0.75rem', fontWeight: 600 }}>🚨 SURGE</span>}
                    </div>
                    <div className="flex justify-between items-center">
                      <div style={{ fontWeight: 600, fontSize: '0.95rem' }}>{outbreak.indicator}</div>
                      {trendCache[outbreak.indicator] && (
                        <Sparkline
                          data={trendCache[outbreak.indicator]}
                          width={72}
                          height={22}
                          color={style.color}
                        />
                      )}
                    </div>
                    <div className="flex justify-between" style={{ marginTop: '0.4rem', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                      <span className="flex items-center gap-2"><MapPin size={12} /> {outbreak.district}</span>
                      <span className="flex items-center gap-2"><TrendingUp size={12} /> +<AnimatedCounter value={parseFloat(outbreak.spike_percentage.toFixed(0))} />%</span>
                    </div>
                    <div style={{ marginTop: '0.4rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      Confidence: <strong style={{ color: outbreak.ml_confidence >= 0.8 ? 'var(--accent-danger)' : 'var(--accent-warning)' }}><AnimatedCounter value={parseFloat((outbreak.ml_confidence * 100).toFixed(0))} />%</strong>
                      {' · '}Avg: {outbreak.recent_daily_avg}/day vs {outbreak.baseline_daily_avg}/day
                    </div>
                  </div>
                );
              })
            ) : (
              <div className="gov-all-clear">
                <Shield size={36} style={{ opacity: 0.4 }} />
                <div>No active outbreaks</div>
                <div style={{ fontSize: '0.8rem' }}>All {data.analyzed_districts} districts within normal parameters</div>
              </div>
            )}
            </div>
          </div>
        </div>

        {/* ── Middle-Lower: Operational Logistics ── */}
        <div className="gov-logistics-row">
          <ResourcePanel />
          <MCIPanel mciActive={mciActive} setMciActive={setMciActive} onAmbulances={handleAmbulanceUpdate} />
        </div>

        {/* ── Bottom: Time-Series Trends (Full Width) ── */}
        <TrendChart days={14} />

        {/* ── 7-Day Forecast ── */}
        <ForecastChart />
        </>
      )}

      {/* Outbreak Detail Drawer */}
      {detailOutbreak && (
        <OutbreakDrawer outbreak={detailOutbreak} onClose={() => setDetailOutbreak(null)} />
      )}
    </div>
  );
};

export default GovDashboard;
