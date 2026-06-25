/** Origami 在线演示 — 对齐 WindowOverlayManager / GroupStore 行为 */

type AppKind = 'safari' | 'notes' | 'terminal';

interface DemoWindow {
  id: string;
  title: string;
  app: AppKind;
  groupId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zIndex: number;
}

interface DemoGroup {
  id: string;
  windowIds: string[];
  activeIndex: number;
}

interface GroupSlot {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface DemoState {
  windows: Record<string, DemoWindow>;
  groups: Record<string, DemoGroup>;
  nextZ: number;
}

const DETACH_DELAY_MS = 1500;
const DRAG_THRESHOLD = 4;

/** 窗口尺寸分档 — 对齐 Tailwind sm/md/lg/xl 断点（按视口宽度） */
interface WindowSizeTier {
  winW: number;
  winH: number;
  cascadeStep: number;
  minWinW: number;
  minWinH: number;
  minStep: number;
}

function getWindowSizeTier(viewportWidth = typeof window !== 'undefined' ? window.innerWidth : 1024): WindowSizeTier {
  if (viewportWidth >= 1280) {
    return { winW: 520, winH: 380, cascadeStep: 136, minWinW: 200, minWinH: 160, minStep: 44 };
  }
  if (viewportWidth >= 1024) {
    return { winW: 460, winH: 340, cascadeStep: 120, minWinW: 200, minWinH: 160, minStep: 40 };
  }
  if (viewportWidth >= 768) {
    return { winW: 380, winH: 280, cascadeStep: 96, minWinW: 180, minWinH: 140, minStep: 36 };
  }
  if (viewportWidth >= 640) {
    return { winW: 300, winH: 220, cascadeStep: 76, minWinW: 160, minWinH: 120, minStep: 32 };
  }
  return { winW: 240, winH: 180, cascadeStep: 60, minWinW: 140, minWinH: 108, minStep: 28 };
}

/** 标签栏浮在窗口上方，居中时需计入高度 */
const TABBAR_FLOAT_H = 30;
const CASCADE_WINDOW_IDS = ['w3', 'w2', 'w1'] as const;

function buildInitialState(): DemoState {
  const tier = getWindowSizeTier(1024);
  return {
    nextZ: 3,
    windows: {
      w3: {
        id: 'w3',
        title: '终端',
        app: 'terminal',
        groupId: 'g3',
        x: 0,
        y: 0,
        width: tier.winW,
        height: tier.winH,
        zIndex: 1,
      },
      w2: {
        id: 'w2',
        title: '备忘录',
        app: 'notes',
        groupId: 'g2',
        x: 0,
        y: 0,
        width: tier.winW,
        height: tier.winH,
        zIndex: 2,
      },
      w1: {
        id: 'w1',
        title: 'Safari',
        app: 'safari',
        groupId: 'g1',
        x: 0,
        y: 0,
        width: tier.winW,
        height: tier.winH,
        zIndex: 3,
      },
    },
    groups: {
      g1: { id: 'g1', windowIds: ['w1'], activeIndex: 0 },
      g2: { id: 'g2', windowIds: ['w2'], activeIndex: 0 },
      g3: { id: 'g3', windowIds: ['w3'], activeIndex: 0 },
    },
  };
}

/** 层叠窗口靠左排列，右侧预留给说明浮层；尺寸随 sm/md/lg/xl 分档 */
function layoutCascadeLeft(desktopWidth: number, desktopHeight: number) {
  const tier = getWindowSizeTier();
  const spanSteps = CASCADE_WINDOW_IDS.length - 1;
  const pad = 12;
  const copyPanel = $('#demo-section-copy');
  const panelW = copyPanel?.offsetWidth ?? desktopWidth * 0.28;
  const zoneGap = 20;
  const leftZoneW = desktopWidth - panelW - zoneGap - pad;
  const availW = Math.max(tier.minWinW, leftZoneW - pad);
  const availH = desktopHeight - TABBAR_FLOAT_H - pad * 2;

  let step = tier.cascadeStep;
  let winW = tier.winW;
  let winH = tier.winH;

  if (spanSteps * step + winW > availW) {
    winW = Math.max(tier.minWinW, availW - spanSteps * step);
  }
  if (spanSteps * step + winH > availH) {
    winH = Math.max(tier.minWinH, availH - spanSteps * step);
  }
  if (spanSteps * step + winW > availW || spanSteps * step + winH > availH) {
    step = Math.max(
      tier.minStep,
      Math.floor(
        Math.min(
          (availW - tier.minWinW) / spanSteps,
          (availH - tier.minWinH) / spanSteps,
        ),
      ),
    );
    winW = Math.max(tier.minWinW, availW - spanSteps * step);
    winH = Math.max(tier.minWinH, availH - spanSteps * step);
  } else {
    winW = Math.min(tier.winW, Math.max(tier.minWinW, availW - spanSteps * step));
    winH = Math.min(tier.winH, Math.max(tier.minWinH, availH - spanSteps * step));
  }

  for (const id of CASCADE_WINDOW_IDS) {
    state.windows[id].width = winW;
    state.windows[id].height = winH;
  }

  const span = spanSteps * step;
  const totalH = TABBAR_FLOAT_H + span + winH;
  const originX = pad;
  const originY = Math.max(pad, (desktopHeight - totalH) / 2);

  CASCADE_WINDOW_IDS.forEach((id, index) => {
    const d = step * index;
    state.windows[id].x = originX + d;
    state.windows[id].y = originY + d;
  });
}

const INITIAL: DemoState = buildInitialState();

let state: DemoState = structuredClone(INITIAL);

let dragGhost: HTMLElement | null = null;
let tabDrag: { windowId: string; startX: number; startY: number; dragging: boolean } | null = null;
let windowDrag: { groupId: string; startX: number; startY: number; origX: number; origY: number } | null = null;
let detachTimer: ReturnType<typeof setTimeout> | null = null;
let highlightedDropGroupId: string | null = null;
let dropHighlightEl: HTMLElement | null = null;
let lastDragPoint: { x: number; y: number } | null = null;

let guideActive = true;
let guideStyleEl: HTMLStyleElement | null = null;
let guideStepInterval: ReturnType<typeof setInterval> | null = null;

function $(sel: string, root: ParentNode = document) {
  return root.querySelector(sel) as HTMLElement | null;
}

function stopGuide() {
  if (!guideActive) return;
  guideActive = false;
  $('#demo-guide-cursor')?.classList.add('hidden');
  if (guideStepInterval) {
    clearInterval(guideStepInterval);
    guideStepInterval = null;
  }
}

function setGuideStep(step: number) {
  document.querySelectorAll('.demo-guide-step').forEach((el, i) => {
    el.classList.toggle('is-active', i === step);
  });
  const chip = $('#demo-guide-chip');
  if (chip) chip.textContent = step === 2 ? 'Safari' : '备忘录';
}

function guidePoint(rect: DOMRect, parent: DOMRect, fx = 0.5, fy = 0.5) {
  return {
    x: rect.left - parent.left + rect.width * fx,
    y: rect.top - parent.top + rect.height * fy,
  };
}

function updateGuideAnimation() {
  if (!guideActive) return;

  const desktop = $('#demo-desktop');
  const cursor = $('#demo-guide-cursor');
  if (!desktop || !cursor) return;

  const notesTab = desktop.querySelector('[data-group-id="g2"] .demo-tab') as HTMLElement | null;
  const safariWin = desktop.querySelector('[data-group-id="g1"] .demo-window') as HTMLElement | null;
  const safariTab = desktop.querySelector('[data-group-id="g1"] .demo-tab') as HTMLElement | null;
  if (!notesTab || !safariWin) return;

  const dRect = desktop.getBoundingClientRect();
  const p0 = guidePoint(notesTab.getBoundingClientRect(), dRect);
  const p1 = guidePoint(safariWin.getBoundingClientRect(), dRect, 0.5, 0.42);
  const p2 = safariTab ? guidePoint(safariTab.getBoundingClientRect(), dRect) : p1;

  if (!guideStyleEl) {
    guideStyleEl = document.createElement('style');
    guideStyleEl.id = 'demo-guide-keyframes';
    document.head.appendChild(guideStyleEl);
  }

  guideStyleEl.textContent = `
    @keyframes demo-guide-path {
      0%, 10% { left: ${p0.x}px; top: ${p0.y}px; opacity: 0; }
      16%, 30% { left: ${p0.x}px; top: ${p0.y}px; opacity: 1; }
      50% { left: ${p1.x}px; top: ${p1.y}px; opacity: 1; }
      58%, 72% { left: ${p1.x}px; top: ${p1.y}px; opacity: 1; }
      82%, 92% { left: ${p2.x}px; top: ${p2.y}px; opacity: 1; }
      100% { left: ${p2.x}px; top: ${p2.y}px; opacity: 0; }
    }
  `;

  cursor.classList.remove('hidden');
  cursor.style.animation = 'none';
  void cursor.offsetWidth;
  cursor.style.animation = 'demo-guide-path 4.8s ease-in-out infinite';

  if (!guideStepInterval) {
    let step = 0;
    setGuideStep(0);
    guideStepInterval = setInterval(() => {
      if (!guideActive) return;
      step = (step + 1) % 3;
      setGuideStep(step);
    }, 1600);
  }
}

function getActiveWindowId(groupId: string) {
  const group = state.groups[groupId];
  return group.windowIds[group.activeIndex];
}

function getGroupSlot(groupId: string): GroupSlot {
  const activeId = getActiveWindowId(groupId);
  const win = state.windows[activeId];
  return { x: win.x, y: win.y, width: win.width, height: win.height };
}

/** 组内共享槽位：默认 matchCurrent，位置与尺寸与当前 active 窗一致 */
function syncGroupSlot(groupId: string, slot: Partial<GroupSlot>) {
  const current = getGroupSlot(groupId);
  const merged: GroupSlot = { ...current, ...slot };
  for (const wid of state.groups[groupId].windowIds) {
    const w = state.windows[wid];
    w.x = merged.x;
    w.y = merged.y;
    w.width = merged.width;
    w.height = merged.height;
  }
}

function bringGroupToFront(groupId: string) {
  state.nextZ += 1;
  const z = state.nextZ;
  for (const wid of state.groups[groupId].windowIds) {
    state.windows[wid].zIndex = z;
  }
}

/** 对齐 handleActivate + switchTargetFrame(matchCurrent) */
function activateTab(groupId: string, windowId: string) {
  const group = state.groups[groupId];
  const idx = group.windowIds.indexOf(windowId);
  if (idx < 0 || idx === group.activeIndex) return;

  const slot = getGroupSlot(groupId);
  group.activeIndex = idx;
  syncGroupSlot(groupId, slot);
  bringGroupToFront(groupId);
  render();
}

/** 对齐 GroupStore.merge + handleDrop：拖入目标窗口主体合并，源窗变为 active */
function mergeIntoWindow(sourceWindowId: string, targetGroupId: string) {
  const sourceWin = state.windows[sourceWindowId];
  const sourceGroupId = sourceWin.groupId;
  if (sourceGroupId === targetGroupId) return;

  const sourceGroup = state.groups[sourceGroupId];
  const targetGroup = state.groups[targetGroupId];
  const slot = getGroupSlot(targetGroupId);

  const srcIdx = sourceGroup.windowIds.indexOf(sourceWindowId);
  sourceGroup.windowIds.splice(srcIdx, 1);

  if (sourceGroup.windowIds.length === 0) {
    delete state.groups[sourceGroupId];
  } else if (sourceGroup.activeIndex >= sourceGroup.windowIds.length) {
    sourceGroup.activeIndex = sourceGroup.windowIds.length - 1;
  } else if (srcIdx < sourceGroup.activeIndex) {
    sourceGroup.activeIndex -= 1;
  }

  if (!targetGroup.windowIds.includes(sourceWindowId)) {
    targetGroup.windowIds.push(sourceWindowId);
  }
  targetGroup.activeIndex = targetGroup.windowIds.indexOf(sourceWindowId);
  sourceWin.groupId = targetGroupId;
  syncGroupSlot(targetGroupId, slot);

  bringGroupToFront(targetGroupId);
  render();
}

/** 对齐 GroupStore.detach + detachFromGroup */
function detachFromGroup(sourceWindowId: string, screenX: number, screenY: number) {
  const sourceGroupId = state.windows[sourceWindowId].groupId;
  const sourceGroup = state.groups[sourceGroupId];
  if (sourceGroup.windowIds.length <= 1) return;

  const srcIdx = sourceGroup.windowIds.indexOf(sourceWindowId);
  const wasActive = srcIdx === sourceGroup.activeIndex;
  sourceGroup.windowIds.splice(srcIdx, 1);

  if (wasActive) {
    sourceGroup.activeIndex = Math.min(srcIdx, sourceGroup.windowIds.length - 1);
  } else if (srcIdx < sourceGroup.activeIndex) {
    sourceGroup.activeIndex -= 1;
  }

  const newGroupId = `g${Date.now()}`;
  state.groups[newGroupId] = { id: newGroupId, windowIds: [sourceWindowId], activeIndex: 0 };

  const win = state.windows[sourceWindowId];
  win.groupId = newGroupId;

  const desktop = $('#demo-desktop');
  const desktopRect = desktop?.getBoundingClientRect();
  const offsetX = desktopRect?.left ?? 0;
  const offsetY = desktopRect?.top ?? 0;
  win.x = Math.max(12, screenX - offsetX - win.width / 2);
  win.y = Math.max(12, screenY - offsetY - 24);

  bringGroupToFront(newGroupId);
  render();
}

function rectContainsPoint(el: Element | null, x: number, y: number, pad = 0) {
  if (!el) return false;
  const r = el.getBoundingClientRect();
  return x >= r.left - pad && x <= r.right + pad && y >= r.top - pad && y <= r.bottom + pad;
}

/** 命中检测：优先 DOM 层叠，再按 z-index 几何回退（处理窗口遮挡） */
function getTargetGroupAtPoint(x: number, y: number): string | null {
  const elements = document.elementsFromPoint(x, y);
  for (const el of elements) {
    const node = el as HTMLElement;
    if (node.closest('.demo-drag-ghost') || node.closest('.demo-drop-highlight')) continue;
    if (node.closest('.demo-section-copy')) continue;

    const tabbar = node.closest('.demo-tabbar') as HTMLElement | null;
    if (tabbar?.dataset.groupId) return tabbar.dataset.groupId;

    const groupEl = node.closest('.demo-window-group:not(.hidden-in-group)') as HTMLElement | null;
    if (groupEl?.dataset.groupId && node.closest('.demo-window')) {
      return groupEl.dataset.groupId;
    }
  }

  const visibleGroups = Object.values(state.groups)
    .map((group) => {
      const activeId = group.windowIds[group.activeIndex];
      const win = state.windows[activeId];
      return { groupId: group.id, zIndex: win.zIndex };
    })
    .sort((a, b) => b.zIndex - a.zIndex);

  for (const { groupId } of visibleGroups) {
    const groupEl = document.querySelector(
      `.demo-window-group[data-group-id="${groupId}"]:not(.hidden-in-group)`,
    );
    if (!groupEl) continue;
    if (
      rectContainsPoint(groupEl.querySelector('.demo-window'), x, y) ||
      rectContainsPoint(groupEl.querySelector('.demo-tabbar-float'), x, y, 4)
    ) {
      return groupId;
    }
  }
  return null;
}

function isPointOverSourceGroup(sourceGroupId: string, x: number, y: number) {
  const groupEl = document.querySelector(
    `.demo-window-group[data-group-id="${sourceGroupId}"]:not(.hidden-in-group)`,
  );
  if (!groupEl) return false;
  const pad = 8;
  return (
    rectContainsPoint(groupEl.querySelector('.demo-tabbar-float'), x, y, pad) ||
    rectContainsPoint(groupEl.querySelector('.demo-window'), x, y, pad)
  );
}

function isInsideSourceDragRegion(sourceWindowId: string, x: number, y: number) {
  const sourceGroupId = state.windows[sourceWindowId].groupId;
  const topGroup = getTargetGroupAtPoint(x, y);
  // 光标处若有更高层窗口遮挡，视为已离开源窗口区域
  if (topGroup && topGroup !== sourceGroupId) return false;
  if (!topGroup) return false;
  return isPointOverSourceGroup(sourceGroupId, x, y);
}

/** 对齐 dropTarget：命中最上层窗口主体（遮挡区域以 z-index 为准） */
function findDropTarget(x: number, y: number, sourceWindowId: string) {
  const sourceGroupId = state.windows[sourceWindowId].groupId;
  const hit = getTargetGroupAtPoint(x, y);
  if (!hit || hit === sourceGroupId) return null;
  return { groupId: hit };
}

/** 对齐 WindowDropHighlightView 蓝色窗口高亮 */
function clearDropHighlight() {
  dropHighlightEl?.remove();
  dropHighlightEl = null;
  highlightedDropGroupId = null;
}

function showDropHighlight(targetGroupId: string) {
  if (highlightedDropGroupId === targetGroupId) return;
  clearDropHighlight();

  const winEl = document.querySelector(
    `.demo-window-group[data-group-id="${targetGroupId}"]:not(.hidden-in-group) .demo-window`,
  ) as HTMLElement | null;
  if (!winEl) return;

  highlightedDropGroupId = targetGroupId;
  const overlay = document.createElement('div');
  overlay.className = 'demo-drop-highlight';
  winEl.appendChild(overlay);
  dropHighlightEl = overlay;
}

function updateDragFeedback(x: number, y: number, sourceWindowId: string) {
  cancelDetachTimer();

  const target = findDropTarget(x, y, sourceWindowId);
  if (target) {
    showDropHighlight(target.groupId);
    return;
  }

  clearDropHighlight();

  if (isInsideSourceDragRegion(sourceWindowId, x, y)) return;

  const sourceGroup = state.groups[state.windows[sourceWindowId].groupId];
  if (sourceGroup.windowIds.length > 1) {
    scheduleDetach(sourceWindowId);
  }
}

function cancelDetachTimer() {
  if (detachTimer) {
    clearTimeout(detachTimer);
    detachTimer = null;
  }
}

function scheduleDetach(sourceWindowId: string) {
  cancelDetachTimer();
  detachTimer = setTimeout(() => {
    if (!tabDrag?.dragging || !lastDragPoint) return;
    const { x, y } = lastDragPoint;
    if (isInsideSourceDragRegion(sourceWindowId, x, y)) return;
    if (findDropTarget(x, y, sourceWindowId)) return;
    detachFromGroup(sourceWindowId, x, y);
    cleanupTabDrag();
  }, DETACH_DELAY_MS);
}

function windowContentHtml(win: DemoWindow): string {
  return `<div class="demo-content-placeholder" data-app="${win.app}"></div>`;
}

function renderTabBar(groupId: string): string {
  const group = state.groups[groupId];
  if (!group || group.windowIds.length === 0) return '';

  const tabs = group.windowIds
    .map((wid) => {
      const win = state.windows[wid];
      const isActive = wid === group.windowIds[group.activeIndex];
      return `<div class="demo-tab${isActive ? ' active' : ''}" data-window-id="${wid}" data-group-id="${groupId}">${win.title}</div>`;
    })
    .join('');

  return `<div class="demo-tabbar-float"><div class="demo-tabbar" data-group-id="${groupId}">${tabs}</div></div>`;
}

function render() {
  const desktop = $('#demo-desktop');
  if (!desktop) return;

  desktop.innerHTML = '';
  clearDropHighlight();

  const sorted = Object.values(state.windows).sort((a, b) => a.zIndex - b.zIndex);

  for (const win of sorted) {
    const group = state.groups[win.groupId];
    const isActiveInGroup = getActiveWindowId(win.groupId) === win.id;
    const slot = getGroupSlot(win.groupId);
    const isFocused = win.zIndex === state.nextZ;

    const el = document.createElement('div');
    el.className = `demo-window-group${!isActiveInGroup ? ' hidden-in-group' : ''}`;
    el.dataset.windowId = win.id;
    el.dataset.groupId = win.groupId;
    el.style.cssText = `left:${slot.x}px;top:${slot.y}px;width:${slot.width}px;z-index:${win.zIndex}`;

    el.innerHTML = `
      ${renderTabBar(win.groupId)}
      <div class="demo-window${isFocused ? ' focused' : ''}" style="height:${slot.height}px">
        <div class="demo-titlebar" data-group-id="${win.groupId}">
          <div class="demo-titlebar-top">
            <div class="demo-traffic">
              <span class="close"></span>
              <span class="minimize"></span>
              <span class="maximize"></span>
            </div>
            <div class="demo-window-title">${win.title}</div>
          </div>
        </div>
        <div class="demo-content">${windowContentHtml(win)}</div>
      </div>
    `;

    desktop.appendChild(el);
  }

  bindWindowEvents();
  if (guideActive) updateGuideAnimation();
}

function bindWindowEvents() {
  document.querySelectorAll('.demo-tab').forEach((tab) => {
    tab.addEventListener('mousedown', onTabMouseDown);
  });

  document.querySelectorAll('.demo-titlebar').forEach((bar) => {
    bar.addEventListener('mousedown', onTitlebarMouseDown);
  });

  document.querySelectorAll('.demo-window-group').forEach((groupEl) => {
    groupEl.addEventListener('mousedown', (e) => {
      const target = e.target as HTMLElement;
      if (target.closest('.demo-tab')) return;
      const gid = (groupEl as HTMLElement).dataset.groupId!;
      bringGroupToFront(gid);
      render();
    });
  });
}

function cleanupTabDrag() {
  dragGhost?.remove();
  dragGhost = null;
  lastDragPoint = null;
  clearDropHighlight();
  cancelDetachTimer();
  document.querySelectorAll('.demo-tab.dragging').forEach((t) => t.classList.remove('dragging'));
  tabDrag = null;
}

function onTabMouseDown(e: MouseEvent) {
  if (e.button !== 0) return;
  stopGuide();
  e.stopPropagation();
  const tab = e.currentTarget as HTMLElement;
  const windowId = tab.dataset.windowId!;
  tabDrag = { windowId, startX: e.clientX, startY: e.clientY, dragging: false };

  const onMove = (ev: MouseEvent) => {
    if (!tabDrag) return;
    const dx = ev.clientX - tabDrag.startX;
    const dy = ev.clientY - tabDrag.startY;

    if (!tabDrag.dragging && Math.hypot(dx, dy) >= DRAG_THRESHOLD) {
      tabDrag.dragging = true;
      const win = state.windows[tabDrag.windowId];
      dragGhost = document.createElement('div');
      dragGhost.className = 'demo-drag-ghost';
      dragGhost.textContent = win.title;
      document.body.appendChild(dragGhost);
      tab.classList.add('dragging');
    }

    if (tabDrag.dragging && dragGhost) {
      lastDragPoint = { x: ev.clientX, y: ev.clientY };
      dragGhost.style.left = `${ev.clientX}px`;
      dragGhost.style.top = `${ev.clientY}px`;
      updateDragFeedback(ev.clientX, ev.clientY, tabDrag.windowId);
    }
  };

  const onUp = (ev: MouseEvent) => {
    document.removeEventListener('mousemove', onMove);
    document.removeEventListener('mouseup', onUp);
    cancelDetachTimer();

    if (tabDrag?.dragging) {
      const target = findDropTarget(ev.clientX, ev.clientY, tabDrag.windowId);
      if (target) {
        mergeIntoWindow(tabDrag.windowId, target.groupId);
      }
      cleanupTabDrag();
    } else if (tabDrag) {
      activateTab(tab.dataset.groupId!, tabDrag.windowId);
      tabDrag = null;
    }
  };

  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
}

function onTitlebarMouseDown(e: MouseEvent) {
  const target = e.target as HTMLElement;
  if (target.closest('.demo-traffic')) return;
  if (e.button !== 0) return;
  stopGuide();

  const bar = e.currentTarget as HTMLElement;
  const groupId = bar.dataset.groupId!;
  bringGroupToFront(groupId);

  const pos = getGroupSlot(groupId);
  windowDrag = { groupId, startX: e.clientX, startY: e.clientY, origX: pos.x, origY: pos.y };

  const onMove = (ev: MouseEvent) => {
    if (!windowDrag) return;
    const nx = windowDrag.origX + ev.clientX - windowDrag.startX;
    const ny = windowDrag.origY + ev.clientY - windowDrag.startY;
    syncGroupSlot(windowDrag.groupId, { x: nx, y: ny });
    render();
  };

  const onUp = () => {
    document.removeEventListener('mousemove', onMove);
    document.removeEventListener('mouseup', onUp);
    windowDrag = null;
  };

  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
  e.preventDefault();
}

const NARROW_PORTRAIT_MQ = '(max-width: 639px) and (orientation: portrait)';

function isDemoViewportAvailable() {
  return typeof window === 'undefined' || !window.matchMedia(NARROW_PORTRAIT_MQ).matches;
}

let demoBooted = false;

export function initDemo() {
  const mq = typeof window !== 'undefined' ? window.matchMedia(NARROW_PORTRAIT_MQ) : null;

  const boot = () => {
    if (!isDemoViewportAvailable()) return;
    if (demoBooted) return;
    demoBooted = true;

    state = structuredClone(INITIAL);
    const desktop = $('#demo-desktop');
    const root = $('#demo-root');

    const applyLayout = () => {
      if (!desktop) return;
      const { width, height } = desktop.getBoundingClientRect();
      if (width > 0 && height > 0) {
        layoutCascadeLeft(width, height);
        render();
      }
    };

    applyLayout();

    if (root && typeof ResizeObserver !== 'undefined') {
      new ResizeObserver(applyLayout).observe(root);
    }
    $('#demo-section-copy') &&
      typeof ResizeObserver !== 'undefined' &&
      new ResizeObserver(applyLayout).observe($('#demo-section-copy')!);

    window.addEventListener('resize', applyLayout, { passive: true });

    root?.addEventListener('mousedown', stopGuide, { once: true });
  };

  boot();
  mq?.addEventListener('change', boot);
}

if (typeof document !== 'undefined') {
  document.addEventListener('DOMContentLoaded', initDemo);
}
