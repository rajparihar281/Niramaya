import { useEffect, useRef } from 'react';
import { useMap } from 'react-leaflet';
import L from 'leaflet';

/**
 * AmbulanceLayer — renders animated ambulance markers on the Leaflet map.
 * Ambulances drift along simulated routes using requestAnimationFrame.
 * 
 * Props:
 *   ambulances: Array of { id, lat, lng, status, destination, callsign }
 *   active: boolean — only render when MCI mode is active
 */

// SVG ambulance icon
const createAmbulanceIcon = (status) => {
  const color = status === 'RESPONDING' ? '#ef4444' : status === 'EN_ROUTE' ? '#f59e0b' : '#10b981';
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="28" height="28">
      <rect x="2" y="8" width="28" height="16" rx="3" fill="${color}" stroke="#0f172a" stroke-width="1.5"/>
      <rect x="7" y="11" width="8" height="5" rx="1" fill="white" opacity="0.9"/>
      <line x1="10" y1="12" x2="10" y2="15" stroke="${color}" stroke-width="1.5"/>
      <line x1="8.5" y1="13.5" x2="11.5" y2="13.5" stroke="${color}" stroke-width="1.5"/>
      <rect x="18" y="10" width="9" height="7" rx="1" fill="rgba(0,0,0,0.3)"/>
      <circle cx="9" cy="24" r="2.5" fill="#334155" stroke="#0f172a" stroke-width="1"/>
      <circle cx="23" cy="24" r="2.5" fill="#334155" stroke="#0f172a" stroke-width="1"/>
      ${status === 'RESPONDING' ? '<circle cx="25" cy="9" r="3" fill="#ef4444" opacity="0.8"><animate attributeName="opacity" values="1;0.3;1" dur="0.6s" repeatCount="indefinite"/></circle>' : ''}
    </svg>
  `;
  return L.divIcon({
    html: svg,
    className: 'ambulance-marker',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  });
};

const AmbulanceLayer = ({ ambulances = [], active = false }) => {
  const map = useMap();
  const markersRef = useRef({});
  const animFrameRef = useRef(null);

  useEffect(() => {
    if (!active || !map) {
      // Clean up markers when MCI mode deactivated
      Object.values(markersRef.current).forEach(m => map.removeLayer(m));
      markersRef.current = {};
      return;
    }

    // Create/update markers
    ambulances.forEach(amb => {
      if (markersRef.current[amb.id]) {
        // Update position
        markersRef.current[amb.id].setLatLng([amb.lat, amb.lng]);
        markersRef.current[amb.id].setIcon(createAmbulanceIcon(amb.status));
      } else {
        // Create new marker
        const marker = L.marker([amb.lat, amb.lng], {
          icon: createAmbulanceIcon(amb.status),
          zIndexOffset: 1000,
        }).addTo(map);

        marker.bindPopup(`
          <div style="min-width:160px; font-family: system-ui;">
            <div style="font-weight:700;font-size:0.9rem;margin-bottom:0.25rem">${amb.callsign}</div>
            <div style="font-size:0.8rem;color:#64748b;margin-bottom:0.4rem">${amb.status.replace('_', ' ')}</div>
            <div style="font-size:0.75rem;display:flex;justify-content:space-between">
              <span>Dest:</span><strong>${amb.destination}</strong>
            </div>
          </div>
        `);

        markersRef.current[amb.id] = marker;
      }
    });

    // Remove stale markers
    const activeIds = new Set(ambulances.map(a => a.id));
    Object.keys(markersRef.current).forEach(id => {
      if (!activeIds.has(id)) {
        map.removeLayer(markersRef.current[id]);
        delete markersRef.current[id];
      }
    });

    return () => {
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    };
  }, [ambulances, active, map]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      Object.values(markersRef.current).forEach(m => {
        if (map.hasLayer(m)) map.removeLayer(m);
      });
      markersRef.current = {};
    };
  }, [map]);

  return null;
};

export default AmbulanceLayer;
