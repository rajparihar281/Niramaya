import './AuditCard.css'

export default function AuditCard({ event, index }) {
  const ts = event.timestamp
    ? new Date(Number(event.timestamp) * 1000).toLocaleString()
    : '—'

  const patientHash = event.patientId ?? 'N/A'
  const shortHash = patientHash.length > 12
    ? `${patientHash.substring(0, 8)}...${patientHash.substring(patientHash.length - 8)}`
    : patientHash

  const shortTx = event.txHash
    ? `${event.txHash.substring(0, 10)}...${event.txHash.substring(event.txHash.length - 8)}`
    : null

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
        {event.block && (
          <div className="field">
            <span className="field-label">Block</span>
            <span className="field-value mono">{parseInt(event.block, 16)}</span>
          </div>
        )}
        {shortTx && (
          <div className="field">
            <span className="field-label">Tx Hash</span>
            <code className="field-hash" title={event.txHash}>{shortTx}</code>
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
