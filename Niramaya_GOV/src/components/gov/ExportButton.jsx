import React, { useState } from 'react';
import { Download, ChevronDown } from 'lucide-react';

/**
 * ExportButton — downloads current outbreak + bed data as CSV.
 * Props:
 *   data: outbreak detection result object
 *   bedData: array of department objects (optional)
 */
const ExportButton = ({ data }) => {
  const [open, setOpen] = useState(false);

  const exportCSV = () => {
    if (!data?.outbreaks?.length) return;

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const headers = [
      'District', 'Indicator', 'Severity', 'Type',
      'Spike%', 'ML_Confidence%', 'Recent_Daily_Avg', 'Baseline_Daily_Avg',
      'Latitude', 'Longitude'
    ];

    const rows = data.outbreaks.map(o => [
      o.district,
      o.indicator,
      o.severity,
      o.type,
      o.spike_percentage.toFixed(1),
      (o.ml_confidence * 100).toFixed(1),
      o.recent_daily_avg,
      o.baseline_daily_avg,
      o.location.lat,
      o.location.lng,
    ]);

    const csv = [
      `# Niramaya Surveillance Export - ${new Date().toLocaleString()}`,
      `# Districts Analyzed: ${data.analyzed_districts}`,
      `# Total Anomalies: ${data.total_anomalies_detected}`,
      '',
      headers.join(','),
      ...rows.map(r => r.join(',')),
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `niramaya_outbreak_${timestamp}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    setOpen(false);
  };

  return (
    <div style={{ position: 'relative' }}>
      <button
        className="btn btn-sm btn-outline"
        onClick={() => data?.outbreaks?.length ? exportCSV() : null}
        disabled={!data?.outbreaks?.length}
        style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}
        title="Export outbreak data as CSV"
      >
        <Download size={11} /> CSV
      </button>
    </div>
  );
};

export default ExportButton;
