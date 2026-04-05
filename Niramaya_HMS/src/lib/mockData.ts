/**
 * Local Data Base — purely offline data persistence using localStorage
 * Provides realistic data and tracks created entries
 */
import type {
  Profile,
  Patient,
  MedicalReport,
  Prescription,
  InventoryItem,
  SOSEvent,
  AuditEntry,
} from '@/types';

const LS_PREFIX = 'niramaya_local_';

export function getLocalData<T>(key: string, fallback: T[]): T[] {
  try {
    const stored = localStorage.getItem(LS_PREFIX + key);
    if (stored) {
      const parsed = JSON.parse(stored);
      if (Array.isArray(parsed) && parsed.length > 0) return parsed;
    }
  } catch { /* ignore */ }
  // Initialize with fallback if empty
  setLocalData(key, fallback);
  return [...fallback];
}

export function setLocalData<T>(key: string, data: T[]): void {
  localStorage.setItem(LS_PREFIX + key, JSON.stringify(data));
}

export function addLocalItem<T>(key: string, item: T, fallback: T[] = []): T[] {
  const current = getLocalData<T>(key, fallback);
  const updated = [item, ...current];
  setLocalData(key, updated);
  return updated;
}

export function updateLocalItem<T extends { id: string }>(
  key: string,
  id: string,
  updates: Partial<T>,
  fallback: T[] = []
): T[] {
  const current = getLocalData<T>(key, fallback);
  const updated = current.map((item) =>
    item.id === id ? { ...item, ...updates } : item
  );
  setLocalData(key, updated);
  return updated;
}

// ─── Local Users ──────────────────────────────────────────────────
export interface LocalUser {
  id: string;
  email: string;
  password?: string;
  profile: Profile;
}

const INITIAL_USERS: LocalUser[] = [
  {
    id: 'u-admin-001',
    email: 'admin@niramaya.in',
    password: 'admin123',
    profile: {
      id: 'u-admin-001',
      email: 'admin@niramaya.in',
      full_name: 'Dr. Rajesh Gupta',
      role: 'admin',
      created_at: '2025-01-01T00:00:00Z',
      updated_at: '2025-01-01T00:00:00Z',
    },
  },
  {
    id: 'u-doctor-001',
    email: 'doctor@niramaya.in',
    password: 'doctor123',
    profile: {
      id: 'u-doctor-001',
      email: 'doctor@niramaya.in',
      full_name: 'Dr. Priya Sharma',
      role: 'doctor',
      created_at: '2025-01-15T00:00:00Z',
      updated_at: '2025-01-15T00:00:00Z',
    },
  },
  {
    id: 'u-reception-001',
    email: 'reception@niramaya.in',
    password: 'reception123',
    profile: {
      id: 'u-reception-001',
      email: 'reception@niramaya.in',
      full_name: 'Anita Verma',
      role: 'receptionist',
      created_at: '2025-02-01T00:00:00Z',
      updated_at: '2025-02-01T00:00:00Z',
    },
  },
  {
    id: 'u-pharma-001',
    email: 'pharma@niramaya.in',
    password: 'pharma123',
    profile: {
      id: 'u-pharma-001',
      email: 'pharma@niramaya.in',
      full_name: 'Vikram Patel',
      role: 'pharmacist',
      created_at: '2025-02-15T00:00:00Z',
      updated_at: '2025-02-15T00:00:00Z',
    },
  },
];

export function getLocalUsers(): LocalUser[] {
  return getLocalData('users', INITIAL_USERS);
}

