import { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { getNavItemsForRole } from '@/lib/rbac';
import {
  Home24Regular,
  Alert24Regular,
  PersonAdd24Regular,
  DocumentBulletList24Regular,
  Pill24Regular,
  Box24Regular,
  Shield24Regular,
  Navigation24Regular,
  SignOut24Regular,
  Person24Regular,
} from '@fluentui/react-icons';
import {
  Avatar,
  Button,
  Tooltip,
} from '@fluentui/react-components';

const ICON_MAP: Record<string, React.ReactNode> = {
  Board: <Home24Regular />,
  Alert: <Alert24Regular />,
  PersonAdd: <PersonAdd24Regular />,
  DocumentBulletList: <DocumentBulletList24Regular />,
  Pill: <Pill24Regular />,
  Box: <Box24Regular />,
  Shield: <Shield24Regular />,
};

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const { profile, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const navItems = profile ? getNavItemsForRole(profile.role) : [];

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <aside className={`sidebar ${collapsed ? 'sidebar--collapsed' : ''}`}>
      {/* Header / Toggle */}
      <div className="sidebar__header">
        <button
          className="sidebar__toggle"
          onClick={() => setCollapsed(!collapsed)}
          aria-label="Toggle sidebar"
        >
          <Navigation24Regular />
        </button>
        {!collapsed && (
          <span className="sidebar__brand">
            <span className="sidebar__brand-icon">🏥</span>
            Niramaya
          </span>
        )}
      </div>

      {/* Navigation */}
      <nav className="sidebar__nav">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          return (
            <Tooltip
              key={item.key}
              content={item.label}
              relationship="label"
              positioning="after"
            >
              <button
                className={`sidebar__item ${isActive ? 'sidebar__item--active' : ''}`}
                onClick={() => navigate(item.path)}
              >
                <span className="sidebar__item-icon">
                  {ICON_MAP[item.icon] || <Home24Regular />}
                </span>
                {!collapsed && (
                  <span className="sidebar__item-label">{item.label}</span>
                )}
              </button>
            </Tooltip>
          );
        })}
      </nav>

      {/* User Section */}
      <div className="sidebar__footer">
        {!collapsed && profile && (
          <div className="sidebar__user">
            <Avatar
              name={profile.full_name}
              size={32}
              color="brand"
            />
            <div className="sidebar__user-info">
              <span className="sidebar__user-name">{profile.full_name}</span>
              <span className="sidebar__user-role">{profile.role}</span>
            </div>
          </div>
        )}
        {collapsed && profile && (
          <Tooltip content={profile.full_name} relationship="label" positioning="after">
            <Avatar
              name={profile.full_name}
              size={28}
              color="brand"
              icon={<Person24Regular />}
            />
          </Tooltip>
        )}
        <Tooltip content="Sign Out" relationship="label" positioning="after">
          <Button
            icon={<SignOut24Regular />}
            appearance="subtle"
            onClick={handleLogout}
            className="sidebar__logout"
          />
        </Tooltip>
      </div>
    </aside>
  );
}
