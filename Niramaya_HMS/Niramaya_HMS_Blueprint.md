# Niramaya-Net: Hospital Management & Audit System (HMAS)
## Project Blueprint v2.1 | Secure Windows-Style ERP System

---

## 1. Executive Summary
The **Niramaya-HMS** is a high-integrity, desktop-style web system designed to bridge the gap between emergency dispatches and hospital clinical operations.

It features:
- Windows-inspired multitasking UI
- Strict Role-Based Access Control (RBAC)
- AES-256 Client-Side Encryption for data privacy

---

## 2. Core Technical Stack

| Layer | Technology |
|------|------------|
| Frontend | React 18 + Vite |
| UI Library | Microsoft Fluent UI React |
| Backend/DB | Supabase (PostgreSQL + Realtime + Auth) |
| Cryptography | Web Crypto API (AES-256-GCM) |
| State Management | TanStack Query + Zustand |

### Supabase Configuration
- URL: https://szktjigmdtubjfksolcr.supabase.co  
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

---

## 3. RBAC & Access Control Matrix

| Feature | Admin | Doctor | Receptionist | Pharmacist |
|--------|------|--------|-------------|------------|
| SOS Monitoring | Full | View | View | - |
| Patient Registration | Full | - | Create/View | - |
| Medical History | Full | Decrypt & Read | Masked | - |
| Prescriptions | View | Write/Update | - | View |
| Inventory Mgmt | Full | - | - | Full |
| Audit/Blockchain | Full | View | - | - |

---

## 4. Architectural Components

### A. Windows Shell UI
- Sidebar (Start Menu)
- Taskbar (Active Windows)
- Multi-Window Context Support

### B. Data Security (Encryption Layer)
- No plaintext storage
- AES-256 encryption before database insert
- Decryption allowed only for authorized roles
- Patient consent validation

```javascript
if (!access_granted) return "Access Restricted by Patient";
```

### C. Emergency Inventory Sync
- Threshold-based shortage alerts
- Real-time broadcast using Supabase
- Doctor sees live stock status while prescribing

---

## 5. Implementation Roadmap

### Phase 1: Database Hardening
- Create `profiles` table with role enum
- Create `medical_reports` table
- Implement RLS policies

### Phase 2: Desktop Shell Development
- Setup React + Fluent UI
- Build DesktopLayout + Taskbar
- Implement WindowProvider

### Phase 3: Clinical & Inventory Modules
- Doctor encryption workflow
- Inventory CRUD + alert system
- Reception dashboard for SOS intake

### Phase 4: Audit & PDF Engine
- Blockchain audit integration (Hardhat)
- PDF report generation with transaction hash

---

## 6. Security Protocol: Client-Side AES-256

```javascript
async function secureReport(data, hospitalKey) {
  const encoded = new TextEncoder().encode(JSON.stringify(data));
  const iv = window.crypto.getRandomValues(new Uint8Array(12));

  const encrypted = await window.crypto.subtle.encrypt(
    { name: "AES-256-GCM", iv },
    hospitalKey,
    encoded
  );

  return { cipher: encrypted, iv: iv };
}
```

---

## 7. Next Steps

### For Antigravity (Claude 3.6 Sonnet)
1. Scaffold project → `/niramaya_hms`
2. Build authentication with role-based routing
3. Sync Supabase schema and validate RBAC

---

## Conclusion
Niramaya-HMS is a **secure, scalable, and intelligent hospital ERP system** that integrates:
- Emergency response systems
- Clinical workflows
- Inventory intelligence
- Blockchain auditing

Designed for **high-trust healthcare environments**.
