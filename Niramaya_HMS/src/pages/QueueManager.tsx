import { useState, useEffect } from 'react';
import {
  fetchQueueLogs,
  registerWalkIn,
  subscribeToQueueLogs,
  onQueueSync,
  type QueueLog
} from '@/lib/queueStore';
import {
  Card, Button, Input, Label, Spinner, Dropdown, Option,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  MessageBar, MessageBarBody, Badge, Title3
} from '@fluentui/react-components';
import {
  PeopleQueue24Regular, TimeAndWeather24Regular, PersonAdd24Regular
} from '@fluentui/react-icons';

const GENDERS = ['male', 'female', 'other', 'prefer_not_to_say'];
const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const DEPARTMENTS = ['ER', 'ICU', 'Emergency', 'Trauma', 'General', 'OPD'];
const ACTIVE_HOSPITAL_ID = '2068e105-ad90-4150-9804-9c0c2d4f2879';

const nowLocal = () => { const n = new Date(); n.setMinutes(n.getMinutes() - n.getTimezoneOffset()); return n.toISOString().slice(0, 16); };
const EMPTY_FORM = { abha_id: '', phone: '', email: '', full_name: '', age: '', gender: '', blood_group: '', allergies: '', existing_conditions: '', emergency_contact_name: '', emergency_contact_phone: '', department: '', check_in_time: nowLocal(), consult_end_time: '' };

