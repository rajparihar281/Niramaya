import { supabase } from '@/lib/supabaseClient';

export interface QueueLog {
  id: string;
  hospital_id: string;
  department_type: string;
  check_in_time: string;
  consultation_end_time: string | null;
  predicted_wait_minutes: number | null;
}

const QUEUE_SYNC_EVENT = 'niramaya_queue_sync';

export function emitQueueSync() {
  window.dispatchEvent(new CustomEvent(QUEUE_SYNC_EVENT));
}

export function onQueueSync(handler: () => void): () => void {
  window.addEventListener(QUEUE_SYNC_EVENT, handler);
  return () => window.removeEventListener(QUEUE_SYNC_EVENT, handler);
}

export async function fetchQueueLogs(): Promise<{ data: QueueLog[]; error: string | null }> {
  const { data, error } = await supabase
    .from('queue_logs')
    .select('*')
    .order('check_in_time', { ascending: false });

  if (error) {
    console.error('[queueStore] fetch error:', error);
    return { data: [], error: error.message };
  }
  return { data: data || [], error: null };
}

export interface WalkInPayload {
  // registered_users
  abha_id?: string;
  phone?: string;
  email?: string;
  // patient_records
  full_name: string;
  age: number;
  gender: string;
  blood_group?: string;
  allergies?: string;
  existing_conditions?: string;
  emergency_contact_name?: string;
  emergency_contact_phone?: string;
  // queue_logs
  hospital_id: string;
  department_type: string;
  check_in_time: string;
  consultation_end_time?: string | null;
}

export async function registerWalkIn(
  payload: WalkInPayload
): Promise<{ success: boolean; patientSaved: boolean; error?: string }> {

  // ── Step 1: registered_users ───────────────────────────────────────────────
  const abhaId = payload.abha_id?.trim() || `WALKIN-${Date.now()}-${Math.random().toString(36).slice(2, 7).toUpperCase()}`;
  const { data: regUser, error: regError } = await supabase
    .from('registered_users')
    .insert({ abha_id: abhaId, phone: payload.phone || null, email: payload.email || null })
    .select('id')
    .single();

  if (regError || !regUser) {
    return { success: false, patientSaved: false, error: `User registration failed: ${regError?.message}` };
  }

  // ── Step 2: patient_records ────────────────────────────────────────────────
  let patientSaved = false;
  const { error: patientError } = await supabase
    .from('patient_records')
    .insert({
      user_id: regUser.id,
      full_name: payload.full_name.trim(),
      age: payload.age,
      gender: payload.gender,
      blood_group: payload.blood_group || null,
      allergies: payload.allergies || null,
      existing_conditions: payload.existing_conditions || null,
      emergency_contact_name: payload.emergency_contact_name || null,
      emergency_contact_phone: payload.emergency_contact_phone || null,
      consent_given: true,
    });

  if (patientError) {
    console.warn('[queueStore] patient_records insert failed:', patientError.message);
  } else {
    patientSaved = true;
  }

  // ── Step 3: queue_logs ─────────────────────────────────────────────────────
  let predictedWaitMinutes: number | null = null;
  if (payload.consultation_end_time) {
    const diffMs = new Date(payload.consultation_end_time).getTime() - new Date(payload.check_in_time).getTime();
    if (diffMs < 0) return { success: false, patientSaved, error: 'Consultation end time cannot be before check-in time.' };
    predictedWaitMinutes = Math.round(diffMs / 60000);
  }

  const { error: queueError } = await supabase
    .from('queue_logs')
    .insert({
      hospital_id: payload.hospital_id,
      department_type: payload.department_type,
      check_in_time: payload.check_in_time,
      consultation_end_time: payload.consultation_end_time || null,
      predicted_wait_minutes: predictedWaitMinutes,
    });

  if (queueError) {
    return { success: false, patientSaved, error: `Queue log failed: ${queueError.message}` };
  }

  emitQueueSync();
  return { success: true, patientSaved };
}

export function subscribeToQueueLogs(): () => void {
  const channel = supabase
    .channel('queue-logs-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'queue_logs' }, () => {
      console.log('[queueStore] Realtime: queue_logs changed');
      emitQueueSync();
    })
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