// ─── Initial Data ───────────────────────────────────────────────
export const INITIAL_PATIENTS: Patient[] = [
  {
    id: 'p-001',
    name: 'Rahul Mehta',
    age: 34,
    gender: 'male',
    contact: '+91 98765 43210',
    address: '12, MG Road, Pune',
    blood_group: 'O+',
    emergency_contact: '+91 98765 43211',
    registered_by: 'u-reception-001',
    created_at: '2025-03-10T09:00:00Z',
    updated_at: '2025-03-10T09:00:00Z',
  },
  {
    id: 'p-002',
    name: 'Sunita Devi',
    age: 45,
    gender: 'female',
    contact: '+91 99876 54321',
    address: '45, Station Rd, Mumbai',
    blood_group: 'A+',
    emergency_contact: '+91 99876 54322',
    registered_by: 'u-reception-001',
    created_at: '2025-03-12T10:30:00Z',
    updated_at: '2025-03-12T10:30:00Z',
  },
  {
    id: 'p-003',
    name: 'Amit Kumar',
    age: 28,
    gender: 'male',
    contact: '+91 97654 32100',
    address: '78, Lal Bagh, Bangalore',
    blood_group: 'B+',
    registered_by: 'u-admin-001',
    created_at: '2025-03-15T14:00:00Z',
    updated_at: '2025-03-15T14:00:00Z',
  },
  {
    id: 'p-004',
    name: 'Kavita Rao',
    age: 52,
    gender: 'female',
    contact: '+91 96543 21000',
    address: '23, Anna Nagar, Chennai',
    blood_group: 'AB-',
    emergency_contact: '+91 96543 21001',
    registered_by: 'u-reception-001',
    created_at: '2025-03-18T08:15:00Z',
    updated_at: '2025-03-18T08:15:00Z',
  },
  {
    id: 'p-005',
    name: 'Deepak Singh',
    age: 60,
    gender: 'male',
    contact: '+91 95432 10000',
    address: '56, Civil Lines, Delhi',
    blood_group: 'O-',
    registered_by: 'u-reception-001',
    created_at: '2025-03-20T11:45:00Z',
    updated_at: '2025-03-20T11:45:00Z',
  },
];

export const INITIAL_REPORTS: MedicalReport[] = [
  {
    id: 'mr-001',
    patient_id: 'p-001',
    doctor_id: 'u-doctor-001',
    encrypted_data: 'DEMO_ENCRYPTED_DATA',
    iv: 'DEMO_IV',
    created_at: '2025-03-11T10:00:00Z',
  },
  {
    id: 'mr-002',
    patient_id: 'p-002',
    doctor_id: 'u-doctor-001',
    encrypted_data: 'DEMO_ENCRYPTED_DATA',
    iv: 'DEMO_IV',
    created_at: '2025-03-13T11:30:00Z',
  },
  {
    id: 'mr-003',
    patient_id: 'p-003',
    doctor_id: 'u-doctor-001',
    encrypted_data: 'DEMO_ENCRYPTED_DATA',
    iv: 'DEMO_IV',
    created_at: '2025-03-16T15:00:00Z',
  },
  {
    id: 'mr-004',
    patient_id: 'p-004',
    doctor_id: 'u-doctor-001',
    encrypted_data: 'DEMO_ENCRYPTED_DATA',
    iv: 'DEMO_IV',
    created_at: '2025-03-19T09:45:00Z',
  },
];

export const INITIAL_PRESCRIPTIONS: Prescription[] = [
  {
    id: 'rx-001',
    patient_id: 'p-001',
    doctor_id: 'u-doctor-001',
    medications: [
      { medication_name: 'Amoxicillin', dosage: '500mg', frequency: 'Thrice daily', duration: '7 days', quantity: 21 },
      { medication_name: 'Paracetamol', dosage: '650mg', frequency: 'As needed', duration: '5 days', quantity: 10 },
    ],
    notes: 'Complete the full course of antibiotics.',
    status: 'active',
    created_at: '2025-03-11T10:15:00Z',
    updated_at: '2025-03-11T10:15:00Z',
  },
  {
    id: 'rx-002',
    patient_id: 'p-002',
    doctor_id: 'u-doctor-001',
    medications: [
      { medication_name: 'Amlodipine', dosage: '10mg', frequency: 'Once daily', duration: '30 days', quantity: 30 },
    ],
    notes: 'Monitor BP daily. Follow up in 2 weeks.',
    status: 'dispensed',
    created_at: '2025-03-13T12:00:00Z',
    updated_at: '2025-03-14T09:00:00Z',
  },
  {
    id: 'rx-003',
    patient_id: 'p-004',
    doctor_id: 'u-doctor-001',
    medications: [
      { medication_name: 'Metformin', dosage: '500mg', frequency: 'Twice daily', duration: '30 days', quantity: 60 },
      { medication_name: 'Insulin Glargine', dosage: '10 units', frequency: 'Once daily', duration: '30 days', quantity: 1 },
    ],
    status: 'active',
    created_at: '2025-03-19T10:00:00Z',
    updated_at: '2025-03-19T10:00:00Z',
  },
];

