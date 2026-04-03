import { useEffect } from 'react';
import { useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet.heat';

/**
 * HeatmapLayer — renders a Leaflet.heat layer on the map.
 * Props:
 *   points: Array of [lat, lng, intensity] triples
 *   options: leaflet.heat config (radius, blur, max, gradient)
 */
const HeatmapLayer = ({ points = [], options = {} }) => {
  const map = useMap();

  useEffect(() => {
    if (!map || points.length === 0) return;

    const defaultOptions = {
      radius: 35,
      blur: 25,
      maxZoom: 17,
      max: 1.0,
      gradient: {
        0.0: '#0ea5e9',   // Sky blue (calm)
        0.3: '#38bdf8',   // Light sky
        0.5: '#f59e0b',   // Amber (warning)
        0.7: '#ef4444',   // Red (danger)
        1.0: '#e11d48',   // Rose (critical)
      },
      ...options,
    };

    const heatLayer = L.heatLayer(points, defaultOptions).addTo(map);

    return () => {
      map.removeLayer(heatLayer);
    };
  }, [map, points, options]);

  return null;
};

export default HeatmapLayer;
