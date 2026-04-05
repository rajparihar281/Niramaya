import { useAuth } from '@/context/AuthContext';
import { hasPermission } from '@/lib/rbac';
import { Card, Badge, CounterBadge } from '@fluentui/react-components';
import {
  Alert24Regular,
  People24Regular,
  Box24Regular,
  DocumentBulletList24Regular,
  Pill24Regular,
  Shield24Regular,
} from '@fluentui/react-icons';

interface StatCard {
  title: string;
  value: string;
  icon: React.ReactNode;
  color: string;
  feature: string;
}

export default function Dashboard() {
  const { profile } = useAuth();

  const stats: StatCard[] = [
    {
      title: 'Active SOS Alerts',
      value: '3',
      icon: <Alert24Regular />,
      color: '#ef4444',
      feature: 'sos_monitoring',
    },
    {
      title: 'Patients Today',
      value: '24',
      icon: <People24Regular />,
      color: '#3b82f6',
      feature: 'patient_registration',
    },
    {
      title: 'Pending Reports',
      value: '8',
      icon: <DocumentBulletList24Regular />,
      color: '#8b5cf6',
      feature: 'medical_history',
    },
    {
      title: 'Active Prescriptions',
      value: '15',
      icon: <Pill24Regular />,
      color: '#10b981',
      feature: 'prescriptions',
    },
    {
      title: 'Low Stock Items',
      value: '7',
      icon: <Box24Regular />,
      color: '#f59e0b',
      feature: 'inventory',
    },
    {
      title: 'Audit Entries',
      value: '142',
      icon: <Shield24Regular />,
      color: '#6366f1',
      feature: 'audit',
    },
  ];

  const visibleStats = stats.filter((s) =>
    hasPermission(profile?.role, s.feature as any, 'view')
  );

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <h1 className="page-title">Dashboard</h1>
        <div className="page-header__meta">
          {profile && (
            <Badge appearance="outline" color="brand" size="large">
              {profile.role.charAt(0).toUpperCase() + profile.role.slice(1)}
            </Badge>
          )}
        </div>
      </div>

      <div className="dashboard-grid">
        {visibleStats.map((stat) => (
          <Card key={stat.title} className="stat-card">
            <div className="stat-card__icon-wrap" style={{ background: `${stat.color}20` }}>
              <span style={{ color: stat.color }}>{stat.icon}</span>
            </div>
            <div className="stat-card__content">
              <span className="stat-card__label">{stat.title}</span>
              <span className="stat-card__value">{stat.value}</span>
            </div>
            <CounterBadge
              count={parseInt(stat.value)}
              color="brand"
              size="small"
              className="stat-card__badge"
            />
          </Card>
        ))}
      </div>

      {/* Quick Info Section */}
      <div className="dashboard-info">
        <Card className="info-card">
          <h3 className="info-card__title">🔒 Security Status</h3>
          <p className="info-card__text">
            AES-256-GCM encryption active. All medical records are encrypted at rest.
          </p>
          <Badge appearance="filled" color="success">Secure</Badge>
        </Card>

        <Card className="info-card">
          <h3 className="info-card__title">📡 System Status</h3>
          <p className="info-card__text">
            Running offline locally. All modules operational. Database writes are persisted globally using localStorage.
          </p>
          <Badge appearance="filled" color="success">Local Mode</Badge>
        </Card>

        <Card className="info-card">
          <h3 className="info-card__title">👋 Welcome</h3>
          <p className="info-card__text">
            Hello, <strong>{profile?.full_name || 'User'}</strong>. You are logged in as{' '}
            <strong>{profile?.role || 'unknown'}</strong>.
          </p>
        </Card>
      </div>
    </div>
  );
}