export const INITIAL_INVENTORY: InventoryItem[] = [
  { id: 'inv-001', name: 'Paracetamol 650mg', category: 'medicine', quantity: 1200, unit: 'tablets', expiry_date: '2026-06-15', updated_at: '2025-03-20T10:00:00Z' },
  { id: 'inv-002', name: 'Amoxicillin 500mg', category: 'medicine', quantity: 80, unit: 'capsules', expiry_date: '2026-03-01', updated_at: '2025-03-18T14:00:00Z' },
  { id: 'inv-003', name: 'Surgical Gloves (M)', category: 'consumable', quantity: 500, unit: 'pairs', updated_at: '2025-03-15T09:00:00Z' },
  { id: 'inv-004', name: 'Digital Thermometer', category: 'equipment', quantity: 15, unit: 'pcs', updated_at: '2025-03-10T12:00:00Z' },
  { id: 'inv-005', name: 'Insulin Glargine', category: 'medicine', quantity: 5, unit: 'vials', expiry_date: '2025-12-01', updated_at: '2025-03-22T08:00:00Z' },
  { id: 'inv-006', name: 'N95 Masks', category: 'consumable', quantity: 3, unit: 'boxes', updated_at: '2025-03-20T16:00:00Z' },
  { id: 'inv-007', name: 'Blood Pressure Monitor', category: 'equipment', quantity: 8, unit: 'pcs', updated_at: '2025-03-05T10:00:00Z' },
];

export const INITIAL_SOS: SOSEvent[] = [
  { id: 'sos-001', location: 'Ward 3, Bed 12', status: 'active', created_at: '2025-03-23T08:30:00Z' },
  { id: 'sos-002', location: 'Emergency Room', status: 'acknowledged', created_at: '2025-03-23T08:45:00Z' },
  { id: 'sos-003', location: 'ICU Unit A', status: 'resolved', created_at: '2025-03-23T07:15:00Z' },
  { id: 'sos-004', location: 'Waiting Area', status: 'active', created_at: '2025-03-23T09:05:00Z' },
];

export const INITIAL_AUDIT: AuditEntry[] = [
  { id: 'aud-001', action: 'CREATE', entity_type: 'patient', entity_id: 'p-005', performed_by: 'u-reception-001', details: 'Registered patient Deepak Singh', created_at: '2025-03-20T11:45:00Z' },
  { id: 'aud-002', action: 'CREATE', entity_type: 'prescription', entity_id: 'rx-003', performed_by: 'u-doctor-001', details: 'Prescribed Metformin + Insulin for Kavita Rao', created_at: '2025-03-19T10:00:00Z' },
  { id: 'aud-003', action: 'UPDATE', entity_type: 'inventory', entity_id: 'inv-002', performed_by: 'u-pharma-001', details: 'Amoxicillin stock updated: 150 → 80', created_at: '2025-03-18T14:00:00Z' },
  { id: 'aud-004', action: 'DECRYPT', entity_type: 'medical_report', entity_id: 'mr-001', performed_by: 'u-doctor-001', details: 'Decrypted report for patient Rahul Mehta', tx_hash: '0x7a3f8c2d1e4b5a6f9c0d3e2b1a4f7c8d9e0a1b2c', created_at: '2025-03-17T16:30:00Z' },
  { id: 'aud-005', action: 'CREATE', entity_type: 'sos_event', entity_id: 'sos-001', performed_by: 'u-reception-001', details: 'SOS alert raised for Rahul Mehta — chest pain', created_at: '2025-03-26T14:30:00Z' },
  { id: 'aud-006', action: 'UPDATE', entity_type: 'prescription', entity_id: 'rx-002', performed_by: 'u-pharma-001', details: 'Prescription dispensed for Sunita Devi', created_at: '2025-03-14T09:00:00Z' },
  { id: 'aud-007', action: 'LOGIN', entity_type: 'session', entity_id: 'u-admin-001', performed_by: 'u-admin-001', details: 'Admin logged in from 192.168.1.10', created_at: '2025-03-26T08:00:00Z' },
];
