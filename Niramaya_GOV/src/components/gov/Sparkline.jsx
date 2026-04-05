import React from 'react';

/**
 * Sparkline — tiny inline SVG chart for outbreak cards.
 * 
 * Props:
 *   data: number[] — array of values (7-14 data points ideal)
 *   width: number (default 80)
 *   height: number (default 24)
 *   color: string (default '#DC2626')
 *   showDot: boolean — show dot on last point (default true)
 */
const Sparkline = ({ data = [], width = 80, height = 24, color = '#DC2626', showDot = true }) => {
  if (!data.length || data.length < 2) return null;

  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const padding = 3;
  const innerW = width - padding * 2;
  const innerH = height - padding * 2;

  const points = data.map((val, i) => {
    const x = padding + (i / (data.length - 1)) * innerW;
    const y = padding + innerH - ((val - min) / range) * innerH;
    return `${x},${y}`;
  });

  const polyline = points.join(' ');
  const lastPoint = points[points.length - 1].split(',');

  // Determine trend direction for area fill
  const isRising = data[data.length - 1] > data[0];
  const fillColor = isRising ? color : '#64748B';

  // Build area path (close to bottom)
  const areaPoints = [
    `${padding},${padding + innerH}`,
    ...points,
    `${padding + innerW},${padding + innerH}`,
  ].join(' ');

  return (
    <svg width={width} height={height} style={{ display: 'block', overflow: 'visible' }}>
      {/* Subtle area fill */}
      <polygon
        points={areaPoints}
        fill={fillColor}
        fillOpacity={0.1}
      />
      {/* Line */}
      <polyline
        points={polyline}
        fill="none"
        stroke={color}
        strokeWidth={1.2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {/* Last point dot */}
      {showDot && (
        <circle
          cx={parseFloat(lastPoint[0])}
          cy={parseFloat(lastPoint[1])}
          r={2}
          fill={color}
          stroke="#1E293B"
          strokeWidth={1}
        />
      )}
    </svg>
  );
};

export default Sparkline;
