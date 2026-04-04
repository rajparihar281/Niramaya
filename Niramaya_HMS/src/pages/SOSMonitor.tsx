import { useState, useEffect } from 'react';
import { INITIAL_SOS, getLocalData } from '@/lib/mockData';
import type { SOSEvent } from '@/types';
import {
  Card, Badge,
  Table, TableBody, TableCell, TableHeader, TableHeaderCell, TableRow,
  Select, Spinner, MessageBar, MessageBarBody,
} from '@fluentui/react-components';
import { Alert24Regular } from '@fluentui/react-icons';

export default function SOSMonitor() {
  const [events, setEvents] = useState<SOSEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>('all');

  useEffect(() => {
    fetchEvents();
  }, []);

  const fetchEvents = async () => {
    await new Promise((resolve) => setTimeout(resolve, 300));
    setEvents(getLocalData('sos', INITIAL_SOS));
    setLoading(false);
  };

  const filtered = events.filter((e) => filter === 'all' ? true : e.status === filter);

  if (loading) return <div className="page-loader"><Spinner size="large" label="Loading SOS events…" /></div>;

  return (
    <div className="module-page">
      <div className="page-header">
        <h1 className="page-title"><Alert24Regular /> SOS Monitor</h1>
        <div className="page-header__actions">
          <Select value={filter} onChange={(_, d) => setFilter(d.value)}>
            <option value="all">All Events</option>
            <option value="active">Active</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="resolved">Resolved</option>
          </Select>
        </div>
      </div>

      {events.length === 0 && (
        <MessageBar intent="info"><MessageBarBody>No SOS events found.</MessageBarBody></MessageBar>
      )}

      <Card className="table-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHeaderCell>ID</TableHeaderCell>
              <TableHeaderCell>Location</TableHeaderCell>
              <TableHeaderCell>Status</TableHeaderCell>
              <TableHeaderCell>Time</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((event) => (
              <TableRow key={event.id}>
                <TableCell>{event.id}</TableCell>
                <TableCell>{event.location}</TableCell>
                <TableCell>
                  <Badge appearance="outline" color={event.status === 'resolved' ? 'success' : 'warning'}>
                    {event.status}
                  </Badge>
                </TableCell>
                <TableCell>{new Date(event.created_at).toLocaleString()}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>
    </div>
  );
}
