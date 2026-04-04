import { create } from 'zustand';
import type { AppWindow, SnapNode, SplitterData, SnapDirection } from '@/types';
import { v4 as uuidv4 } from 'uuid';

interface WindowState {
  windows: AppWindow[];
  nextZIndex: number;
  snapTree?: SnapNode;
  splitters: SplitterData[];

  // Actions
  openWindow: (title: string, component: string, icon?: string) => void;
  closeWindow: (id: string) => void;
  focusWindow: (id: string) => void;
  minimizeWindow: (id: string) => void;
  restoreWindow: (id: string) => void;
  toggleMaximize: (id: string) => void;
  updateWindowPosition: (id: string, position: { x: number; y: number }) => void;
  updateWindowSize: (id: string, size: { width: number | string; height: number | string }) => void;
  closeAllWindows: () => void;
  resetStore: () => void; // ← Full session reset: clears all windows + layout state

  // Snap Actions
  snapWindowToNode: (windowId: string, targetId: string | null, direction: SnapDirection, ratio?: number, insertFirst?: boolean) => void;
  unsnapWindow: (windowId: string) => void;
  updateSplitRatio: (nodeId: string, newRatio: number) => void;
  computeSnapBounds: (dragAreaW: number, dragAreaH: number) => void;
}

// ─── BSP Helper Functions ──────────────────────────────────────────────

function removeNodeRecursive(node: SnapNode, id: string): SnapNode | undefined {
  if (node.isLeaf) {
    return node.windowId === id ? undefined : node;
  }
  if (!node.child1 || !node.child2) return node;

  const newChild1 = removeNodeRecursive(node.child1, id);
  const newChild2 = removeNodeRecursive(node.child2, id);

  if (!newChild1) return newChild2;
  if (!newChild2) return newChild1;

  return { ...node, child1: newChild1, child2: newChild2 };
}

function insertNodeRecursive(node: SnapNode, targetId: string | null, newNodeId: string, direction: SnapDirection, ratio: number, insertFirst: boolean): SnapNode {
  if (targetId === null) {
      const newLeaf: SnapNode = { id: uuidv4(), isLeaf: true, windowId: newNodeId };
      return {
          id: uuidv4(),
          isLeaf: false,
          direction,
          splitRatio: ratio,
          child1: insertFirst ? newLeaf : node,
          child2: insertFirst ? node : newLeaf
      };
  }

  if (node.isLeaf && node.windowId === targetId) {
    const newLeaf: SnapNode = { id: uuidv4(), isLeaf: true, windowId: newNodeId };
    return {
        id: uuidv4(),
        isLeaf: false,
        direction,
        splitRatio: ratio,
        child1: insertFirst ? newLeaf : node,
        child2: insertFirst ? node : newLeaf
    };
  }

  if (!node.isLeaf && node.child1 && node.child2) {
    return { 
      ...node, 
      child1: insertNodeRecursive(node.child1, targetId, newNodeId, direction, ratio, insertFirst), 
      child2: insertNodeRecursive(node.child2, targetId, newNodeId, direction, ratio, insertFirst) 
    };
  }

  return node;
}

function updateRatioRecursive(node: SnapNode, nodeId: string, newRatio: number): SnapNode {
  if (node.id === nodeId && !node.isLeaf) {
      return { ...node, splitRatio: newRatio };
  }
  if (!node.isLeaf && node.child1 && node.child2) {
      return {
          ...node,
          child1: updateRatioRecursive(node.child1, nodeId, newRatio),
          child2: updateRatioRecursive(node.child2, nodeId, newRatio)
      };
  }
  return node;
}

function computeBoundsRecursive(
  node: SnapNode, bounds: {x:number, y:number, w:number, h:number}, 
  outMap: Map<string, {x:number, y:number, w:number, h:number}>, 
  outSplitters: SplitterData[]
) {
   if (node.isLeaf && node.windowId) {
      outMap.set(node.windowId, bounds);
      return;
   }

   const ratio = node.splitRatio ?? 0.5;
   let bounds1, bounds2;
   
   if (node.direction === 'horizontal') {
       const h1 = bounds.h * ratio;
       const h2 = bounds.h - h1;
       bounds1 = { x: bounds.x, y: bounds.y, w: bounds.w, h: h1 };
       bounds2 = { x: bounds.x, y: bounds.y + h1, w: bounds.w, h: h2 };

       outSplitters.push({
           id: node.id,
           nodeId: node.id,
           direction: 'horizontal',
           x: bounds.x,
           y: bounds.y + h1 - 5,
           width: bounds.w,
           height: 10,
           span: bounds.h,
           currentRatio: ratio
       });
   } else {
       const w1 = bounds.w * ratio;
       const w2 = bounds.w - w1;
       bounds1 = { x: bounds.x, y: bounds.y, w: w1, h: bounds.h };
       bounds2 = { x: bounds.x + w1, y: bounds.y, w: w2, h: bounds.h };

       outSplitters.push({
           id: node.id,
           nodeId: node.id,
           direction: 'vertical',
           x: bounds.x + w1 - 5,
           y: bounds.y,
           width: 10,
           height: bounds.h,
           span: bounds.w,
           currentRatio: ratio
       });
   }

   if (node.child1) computeBoundsRecursive(node.child1, bounds1, outMap, outSplitters);
   if (node.child2) computeBoundsRecursive(node.child2, bounds2, outMap, outSplitters);
}

// ─── Store Implementation ────────────────────────────────────────────────

