import { useState, useEffect } from 'react';
import { INITIAL_PRESCRIPTIONS, getLocalData } from '@/lib/mockData';
import type { Prescription } from '@/types';
import {
  Card, Badge,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Input, Spinner,
} from '@fluentui/react-components';
import { Pill24Regular, Search24Regular } from '@fluentui/react-icons';

export default function Prescriptions() {
  const [prescriptions, setPrescriptions] = useState<Prescription[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => { fetchPrescriptions(); }, []);

  const fetchPrescriptions = async () => {
    setPrescriptions(getLocalData('prescriptions', INITIAL_PRESCRIPTIONS));
    setLoading(false);
  };

  const STATUS_COLORS: Record<string, 'success' | 'warning' | 'danger'> = { active: 'warning', dispensed: 'success', cancelled: 'danger' };
  
  const filtered = prescriptions.filter((rx) => rx.patient_id.toLowerCase().includes(search.toLowerCase()));

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading prescriptions…" /></div>;

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><Pill24Regular /> Prescriptions</h1>
        <div className="page-header__actions">
          <Input placeholder="Search records…" contentBefore={<Search24Regular />} value={search} onChange={(_, d) => setSearch(d.value)} />
        </div>
      </div>

      <Card className="table-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Patient ID</TableHeaderCell>
              <TableHeaderCell>Medications</TableHeaderCell>
              <TableHeaderCell>Status</TableHeaderCell>
              <TableHeaderCell>Date</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((rx) => (
              <TableRow key={rx.id}>
                <TableCell>{rx.patient_id.slice(0, 8)}…</TableCell>
                <TableCell>{rx.medications?.map((m) => `${m.medication_name} ${m.dosage}`).join(', ') || '—'}</TableCell>
                <TableCell><Badge appearance="filled" color={STATUS_COLORS[rx.status] || 'informative'}>{rx.status}</Badge></TableCell>
                <TableCell>{new Date(rx.created_at).toLocaleDateString()}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>
    </div>
  );
}
