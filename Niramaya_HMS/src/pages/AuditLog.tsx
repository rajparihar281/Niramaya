import { useState, useEffect } from 'react';
import { useAuth } from '@/context/AuthContext';
import { INITIAL_AUDIT, getLocalData } from '@/lib/mockData';
import type { AuditEntry } from '@/types';
import {
  Card, Badge,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Input, Select, Spinner,
} from '@fluentui/react-components';
import { Shield24Regular, Search24Regular } from '@fluentui/react-icons';

export default function AuditLog() {
  const { profile } = useAuth();
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [entityFilter, setEntityFilter] = useState('all');

  useEffect(() => { fetchEntries(); }, []);

  const fetchEntries = async () => {
    setEntries(getLocalData('audit', INITIAL_AUDIT));
    setLoading(false);
  };

  const entityTypes = [...new Set(entries.map((e) => e.entity_type))];

  const filtered = entries.filter((e) => {
    const matchesSearch = e.action.toLowerCase().includes(search.toLowerCase()) || e.entity_type.toLowerCase().includes(search.toLowerCase());
    const matchesEntity = entityFilter === 'all' || e.entity_type === entityFilter;
    return matchesSearch && matchesEntity;
  });

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading audit log…" /></div>;

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><Shield24Regular /> Audit Log</h1>
        <div className="page-header__actions">
          <Input placeholder="Search actions…" contentBefore={<Search24Regular />} value={search} onChange={(_, d) => setSearch(d.value)} />
          <Select value={entityFilter} onChange={(_, d) => setEntityFilter(d.value)}>
            <option value="all">All Entities</option>
            {entityTypes.map((et) => <option key={et} value={et}>{et}</option>)}
          </Select>
        </div>
      </div>

      <Card className="table-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Action</TableHeaderCell>
              <TableHeaderCell>Entity</TableHeaderCell>
              <TableHeaderCell>Performed By</TableHeaderCell>
              <TableHeaderCell>Details</TableHeaderCell>
              <TableHeaderCell>TX Hash</TableHeaderCell>
              <TableHeaderCell>Time</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((entry) => (
              <TableRow key={entry.id}>
                <TableCell><Badge appearance="outline" color="informative">{entry.action}</Badge></TableCell>
                <TableCell>{entry.entity_type}</TableCell>
                <TableCell>{entry.performed_by.slice(0, 12)}…</TableCell>
                <TableCell>{entry.details?.slice(0, 50) || '—'}</TableCell>
                <TableCell>{entry.tx_hash ? <code className="tx-hash">{entry.tx_hash.slice(0, 10)}…</code> : '—'}</TableCell>
                <TableCell>{new Date(entry.created_at).toLocaleString()}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>

      <div className="audit-summary">
        <Card className="info-card">
          <p className="info-card__text">Total entries: <strong>{entries.length}</strong> | Role: <strong>{profile?.role}</strong></p>
        </Card>
      </div>
    </div>
  );
}
