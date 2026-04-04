import { useState, useEffect, useRef, useCallback } from 'react';
import {
  fetchInventory,
  fetchSales,
  recordSale,
  onInventorySync,
  subscribeToInventoryChanges,
  type InventoryItemUI,
  type PharmacySaleRow,
} from '@/lib/pharmacyStore';
import { supabase } from '@/lib/supabaseClient';
import { useAuth } from '@/context/AuthContext';
import {
  Card, Button, Input, Label, Spinner,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Dropdown, Option,
  MessageBar, MessageBarBody,
  Dialog, DialogTrigger, DialogSurface, DialogTitle, DialogBody,
  DialogActions, DialogContent,
} from '@fluentui/react-components';
import {
  Cart24Regular,
  Box24Regular,
  CheckmarkCircle24Regular,
  History24Regular,
  Search24Regular,
  Person24Regular,
} from '@fluentui/react-icons';

const LOW_STOCK = 20;

// ─── Patient Search Result ───────────────────────────────────────
interface PatientResult {
  id: string;
  full_name: string | null;
  age: number | null;
  blood_group: string | null;
}

export default function PharmacySales() {
  const { profile } = useAuth();

  const [inventory, setInventory] = useState<InventoryItemUI[]>([]);
  const [sales, setSales] = useState<PharmacySaleRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);

  // Sale form
  const [selectedItemId, setSelectedItemId] = useState<string>('');
  const [submitting, setSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState<{ type: 'success' | 'error'; msg: string } | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  // Patient search state
  const [patientSearch, setPatientSearch] = useState('');
  const [patientResults, setPatientResults] = useState<PatientResult[]>([]);
  const [selectedPatient, setSelectedPatient] = useState<PatientResult | null>(null);
  const [searchingPatients, setSearchingPatients] = useState(false);
  const [showPatientDropdown, setShowPatientDropdown] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // ─── Data loading ──────────────────────────────────────────────
  const loadData = async () => {
    const [invResult, salesResult] = await Promise.all([
      fetchInventory(),
      fetchSales(),
    ]);
    if (invResult.error) setFetchError(invResult.error);
    else setFetchError(null);
    setInventory(invResult.data);
    setSales(salesResult.data);
    setLoading(false);
  };

  useEffect(() => {
    loadData();
    const unsubSync = onInventorySync(() => { loadData(); });
    const unsubRealtime = subscribeToInventoryChanges();
    return () => { unsubSync(); unsubRealtime(); };
  }, []);

  // ─── Patient Search (debounced) ────────────────────────────────
  const searchPatients = useCallback(async (query: string) => {
    const trimmed = query.trim();
    console.log('[PatientSearch] Searching for:', trimmed);
    if (trimmed.length < 1) {
      setPatientResults([]);
      setShowPatientDropdown(false);
      return;
    }
    setSearchingPatients(true);
    const { data, error } = await supabase
      .from('patient_records')
      .select('id, full_name, age, blood_group')
      .ilike('full_name', `%${trimmed}%`)
      .limit(8);

    console.log('[PatientSearch] Response:', { data, error });

    if (!error && data) {
      setPatientResults(data);
      setShowPatientDropdown(data.length > 0);
    } else {
      console.error('[PatientSearch] Query error:', error);
      setPatientResults([]);
      setShowPatientDropdown(false);
    }
    setSearchingPatients(false);
  }, []);

  const handlePatientInput = (value: string) => {
    setPatientSearch(value);
    setSelectedPatient(null);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => searchPatients(value), 300);
  };

  const handlePatientSelect = (patient: PatientResult) => {
    console.log('[PatientSearch] Selected:', patient);
    setSelectedPatient(patient);
    setPatientSearch(patient.full_name || patient.id);
    setShowPatientDropdown(false);
    setPatientResults([]);
  };

  // Close dropdown on outside click (use setTimeout to let onClick fire first)
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setTimeout(() => setShowPatientDropdown(false), 150);
      }
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // ─── Sale logic ────────────────────────────────────────────────
  const selectedItem = inventory.find((i) => i.id === selectedItemId);
  const canSubmit = !!selectedItemId && !!selectedItem && selectedItem.quantity > 0;

  const handleSale = async () => {
    if (!selectedItem || !canSubmit) return;
    setSubmitting(true);
    setSubmitResult(null);

    // Use selected patient's ID as patient_hash, or the search text
    const patientHash = selectedPatient?.id || patientSearch.trim();
    console.log('[PharmacySales] Recording sale:', {
      medicine: selectedItem.name,
      patientHash,
      selectedPatient: selectedPatient ? { id: selectedPatient.id, name: selectedPatient.full_name } : null,
    });
    const result = await recordSale(selectedItem, patientHash);

    setSubmitting(false);
    if (result.success) {
      setSubmitResult({
        type: 'success',
        msg: `✅ Sold 1 × ${selectedItem.name}${selectedPatient ? ` to ${selectedPatient.full_name}` : ''}. Stock updated & verified.`,
      });
      setSelectedItemId('');
      setPatientSearch('');
      setSelectedPatient(null);
      setDialogOpen(false);
    } else {
      setSubmitResult({ type: 'error', msg: result.error || 'Sale failed.' });
    }
  };

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading pharmacy data…" /></div>;

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><Cart24Regular /> Pharmacy Sales</h1>
        <div className="page-header__actions">
          <Dialog open={dialogOpen} onOpenChange={(_, d) => {
            setDialogOpen(d.open);
            setSubmitResult(null);
            if (!d.open) {
              setPatientSearch('');
              setSelectedPatient(null);
              setPatientResults([]);
            }
          }}>
            <DialogTrigger disableButtonEnhancement>
              <Button appearance="primary" icon={<Cart24Regular />}>New Sale</Button>
            </DialogTrigger>
            <DialogSurface>
              <DialogBody>
                <DialogTitle>Record a Sale</DialogTitle>
                <DialogContent>
                  <div className="dialog-form" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

                    {submitResult && (
                      <MessageBar intent={submitResult.type === 'success' ? 'success' : 'error'}>
                        <MessageBarBody>{submitResult.msg}</MessageBarBody>
                      </MessageBar>
                    )}

                    {/* Medicine Selection */}
                    <div className="form-field">
                      <Label htmlFor="sale-product">Medicine *</Label>
                      <Dropdown
                        id="sale-product"
                        placeholder="Select medicine…"
                        value={selectedItem?.name ?? ''}
                        onOptionSelect={(_, d) => {
                          setSelectedItemId(d.optionValue ?? '');
                          setSubmitResult(null);
                        }}
                      >
                        {inventory.map((item) => {
                          const label = `${item.name} — ${item.quantity} ${item.unit}${item.quantity === 0 ? ' (Out of Stock)' : item.quantity <= LOW_STOCK ? ' ⚠️' : ''}`;
                          return (
                            <Option key={item.id} value={item.id} text={item.name} disabled={item.quantity === 0}>
                              {label}
                            </Option>
                          );
                        })}
                      </Dropdown>
                    </div>

                    {selectedItem && (
                      <MessageBar intent={selectedItem.quantity <= LOW_STOCK ? 'warning' : 'info'}>
                        <MessageBarBody>
                          Current stock: <strong>{selectedItem.quantity} {selectedItem.unit}</strong>
                          {selectedItem.quantity <= LOW_STOCK && ' — Low Stock!'}
                          <br />
                          <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                            1 unit will be deducted upon sale.
                          </span>
                        </MessageBarBody>
                      </MessageBar>
                    )}

                    {/* Patient Search */}
                    <div className="form-field" ref={dropdownRef} style={{ position: 'relative' }}>
                      <Label htmlFor="sale-patient"><Person24Regular style={{ width: 14, marginRight: 4 }} />Patient (search by name)</Label>
                      <Input
                        id="sale-patient"
                        value={patientSearch}
                        onChange={(_, d) => handlePatientInput(d.value)}
                        onFocus={() => { if (patientResults.length > 0) setShowPatientDropdown(true); }}
                        contentBefore={searchingPatients ? <Spinner size="tiny" /> : <Search24Regular />}
                        placeholder="Start typing patient name…"
                        autoComplete="off"
                      />

                      {/* Search results dropdown */}
                      {showPatientDropdown && (
                        <div style={{
                          position: 'absolute',
                          top: '100%',
                          left: 0,
                          right: 0,
                          zIndex: 100,
                          background: 'var(--bg-card, #16162a)',
                          border: '1px solid var(--border-color, #2a2a4a)',
                          borderRadius: 'var(--radius-md, 10px)',
                          boxShadow: 'var(--shadow-lg, 0 8px 32px rgba(0,0,0,0.5))',
                          maxHeight: 220,
                          overflowY: 'auto',
                          marginTop: 4,
                        }}>
                          {patientResults.map((p) => (
                            <div
                              key={p.id}
                              onMouseDown={(e) => { e.preventDefault(); handlePatientSelect(p); }}
                              style={{
                                padding: '10px 14px',
                                cursor: 'pointer',
                                display: 'flex',
                                justifyContent: 'space-between',
                                alignItems: 'center',
                                borderBottom: '1px solid rgba(255,255,255,0.05)',
                                transition: 'background 0.15s',
                              }}
                              onMouseEnter={(e) => { e.currentTarget.style.background = 'rgba(99,102,241,0.15)'; }}
                              onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent'; }}
                            >
                              <div style={{ pointerEvents: 'none' }}>
                                <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--text-primary)' }}>
                                  {p.full_name || 'Unknown'}
                                </div>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                                  {p.age ? `Age: ${p.age}` : ''}{p.blood_group ? ` • ${p.blood_group}` : ''}
                                </div>
                              </div>
                              <span style={{ fontSize: 10, color: 'var(--text-muted)', fontFamily: 'monospace', pointerEvents: 'none' }}>
                                {p.id.slice(0, 8)}…
                              </span>
                            </div>
                          ))}
                        </div>
                      )}

                      {/* Selected patient indicator */}
                      {selectedPatient && (
                        <div style={{
                          marginTop: 6,
                          padding: '6px 10px',
                          background: 'rgba(16, 185, 129, 0.1)',
                          border: '1px solid rgba(16, 185, 129, 0.3)',
                          borderRadius: 6,
                          fontSize: 12,
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}>
                          <span>
                            <strong>{selectedPatient.full_name}</strong>
                            {selectedPatient.age && ` • Age ${selectedPatient.age}`}
                            {selectedPatient.blood_group && ` • ${selectedPatient.blood_group}`}
                          </span>
                          <button
                            type="button"
                            onClick={() => { setSelectedPatient(null); setPatientSearch(''); }}
                            style={{
                              background: 'none', border: 'none', color: 'var(--text-muted)',
                              cursor: 'pointer', fontSize: 14, padding: '0 4px',
                            }}
                          >
                            ✕
                          </button>
                        </div>
                      )}

                      {patientSearch.length >= 1 && !searchingPatients && patientResults.length === 0 && !selectedPatient && (
                        <div style={{ marginTop: 4, fontSize: 12, color: 'var(--text-muted)' }}>
                          No patients found for "{patientSearch}"
                        </div>
                      )}
                    </div>
                  </div>
                </DialogContent>
                <DialogActions>
                  <Button appearance="subtle" onClick={() => setDialogOpen(false)}>Cancel</Button>
                  <Button
                    appearance="primary"
                    icon={submitting ? <Spinner size="tiny" /> : <CheckmarkCircle24Regular />}
                    disabled={!canSubmit || submitting}
                    onClick={handleSale}
                  >
                    {submitting ? 'Processing…' : 'Confirm Sale (1 unit)'}
                  </Button>
                </DialogActions>
              </DialogBody>
            </DialogSurface>
          </Dialog>
        </div>
      </div>

      {/* Feedback banners */}
      {fetchError && (
        <MessageBar intent="error" style={{ marginBottom: 16 }}>
          <MessageBarBody>Database error: {fetchError}</MessageBarBody>
        </MessageBar>
      )}
      {submitResult && !dialogOpen && (
        <MessageBar intent={submitResult.type === 'success' ? 'success' : 'error'} style={{ marginBottom: 16 }}>
          <MessageBarBody>{submitResult.msg}</MessageBarBody>
        </MessageBar>
      )}

      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 12, marginBottom: 20 }}>
        <Card style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Box24Regular style={{ color: 'var(--accent)' }} />
            <span style={{ fontWeight: 600 }}>Total Medicines</span>
          </div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{inventory.length}</div>
        </Card>
        <Card style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Box24Regular style={{ color: 'var(--warning)' }} />
            <span style={{ fontWeight: 600 }}>Low Stock</span>
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--warning)' }}>
            {inventory.filter((i) => i.quantity <= LOW_STOCK && i.quantity > 0).length}
          </div>
        </Card>
        <Card style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <History24Regular style={{ color: 'var(--accent)' }} />
            <span style={{ fontWeight: 600 }}>Total Sales</span>
          </div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{sales.length}</div>
        </Card>
      </div>

      {/* Sales History */}
      <div className="page-header" style={{ marginBottom: 12 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 8 }}>
          <History24Regular /> Sales History
        </h2>
      </div>

      <Card className="table-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Medicine</TableHeaderCell>
              <TableHeaderCell>Patient</TableHeaderCell>
              <TableHeaderCell>Verified</TableHeaderCell>
              <TableHeaderCell>Date & Time</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {sales.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)' }}>
                  No sales recorded yet. Use "New Sale" to record a transaction.
                </TableCell>
              </TableRow>
            ) : (
              sales.map((sale) => (
                <TableRow key={sale.id}>
                  <TableCell>{sale.medicine_name || '—'}</TableCell>
                  <TableCell style={{ fontSize: 12 }}>{sale.patient_hash || '—'}</TableCell>
                  <TableCell>{sale.is_verified ? '✅ OK' : '⏳ Pending'}</TableCell>
                  <TableCell style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                    {new Date(sale.created_at).toLocaleString()}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </Card>
    </div>
  );
}
