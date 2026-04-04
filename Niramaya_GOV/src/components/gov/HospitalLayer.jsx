import React from 'react';
import { CircleMarker, Tooltip } from 'react-leaflet';
import { Building2, Activity } from 'lucide-react';
import ReactDOMServer from 'react-dom/server';

const HospitalLayer = ({ hospitals, active }) => {
  if (!active || !hospitals || hospitals.length === 0) return null;

  const getStatusColor = (utilization) => {
    if (utilization > 0.9) return '#e11d48'; // Critical
    if (utilization > 0.7) return '#f59e0b'; // Warning
    return '#10b981'; // Normal
  };

  return (
    <>
      {hospitals.map((h, i) => {
        const color = getStatusColor(h.utilization);
        return (
          <React.Fragment key={`hosp-${h.id}`}>
            <CircleMarker
              center={[h.lat, h.lng]}
              radius={8}
              pathOptions={{
                color: color,
                fillColor: color,
                fillOpacity: 0.8,
                weight: 2
              }}
            >
              <Tooltip direction="top" offset={[0, -10]} className="tactical-tooltip" permanent={false}>
                <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.2rem', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <Building2 size={12} /> {h.name}
                </div>
                <div style={{ fontSize: '0.75rem', color: '#94a3b8' }}>
                  Total Beds: {h.total_beds}<br/>
                  Available: <strong style={{ color: color }}>{h.available_beds}</strong>
                </div>
                <div style={{ fontSize: '0.7rem', marginTop: '0.3rem', borderTop: '1px solid #334155', paddingTop: '0.3rem' }}>
                  Utilization: {(h.utilization * 100).toFixed(0)}%
                </div>
              </Tooltip>
            </CircleMarker>
            {/* Pulse effect if critical */}
            {h.utilization > 0.9 && (
              <CircleMarker
                center={[h.lat, h.lng]}
                radius={16}
                pathOptions={{
                  color: 'transparent',
                  fillColor: color,
                  fillOpacity: 0.2
                }}
                className="map-marker-pulse"
              />
            )}
          </React.Fragment>
        );
      })}
    </>
  );
};

export default HospitalLayer;
