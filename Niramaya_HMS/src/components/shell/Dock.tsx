import { useAuth } from '@/context/AuthContext';
import { useWindowStore } from '@/stores/windowStore';
import { APPS } from '@/config/apps';
import { motion } from 'framer-motion';

export function Dock() {
  const { profile } = useAuth();
  const { windows, openWindow, minimizeWindow, restoreWindow } = useWindowStore();

  if (!profile) return null;

  // Filter apps permitted for this user role
  const allowedApps = APPS.filter((app) =>
    app.roles.includes(profile.role as any)
  );

  const handleAppLaunch = (appId: string) => {
    const existingWindow = windows.find((w) => w.component === appId);
    if (existingWindow) {
      if (existingWindow.isMinimized) {
        restoreWindow(existingWindow.id);
      } else {
        minimizeWindow(existingWindow.id);
      }
    } else {
      const appDef = APPS.find((a) => a.id === appId);
      if (appDef) {
        openWindow(appDef.name, appDef.id, appDef.icon as unknown as string);
      }
    }
  };

  return (
    <nav className="os-dock">
      {allowedApps.map((app) => {
        const isOpen = windows.some((w) => w.component === app.id);
        const isActive = windows.some(
          (w) => w.component === app.id && w.isActive && !w.isMinimized
        );

        return (
          <motion.div
            key={app.id}
            whileHover={{ scale: 1.15 }}
            whileTap={{ scale: 0.95 }}
            className={`os-dock-item ${isOpen ? 'is-open' : ''} ${
              isActive ? 'is-active' : ''
            }`}
            onClick={() => handleAppLaunch(app.id)}
            title={app.name}
          >
            <div className="os-dock-icon">{app.icon}</div>
            {isOpen && <div className="os-dock-indicator" />}
          </motion.div>
        );
      })}
    </nav>
  );
}
