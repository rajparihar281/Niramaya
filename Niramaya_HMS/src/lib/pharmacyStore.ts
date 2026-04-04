/**
 * Pharmacy Store — Supabase-backed inventory & sales with real-time sync
 *
 * Supabase `inventory`:    id, hospital_id, medicine_name, stock_level, is_antibiotic, updated_at
 * Supabase `pharmacy_sales`: id, pharmacist_id, medicine_name, patient_hash, is_verified, created_at
 *
 * Each sale = 1 unit. stock_level is decremented by 1 per sale.
 */
import { supabase } from '@/lib/supabaseClient';

// ─── Supabase Row Types (match DB exactly) ───────────────────────
export interface InventoryRow {
  id: string;
  hospital_id: string | null;
  medicine_name: string;
  stock_level: number;
  is_antibiotic: boolean;
  updated_at: string;
}

export interface PharmacySaleRow {
  id: string;
  pharmacist_id: string | null;
  medicine_name: string | null;
  patient_hash: string | null;
  is_verified: boolean;
  created_at: string;
}

// ─── UI-mapped type for Inventory panel ──────────────────────────
export interface InventoryItemUI {
  id: string;
  name: string;
  category: 'medicine' | 'equipment' | 'consumable';
  quantity: number;
  unit: string;
  is_antibiotic: boolean;
  updated_at: string;
}

function mapRow(row: InventoryRow): InventoryItemUI {
  return {
    id: row.id,
    name: row.medicine_name,
    category: 'medicine',
    quantity: row.stock_level,
    unit: 'units',
    is_antibiotic: row.is_antibiotic,
    updated_at: row.updated_at,
  };
}

// ─── Sync Event Bus ──────────────────────────────────────────────
const SYNC_EVENT = 'niramaya_inventory_sync';

function emitSync() {
  window.dispatchEvent(new CustomEvent(SYNC_EVENT));
}

export function onInventorySync(handler: () => void): () => void {
  window.addEventListener(SYNC_EVENT, handler);
  return () => window.removeEventListener(SYNC_EVENT, handler);
}

// ─── Supabase Queries ────────────────────────────────────────────

export async function fetchInventory(): Promise<{ data: InventoryItemUI[]; error: string | null }> {
  const { data, error } = await supabase
    .from('inventory')
    .select('*')
    .order('medicine_name', { ascending: true });

  if (error) {
    console.error('[pharmacyStore] fetchInventory error:', error);
    return { data: [], error: error.message };
  }
  return { data: (data || []).map(mapRow), error: null };
}

export async function fetchSales(): Promise<{ data: PharmacySaleRow[]; error: string | null }> {
  const { data, error } = await supabase
    .from('pharmacy_sales')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('[pharmacyStore] fetchSales error:', error);
    return { data: [], error: error.message };
  }
  return { data: data || [], error: null };
}

/**
 * Record a single-unit sale:
 * 1. Validate stock > 0
 * 2. Decrement inventory.stock_level by 1
 * 3. Insert into pharmacy_sales (id=auto, pharmacist_id=null, medicine_name, patient_hash, is_verified=false, created_at=auto)
 * 4. Emit sync
 */
export async function recordSale(
  item: InventoryItemUI,
  patientHash: string
): Promise<{ success: boolean; error?: string }> {
  if (item.quantity <= 0) {
    return { success: false, error: `${item.name} is out of stock.` };
  }

  // Step 1: Insert sale record (is_verified = false initially)
  const { data: saleData, error: insertError } = await supabase
    .from('pharmacy_sales')
    .insert({
      pharmacist_id: null,
      medicine_name: item.name,
      patient_hash: patientHash.trim() || null,
      is_verified: false,
    })
    .select('id')
    .single();

  if (insertError) {
    console.error('[pharmacyStore] Sale insert error:', insertError);
    return { success: false, error: `Failed to record sale: ${insertError.message}` };
  }

  // Step 2: Decrement stock_level by 1
  const { error: updateError } = await supabase
    .from('inventory')
    .update({
      stock_level: item.quantity - 1,
      updated_at: new Date().toISOString(),
    })
    .eq('id', item.id);

  if (updateError) {
    console.error('[pharmacyStore] Inventory update error:', updateError);
    // Rollback sale if inventory update fails
    await supabase.from('pharmacy_sales').delete().eq('id', saleData.id);
    return { success: false, error: `Failed to update inventory: ${updateError.message}` };
  }

  // Step 3: Verify the sale
  const { error: verifyError } = await supabase
    .from('pharmacy_sales')
    .update({ is_verified: true })
    .eq('id', saleData.id);

  if (verifyError) {
    console.error('[pharmacyStore] Sale verification error:', verifyError);
  }

  console.log('[pharmacyStore] Sale recorded and verified successfully');
  emitSync();
  return { success: true };
}

// ─── Supabase Realtime ───────────────────────────────────────────

export function subscribeToInventoryChanges(): () => void {
  const channel = supabase
    .channel('inventory-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'inventory' }, () => {
      console.log('[pharmacyStore] Realtime: inventory changed');
      emitSync();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'pharmacy_sales' }, () => {
      console.log('[pharmacyStore] Realtime: pharmacy_sales changed');
      emitSync();
    })
    .subscribe();

  return () => { supabase.removeChannel(channel); };
}
