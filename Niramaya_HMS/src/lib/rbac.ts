import type { UserRole } from '@/types';

// ─── Feature Keys ────────────────────────────────────────────────
export type Feature =
  | 'sos_monitoring'
  | 'patient_registration'
  | 'medical_history'
  | 'prescriptions'
  | 'inventory'
  | 'audit';

export type Action = 'view' | 'create' | 'update' | 'delete' | 'decrypt';

// ─── Permission Matrix (from Blueprint §3) ──────────────────────
const PERMISSIONS: Record<Feature, Partial<Record<UserRole, Action[]>>> = {
  sos_monitoring: {
    admin:        ['view', 'create', 'update', 'delete'],
    doctor:       ['view'],
    receptionist: ['view'],
  },
  patient_registration: {
    admin:        ['view', 'create', 'update', 'delete'],
    receptionist: ['view', 'create'],
  },
  medical_history: {
    admin:        ['view', 'create', 'update', 'delete', 'decrypt'],
    doctor:       ['view', 'create', 'decrypt'],
    receptionist: ['view'],        // masked view only
  },
  prescriptions: {
    admin:        ['view'],
    doctor:       ['view', 'create', 'update'],
    pharmacist:   ['view'],
  },
  inventory: {
    admin:        ['view', 'create', 'update', 'delete'],
    pharmacist:   ['view', 'create', 'update', 'delete'],
  },
  audit: {
    admin:        ['view', 'create', 'update', 'delete'],
    doctor:       ['view'],
  },
};

/** Check if a role has a specific action on a feature */
export function hasPermission(
  role: UserRole | undefined,
  feature: Feature,
  action: Action
): boolean {
  if (!role) return false;
  const allowed = PERMISSIONS[feature]?.[role];
  return allowed ? allowed.includes(action) : false;
}

/** Get all features accessible to a role (at least 'view') */
export function getAccessibleFeatures(role: UserRole): Feature[] {
  return (Object.keys(PERMISSIONS) as Feature[]).filter(
    (feature) => PERMISSIONS[feature][role]?.includes('view')
  );
}

/** Navigation items for the sidebar, filtered by role */
export interface NavItem {
  key: Feature | 'dashboard';
  label: string;
  icon: string;
  path: string;
}

const ALL_NAV_ITEMS: NavItem[] = [
  { key: 'dashboard',            label: 'Dashboard',            icon: 'Board',              path: '/' },
  { key: 'sos_monitoring',       label: 'SOS Monitor',          icon: 'Alert',              path: '/sos' },
  { key: 'patient_registration', label: 'Patient Registration', icon: 'PersonAdd',          path: '/patients' },
  { key: 'medical_history',      label: 'Medical History',      icon: 'DocumentBulletList', path: '/medical-history' },
  { key: 'prescriptions',        label: 'Prescriptions',        icon: 'Pill',               path: '/prescriptions' },
  { key: 'inventory',            label: 'Inventory',            icon: 'Box',                path: '/inventory' },
  { key: 'audit',                label: 'Audit Log',            icon: 'Shield',             path: '/audit' },
];

export function getNavItemsForRole(role: UserRole): NavItem[] {
  return ALL_NAV_ITEMS.filter((item) => {
    if (item.key === 'dashboard') return true;
    return hasPermission(role, item.key, 'view');
  });
}
