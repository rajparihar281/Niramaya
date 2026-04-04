import { supabase } from '@/lib/supabaseClient';

export interface SymptomLog {
  id: string;
  district: string;
  symptom_type: string;
  occurrence_count: number;
  latitude: number | null;
  longitude: number | null;
  created_at: string;
}

const SYMPTOMS_SYNC_EVENT = 'niramaya_symptoms_sync';

export function emitSymptomsSync() {
  window.dispatchEvent(new CustomEvent(SYMPTOMS_SYNC_EVENT));
}

export function onSymptomsSync(handler: () => void): () => void {
  window.addEventListener(SYMPTOMS_SYNC_EVENT, handler);
  return () => window.removeEventListener(SYMPTOMS_SYNC_EVENT, handler);
}

export async function fetchSymptomLogs(): Promise<{ data: SymptomLog[]; error: string | null }> {
  const { data, error } = await supabase
    .from('symptom_logs')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('[symptomStore] fetch error:', error);
    return { data: [], error: error.message };
  }
  return { data: data || [], error: null };
}

export async function insertSymptomLog(
  district: string,
  symptomType: string,
  occurrenceCount: number,
  latitude?: number | null,
  longitude?: number | null
): Promise<{ success: boolean; error?: string }> {
  const { error } = await supabase
    .from('symptom_logs')
    .insert({
      district: district.trim(),
      symptom_type: symptomType.trim(),
      occurrence_count: occurrenceCount,
      latitude: latitude ?? null,
      longitude: longitude ?? null,
    });

  if (error) {
    console.error('[symptomStore] insert error:', error);
    return { success: false, error: `Failed to insert log: ${error.message}` };
  }

  // The caller gets success true and the realtime channel triggers a refresh too,
  // but we can also manually emit a sync if we inserted it ourselves so it updates instantly locally.
  emitSymptomsSync();
  return { success: true };
}

export function subscribeToSymptomLogs(): () => void {
  const channel = supabase
    .channel('symptom-logs-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'symptom_logs' }, () => {
      console.log('[symptomStore] Realtime: symptom_logs changed');
      emitSymptomsSync();
    })
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