export default function QueueManager() {
  const [logs, setLogs] = useState<QueueLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState<{ type: 'success' | 'error'; msg: string } | null>(null);

  const sf = (key: string, value: string) => setForm(f => ({ ...f, [key]: value }));

  const loadLogs = async () => {
    const { data, error } = await fetchQueueLogs();
    if (error) setFetchError(error);
    else setFetchError(null);
    setLogs(data);
    setLoading(false);
  };

  useEffect(() => {
    loadLogs();
    const unsubRealtime = subscribeToQueueLogs();
    const unsubSync = onQueueSync(() => {
      loadLogs();
    });

    return () => {
      unsubRealtime();
      unsubSync();
    };
  }, []);

  const handleRegister = async () => {
    if (!form.full_name || !form.age || !form.gender || !form.department || !form.check_in_time) {
      setSubmitResult({ type: 'error', msg: 'Please fill in all required fields.' });
      return;
    }
    const age = parseInt(form.age, 10);
    if (isNaN(age) || age < 0) {
      setSubmitResult({ type: 'error', msg: 'Age must be a valid number.' });
      return;
    }
    setSubmitting(true);
    setSubmitResult(null);

    const { success, patientSaved, error } = await registerWalkIn({
      abha_id: form.abha_id || undefined,
      phone: form.phone || undefined,
      email: form.email || undefined,
      full_name: form.full_name,
      age,
      gender: form.gender,
      blood_group: form.blood_group || undefined,
      allergies: form.allergies || undefined,
      existing_conditions: form.existing_conditions || undefined,
      emergency_contact_name: form.emergency_contact_name || undefined,
      emergency_contact_phone: form.emergency_contact_phone || undefined,
      hospital_id: ACTIVE_HOSPITAL_ID,
      department_type: form.department,
      check_in_time: new Date(form.check_in_time).toISOString(),
      consultation_end_time: form.consult_end_time ? new Date(form.consult_end_time).toISOString() : null,
    });

    setSubmitting(false);
    if (success) {
      setSubmitResult({ type: 'success', msg: patientSaved ? 'Patient registered and added to queue!' : 'Added to queue! (patient record skipped)' });
      setForm({ ...EMPTY_FORM, check_in_time: nowLocal() });
    } else {
      setSubmitResult({ type: 'error', msg: error || 'Failed to register patient.' });
    }
  };

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading queue logs…" /></div>;

  return (
    <div className="module-page" style={{ height: '100%', overflowY: 'auto' }}>
      <div className="page-header">
        <h1 className="page-title"><PeopleQueue24Regular /> Walk-In Queue Registration</h1>
      </div>

      {fetchError && (
        <MessageBar intent="error" style={{ marginBottom: 16 }}>
          <MessageBarBody>Failed to sync with database: {fetchError}</MessageBarBody>
        </MessageBar>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(420px, 480px) 1fr', gap: 20 }}>
        
        {/* Insert Form */}
        <Card style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 14, height: 'fit-content' }}>
          <Title3>Register Patient</Title3>

          {submitResult && (
            <MessageBar intent={submitResult.type === 'success' ? 'success' : 'error'}>
              <MessageBarBody>{submitResult.msg}</MessageBarBody>
            </MessageBar>
          )}

          {/* ── registered_users ── */}
          <div style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: 6 }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Identity & Contact</span>
          </div>

          <div className="form-field">
            <Label htmlFor="q-abha">ABHA ID</Label>
            <Input id="q-abha" placeholder="12-3456-7890-1234" value={form.abha_id} onChange={(_, d) => sf('abha_id', d.value)} />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="q-phone">Phone</Label>
              <Input id="q-phone" placeholder="+91 XXXXX XXXXX" value={form.phone} onChange={(_, d) => sf('phone', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="q-email">Email</Label>
              <Input id="q-email" type="email" placeholder="patient@email.com" value={form.email} onChange={(_, d) => sf('email', d.value)} />
            </div>
          </div>

          {/* ── patient_records ── */}
          <div style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: 6, marginTop: 4 }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Patient Details</span>
          </div>

          <div className="form-field">
            <Label htmlFor="q-name" required>Full Name</Label>
            <Input id="q-name" placeholder="John Doe" value={form.full_name} onChange={(_, d) => sf('full_name', d.value)} />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="q-age" required>Age</Label>
              <Input id="q-age" type="number" min={0} value={form.age} onChange={(_, d) => sf('age', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="q-gender" required>Gender</Label>
              <Dropdown id="q-gender" placeholder="Select…" value={form.gender} onOptionSelect={(_, d) => sf('gender', d.optionValue ?? '')}>
                {GENDERS.map(g => <Option key={g} value={g} text={g} style={{ textTransform: 'capitalize' }}>{g.replace(/_/g, ' ')}</Option>)}
              </Dropdown>
            </div>
            <div className="form-field">
              <Label htmlFor="q-bg">Blood Group</Label>
              <Dropdown id="q-bg" placeholder="Select…" value={form.blood_group} onOptionSelect={(_, d) => sf('blood_group', d.optionValue ?? '')}>
                {BLOOD_GROUPS.map(b => <Option key={b} value={b} text={b}>{b}</Option>)}
              </Dropdown>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="q-allergy">Allergies</Label>
              <Input id="q-allergy" placeholder="e.g. Penicillin" value={form.allergies} onChange={(_, d) => sf('allergies', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="q-conditions">Existing Conditions</Label>
              <Input id="q-conditions" placeholder="e.g. Diabetes" value={form.existing_conditions} onChange={(_, d) => sf('existing_conditions', d.value)} />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="q-ec-name">Emergency Contact Name</Label>
              <Input id="q-ec-name" placeholder="Jane Doe" value={form.emergency_contact_name} onChange={(_, d) => sf('emergency_contact_name', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="q-ec-phone">Emergency Contact Phone</Label>
              <Input id="q-ec-phone" placeholder="+91 XXXXX XXXXX" value={form.emergency_contact_phone} onChange={(_, d) => sf('emergency_contact_phone', d.value)} />
            </div>
          </div>

          {/* ── queue_logs ── */}
          <div style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: 6, marginTop: 4 }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Queue Details</span>
          </div>

          <div className="form-field">
            <Label htmlFor="q-dept" required>Department</Label>
            <Dropdown id="q-dept" placeholder="Select department…" value={form.department} onOptionSelect={(_, d) => sf('department', d.optionValue ?? '')}>
              {DEPARTMENTS.map(d => <Option key={d} value={d} text={d}>{d}</Option>)}
            </Dropdown>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="q-checkin" required>Check-In Time</Label>
              <Input id="q-checkin" type="datetime-local" value={form.check_in_time} onChange={(_, d) => sf('check_in_time', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="q-end">Consultation End Time</Label>
              <Input id="q-end" type="datetime-local" value={form.consult_end_time} onChange={(_, d) => sf('consult_end_time', d.value)} />
            </div>
          </div>

          <Button
            appearance="primary"
            icon={submitting ? <Spinner size="tiny" /> : <PersonAdd24Regular />}
            onClick={handleRegister}
            disabled={submitting}
            style={{ marginTop: 6 }}
          >
            {submitting ? 'Registering...' : 'Register & Add to Queue'}
          </Button>
        </Card>

        {/* Display Panel */}
        <Card className="table-card" style={{ height: 'fit-content' }}>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHeaderCell>Department</TableHeaderCell>
                <TableHeaderCell>Check-In</TableHeaderCell>
                <TableHeaderCell>Consultation End</TableHeaderCell>
                <TableHeaderCell>Predicted Wait</TableHeaderCell>
              </TableRow>
            </TableHeader>
            <TableBody>
              {logs.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)' }}>
                    No queue metrics available.
                  </TableCell>
                </TableRow>
              ) : (
                logs.map((log) => {
                  const isLongWait = log.predicted_wait_minutes && log.predicted_wait_minutes > 60;
                  return (
                  <TableRow key={log.id}>
                    <TableCell><strong style={{ color: 'var(--text-primary)' }}>{log.department_type}</strong></TableCell>
                    <TableCell>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12 }}>
                        <TimeAndWeather24Regular style={{ width: 14, color: 'var(--text-muted)' }} />
                        {new Date(log.check_in_time).toLocaleString(undefined, {
                          month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
                        })}
                      </div>
                    </TableCell>
                    <TableCell>
                      {log.consultation_end_time ? (
                        <div style={{ fontSize: 12 }}>
                          {new Date(log.consultation_end_time).toLocaleString(undefined, {
                            month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
                          })}
                        </div>
                      ) : (
                        <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>—</span>
                      )}
                    </TableCell>
                    <TableCell>
                      {log.predicted_wait_minutes !== null ? (
                        <Badge appearance={isLongWait ? "filled" : "tint"} color={isLongWait ? "danger" : "brand"}>
                          {log.predicted_wait_minutes} mins
                        </Badge>
                      ) : (
                        <Badge appearance="ghost" color="informative">TBD</Badge>
                      )}
                    </TableCell>
                  </TableRow>
                )})
              )}
            </TableBody>
          </Table>
        </Card>

      </div>
    </div>
  );
}
