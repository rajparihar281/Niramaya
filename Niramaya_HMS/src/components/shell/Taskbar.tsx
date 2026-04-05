import { useState, useEffect } from 'react';
import { useWindowStore } from '@/stores/windowStore';
import { useAuth } from '@/context/AuthContext';
import {
  Dismiss12Regular,
  WindowNew16Regular,
} from '@fluentui/react-icons';
import { Badge, Tooltip } from '@fluentui/react-components';

export function Taskbar() {
  const { windows, focusWindow, closeWindow, minimizeWindow } = useWindowStore();
  const { profile } = useAuth();
  const [clock, setClock] = useState(getTimeString());

  useEffect(() => {
    const interval = setInterval(() => setClock(getTimeString()), 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <footer className="taskbar">
      {/* Start / Brand */}
      <div className="taskbar__start">
        <span className="taskbar__brand">🏥 Niramaya HMS</span>
      </div>

      {/* Active Windows */}
      <div className="taskbar__windows">
        {windows.map((w) => (
          <Tooltip key={w.id} content={w.title} relationship="description">
            <button
              className={`taskbar__window-btn ${
                w.isActive ? 'taskbar__window-btn--active' : ''
              } ${w.isMinimized ? 'taskbar__window-btn--minimized' : ''}`}
              onClick={() =>
                w.isActive && !w.isMinimized
                  ? minimizeWindow(w.id)
                  : focusWindow(w.id)
              }
            >
              <span className="taskbar__window-icon">{w.icon}</span>
              <span className="taskbar__window-title">{w.title}</span>
              <button
                className="taskbar__window-close"
                onClick={(e) => {
                  e.stopPropagation();
                  closeWindow(w.id);
                }}
              >
                <Dismiss12Regular />
              </button>
            </button>
          </Tooltip>
        ))}
        {windows.length === 0 && (
          <span className="taskbar__hint">
            <WindowNew16Regular /> No active windows
          </span>
        )}
      </div>

      {/* System Tray */}
      <div className="taskbar__tray">
        {profile && (
          <Badge
            appearance="filled"
            color="brand"
            size="small"
            className="taskbar__role-badge"
          >
            {profile.role.toUpperCase()}
          </Badge>
        )}
        <span className="taskbar__clock">{clock}</span>
      </div>
    </footer>
  );
}

function getTimeString(): string {
  return new Date().toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });
}
