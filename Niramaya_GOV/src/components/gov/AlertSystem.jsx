import React, { useState, useEffect, useRef } from 'react';
import { Bell, BellRing, Clock, AlertTriangle, Shield, MapPin, X } from 'lucide-react';

/**
 * AlertSystem — Detects new anomalies by comparing successive poll results.
 * Shows a flashing banner when new outbreaks appear + maintains an alert history log.
 *
 * Props:
 *   data       — current outbreak response from API
 *   prevData   — previous outbreak response (for diff)
 */

const AlertSystem = ({ data, prevData }) => {
  const [alerts, setAlerts] = useState([]);
  const [showBanner, setShowBanner] = useState(false);
  const [bannerAlert, setBannerAlert] = useState(null);
  const [expanded, setExpanded] = useState(false);
  const audioRef = useRef(null);

  // Compare current vs previous data to detect NEW outbreaks
  useEffect(() => {
    if (!data || !prevData) return;

    const prevDistricts = new Set(
      (prevData.outbreaks || []).map(o => `${o.district}:${o.indicator}`)
    );
    const newOutbreaks = (data.outbreaks || []).filter(
      o => !prevDistricts.has(`${o.district}:${o.indicator}`)
    );

    if (newOutbreaks.length > 0) {
      const newAlerts = newOutbreaks.map(o => ({
        id: Date.now() + Math.random(),
        timestamp: new Date(),
        district: o.district,
        indicator: o.indicator,
        severity: o.severity,
        spike: o.spike_percentage,
        confidence: o.ml_confidence,
        type: o.type,
        dismissed: false,
      }));

      setAlerts(prev => [...newAlerts, ...prev].slice(0, 50));
      setBannerAlert(newAlerts[0]);
      setShowBanner(true);

      // Auto-dismiss banner after 10s
      setTimeout(() => setShowBanner(false), 10000);
    }

    // Also detect resolution (outbreaks that disappeared)
    const currentDistricts = new Set(
      (data.outbreaks || []).map(o => `${o.district}:${o.indicator}`)
    );
    const resolvedOutbreaks = (prevData.outbreaks || []).filter(
      o => !currentDistricts.has(`${o.district}:${o.indicator}`)
    );
    if (resolvedOutbreaks.length > 0) {
      const resolvedAlerts = resolvedOutbreaks.map(o => ({
        id: Date.now() + Math.random(),
        timestamp: new Date(),
        district: o.district,
        indicator: o.indicator,
        severity: 'RESOLVED',
        spike: 0,
        confidence: 0,
        type: 'Resolved',
        dismissed: false,
      }));
      setAlerts(prev => [...resolvedAlerts, ...prev].slice(0, 50));
    }
  }, [data, prevData]);

  const unreadCount = alerts.filter(a => !a.dismissed).length;

  const severityIcon = (sev) => {
    if (sev === 'CRITICAL') return '🔴';
    if (sev === 'WARNING') return '🟡';
    if (sev === 'RESOLVED') return '🟢';
    return '⚪';
  };

  const timeSince = (date) => {
    const secs = Math.floor((Date.now() - date.getTime()) / 1000);
    if (secs < 60) return `${secs}s ago`;
    if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
    return `${Math.floor(secs / 3600)}h ago`;
  };

  return (
    <>
      {/* Flashing New Alert Banner */}
      {showBanner && bannerAlert && (
        <div className="alert-flash-banner">
          <div className="alert-flash-content">
            <BellRing size={20} className="alert-bell-ring" />
            <div>
              <strong>
                {bannerAlert.severity === 'CRITICAL' ? '🚨 CRITICAL ALERT' : '⚠️ NEW ALERT'} —{' '}
                {bannerAlert.indicator} in {bannerAlert.district}
              </strong>
              <div style={{ fontSize: '0.8rem', opacity: 0.85, marginTop: '0.15rem' }}>
                +{bannerAlert.spike?.toFixed(0)}% spike · ML Confidence: {(bannerAlert.confidence * 100).toFixed(0)}%
              </div>
            </div>
          </div>
          <button className="alert-dismiss-btn" onClick={() => setShowBanner(false)}>
            <X size={16} />
          </button>
        </div>
      )}

      {/* Alert Bell + History Panel */}
      <div className="alert-system">
        <button
          className={`alert-bell-btn ${unreadCount > 0 ? 'alert-bell-active' : ''}`}
          onClick={() => setExpanded(!expanded)}
          title="Alert History"
        >
          {unreadCount > 0 ? <BellRing size={18} /> : <Bell size={18} />}
          {unreadCount > 0 && <span className="alert-badge">{unreadCount}</span>}
        </button>

        {expanded && (
          <div className="alert-history-panel">
            <div className="alert-history-header">
              <h4 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                <Bell size={16} /> Alert History
              </h4>
              {alerts.length > 0 && (
                <button
                  className="btn btn-sm btn-outline"
                  onClick={() => setAlerts(prev => prev.map(a => ({ ...a, dismissed: true })))}
                  style={{ fontSize: '0.7rem', padding: '0.2rem 0.5rem' }}
                >
                  Mark all read
                </button>
              )}
            </div>

            <div className="alert-history-list">
              {alerts.length === 0 ? (
                <div className="alert-empty">
                  <Shield size={28} style={{ opacity: 0.3 }} />
                  <div>No alerts yet</div>
                  <div style={{ fontSize: '0.75rem' }}>Alerts appear when new anomalies are detected between polling cycles</div>
                </div>
              ) : (
                alerts.map(alert => (
                  <div
                    key={alert.id}
                    className={`alert-history-item ${!alert.dismissed ? 'alert-unread' : ''}`}
                    onClick={() => {
                      setAlerts(prev => prev.map(a => a.id === alert.id ? { ...a, dismissed: true } : a));
                    }}
                  >
                    <div className="flex justify-between items-center" style={{ marginBottom: '0.2rem' }}>
                      <span style={{ fontWeight: 600, fontSize: '0.8rem' }}>
                        {severityIcon(alert.severity)} {alert.severity}
                      </span>
                      <span style={{ color: 'var(--text-muted)', fontSize: '0.7rem', display: 'flex', alignItems: 'center', gap: '0.2rem' }}>
                        <Clock size={10} /> {timeSince(alert.timestamp)}
                      </span>
                    </div>
                    <div style={{ fontSize: '0.85rem', fontWeight: 500 }}>{alert.indicator}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                      <MapPin size={10} /> {alert.district}
                      {alert.spike > 0 && <> · +{alert.spike.toFixed(0)}%</>}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>
    </>
  );
};

export default AlertSystem;
