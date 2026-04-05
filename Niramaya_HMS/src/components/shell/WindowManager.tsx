import { useState, useEffect } from 'react';
import { useWindowStore } from '@/stores/windowStore';
import { Window } from './Window';
import { APPS } from '@/config/apps';
import { AnimatePresence } from 'framer-motion';
import { Suspense } from 'react';

export interface SnapPreviewData {
  x: number | string;
  y: number | string;
  width: number | string;
  height: number | string;
}

export function WindowManager() {
  const { windows, splitters, updateSplitRatio, computeSnapBounds } = useWindowStore();
  const [snapPreview, setSnapPreview] = useState<SnapPreviewData | null>(null);

  // Recompute tiles automatically if screen dimensions resize
  useEffect(() => {
    const handleResize = () => {
      computeSnapBounds(window.innerWidth - 60, window.innerHeight - 28);
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [computeSnapBounds]);

  const handlePointerDownSplitter = (e: React.PointerEvent, nodeId: string, direction: 'horizontal' | 'vertical', ratio: number, span: number) => {
    e.preventDefault();
    e.stopPropagation();

    const startX = e.clientX;
    const startY = e.clientY;
    const startRatio = ratio;

    const handlePointerMove = (moveEvent: PointerEvent) => {
      const delta = direction === 'vertical' 
        ? moveEvent.clientX - startX 
        : moveEvent.clientY - startY;

      // Calculate ratio based on movement over the total span
      const newRatio = Math.max(0.1, Math.min(0.9, startRatio + (delta / span)));
      updateSplitRatio(nodeId, newRatio);
    };

    const handlePointerUp = () => {
      document.removeEventListener('pointermove', handlePointerMove);
      document.removeEventListener('pointerup', handlePointerUp);
    };

    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  };

  return (
    <div className="window-manager">
      {/* ─── Global Snap Preview Overlay ─── */}
      {snapPreview && (
        <div
          className="snap-preview"
          style={{
            left: snapPreview.x,
            top: snapPreview.y,
            width: snapPreview.width,
            height: snapPreview.height,
          }}
        />
      )}

      {/* ─── BSP Splitters Overlay ─── */}
      {splitters.map((s) => (
        <div
          key={s.id}
          className={`os-splitter is-${s.direction}`}
          style={{
            left: s.x,
            top: s.y,
            width: s.width,
            height: s.height,
          }}
          onPointerDown={(e) => handlePointerDownSplitter(e, s.nodeId, s.direction, s.currentRatio, s.span)}
        />
      ))}

      {/* ─── Windows Engine ─── */}
      <AnimatePresence>
        {windows.map((w) => {
          if (w.isMinimized) return null;

          const appDef = APPS.find((a) => a.id === w.component);
          if (!appDef) return null;

          const Component = appDef.component;

          return (
            <Window
              key={w.id}
              windowState={w}
              defaultWidth={appDef.defaultWidth}
              defaultHeight={appDef.defaultHeight}
              onSnapPreview={setSnapPreview}
            >
              <Suspense fallback={<div className="os-loading-app">Loading...</div>}>
                <Component />
              </Suspense>
            </Window>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
