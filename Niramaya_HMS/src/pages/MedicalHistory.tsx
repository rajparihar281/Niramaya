import { useState, useEffect } from 'react';
import { useAuth } from '@/context/AuthContext';
import { hasPermission } from '@/lib/rbac';
import { supabase } from '@/lib/supabaseClient';
import {
  Card, Badge, Button,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Dialog, DialogSurface, DialogTitle, DialogBody, DialogContent, DialogActions,
  Input, Spinner, MessageBar, MessageBarBody,
} from '@fluentui/react-components';
import { DocumentBulletList24Regular, LockOpen24Regular, Search24Regular } from '@fluentui/react-icons';

// ─── DB Row shape matching public.medical_reports exactly ────────
interface MedicalReportRow {
  id: string;
  patient_hash: string;
  doctor_id: string | null;
  encrypted_content: string;
  iv: string;
  created_at: string;
}

export default function MedicalHistory() {
  const { profile } = useAuth();
  const [reports, setReports] = useState<MedicalReportRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [decryptDialogOpen, setDecryptDialogOpen] = useState(false);
  const [selectedReport, setSelectedReport] = useState<MedicalReportRow | null>(null);

  const canDecrypt = hasPermission(profile?.role, 'medical_history', 'decrypt');

  useEffect(() => {
    fetchReports();
  }, []);

  const fetchReports = async () => {
    try {
      setLoading(true);
      setFetchError(null);

      const { data, error } = await supabase
        .from('medical_reports')
        .select('id, patient_hash, doctor_id, encrypted_content, iv, created_at')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setReports(data || []);
    } catch (err: any) {
      console.error('[MedicalHistory] Fetch error:', err);
      setFetchError('Failed to load medical records. Please try again or contact the administrator.');
    } finally {
      setLoading(false);
    }
  };

  const filtered = reports.filter((r) => {
    const hash = r.patient_hash || '';
    return hash.toLowerCase().includes(search.toLowerCase());
  });

  const openDecryptDialog = (report: MedicalReportRow) => {
    setSelectedReport(report);
    setDecryptDialogOpen(true);
  };

  if (loading) {
    return <div className="page-loader"><Spinner size="large" label="Loading medical records…" /></div>;
  }

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><DocumentBulletList24Regular /> Medical Records</h1>
        <div className="page-header__actions">
          <Input
            placeholder="Search by patient hash…"
            contentBefore={<Search24Regular />}
            value={search}
            onChange={(_, d) => setSearch(d.value)}
          />
        </div>
      </div>

      {!canDecrypt && (
        <MessageBar intent="warning" className="rbac-notice">
          <MessageBarBody>
            Medical data is encrypted. Your role does not have decryption access — record content is masked.
          </MessageBarBody>
        </MessageBar>
      )}

      {fetchError ? (
        <MessageBar intent="error" style={{ marginBottom: 16 }}>
          <MessageBarBody>{fetchError}</MessageBarBody>
        </MessageBar>
      ) : (
        <Card className="table-card">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHeaderCell>Patient Hash</TableHeaderCell>
                <TableHeaderCell>Encrypted Content</TableHeaderCell>
                <TableHeaderCell>Created</TableHeaderCell>
                {canDecrypt && <TableHeaderCell>Action</TableHeaderCell>}
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={canDecrypt ? 4 : 3}
                    style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)' }}
                  >
                    No medical records found.
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((report) => (
                  <TableRow key={report.id}>
                    <TableCell>
                      <Badge appearance="tint" color="brand">
                        {report.patient_hash.slice(0, 12)}…
                      </Badge>
                    </TableCell>
                    <TableCell style={{ fontFamily: 'monospace', fontSize: '0.8em', opacity: 0.7 }}>
                      {canDecrypt
                        ? `${report.encrypted_content.slice(0, 32)}…`
                        : '████████████ ████████ ██████████'}
                    </TableCell>
                    <TableCell>{new Date(report.created_at).toLocaleDateString()}</TableCell>
                    {canDecrypt && (
                      <TableCell>
                        <Button
                          size="small"
                          appearance="outline"
                          icon={<LockOpen24Regular />}
                          onClick={() => openDecryptDialog(report)}
                        >
                          View
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

      {/* ─── Record Detail Dialog ─── */}
      <Dialog open={decryptDialogOpen} onOpenChange={(_, d) => setDecryptDialogOpen(d.open)}>
        <DialogSurface>
          <DialogBody>
            <DialogTitle>Encrypted Medical Record</DialogTitle>
            <DialogContent className="dialog-form">
              {selectedReport && (
                <div className="decrypted-view">
                  <div className="decrypted-field">
                    <strong>Patient Hash:</strong> {selectedReport.patient_hash}
                  </div>
                  <div className="decrypted-field">
                    <strong>Doctor ID:</strong> {selectedReport.doctor_id || 'Unassigned'}
                  </div>
                  <div className="decrypted-field">
                    <strong>IV (Encryption Nonce):</strong>
                    <code style={{ fontSize: '0.75em', display: 'block', marginTop: 4, opacity: 0.7 }}>
                      {selectedReport.iv}
                    </code>
                  </div>
                  <div className="decrypted-field">
                    <strong>Encrypted Payload:</strong>
                    <code style={{ fontSize: '0.75em', display: 'block', marginTop: 4, wordBreak: 'break-all', opacity: 0.7 }}>
                      {selectedReport.encrypted_content}
                    </code>
                  </div>
                  <MessageBar intent="warning" style={{ marginTop: 12 }}>
                    <MessageBarBody>
                      Full decryption requires the client-side key. This panel shows the raw encrypted payload from the database.
                    </MessageBarBody>
                  </MessageBar>
                </div>
              )}
            </DialogContent>
            <DialogActions>
              <Button onClick={() => setDecryptDialogOpen(false)}>Close</Button>
            </DialogActions>
          </DialogBody>
        </DialogSurface>
      </Dialog>
    </div>
  );
}
