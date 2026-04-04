import './AuditCard.css'

export default function AuditCard({ event, index }) {
  const ts = event.timestamp
    ? new Date(Number(event.timestamp) * 1000).toLocaleString()
    : '—'

  // Patient ID is always a 64-char SHA-256 hex string
  const patientHash = event.patientId ?? 'N/A'
  const shortHash = patientHash.length > 12
    ? `${patientHash.substring(0, 8)}...${patientHash.substring(patientHash.length - 8)}`
    : patientHash

  return (
    <article className="audit-card">
      <div className="card-header">
        <div className="card-index">#{index + 1}</div>
        <div className="card-badge">VERIFIED</div>
      </div>

      <div className="card-body">
        <div className="field">
          <span className="field-label">Patient Hash</span>
          <code className="field-hash" title={patientHash}>{shortHash}</code>
        </div>
        <div className="field">
          <span className="field-label">Hospital</span>
          <span className="field-value">{event.hospitalId ?? '—'}</span>
        </div>
        <div className="field">
          <span className="field-label">Department</span>
          <span className="field-value dept-badge">{event.department ?? '—'}</span>
        </div>
        <div className="field">
          <span className="field-label">Timestamp</span>
          <span className="field-value">{ts}</span>
        </div>
        {event.logId !== undefined && (
          <div className="field">
            <span className="field-label">Log ID</span>
            <span className="field-value mono">{event.logId.toString()}</span>
          </div>
        )}
      </div>

      <div className="card-footer">
        <span className="chain-seal">⛓ On-Chain Record</span>
        <span className="hash-truncated">SHA256: {shortHash}</span>
      </div>
    </article>
  )
}
