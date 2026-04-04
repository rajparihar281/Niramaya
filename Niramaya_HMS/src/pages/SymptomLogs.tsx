import { useState, useEffect } from 'react';
import {
  fetchSymptomLogs,
  insertSymptomLog,
  subscribeToSymptomLogs,
  onSymptomsSync,
  type SymptomLog,
} from '@/lib/symptomStore';
import {
  Card, Button, Input, Label, Spinner, Dropdown, Option,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  MessageBar, MessageBarBody, Badge,
} from '@fluentui/react-components';
import {
  Stethoscope24Regular, Search24Regular, Send24Regular, Location24Regular
} from '@fluentui/react-icons';

const SYMPTOM_TYPES = [
  'Fever',
  'Cough',
  'Respiratory Distress',
  'Nausea',
  'Severe Dehydration',
  'Headache',
  'Fatigue'
];

export default function SymptomLogs() {
  const [logs, setLogs] = useState<SymptomLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  // Form State
  const [district, setDistrict] = useState('');
  const [symptomType, setSymptomType] = useState<string>('');
  const [occurrenceCount, setOccurrenceCount] = useState<string>('');
  const [latitude, setLatitude] = useState<string>('');
  const [longitude, setLongitude] = useState<string>('');
  const [submitting, setSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState<{ type: 'success' | 'error'; msg: string } | null>(null);

  const loadLogs = async () => {
    const { data, error } = await fetchSymptomLogs();
    if (error) setFetchError(error);
    else setFetchError(null);
    setLogs(data);
    setLoading(false);
  };

  useEffect(() => {
    loadLogs();
    const unsubRealtime = subscribeToSymptomLogs();
    const unsubSync = onSymptomsSync(() => {
      loadLogs();
    });

    return () => {
      unsubRealtime();
      unsubSync();
    };
  }, []);

  const handleInsert = async () => {
    if (!district || !symptomType || !occurrenceCount) {
      setSubmitResult({ type: 'error', msg: 'District, Symptom Type, and Occurrence Count are required.' });
      return;
    }

    const count = parseInt(occurrenceCount, 10);
    if (isNaN(count) || count < 1) {
      setSubmitResult({ type: 'error', msg: 'Occurrence count must be a valid number greater than 0.' });
      return;
    }

    setSubmitting(true);
    setSubmitResult(null);

    const lat = latitude ? parseFloat(latitude) : undefined;
    const lng = longitude ? parseFloat(longitude) : undefined;

    const { success, error } = await insertSymptomLog(district, symptomType, count, lat, lng);

    setSubmitting(false);

    if (success) {
      setSubmitResult({ type: 'success', msg: 'Log submitted successfully!' });
      // Reset form
      setDistrict('');
      setSymptomType('');
      setOccurrenceCount('');
      setLatitude('');
      setLongitude('');
    } else {
      setSubmitResult({ type: 'error', msg: error || 'Failed to submit log.' });
    }
  };

  const filteredLogs = logs.filter((log) =>
    log.district.toLowerCase().includes(search.toLowerCase()) ||
    log.symptom_type.toLowerCase().includes(search.toLowerCase())
  );

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading symptom logs…" /></div>;

  return (
    <div className="module-page" style={{ height: '100%', overflowY: 'auto' }}>
      <div className="page-header">
        <h1 className="page-title"><Stethoscope24Regular /> Symptom Logs</h1>
        <div className="page-header__actions">
          <Input
            placeholder="Search district or symptom…"
            contentBefore={<Search24Regular />}
            value={search}
            onChange={(_, d) => setSearch(d.value)}
            style={{ width: 250 }}
          />
        </div>
      </div>

      {fetchError && (
        <MessageBar intent="error" style={{ marginBottom: 16 }}>
          <MessageBarBody>Failed to sync with database: {fetchError}</MessageBarBody>
        </MessageBar>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(300px, 350px) 1fr', gap: 20 }}>
        {/* Left column: Insert Form */}
        <Card style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 16, height: 'fit-content' }}>
          <h3 style={{ margin: 0, fontSize: 18, fontWeight: 600 }}>Report New Log</h3>
          
          {submitResult && (
            <MessageBar intent={submitResult.type === 'success' ? 'success' : 'error'}>
              <MessageBarBody>{submitResult.msg}</MessageBarBody>
            </MessageBar>
          )}

          <div className="form-field">
            <Label htmlFor="slog-district" required>District</Label>
            <Input 
              id="slog-district" 
              placeholder="e.g. Andheri" 
              value={district}
              onChange={(_, d) => setDistrict(d.value)}
            />
          </div>

          <div className="form-field">
            <Label htmlFor="slog-symptom" required>Symptom Type</Label>
            <Dropdown
              id="slog-symptom"
              placeholder="Select symptom…"
              value={symptomType}
              onOptionSelect={(_, d) => setSymptomType(d.optionValue ?? '')}
            >
              {SYMPTOM_TYPES.map((type) => (
                <Option key={type} value={type} text={type}>{type}</Option>
              ))}
            </Dropdown>
          </div>

          <div className="form-field">
            <Label htmlFor="slog-count" required>Occurrence Count</Label>
            <Input 
              id="slog-count" 
              type="number" 
              min={1}
              placeholder="Number of cases" 
              value={occurrenceCount}
              onChange={(_, d) => setOccurrenceCount(d.value)}
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="slog-lat">Latitude</Label>
              <Input 
                id="slog-lat" 
                type="number" 
                step="any"
                placeholder="(Optional)" 
                value={latitude}
                onChange={(_, d) => setLatitude(d.value)}
              />
            </div>
            <div className="form-field">
              <Label htmlFor="slog-lng">Longitude</Label>
              <Input 
                id="slog-lng" 
                type="number" 
                step="any"
                placeholder="(Optional)" 
                value={longitude}
                onChange={(_, d) => setLongitude(d.value)}
              />
            </div>
          </div>

          <Button 
            appearance="primary" 
            icon={submitting ? <Spinner size="tiny" /> : <Send24Regular />}
            onClick={handleInsert}
            disabled={submitting}
            style={{ marginTop: 8 }}
          >
            {submitting ? 'Submitting...' : 'Submit Log'}
          </Button>
        </Card>

        {/* Right column: Data Display Table */}
        <Card className="table-card" style={{ height: 'fit-content' }}>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHeaderCell>District</TableHeaderCell>
                <TableHeaderCell>Symptom</TableHeaderCell>
                <TableHeaderCell>Cases</TableHeaderCell>
                <TableHeaderCell>Location</TableHeaderCell>
                <TableHeaderCell>Reported At</TableHeaderCell>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredLogs.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)' }}>
                    No symptom logs found.
                  </TableCell>
                </TableRow>
              ) : (
                filteredLogs.map((log) => (
                  <TableRow key={log.id}>
                    <TableCell><strong style={{ color: 'var(--text-primary)' }}>{log.district}</strong></TableCell>
                    <TableCell><Badge appearance="tint" color="danger">{log.symptom_type}</Badge></TableCell>
                    <TableCell><span style={{ fontWeight: 600 }}>{log.occurrence_count}</span></TableCell>
                    <TableCell>
                      {log.latitude && log.longitude ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: 'var(--text-muted)' }}>
                          <Location24Regular style={{ width: 14 }} />
                          {log.latitude.toFixed(4)}, {log.longitude.toFixed(4)}
                        </div>
                      ) : (
                        <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>—</span>
                      )}
                    </TableCell>
                    <TableCell style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                      {new Date(log.created_at).toLocaleString()}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </Card>
      </div>
    </div>
  );
}
