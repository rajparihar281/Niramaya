import { useState, useEffect, useCallback } from 'react'
import AuditTrail from './pages/AuditTrail.jsx'
import './App.css'

export default function App() {
  const [isOnline, setIsOnline] = useState(null)

  const checkBackend = useCallback(async () => {
    try {
      const res = await fetch('/v1/audit/trail', { signal: AbortSignal.timeout(4000), headers: { 'ngrok-skip-browser-warning': 'true' } })
      setIsOnline(res.ok)
    } catch {
      setIsOnline(false)
    }
  }, [])

  useEffect(() => {
    checkBackend()
  }, [checkBackend])

  return (
    <div className="app-shell">
      <header className="top-bar">
        <div className="top-bar__brand">
          <span className="brand-icon">⚕</span>
          <div>
            <h1 className="brand-title">NIRAMAYA-NET</h1>
            <p className="brand-sub">Blockchain Audit Command Centre</p>
          </div>
        </div>
        <div className="top-bar__status">
          <span className={`status-dot ${isOnline === true ? 'online' : isOnline === false ? 'offline' : 'checking'}`} />
          <span className="status-label">
            {isOnline === null ? 'Connecting...' : isOnline ? 'Engine Online' : 'Engine Offline'}
          </span>
          <button className="refresh-btn" onClick={checkBackend} title="Refresh connection">
            ↻
          </button>
        </div>
      </header>

      <main className="main-content">
        <AuditTrail />
      </main>

      <footer className="bottom-bar">
        <span>Niramaya-Net Admin v2.0</span>
        <span className="sep">|</span>
        <span>All patient IDs are SHA-256 hashed</span>
        <span className="sep">|</span>
        <span>Data read directly from blockchain ledger</span>
      </footer>
    </div>
  )
}
