import { Dock } from './Dock';
import { WindowManager } from './WindowManager';
import { useAuth } from '@/context/AuthContext';
import { Power20Regular } from '@fluentui/react-icons';

export function DesktopLayout() {
  const { profile, logout } = useAuth();
  
  return (
    <div className="os-desktop animate-fade-in">
      {/* Top Bar */}
      <header className="os-topbar">
        <div className="os-topbar-left">
          <span className="os-brand">NiramayaOS</span>
          <span className="os-role-badge">{profile?.role}</span>
        </div>
        <div className="os-topbar-right">
          <span className="os-user-name">{profile?.full_name}</span>
          <button className="os-logout-btn" onClick={logout} title="Log Out">
            <Power20Regular />
          </button>
        </div>
      </header>

      {/* Main Workspace Workspace */}
      <main className="os-workspace">
        <Dock />
        <div className="os-drag-area">
          <WindowManager />
        </div>
      </main>
    </div>
  );
}