export const useWindowStore = create<WindowState>((set, get) => ({
  windows: [],
  nextZIndex: 100,
  splitters: [],

  openWindow: (title, component, icon = '📋') => {
    const { windows, nextZIndex } = get();
    const existing = windows.find((w) => w.component === component);
    if (existing) {
      if (existing.isMinimized) get().restoreWindow(existing.id);
      else get().focusWindow(existing.id);
      return;
    }

    const newWindow: AppWindow = {
      id: uuidv4(),
      title,
      icon,
      component,
      isMinimized: false,
      isMaximized: false,
      isActive: true,
      zIndex: nextZIndex,
      isSnapped: false,
      position: { x: 60 + (windows.length * 30), y: 60 + (windows.length * 30) },
    };

    set({
      windows: [...windows.map((w) => ({ ...w, isActive: false })), newWindow],
      nextZIndex: nextZIndex + 1,
    });
  },

  closeWindow: (id) => {
    const { unsnapWindow } = get();
    // Reclaim tiled space implicitly
    unsnapWindow(id);

    set((state) => ({
      windows: state.windows.filter((w) => w.id !== id),
    }));
  },

  focusWindow: (id) => {
    const { nextZIndex, windows } = get();
    const isAlreadyTop = windows.find(w => w.id === id)?.zIndex === Math.max(...windows.map(w => w.zIndex));
    
    set((state) => ({
      windows: state.windows.map((w) => ({
        ...w,
        isActive: w.id === id,
        zIndex: w.id === id ? (isAlreadyTop ? w.zIndex : nextZIndex) : w.zIndex,
      })),
      nextZIndex: isAlreadyTop ? nextZIndex : nextZIndex + 1,
    }));
  },

  minimizeWindow: (id) => {
    set((state) => ({
      windows: state.windows.map((w) => w.id === id ? { ...w, isMinimized: true, isActive: false } : w )
    }));
  },

  restoreWindow: (id) => {
    set((state) => ({
      windows: state.windows.map((w) => w.id === id ? { ...w, isMinimized: false } : w )
    }));
    get().focusWindow(id);
  },

  toggleMaximize: (id) => {
    set((state) => ({
      windows: state.windows.map((w) => w.id === id ? { ...w, isMaximized: !w.isMaximized } : w )
    }));
    get().focusWindow(id);
  },

  updateWindowPosition: (id, position) => {
    set((state) => ({
      windows: state.windows.map((w) => w.id === id ? { ...w, position } : w )
    }));
  },

  updateWindowSize: (id, size) => {
    set((state) => ({
      windows: state.windows.map((w) => w.id === id ? { ...w, size } : w )
    }));
  },

  closeAllWindows: () => {
    set({ windows: [], nextZIndex: 100, snapTree: undefined, splitters: [] });
  },

  resetStore: () => {
    // Full atomic reset — called on logout to guarantee no cross-session state leak
    set({ windows: [], nextZIndex: 100, snapTree: undefined, splitters: [] });
  },

  // ─── Tiling Actions ───

  snapWindowToNode: (windowId, targetId, direction, ratio = 0.5, insertFirst = true) => {
    const { snapTree, computeSnapBounds } = get();
    let newTree: SnapNode;

    if (!snapTree) {
      newTree = { id: uuidv4(), isLeaf: true, windowId };
    } else {
      // Unsnap from its old position first if already snapped somewhere
      get().unsnapWindow(windowId);
      const cleanedTree = get().snapTree; // might be undefined if it was the only node
      if (!cleanedTree) {
        newTree = { id: uuidv4(), isLeaf: true, windowId };
      } else {
        newTree = insertNodeRecursive(cleanedTree, targetId, windowId, direction, ratio, insertFirst);
      }
    }

    set((state) => ({
      snapTree: newTree,
      windows: state.windows.map(w => w.id === windowId ? { ...w, isMaximized: false, isSnapped: true } : w)
    }));
    
    // Automatically recalculate utilizing stored DOM bounds if available
    computeSnapBounds(window.innerWidth - 60, window.innerHeight - 28);
  },

  unsnapWindow: (windowId) => {
    const { snapTree, computeSnapBounds } = get();
    if (!snapTree) return;

    const newTree = removeNodeRecursive(snapTree, windowId);
    set((state) => ({
      snapTree: newTree,
      windows: state.windows.map(w => w.id === windowId ? { ...w, isSnapped: false } : w)
    }));

    if (newTree) {
      computeSnapBounds(window.innerWidth - 60, window.innerHeight - 28);
    } else {
      set({ splitters: [] });
    }
  },

  updateSplitRatio: (nodeId, newRatio) => {
    const { snapTree, computeSnapBounds } = get();
    if (!snapTree) return;
    set({ snapTree: updateRatioRecursive(snapTree, nodeId, newRatio) });
    computeSnapBounds(window.innerWidth - 60, window.innerHeight - 28);
  },

  computeSnapBounds: (dragAreaW, dragAreaH) => {
    const { snapTree } = get();
    if (!snapTree) {
      set({ splitters: [] });
      return;
    }

    const boundsMap = new Map<string, { x: number, y: number, w: number, h: number }>();
    const newSplitters: SplitterData[] = [];
    
    computeBoundsRecursive(snapTree, { x: 0, y: 0, w: dragAreaW, h: dragAreaH }, boundsMap, newSplitters);

    set((state) => ({
      splitters: newSplitters,
      windows: state.windows.map(w => {
         const bounds = boundsMap.get(w.id);
         if (bounds) {
            return {
              ...w,
              position: { x: bounds.x, y: bounds.y },
              size: { width: bounds.w, height: bounds.h }
            };
         }
         return w;
      })
    }));
  }
}));
