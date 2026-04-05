import React, { useEffect } from 'react';
import type { Dispatch, SetStateAction } from 'react';
import { motion, useDragControls, useMotionValue } from 'framer-motion';
import { useWindowStore } from '@/stores/windowStore';
import type { AppWindow } from '@/types';
import type { SnapPreviewData } from './WindowManager';
import {
  Dismiss16Regular,
  Subtract16Regular,
  Maximize16Regular,
  Square16Regular,
} from '@fluentui/react-icons';
import { ErrorBoundary } from '@/components/ErrorBoundary';

interface WindowProps {
  windowState: AppWindow;
  children: React.ReactNode;
  defaultWidth?: number;
  defaultHeight?: number;
  onSnapPreview?: Dispatch<SetStateAction<SnapPreviewData | null>>;
}

export const Window = React.memo(function Window({
  windowState,
  children,
  defaultWidth = 800,
  defaultHeight = 600,
  onSnapPreview,
}: WindowProps) {
  const {
    id,
    title,
    icon,
    isActive,
    isMaximized,
    zIndex,
    position,
    size,
  } = windowState;

  const {
    closeWindow,
    minimizeWindow,
    toggleMaximize,
    focusWindow,
    updateWindowPosition,
    updateWindowSize,
  } = useWindowStore();

  const dragControls = useDragControls();

  // ─── Independent Motion Values ──────────────────────────────────
  const x = useMotionValue(position?.x ?? 60);
  const y = useMotionValue(position?.y ?? 60);
  const w = useMotionValue(size?.width ?? defaultWidth);
  const h = useMotionValue(size?.height ?? defaultHeight);

  // Sync incoming state changes if they differ
  useEffect(() => {
    if (position?.x !== undefined && position.x !== x.get()) x.set(position.x);
    if (position?.y !== undefined && position.y !== y.get()) y.set(position.y);
  }, [position, x, y]);

  useEffect(() => {
    if (size?.width !== undefined && size.width !== w.get()) w.set(size.width as number);
    if (size?.height !== undefined && size.height !== h.get()) h.set(size.height as number);
  }, [size, w, h]);

  // ─── Resizing Logic ──────────────────────────────────────────────
  const handlePointerDownResize = (e: React.PointerEvent) => {
    e.stopPropagation();
    e.preventDefault();
    focusWindow(id);

    const startX = e.clientX;
    const startY = e.clientY;
    const startW = w.get() as number;
    const startH = h.get() as number;

    const handlePointerMove = (moveEvent: PointerEvent) => {
      w.set(Math.max(300, startW + (moveEvent.clientX - startX)));
      h.set(Math.max(200, startH + (moveEvent.clientY - startY)));
    };

    const handlePointerUp = (upEvent: PointerEvent) => {
      const finalW = Math.max(300, startW + (upEvent.clientX - startX));
      const finalH = Math.max(200, startH + (upEvent.clientY - startY));
      
      updateWindowSize(id, { width: finalW, height: finalH });
      
      document.removeEventListener('pointermove', handlePointerMove);
      document.removeEventListener('pointerup', handlePointerUp);
    };

    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  };

  return (
    <motion.div
      className={`os-window ${isActive ? 'is-active' : ''} ${
        isMaximized ? 'is-maximized' : ''
      }`}
      style={{
        zIndex,
        width: isMaximized ? '100%' : w,
        height: isMaximized ? '100%' : h,
        x: isMaximized ? 0 : x,
        y: isMaximized ? 0 : y,
      }}
      initial={{ scale: 0.8, opacity: 0 }}
      animate={{
        scale: 1,
        opacity: 1,
        x: isMaximized ? 0 : x.get(), 
        y: isMaximized ? 0 : y.get(),
      }}
      exit={{ scale: 0.8, opacity: 0 }}
      transition={{ type: 'spring', bounce: 0, duration: 0.3 }}
      
      // ─── Dragging Handling ───
      drag={!isMaximized}
      dragControls={dragControls}
      dragListener={false}
      dragMomentum={false}
      
      onDrag={(_event, info) => {
        if (!onSnapPreview) return;
        const pointerX = info.point.x;
        const pointerY = info.point.y;

        let targetSplit: { id: string; edge: 'left' | 'right' | 'top' | 'bottom', bounds: {x:number, y:number, w:number, h:number} } | null = null;
        let rootSplit: 'left' | 'right' | 'top' | 'bottom' | null = null;

        const { windows } = useWindowStore.getState();

        for (const otherW of windows) {
           if (otherW.id === id || otherW.isMinimized) continue;
           const oX = (otherW.position?.x as number) ?? 0;
           const oY = (otherW.position?.y as number) ?? 0;
           // If the other window is maximized or snapped, its width could be '100%'. But snapped windows are fully bound to pixel integers inside the state tracker in the BSP model!
           const oW = (typeof otherW.size?.width === 'number' ? otherW.size.width : parseInt(otherW.size?.width as string) || 800);
           const oH = (typeof otherW.size?.height === 'number' ? otherW.size.height : parseInt(otherW.size?.height as string) || 600);
           
           if (pointerX > oX && pointerX < oX + oW && pointerY > oY && pointerY < oY + oH) {
              const pctX = (pointerX - oX) / oW;
              const pctY = (pointerY - oY) / oH;

              if (pctX < 0.25) targetSplit = { id: otherW.id, edge: 'left', bounds: {x:oX, y:oY, w:oW, h:oH} };
              else if (pctX > 0.75) targetSplit = { id: otherW.id, edge: 'right', bounds: {x:oX, y:oY, w:oW, h:oH} };
              else if (pctY < 0.25) targetSplit = { id: otherW.id, edge: 'top', bounds: {x:oX, y:oY, w:oW, h:oH} };
              else if (pctY > 0.75) targetSplit = { id: otherW.id, edge: 'bottom', bounds: {x:oX, y:oY, w:oW, h:oH} };
              
              if (targetSplit) break;
           }
        }

        if (!targetSplit) {
          if (pointerY < 35) rootSplit = 'top';
          else if (pointerY > window.innerHeight - 20) rootSplit = 'bottom';
          else if (pointerX < 80) rootSplit = 'left';
          else if (pointerX > window.innerWidth - 20) rootSplit = 'right';
        }

        if (targetSplit) {
           const b = targetSplit.bounds;
           if (targetSplit.edge === 'left') onSnapPreview({ x: b.x, y: b.y, width: b.w / 2, height: b.h });
           else if (targetSplit.edge === 'right') onSnapPreview({ x: b.x + b.w / 2, y: b.y, width: b.w / 2, height: b.h });
           else if (targetSplit.edge === 'top') onSnapPreview({ x: b.x, y: b.y, width: b.w, height: b.h / 2 });
           else if (targetSplit.edge === 'bottom') onSnapPreview({ x: b.x, y: b.y + b.h / 2, width: b.w, height: b.h / 2 });
        } else if (rootSplit) {
           // We'll mimic Windows 11 edge drag. Top drag = standard maximize preview for simplicity, or top split.
           if (rootSplit === 'top') onSnapPreview({ x: 0, y: 0, width: '100%', height: '100%' }); // fallback to maximize
           else if (rootSplit === 'bottom') onSnapPreview({ x: 0, y: '50%', width: '100%', height: '50%' });
           else if (rootSplit === 'left') onSnapPreview({ x: 0, y: 0, width: '50%', height: '100%' });
           else if (rootSplit === 'right') onSnapPreview({ x: '50%', y: 0, width: '50%', height: '100%' });
        } else {
           onSnapPreview(null);
        }
      }}

      onDragEnd={(_e, info) => {
        if (onSnapPreview) onSnapPreview(null);
        const pointerX = info.point.x;
        const pointerY = info.point.y;

        const { windows, snapWindowToNode } = useWindowStore.getState();

        let targetId: string | null = null;
        let snapDirection: 'vertical' | 'horizontal' | null = null;
        let insertFirst = true;
        let requiresMaximize = false;

        for (const otherW of windows) {
           if (otherW.id === id || otherW.isMinimized) continue;
           const oX = (otherW.position?.x as number) ?? 0;
           const oY = (otherW.position?.y as number) ?? 0;
           const oW = (typeof otherW.size?.width === 'number' ? otherW.size.width : parseInt(otherW.size?.width as string) || 800);
           const oH = (typeof otherW.size?.height === 'number' ? otherW.size.height : parseInt(otherW.size?.height as string) || 600);
           
           if (pointerX > oX && pointerX < oX + oW && pointerY > oY && pointerY < oY + oH) {
              const pctX = (pointerX - oX) / oW;
              const pctY = (pointerY - oY) / oH;

              targetId = otherW.id;
              if (pctX < 0.25) { snapDirection = 'vertical'; insertFirst = true; }
              else if (pctX > 0.75) { snapDirection = 'vertical'; insertFirst = false; }
              else if (pctY < 0.25) { snapDirection = 'horizontal'; insertFirst = true; }
              else if (pctY > 0.75) { snapDirection = 'horizontal'; insertFirst = false; }
              else targetId = null; // not close enough to edge
              
              if (targetId) break;
           }
        }

        if (!targetId) {
          if (pointerY < 35) { requiresMaximize = true; }
          else if (pointerY > window.innerHeight - 20) { snapDirection = 'horizontal'; insertFirst = false; }
          else if (pointerX < 80) { snapDirection = 'vertical'; insertFirst = true; }
          else if (pointerX > window.innerWidth - 20) { snapDirection = 'vertical'; insertFirst = false; }
        }

        if (requiresMaximize) {
          if (!isMaximized) toggleMaximize(id);
          return;
        }

        if (snapDirection) {
           snapWindowToNode(id, targetId, snapDirection, 0.5, insertFirst);
           return;
        }

        // Float standardly
        const dragAreaW = window.innerWidth - 60;
        const dragAreaH = window.innerHeight - 28;
        const safeX = Math.max(0, Math.min(x.get() + info.offset.x, dragAreaW - (w.get() as number)));
        const safeY = Math.max(0, Math.min(y.get() + info.offset.y, dragAreaH - (h.get() as number)));

        updateWindowPosition(id, { x: safeX, y: safeY });
      }}

      onPointerDown={() => {
        if (!isActive) focusWindow(id);
      }}
    >
      {/* Title Bar */}
      <div
        className="os-window-titlebar"
        onPointerDown={(e) => {
          if (!isMaximized) {
            const { unsnapWindow } = useWindowStore.getState();
            if (windowState.isSnapped) unsnapWindow(id);
            dragControls.start(e);
          }
        }}
        onDoubleClick={() => toggleMaximize(id)}
      >
        <div className="os-window-title">
          <span className="os-window-icon">{icon}</span>
          {title}
        </div>
        <div className="os-window-controls">
          <button
            className="os-window-ctrl min-btn"
            onPointerDown={(e) => {
              e.stopPropagation();
              e.preventDefault();
              minimizeWindow(id);
            }}
          >
            <Subtract16Regular />
          </button>
          <button
            className="os-window-ctrl max-btn"
            onPointerDown={(e) => {
              e.stopPropagation();
              e.preventDefault();
              toggleMaximize(id);
            }}
          >
            {isMaximized ? <Square16Regular /> : <Maximize16Regular />}
          </button>
          <button
            className="os-window-ctrl close-btn"
            onPointerDown={(e) => {
              e.stopPropagation();
              e.preventDefault();
              closeWindow(id);
            }}
          >
            <Dismiss16Regular />
          </button>
        </div>
      </div>

      {/* Body Content */}
      <div className="os-window-body">
         <ErrorBoundary>
           {children}
         </ErrorBoundary>
      </div>

      {/* Resizer */}
      {!isMaximized && !windowState.isSnapped && (
        <div
          className="os-window-resizer"
          onPointerDown={handlePointerDownResize}
        />
      )}
    </motion.div>
  );
});
