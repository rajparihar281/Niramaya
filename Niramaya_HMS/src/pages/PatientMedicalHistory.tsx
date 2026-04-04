import { useState, useEffect, useCallback, useRef } from "react";
import { useAuth } from "@/context/AuthContext";
import { supabase } from "@/lib/supabaseClient";
import { hasPermission } from "@/lib/rbac";
import {
  Card,
  Button,
  Spinner,
  MessageBar,
  MessageBarBody,
  Textarea,
  Input,
  Badge,
  Divider,
  Dialog,
  DialogSurface,
  DialogTitle,
  DialogBody,
  DialogContent,
  DialogActions,
} from "@fluentui/react-components";
import {
  DocumentBulletList24Regular,
  Add24Regular,
  Timer24Regular,
  LockClosed24Regular,
  Person24Regular,
  ChevronDown24Regular,
  ChevronUp24Regular,
} from "@fluentui/react-icons";

// ─── DB Types ──────────────────────────────────────────────────────
interface MedicalRecord {
  id: string;
  patient_id: string;
  doctor_id: string | null;
  diagnosis: string;
  notes: string | null;
  metadata: Record<string, any>;
  created_at: string;
}

// ─── 15-minute timer in seconds ──────────────────────────────────
const ACCESS_DURATION_SECONDS = 15 * 60; // 15 minutes

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
    .toString()
    .padStart(2, "0");
  const s = (seconds % 60).toString().padStart(2, "0");
  return `${m}:${s}`;
}

// ─── Timer Badge Component ────────────────────────────────────────
function AccessTimer({ onExpire }: { onExpire: () => void }) {
  const [remaining, setRemaining] = useState(ACCESS_DURATION_SECONDS);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    intervalRef.current = setInterval(() => {
      setRemaining((prev) => {
        if (prev <= 1) {
          clearInterval(intervalRef.current!);
          onExpire();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(intervalRef.current!);
  }, [onExpire]);

  const isWarning = remaining < 120; // red below 2 minutes
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 6,
        padding: "4px 12px",
        borderRadius: 20,
        background: isWarning
          ? "rgba(239,68,68,0.15)"
          : "rgba(99,102,241,0.15)",
        border: `1px solid ${isWarning ? "rgba(239,68,68,0.4)" : "rgba(99,102,241,0.4)"}`,
        color: isWarning ? "#ef4444" : "#818cf8",
        fontFamily: "monospace",
        fontSize: "0.85em",
        fontWeight: 600,
        transition: "all 0.5s ease",
      }}
    >
      <Timer24Regular style={{ width: 16, height: 16 }} />
      {formatTime(remaining)}
    </div>
  );
}

