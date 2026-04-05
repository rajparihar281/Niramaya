import React, { useState, useEffect } from 'react';
import { Bed, RefreshCw, AlertTriangle, Heart } from 'lucide-react';
import { api } from '../../api';

const ResourcePanel = () => {
  const [departments, setDepartments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.bedStatus();
      setDepartments(res.departments || []);
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 60000); // refresh every minute
    return () => clearInterval(interval);
  }, []);

  const totalBeds = departments.reduce((s, d) => s + (d.total_beds || 0), 0);
  const availBeds = departments.reduce((s, d) => s + (d.available_beds || 0), 0);
  const overallUtil = totalBeds > 0 ? ((totalBeds - availBeds) / totalBeds) : 0;

  const utilColor = (u) => {
    if (u >= 0.9) return 'var(--accent-danger)';
    if (u >= 0.7) return 'var(--accent-warning)';
    return 'var(--accent-success)';
  };

  return (
    <div className="gov-resource-panel glass-panel">
      <div className="flex justify-between items-center" style={{ marginBottom: '1rem' }}>
        <div className="flex items-center gap-2">
          <Bed size={18} color="#0ea5e9" />
          <h4 style={{ margin: 0 }}>Resource & Bed Status</h4>
        </div>
        <button className="btn btn-sm btn-outline" onClick={fetchData} disabled={loading}>
          <RefreshCw size={12} className={loading ? 'spin' : ''} />
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2" style={{ color: 'var(--accent-danger)', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
          <AlertTriangle size={14} /> {error}
        </div>
      )}

      {departments.length > 0 ? (
        <>
          {/* Overall summary */}
          <div className="resource-summary" style={{ marginBottom: '1rem' }}>
            <div className="flex justify-between items-center" style={{ marginBottom: '0.4rem' }}>
              <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>
                <Heart size={14} style={{ display: 'inline', marginRight: '4px', verticalAlign: 'text-bottom', color: utilColor(overallUtil) }} />
                Overall Utilization
              </span>
              <span style={{ fontWeight: 700, color: utilColor(overallUtil) }}>
                {(overallUtil * 100).toFixed(0)}%
              </span>
            </div>
            <div className="resource-bar-bg">
              <div
                className="resource-bar-fill"
                style={{
                  width: `${Math.min(overallUtil * 100, 100)}%`,
                  background: `linear-gradient(90deg, ${utilColor(overallUtil)}, ${utilColor(overallUtil)}88)`,
                }}
              />
            </div>
            <div className="flex justify-between" style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
              <span>{availBeds} beds available</span>
              <span>{totalBeds} total</span>
            </div>
          </div>

          {/* Per-department bars */}
          <div className="resource-dept-list">
            {departments.map((dept, i) => (
              <div key={i} className="resource-dept-row">
                <div className="flex justify-between items-center" style={{ marginBottom: '0.3rem' }}>
                  <span className="resource-dept-name">{dept.department_type}</span>
                  <span className="resource-dept-stat">
                    <span style={{ color: utilColor(dept.utilization), fontWeight: 600 }}>
                      {dept.available_beds}
                    </span>
                    <span style={{ color: 'var(--text-muted)' }}>/{dept.total_beds}</span>
                  </span>
                </div>
                <div className="resource-bar-bg resource-bar-sm">
                  <div
                    className="resource-bar-fill"
                    style={{
                      width: `${Math.min(dept.utilization * 100, 100)}%`,
                      background: utilColor(dept.utilization),
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </>
      ) : (
        <div style={{ textAlign: 'center', padding: '1.5rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
          {loading ? 'Loading resources...' : 'No department data available.'}
        </div>
      )}
    </div>
  );
};

export default ResourcePanel;
