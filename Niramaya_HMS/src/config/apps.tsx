import React, { lazy } from 'react';
import {
  HeartPulse32Regular,
  People32Regular,
  DataTrending32Regular,
  DocumentPill24Regular,
  Box32Regular,
  PeopleQueue24Regular,
  AlertUrgent24Regular,
  ShieldKeyhole24Regular,
  ShoppingBag24Regular,
  Stethoscope24Regular,
} from '@fluentui/react-icons';

// Lazy loading the modules
const PatientRegistration = lazy(() => import('@/pages/PatientRegistration'));
const MedicalHistory = lazy(() => import('@/pages/MedicalHistory'));
const Prescriptions = lazy(() => import('@/pages/Prescriptions'));
const Inventory = lazy(() => import('@/pages/Inventory'));
const PharmacySales = lazy(() => import('@/pages/PharmacySales'));
const SOSMonitor = lazy(() => import('@/pages/SOSMonitor'));
const Dashboard = lazy(() => import('@/pages/Dashboard'));
const AuditLog = lazy(() => import('@/pages/AuditLog'));
const SymptomLogs = lazy(() => import('@/pages/SymptomLogs'));
const QueueManager = lazy(() => import('@/pages/QueueManager'));

export interface AppConfig {
  id: string;
  name: string;
  icon: React.ReactNode;
  component: React.LazyExoticComponent<any> | React.FC<any>;
  roles: ('admin' | 'doctor' | 'receptionist' | 'pharmacist')[];
  defaultWidth?: number;
  defaultHeight?: number;
}

export const APPS: AppConfig[] = [
  {
    id: 'dashboard',
    name: 'Analytics',
    icon: <DataTrending32Regular />,
    component: Dashboard,
    roles: ['admin'],
    defaultWidth: 1000,
    defaultHeight: 700,
  },
  {
    id: 'patients',
    name: 'Patients',
    icon: <People32Regular />,
    component: PatientRegistration,
    roles: ['admin', 'doctor', 'receptionist'],
    defaultWidth: 800,
    defaultHeight: 600,
  },
  {
    id: 'medical-history',
    name: 'Records',
    icon: <HeartPulse32Regular />,
    component: MedicalHistory,
    roles: ['admin', 'doctor'],
    defaultWidth: 900,
    defaultHeight: 650,
  },
  {
    id: 'prescriptions',
    name: 'Prescriptions',
    icon: <DocumentPill24Regular />,
    component: Prescriptions,
    roles: ['admin', 'doctor', 'pharmacist'],
    defaultWidth: 800,
    defaultHeight: 600,
  },
  {
    id: 'inventory',
    name: 'Inventory',
    icon: <Box32Regular />,
    component: Inventory,
    roles: ['admin', 'pharmacist'],
    defaultWidth: 900,
    defaultHeight: 650,
  },
  {
    id: 'pharmacy-sales',
    name: 'Sales',
    icon: <ShoppingBag24Regular />,
    component: PharmacySales,
    roles: ['pharmacist'],
    defaultWidth: 960,
    defaultHeight: 680,
  },
  {
    id: 'sos',
    name: 'SOS Monitor',
    icon: <AlertUrgent24Regular />,
    component: SOSMonitor,
    roles: ['admin', 'doctor', 'receptionist'],
    defaultWidth: 700,
    defaultHeight: 500,
  },
  {
    id: 'audit',
    name: 'Audit Log',
    icon: <ShieldKeyhole24Regular />,
    component: AuditLog,
    roles: ['admin'],
    defaultWidth: 800,
    defaultHeight: 600,
  },
  {
    id: 'symptom-logs',
    name: 'Symptom Logs',
    icon: <Stethoscope24Regular />,
    component: SymptomLogs,
    roles: ['admin', 'doctor'],
    defaultWidth: 900,
    defaultHeight: 650,
  },
  {
    id: 'queue-manager',
    name: 'Queue Desk',
    icon: <PeopleQueue24Regular />,
    component: QueueManager,
    roles: ['admin', 'receptionist'],
    defaultWidth: 900,
    defaultHeight: 650,
  },
];
