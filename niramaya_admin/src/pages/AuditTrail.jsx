import { useState, useEffect, useCallback, useRef } from 'react'
import AuditCard from '../components/AuditCard.jsx'
import './AuditTrail.css'

const POLL_INTERVAL_MS = 8000

export default function AuditTrail() {
  const [events, setEvents] = useState([])
  const [meta, setMeta] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [engineWaiting, setEngineWaiting] = useState(false)
  const [bridgeOffline, setBridgeOffline] = useState(false)
  const [lastRefreshed, setLastRefreshed] = useState(null)
  const [autoRefresh, setAutoRefresh] = useState(true)
  const timerRef = useRef(null)

  const fetchAuditTrail = useCallback(async () => {
    try {
      setBridgeOffline(false)
      const res = await fetch('/v1/audit/trail', {
        signal: AbortSignal.timeout(8000),
        headers: { 'ngrok-skip-browser-warning': 'true' },
      })
      const data = await res.json()

      if (res.status === 503 || data?.status === 'service_unavailable' || data?.status === 'blockchain_offline') {
        setEngineWaiting(true)
        setBridgeOffline(data?.status === 'blockchain_offline')
        setMeta(data)
        setEvents([])
        setError(null)
        return
      }

      if (data?.status === 'waiting_for_config') {
        setEngineWaiting(true)
        setMeta(data)
        setEvents([])
        setError(null)
        setLastRefreshed(new Date())
        return
      }

      if (!res.ok) throw new Error(`HTTP ${res.status}`)

      setEngineWaiting(false)
      setMeta(data)
      // Backend now returns pre-decoded structured events
      const decoded = (data.events ?? []).map((ev, i) => ({
        logId:      ev.logId ?? i,
        patientId:  ev.patientId  || 'N/A',
        hospitalId: ev.hospitalId || '—',
        department: ev.department || '—',
        timestamp:  ev.timestamp  ?? null,
        txHash:     ev.txHash     ?? null,
        block:      ev.block      ?? null,
      }))
      setEvents(decoded)
      setError(null)
      setLastRefreshed(new Date())
    } catch (err) {
      setEngineWaiting(true)
      setBridgeOffline(true)
      setError('Niramaya Bridge Offline')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAuditTrail()
  }, [fetchAuditTrail])

  useEffect(() => {
    if (!autoRefresh) {
      clearInterval(timerRef.current)
      return
    }
    timerRef.current = setInterval(fetchAuditTrail, POLL_INTERVAL_MS)
    return () => clearInterval(timerRef.current)
  }, [autoRefresh, fetchAuditTrail])

  const handleManualRefresh = () => {
    setLoading(true)
    fetchAuditTrail()
  }

  return (
    <div className="audit-trail">
      {/* ── Page Header ── */}
      <div className="audit-header">
        <div>
          <h2 className="audit-title">Cryptographic Audit Trail</h2>
          <p className="audit-subtitle">
            Immutable dispatch records verified on-chain · SHA-256 patient identifiers
          </p>
        </div>
        <div className="audit-controls">
          <label className="auto-refresh-toggle">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={e => setAutoRefresh(e.target.checked)}
            />
            <span>Auto-refresh</span>
          </label>
          <button className="btn-refresh" onClick={handleManualRefresh} disabled={loading}>
            {loading ? '⟳ Loading...' : '↻ Refresh'}
          </button>
        </div>
      </div>

      {/* ── Stats Bar ── */}
      <div className="stats-row">
        <StatCard
          icon="🔗"
          label="Blockchain Status"
          value={meta?.status === 'connected' ? 'Connected' : meta?.status ?? '—'}
          accent={meta?.status === 'connected' ? 'green' : 'amber'}
        />
        <StatCard
          icon="📋"
          label="Total Events"
          value={events.length}
          accent="blue"
        />
        <StatCard
          icon="🛡️"
          label="Privacy Mode"
          value="SHA-256 ZK"
          accent="red"
        />
        <StatCard
          icon="🕐"
          label="Last Synced"
          value={lastRefreshed ? lastRefreshed.toLocaleTimeString() : '—'}
          accent="default"
        />
      </div>

      {/* ── Blockchain Info ── */}
      {meta?.rpc && (
        <div className="chain-info">
          <span className="chain-label">RPC</span>
          <code className="chain-value">{meta.rpc}</code>
          <span className="chain-label">Contract</span>
          <code className="chain-value">{meta.contract_address}</code>
        </div>
      )}

      {/* ── Error State ── */}
      {error && (
        <div className="alert alert-error">
          <span className="alert-icon">⚠</span>
          <div>
            <strong>Connection Error</strong>
            <p>{error}</p>
            <p className="alert-hint">
              Ensure the Niramaya Go engine is running on <code>localhost:10000</code> and
              set <code>BLOCKCHAIN_RPC_URL</code> + <code>CONTRACT_ADDRESS</code> env vars.
            </p>
          </div>
        </div>
      )}

      {engineWaiting && !error && (
        <div className="alert alert-warn">
          <span className="alert-icon">⏳</span>
          <div>
            <strong>Waiting for Backend Engine...</strong>
            <p>
              The Go engine or blockchain bridge is not ready yet. Keep the backend running on{' '}
              <code>localhost:10000</code> and start Hardhat RPC when needed.
            </p>
          </div>
        </div>
      )}

      {bridgeOffline && (
        <div className="alert alert-error">
          <span className="alert-icon">⛔</span>
          <div>
            <strong>Niramaya Bridge Offline</strong>
            <p>
              Unable to reach <code>/v1/audit/trail</code>. Verify the Go engine is running on{' '}
              <code>localhost:10000</code>.
            </p>
          </div>
        </div>
      )}

      {/* ── Blockchain Not Configured ── */}
      {meta?.status === 'blockchain_not_configured' && !error && !engineWaiting && (
        <div className="alert alert-warn">
          <span className="alert-icon">🔧</span>
          <div>
            <strong>Blockchain Not Configured</strong>
            <p>{meta.message}</p>
          </div>
        </div>
      )}

      {/* ── Event List ── */}
      {loading && events.length === 0 ? (
        <div className="loading-state">
          <div className="loader-ring" />
          <p>Querying blockchain ledger...</p>
        </div>
      ) : events.length === 0 && !error ? (
        <div className="empty-state">
          <div className="empty-icon">📭</div>
          <h3>No Dispatch Events Found</h3>
          <p>
            The contract has logged 0 events. Trigger an SOS from the Niramaya Guardian
            app to create your first on-chain audit record.
          </p>
        </div>
      ) : (
        <div className="events-grid">
          {events.map((event, idx) => (
            <AuditCard key={event.logId ?? idx} event={event} index={idx} />
          ))}
        </div>
      )}
    </div>
  )
}

function StatCard({ icon, label, value, accent }) {
  return (
    <div className={`stat-card stat-card--${accent}`}>
      <span className="stat-icon">{icon}</span>
      <div>
        <p className="stat-label">{label}</p>
        <p className="stat-value">{value}</p>
      </div>
    </div>
  )
}
