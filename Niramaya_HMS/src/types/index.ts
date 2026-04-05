// ─── Role & Auth Types ───────────────────────────────────────────
export type UserRole = 'admin' | 'doctor' | 'receptionist' | 'pharmacist';

export interface Profile {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
  avatar_url?: string;
  created_at: string;
  updated_at: string;
}

// ─── Patient (Maps to public.patient_records) ──────────────────────
export interface Patient {
  id: string;
  user_id: string;
  full_name: string | null;
  age: number | null;
  gender: 'male' | 'female' | 'other' | 'prefer_not_to_say' | null;
  blood_group: string | null;
  allergies: string | null;
  existing_conditions: string | null;
  emergency_contact_name: string | null;
  emergency_contact_phone: string | null;
  consent_given: boolean;
  created_at: string;
  updated_at: string;
}

// ─── Medical Report (encrypted) ──────────────────────────────────
export interface MedicalReport {
  id: string;
  patient_id: string;
  doctor_id: string;
  encrypted_data: string;
  iv: string;
  created_at: string;
}

export interface MedicalReportDecrypted {
  symptoms: string;
  diagnosis: string;
  notes: string;
  vitals: {
    bp: string;
    pulse: number;
    temperature: number;
    spo2: number;
  };
}

// ─── Prescription ────────────────────────────────────────────────
export interface Prescription {
  id: string;
  patient_id: string;
  doctor_id: string;
  medications: PrescriptionItem[];
  notes?: string;
  status: 'active' | 'dispensed' | 'cancelled';
  created_at: string;
  updated_at: string;
}

export interface PrescriptionItem {
  medication_name: string;
  dosage: string;
  frequency: string;
  duration: string;
  quantity: number;
}

// ─── Inventory ───────────────────────────────────────────────────
export interface InventoryItem {
  id: string;
  name: string;
  category: 'medicine' | 'equipment' | 'consumable';
  quantity: number;
  unit: string;
  expiry_date?: string;
  updated_at: string;
}

// ─── SOS / Emergency ────────────────────────────────────────────
export interface SOSEvent {
  id: string;
  location: string;
  status: 'active' | 'acknowledged' | 'resolved';
  created_at: string;
}

// ─── Audit ───────────────────────────────────────────────────────
export interface AuditEntry {
  id: string;
  action: string;
  entity_type: string;
  entity_id: string;
  performed_by: string;
  details?: string;
  tx_hash?: string;
  created_at: string;
}

// ─── Supporting DB Entities (new — for future modules) ───────────
export interface Hospital {
  id: string;
  name: string;
}

export interface Department {
  id: string;
  hospital_id: string;
  type: string;
  available_beds: number;
  total_beds: number;
}

export interface Ambulance {
  id: string;
  hospital_id: string;
  status: 'available' | 'dispatched' | 'maintenance';
  vehicle_number: string;
}

// ─── Window Manager ──────────────────────────────────────────────
export interface AppWindow {
  id: string;
  title: string;
  icon: string;
  component: string;       // route/component key
  isMinimized: boolean;
  isMaximized: boolean;
  isActive: boolean;
  zIndex: number;
  position?: { x: number; y: number };
  size?: { width: number | string; height: number | string };
  isSnapped?: boolean;
}

export type SnapDirection = 'horizontal' | 'vertical';

export interface SnapNode {
  id: string; // unique node id
  isLeaf: boolean;
  windowId?: string; // if isLeaf is true
  direction?: SnapDirection;
  splitRatio?: number; // scale between 0.1 and 0.9. Default 0.5
  child1?: SnapNode;
  child2?: SnapNode;
}

export interface SplitterData {
  id: string;
  nodeId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  direction: SnapDirection;
  span: number;
  currentRatio: number;
}