// ─── Record Card Component ────────────────────────────────────────
function RecordCard({
  record,
  canView,
}: {
  record: MedicalRecord;
  canView: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const [locked, setLocked] = useState(false);

  const handleExpire = useCallback(() => {
    setExpanded(false);
    setLocked(true);
  }, []);

  const handleViewClick = () => {
    if (locked) return;
    setExpanded((prev) => !prev);
  };

  return (
    <div
      style={{
        background: "var(--bg-card)",
        border: "1px solid var(--border-color)",
        borderRadius: 10,
        overflow: "hidden",
        transition: "border-color 0.2s",
      }}
    >
      {/* Record Header Row */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 12,
          padding: "12px 16px",
          cursor: canView && !locked ? "pointer" : "default",
        }}
        onClick={handleViewClick}
      >
        <DocumentBulletList24Regular
          style={{ color: "var(--accent)", flexShrink: 0 }}
        />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              fontWeight: 600,
              color: "var(--text-primary)",
              marginBottom: 2,
            }}
          >
            {record.diagnosis}
          </div>
          <div style={{ fontSize: "0.78em", color: "var(--text-muted)" }}>
            {new Date(record.created_at).toLocaleString()}
            {record.doctor_id && ` · Dr. ${record.doctor_id}`}
          </div>
        </div>

        {/* Status badges */}
        <div
          style={{
            display: "flex",
            gap: 8,
            alignItems: "center",
            flexShrink: 0,
          }}
        >
          {locked && (
            <Badge appearance="filled" color="danger" style={{ gap: 4 }}>
              <LockClosed24Regular style={{ width: 12, height: 12 }} /> Locked
            </Badge>
          )}
          {canView && !locked && (
            <Button
              size="small"
              appearance="outline"
              icon={
                expanded ? <ChevronUp24Regular /> : <ChevronDown24Regular />
              }
              onClick={(e) => {
                e.stopPropagation();
                handleViewClick();
              }}
            >
              {expanded ? "Collapse" : "View Record"}
            </Button>
          )}
        </div>
      </div>

      {/* Expanded Record Body — read-only + timer */}
      {expanded && !locked && (
        <>
          <Divider />
          <div
            style={{ padding: "12px 16px", background: "var(--bg-secondary)" }}
          >
            {/* Timer Banner */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                marginBottom: 14,
              }}
            >
              <span style={{ fontSize: "0.8em", color: "var(--text-muted)" }}>
                Read-only access · Auto-closes when timer expires
              </span>
              <AccessTimer onExpire={handleExpire} />
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <div>
                <div
                  style={{
                    fontSize: "0.75em",
                    color: "var(--text-muted)",
                    marginBottom: 4,
                    textTransform: "uppercase",
                    letterSpacing: "0.08em",
                  }}
                >
                  Diagnosis
                </div>
                <div style={{ color: "var(--text-primary)", fontWeight: 500 }}>
                  {record.diagnosis}
                </div>
              </div>
              {record.notes && (
                <div>
                  <div
                    style={{
                      fontSize: "0.75em",
                      color: "var(--text-muted)",
                      marginBottom: 4,
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                    }}
                  >
                    Notes
                  </div>
                  <div
                    style={{ color: "var(--text-secondary)", lineHeight: 1.6 }}
                  >
                    {record.notes}
                  </div>
                </div>
              )}
              {record.metadata && Object.keys(record.metadata).length > 0 && (
                <div>
                  <div
                    style={{
                      fontSize: "0.75em",
                      color: "var(--text-muted)",
                      marginBottom: 4,
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                    }}
                  >
                    Metadata
                  </div>
                  <code
                    style={{
                      fontSize: "0.8em",
                      color: "var(--text-secondary)",
                      opacity: 0.8,
                    }}
                  >
                    {JSON.stringify(record.metadata, null, 2)}
                  </code>
                </div>
              )}
              <div
                style={{
                  fontSize: "0.75em",
                  color: "var(--text-muted)",
                  marginTop: 4,
                }}
              >
                Record ID: <code>{record.id}</code>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Locked State */}
      {locked && (
        <>
          <Divider />
          <div
            style={{
              padding: "10px 16px",
              background: "rgba(239,68,68,0.07)",
              display: "flex",
              alignItems: "center",
              gap: 8,
            }}
          >
            <LockClosed24Regular
              style={{ color: "#ef4444", width: 16, height: 16 }}
            />
            <span style={{ fontSize: "0.8em", color: "#ef4444" }}>
              Access session expired. Close and reopen to start a new 15-minute
              session.
            </span>
          </div>
        </>
      )}
    </div>
  );
}

