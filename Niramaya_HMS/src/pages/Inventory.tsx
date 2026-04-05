import { useState, useEffect } from 'react';
import {
  fetchInventory,
  onInventorySync,
  subscribeToInventoryChanges,
  type InventoryItemUI,
} from '@/lib/pharmacyStore';
import { useAuth } from '@/context/AuthContext';
import { hasPermission } from '@/lib/rbac';
import {
  Card, Badge,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Input, Spinner, MessageBar, MessageBarBody,
} from '@fluentui/react-components';
import { Box24Regular, Search24Regular, WarningRegular } from '@fluentui/react-icons';

// Low-stock threshold
const LOW_STOCK = 20;

export default function Inventory() {
  const { profile } = useAuth();
  const canEdit = hasPermission(profile?.role, 'inventory', 'update');

  const [items, setItems] = useState<InventoryItemUI[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  const loadInventory = async () => {
    const { data, error: fetchError } = await fetchInventory();
    if (fetchError) {
      setError(fetchError);
    } else {
      setItems(data);
      setError(null);
    }
    setLoading(false);
  };

  useEffect(() => {
    loadInventory();

    // Subscribe to local sync events (from PharmacySales panel)
    const unsubSync = onInventorySync(() => {
      loadInventory();
    });

    // Subscribe to Supabase realtime (cross-browser/cross-tab auto-refresh)
    const unsubRealtime = subscribeToInventoryChanges();

    return () => {
      unsubSync();
      unsubRealtime();
    };
  }, []);

  const filtered = items.filter((i) =>
    i.name.toLowerCase().includes(search.toLowerCase())
  );

  const lowStockItems = items.filter((i) => i.quantity <= LOW_STOCK);

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading inventory…" /></div>;

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><Box24Regular /> Inventory</h1>
        <div className="page-header__actions">
          <Input
            placeholder="Search items…"
            contentBefore={<Search24Regular />}
            value={search}
            onChange={(_, d) => setSearch(d.value)}
          />
        </div>
      </div>

      {error && (
        <MessageBar intent="error" style={{ marginBottom: 16 }}>
          <MessageBarBody>{error}</MessageBarBody>
        </MessageBar>
      )}

      {/* Low stock warnings */}
      {lowStockItems.length > 0 && (
        <MessageBar intent="warning" style={{ marginBottom: 16 }}>
          <MessageBarBody>
            <strong>Low Stock Alert:</strong>{' '}
            {lowStockItems.map((i) => `${i.name} (${i.quantity} ${i.unit})`).join(', ')}
          </MessageBarBody>
        </MessageBar>
      )}

      {!canEdit && (
        <MessageBar intent="info" style={{ marginBottom: 16 }}>
          <MessageBarBody>Read-only view. Only Pharmacy role can record sales.</MessageBarBody>
        </MessageBar>
      )}

      <Card className="table-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Name</TableHeaderCell>
              <TableHeaderCell>Category</TableHeaderCell>
              <TableHeaderCell>Stock</TableHeaderCell>
              <TableHeaderCell>Antibiotic</TableHeaderCell>
              <TableHeaderCell>Status</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-muted)' }}>
                  No items found.
                </TableCell>
              </TableRow>
            ) : (
              filtered.map((item) => {
                const isLow = item.quantity <= LOW_STOCK;
                const isOut = item.quantity === 0;
                return (
                  <TableRow key={item.id}>
                    <TableCell>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        {isLow && <WarningRegular style={{ color: isOut ? 'var(--danger)' : 'var(--warning)', width: 14 }} />}
                        {item.name}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge appearance="outline">{item.category}</Badge>
                    </TableCell>
                    <TableCell>
                      <span style={{ color: isOut ? 'var(--danger)' : isLow ? 'var(--warning)' : 'var(--text-primary)', fontWeight: isLow ? 600 : 400 }}>
                        {item.quantity} {item.unit}
                      </span>
                    </TableCell>
                    <TableCell>
                      {item.is_antibiotic
                        ? <Badge appearance="tint" color="important">Yes</Badge>
                        : <span style={{ color: 'var(--text-muted)' }}>No</span>}
                    </TableCell>
                    <TableCell>
                      <Badge
                        appearance="tint"
                        color={isOut ? 'danger' : isLow ? 'warning' : 'success'}
                      >
                        {isOut ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock'}
                      </Badge>
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </Card>
    </div>
  );
}
