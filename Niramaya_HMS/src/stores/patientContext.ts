import { create } from 'zustand';

// ─── Lightweight store to pass selected patient context
//     between the Patients panel and the Medical History panel ────
interface PatientContextState {
  selectedPatientId: string | null;
  selectedPatientName: string | null;
  setSelectedPatient: (id: string, name: string) => void;
  clearSelectedPatient: () => void;
}

export const usePatientContext = create<PatientContextState>((set) => ({
  selectedPatientId: null,
  selectedPatientName: null,

  setSelectedPatient: (id, name) => set({ selectedPatientId: id, selectedPatientName: name }),
  clearSelectedPatient: () => set({ selectedPatientId: null, selectedPatientName: null }),
}));