// ─── Main Page Component ──────────────────────────────────────────
export default function PatientMedicalHistory({
  patientId,
  patientName,
}: {
  patientId: string;
  patientName: string;
}) {
  const { profile } = useAuth();

  const [records, setRecords] = useState<MedicalRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [addDialogOpen, setAddDialogOpen] = useState(false);

  // Add New Record form state
  const [newDiagnosis, setNewDiagnosis] = useState("");
  const [newNotes, setNewNotes] = useState("");
  const [newMetadata, setNewMetadata] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const canCreate = hasPermission(profile?.role, "medical_history", "create");
  const canView = hasPermission(profile?.role, "medical_history", "decrypt");

  // Always re-fetch when patientId changes — including on first mount
  useEffect(() => {
    if (patientId) {
      fetchRecords();
    } else {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [patientId]);

  const fetchRecords = async () => {
    if (!patientId) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setFetchError(null);
      const { data, error } = await supabase
        .from("patient_medical_records")
        .select("*")
        .eq("patient_id", patientId)
        .order("created_at", { ascending: false });

      if (error) throw error;
      setRecords(data || []);
    } catch (err: any) {
      console.error("[PatientMedicalHistory] Fetch error:", err);
      setFetchError(
        err?.message
          ? `Database error: ${err.message}`
          : "Failed to load medical history. Ensure the SQL migration has been run in Supabase.",
      );
    } finally {
      setLoading(false);
    }
  };

  const handleAddRecord = async () => {
    if (!newDiagnosis.trim()) {
      setSubmitError("Diagnosis is required.");
      return;
    }

    let parsedMetadata = {};
    if (newMetadata.trim()) {
      try {
        parsedMetadata = JSON.parse(newMetadata.trim());
      } catch {
        setSubmitError("Metadata must be valid JSON (or leave it empty).");
        return;
      }
    }

    try {
      setSubmitting(true);
      setSubmitError(null);

      const { error } = await supabase.from("patient_medical_records").insert({
        patient_id: patientId,
        doctor_id: profile?.id || "unknown",
        diagnosis: newDiagnosis.trim(),
        notes: newNotes.trim() || null,
        metadata: parsedMetadata,
      });

      if (error) throw error;

      // Reset form
      setNewDiagnosis("");
      setNewNotes("");
      setNewMetadata("");
      setAddDialogOpen(false);

      // Refresh records list
      await fetchRecords();
    } catch (err: any) {
      console.error("[PatientMedicalHistory] Insert error:", err);
      setSubmitError(err.message || "Failed to save record. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  // Since this component is always rendered from PatientRegistration with a valid patientId,
  // no null-guard needed here.

  return (
    <div className="module-page">
      {/* ─── Header ─── */}
      <div className="page-header">
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          <h1 className="page-title" style={{ marginBottom: 0 }}>
            <DocumentBulletList24Regular /> Medical History
          </h1>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              marginLeft: 2,
            }}
          >
            <Person24Regular
              style={{ width: 14, height: 14, color: "var(--text-muted)" }}
            />
            <span style={{ fontSize: "0.82em", color: "var(--text-muted)" }}>
              {patientName || "Unknown Patient"}
            </span>
            <Badge appearance="tint" color="brand" size="small">
              {patientId.slice(0, 8)}…
            </Badge>
          </div>
        </div>
        <div className="page-header__actions">
          {canCreate && (
            <Button
              appearance="primary"
              icon={<Add24Regular />}
              onClick={() => setAddDialogOpen(true)}
            >
              Add New Record
            </Button>
          )}
        </div>
      </div>

      {/* ─── Security Notice ─── */}
      <MessageBar intent="warning" style={{ marginBottom: 14 }}>
        <MessageBarBody>
          All records are <strong>immutable</strong>. Viewing opens a 15-minute
          timed session per record. No editing or deletion is permitted.
        </MessageBarBody>
      </MessageBar>

      {/* ─── Content ─── */}
      {loading ? (
        <div className="page-loader">
          <Spinner size="large" label="Loading medical history…" />
        </div>
      ) : fetchError ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <MessageBar intent="error">
            <MessageBarBody>{fetchError}</MessageBarBody>
          </MessageBar>
          <Button
            appearance="outline"
            onClick={fetchRecords}
            style={{ alignSelf: "flex-start" }}
          >
            Retry
          </Button>
        </div>
      ) : records.length === 0 ? (
        <Card
          style={{
            padding: "3rem",
            textAlign: "center",
            color: "var(--text-muted)",
          }}
        >
          <DocumentBulletList24Regular
            style={{ width: 40, height: 40, opacity: 0.3, marginBottom: 12 }}
          />
          <p>No medical records found for this patient.</p>
          {canCreate && (
            <Button
              appearance="primary"
              icon={<Add24Regular />}
              style={{ marginTop: 12 }}
              onClick={() => setAddDialogOpen(true)}
            >
              Add First Record
            </Button>
          )}
        </Card>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {records.map((record) => (
            <RecordCard key={record.id} record={record} canView={canView} />
          ))}
        </div>
      )}

      {/* ─── Add New Record Dialog ─── */}
      <Dialog
        open={addDialogOpen}
        onOpenChange={(_, d) => {
          if (!submitting) {
            setAddDialogOpen(d.open);
            setSubmitError(null);
          }
        }}
      >
        <DialogSurface style={{ minWidth: 480 }}>
          <DialogBody>
            <DialogTitle>Add New Medical Record</DialogTitle>
            <DialogContent className="dialog-form">
              <MessageBar style={{ marginBottom: 14 }}>
                <MessageBarBody>
                  This record will be <strong>permanent and immutable</strong>{" "}
                  once saved. Double-check before submitting.
                </MessageBarBody>
              </MessageBar>

              {submitError && (
                <MessageBar intent="error" style={{ marginBottom: 12 }}>
                  <MessageBarBody>{submitError}</MessageBarBody>
                </MessageBar>
              )}

              <div
                style={{ display: "flex", flexDirection: "column", gap: 14 }}
              >
                <div>
                  <label
                    style={{
                      fontSize: "0.8em",
                      color: "var(--text-muted)",
                      display: "block",
                      marginBottom: 6,
                    }}
                  >
                    Diagnosis <span style={{ color: "#ef4444" }}>*</span>
                  </label>
                  <Input
                    placeholder="e.g. Type 2 Diabetes — HbA1c 9.2%"
                    value={newDiagnosis}
                    onChange={(_, d) => setNewDiagnosis(d.value)}
                    style={{ width: "100%" }}
                    disabled={submitting}
                  />
                </div>
                <div>
                  <label
                    style={{
                      fontSize: "0.8em",
                      color: "var(--text-muted)",
                      display: "block",
                      marginBottom: 6,
                    }}
                  >
                    Notes / Description
                  </label>
                  <Textarea
                    placeholder="Clinical notes, treatment plan, follow-up instructions…"
                    value={newNotes}
                    onChange={(_, d) => setNewNotes(d.value)}
                    rows={4}
                    style={{ width: "100%", resize: "vertical" }}
                    disabled={submitting}
                  />
                </div>

                <div>
                  <label
                    style={{
                      fontSize: "0.8em",
                      color: "var(--text-muted)",
                      display: "block",
                      marginBottom: 6,
                    }}
                  >
                    Optional Metadata{" "}
                    <span style={{ opacity: 0.6 }}>(JSON format)</span>
                  </label>
                  <Textarea
                    placeholder={
                      '{\n  "vitals": {"BP": "120/80", "pulse": 78}\n}'
                    }
                    value={newMetadata}
                    onChange={(_, d) => setNewMetadata(d.value)}
                    rows={3}
                    style={{
                      width: "100%",
                      fontFamily: "monospace",
                      fontSize: "0.82em",
                      resize: "vertical",
                    }}
                    disabled={submitting}
                  />
                </div>
              </div>
            </DialogContent>
            <DialogActions>
              <Button
                onClick={() => setAddDialogOpen(false)}
                disabled={submitting}
              >
                Cancel
              </Button>
              <Button
                appearance="primary"
                onClick={handleAddRecord}
                disabled={submitting || !newDiagnosis.trim()}
                icon={submitting ? <Spinner size="tiny" /> : undefined}
              >
                {submitting ? "Saving…" : "Save Record"}
              </Button>
            </DialogActions>
          </DialogBody>
        </DialogSurface>
      </Dialog>
    </div>
  );
}
