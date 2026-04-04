import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabaseClient';
import type { Patient } from '@/types';
import { useAuth } from '@/context/AuthContext';
import { hasPermission } from '@/lib/rbac';
import { registerWalkIn } from '@/lib/queueStore';
import {
  Card, Input, Button, Label, Dropdown, Option,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Spinner, MessageBar, MessageBarBody, Badge, Title3,
} from '@fluentui/react-components';
import {
  PersonAdd24Regular, Search24Regular, DocumentBulletList24Regular, ArrowLeft24Regular,
} from '@fluentui/react-icons';
import PatientMedicalHistory from './PatientMedicalHistory';

const GENDERS = ['male', 'female', 'other', 'prefer_not_to_say'];
const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const DEPARTMENTS = ['ER', 'ICU', 'Emergency', 'Trauma', 'General', 'OPD'];
const ACTIVE_HOSPITAL_ID = '2068e105-ad90-4150-9804-9c0c2d4f2879';

export default function PatientRegistration() {
  const { profile } = useAuth();
  const canViewMedicalHistory = hasPermission(profile?.role, 'medical_history', 'decrypt');

  const [patients, setPatients] = useState<Patient[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [view, setView] = useState<'records' | 'register'>('records');

  // ─── Register form state ──────────────────────────────────────────
  const [form, setForm] = useState({
    full_name: '', age: '', gender: '', blood_group: '',
    allergies: '', existing_conditions: '',
    emergency_contact_name: '', emergency_contact_phone: '',
    abha_id: '', phone: '', email: '',
    department: '',
    check_in_time: (() => { const n = new Date(); n.setMinutes(n.getMinutes() - n.getTimezoneOffset()); return n.toISOString().slice(0, 16); })()
  });
  const [submitting, setSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState<{ type: 'success' | 'error'; msg: string } | null>(null);

  // ─── Medical History inline panel state ──────────────────────────
  const [selectedPatient, setSelectedPatient] = useState<{ id: string; name: string } | null>(null);

  useEffect(() => {
    fetchPatients();
  }, []);

  const fetchPatients = async () => {
    try {
      setLoading(true);
      setError(null);
      const { data, error: err } = await supabase
        .from('patient_records')
        .select('*')
        .order('created_at', { ascending: false });

      if (err) throw err;
      setPatients(data || []);
    } catch (err: any) {
      console.error('Records Fetch Error:', err);
      setError('Failed to load patient records. Please contact the administrator.');
    } finally {
      setLoading(false);
    }
  };

  const setField = (key: string, value: string) => setForm(f => ({ ...f, [key]: value }));

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
    });
    setSubmitting(false);
    if (success) {
      setSubmitResult({ type: 'success', msg: patientSaved ? 'Patient registered and added to queue!' : 'Added to queue! (Patient record skipped — requires auth)' });
      const n = new Date(); n.setMinutes(n.getMinutes() - n.getTimezoneOffset());
      setForm({ full_name: '', age: '', gender: '', blood_group: '', allergies: '', existing_conditions: '', emergency_contact_name: '', emergency_contact_phone: '', abha_id: '', phone: '', email: '', department: '', check_in_time: n.toISOString().slice(0, 16) });
      fetchPatients();
    } else {
      setSubmitResult({ type: 'error', msg: error || 'Registration failed.' });
    }
  };

  const filtered = patients.filter((p) => {
    const nameStr = p.full_name || '';
    return nameStr.toLowerCase().includes(search.toLowerCase());
  });

  // ─── If a patient is selected, show their medical history inline ──
  if (selectedPatient) {
    return (
      <div className="module-page">
        {/* Back button bar */}
        <div className="page-header" style={{ marginBottom: 0, paddingBottom: 10, borderBottom: '1px solid var(--border-color)' }}>
          <Button
            appearance="subtle"
            icon={<ArrowLeft24Regular />}
            onClick={() => setSelectedPatient(null)}
          >
            Back to Patient Records
          </Button>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <PersonAdd24Regular style={{ color: 'var(--text-muted)', width: 16 }} />
            <span style={{ color: 'var(--text-muted)', fontSize: '0.85em' }}>{selectedPatient.name}</span>
            <Badge appearance="tint" color="brand" size="small">{selectedPatient.id.slice(0, 8)}…</Badge>
          </div>
        </div>
        {/* Inline medical history panel — patient ID passed directly via props */}
        <PatientMedicalHistory patientId={selectedPatient.id} patientName={selectedPatient.name} />
      </div>
    );
  }

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading patients…" /></div>;

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><PersonAdd24Regular /> Patient Records</h1>
        <div className="page-header__actions">
          {view === 'records' && <Input placeholder="Search patients…" contentBefore={<Search24Regular />} value={search} onChange={(_, d) => setSearch(d.value)} />}
          <Button
            appearance={view === 'register' ? 'primary' : 'outline'}
            icon={<PersonAdd24Regular />}
            onClick={() => { setView(v => v === 'register' ? 'records' : 'register'); setSubmitResult(null); }}
          >
            {view === 'register' ? 'View Records' : 'Register Patient'}
          </Button>
        </div>
      </div>

      {view === 'register' ? (
        <Card style={{ padding: 24, maxWidth: 700, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Title3>Register New Patient</Title3>

          {submitResult && (
            <MessageBar intent={submitResult.type === 'success' ? 'success' : 'error'}>
              <MessageBarBody>{submitResult.msg}</MessageBarBody>
            </MessageBar>
          )}

          <div style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: 8 }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Identity & Contact <span style={{ fontWeight: 400, fontSize: 11 }}>(stored in registered_users)</span></span>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="pr-abha">ABHA ID</Label>
              <Input id="pr-abha" placeholder="e.g. 12-3456-7890-1234" value={form.abha_id} onChange={(_, d) => setField('abha_id', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="pr-phone">Phone</Label>
              <Input id="pr-phone" placeholder="+91 XXXXX XXXXX" value={form.phone} onChange={(_, d) => setField('phone', d.value)} />
            </div>
          </div>

          <div className="form-field">
            <Label htmlFor="pr-email">Email</Label>
            <Input id="pr-email" type="email" placeholder="patient@email.com" value={form.email} onChange={(_, d) => setField('email', d.value)} />
          </div>

          <div style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: 8, marginTop: 4 }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Patient Details <span style={{ fontWeight: 400, fontSize: 11 }}>(stored in patient_records)</span></span>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="pr-age" required>Age</Label>
              <Input id="pr-age" type="number" min={0} value={form.age} onChange={(_, d) => setField('age', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="pr-gender" required>Gender</Label>
              <Dropdown id="pr-gender" placeholder="Select…" value={form.gender} onOptionSelect={(_, d) => setField('gender', d.optionValue ?? '')}>
                {GENDERS.map(g => <Option key={g} value={g} text={g} style={{ textTransform: 'capitalize' }}>{g.replace(/_/g, ' ')}</Option>)}
              </Dropdown>
            </div>
            <div className="form-field">
              <Label htmlFor="pr-bg">Blood Group</Label>
              <Dropdown id="pr-bg" placeholder="Select…" value={form.blood_group} onOptionSelect={(_, d) => setField('blood_group', d.optionValue ?? '')}>
                {BLOOD_GROUPS.map(b => <Option key={b} value={b} text={b}>{b}</Option>)}
              </Dropdown>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="pr-allergy">Allergies</Label>
              <Input id="pr-allergy" placeholder="e.g. Penicillin" value={form.allergies} onChange={(_, d) => setField('allergies', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="pr-conditions">Existing Conditions</Label>
              <Input id="pr-conditions" placeholder="e.g. Diabetes" value={form.existing_conditions} onChange={(_, d) => setField('existing_conditions', d.value)} />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="pr-ec-name">Emergency Contact Name</Label>
              <Input id="pr-ec-name" placeholder="Jane Doe" value={form.emergency_contact_name} onChange={(_, d) => setField('emergency_contact_name', d.value)} />
            </div>
            <div className="form-field">
              <Label htmlFor="pr-ec-phone">Emergency Contact Phone</Label>
              <Input id="pr-ec-phone" placeholder="+91 XXXXX XXXXX" value={form.emergency_contact_phone} onChange={(_, d) => setField('emergency_contact_phone', d.value)} />
            </div>
          </div>

          <div style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: 8, marginTop: 4 }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Queue Details</span>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-field">
              <Label htmlFor="pr-dept" required>Department</Label>
              <Dropdown id="pr-dept" placeholder="Select department…" value={form.department} onOptionSelect={(_, d) => setField('department', d.optionValue ?? '')}>
                {DEPARTMENTS.map(d => <Option key={d} value={d} text={d}>{d}</Option>)}
              </Dropdown>
            </div>
            <div className="form-field">
              <Label htmlFor="pr-checkin" required>Check-In Time</Label>
              <Input id="pr-checkin" type="datetime-local" value={form.check_in_time} onChange={(_, d) => setField('check_in_time', d.value)} />
            </div>
          </div>

          <Button
            appearance="primary"
            icon={submitting ? <Spinner size="tiny" /> : <PersonAdd24Regular />}
            onClick={handleRegister}
            disabled={submitting}
            style={{ marginTop: 8, alignSelf: 'flex-start' }}
          >
            {submitting ? 'Registering...' : 'Register & Add to Queue'}
          </Button>
        </Card>
      ) : error ? (
        <MessageBar intent="error" style={{ marginBottom: 16 }}>
          <MessageBarBody>{error}</MessageBarBody>
        </MessageBar>
      ) : (
        <Card className="table-card">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHeaderCell>Name</TableHeaderCell>
                <TableHeaderCell>Age</TableHeaderCell>
                <TableHeaderCell>Gender</TableHeaderCell>
                <TableHeaderCell>Blood Group</TableHeaderCell>
                <TableHeaderCell>Emergency Contact</TableHeaderCell>
                <TableHeaderCell>Consent</TableHeaderCell>
                <TableHeaderCell>Registered</TableHeaderCell>
                {canViewMedicalHistory && <TableHeaderCell>Actions</TableHeaderCell>}
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={canViewMedicalHistory ? 8 : 7} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)' }}>
                    No patient records found.
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((patient) => (
                  <TableRow key={patient.id}>
                    <TableCell>{patient.full_name || 'Unknown'}</TableCell>
                    <TableCell>{patient.age || '—'}</TableCell>
                    <TableCell style={{ textTransform: 'capitalize' }}>{patient.gender?.replace(/_/g, ' ') || '—'}</TableCell>
                    <TableCell>{patient.blood_group || '—'}</TableCell>
                    <TableCell>
                      {patient.emergency_contact_name || '—'}
                      {patient.emergency_contact_phone ? ` (${patient.emergency_contact_phone})` : ''}
                    </TableCell>
                    <TableCell>{patient.consent_given ? 'Yes' : 'No'}</TableCell>
                    <TableCell>{new Date(patient.created_at).toLocaleDateString()}</TableCell>
                    {canViewMedicalHistory && (
                      <TableCell>
                        <Button
                          size="small"
                          appearance="outline"
                          icon={<DocumentBulletList24Regular />}
                          onClick={() => setSelectedPatient({ id: patient.id, name: patient.full_name || 'Unknown' })}
                        >
                          Medical History
                        </Button>
                      </TableCell>
                    )}
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </Card>
      )}
    </div>
  );
}
