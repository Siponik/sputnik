// Анимации интерфейса (docs/design-v2.md — «Анимации интерфейса»): общие пресеты для Svelte-переходов
// и View Transitions. Уровень — настройка settings.motion: full | min | off. При «уменьшении движения» в системе
// full работает как min. min — без сдвигов и масштаба, только короткие (≤ 120 мс) затухания; off — без анимаций.
// Уровень дублируется в <html data-motion="…">, чтобы CSS-анимации подчинялись тому же правилу.
import { crossfade as svelteCrossfade } from 'svelte/transition';
import { cubicOut } from 'svelte/easing';

export const LEVELS = [
  { id: 'full', name: 'полные' },
  { id: 'min', name: 'минимум' },
  { id: 'off', name: 'выкл' },
];

let chosen = 'full';
const reducedQuery = typeof matchMedia === 'function' ? matchMedia('(prefers-reduced-motion: reduce)') : null;

/** Действующий уровень с учётом системной настройки. */
export function level() {
  if (chosen === 'off') return 'off';
  if (chosen === 'min' || reducedQuery?.matches) return 'min';
  return 'full';
}
function apply() { if (typeof document !== 'undefined') document.documentElement.dataset.motion = level(); }
reducedQuery?.addEventListener?.('change', apply);

export function setMotion(v) {
  chosen = LEVELS.some((l) => l.id === v) ? v : 'full';
  apply();
}
apply();

// Кривые из токенов (--ease-out / --ease-in / --ease-pop) — для JS-переходов те же формы.
const bezier = (x1, y1, x2, y2) => {
  // Решение кубической Безье для t по x (метод Ньютона, как в CSS).
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
  const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  const sx = (t) => ((ax * t + bx) * t + cx) * t;
  const sy = (t) => ((ay * t + by) * t + cy) * t;
  const dx = (t) => (3 * ax * t + 2 * bx) * t + cx;
  return (x) => {
    let t = x;
    for (let i = 0; i < 6; i++) { const d = dx(t); if (Math.abs(d) < 1e-6) break; t -= (sx(t) - x) / d; }
    return sy(Math.min(1, Math.max(0, t)));
  };
};
export const easeOut = bezier(0.2, 0.8, 0.2, 1);
export const easeIn = bezier(0.4, 0, 1, 1);
export const easePop = bezier(0.3, 1.4, 0.5, 1);

const base = (node) => {
  const s = getComputedStyle(node);
  return { opacity: +s.opacity, transform: s.transform === 'none' ? '' : s.transform };
};
/** Уход быстрее появления (~0,7×); min — только короткое затухание; off — ничего. */
function tune(duration, opts) {
  const lv = level();
  if (lv === 'off') return { off: true, duration: 0 };
  const d = opts?.out ? Math.round(duration * 0.7) : duration;
  return { min: lv === 'min', duration: lv === 'min' ? Math.min(120, d) : d };
}

/** Сдвиг + затухание: { x, y, duration, delay, out }. */
export function fly(node, { x = 0, y = 0, duration = 220, delay = 0, out = false } = {}) {
  const t = tune(duration, { out });
  if (t.off) return { duration: 0 };
  const { opacity, transform } = base(node);
  return {
    delay: t.min ? 0 : delay,
    duration: t.duration,
    easing: out ? easeIn : easeOut,
    css: (k, u) => (t.min ? `opacity: ${k * opacity}` : `opacity: ${k * opacity}; transform: ${transform} translate(${u * x}px, ${u * y}px)`),
  };
}

/** Затухание. */
export function fade(node, { duration = 160, delay = 0, out = false } = {}) {
  const t = tune(duration, { out });
  if (t.off) return { duration: 0 };
  const { opacity } = base(node);
  return { delay: t.min ? 0 : delay, duration: t.duration, easing: out ? easeIn : easeOut, css: (k) => `opacity: ${k * opacity}` };
}

/** Поповеры и меню: scale .96 → 1 + затухание от точки привязки (transform-origin задаётся стилем элемента). */
export function pop(node, { duration = 160, start = 0.96, out = false } = {}) {
  const t = tune(out ? 140 : duration, { out });
  if (t.off) return { duration: 0 };
  const { opacity, transform } = base(node);
  return {
    duration: t.duration,
    easing: out ? easeIn : easeOut,
    css: (k, u) => (t.min ? `opacity: ${k * opacity}` : `opacity: ${k * opacity}; transform: ${transform} scale(${1 - u * (1 - start)})`),
  };
}

/** Раскрытие по высоте (строка Конвейера): высота 0 → своя, 240 мс; сворачивание быстрее. */
export function expand(node, { duration = 240, out = false } = {}) {
  const t = tune(out ? 180 / 0.7 : duration, { out });
  if (t.off) return { duration: 0 };
  if (t.min) return { duration: t.duration, css: (k) => `opacity: ${k}` };
  const s = getComputedStyle(node);
  const h = node.offsetHeight, pt = parseFloat(s.paddingTop), pb = parseFloat(s.paddingBottom);
  return {
    duration: t.duration,
    easing: out ? easeIn : easeOut,
    css: (k) => `overflow: hidden; height: ${k * h}px; padding-top: ${k * pt}px; padding-bottom: ${k * pb}px; opacity: ${Math.min(1, k * 1.6)}`,
  };
}

/** Перелёт карточки между колонками (send/receive); новая карточка без пары — сдвиг сверху и подсветка. */
export function cardCrossfade() {
  return svelteCrossfade({
    duration: () => (level() === 'full' ? 260 : 0),
    easing: cubicOut,
    fallback: (node) => {
      if (level() !== 'full') return { duration: 0 };
      return { duration: 220, easing: easeOut, css: (k, u) => `opacity: ${k}; transform: translateY(${-8 * u}px)` };
    },
  });
}

/** Длительность для animate:flip — 0, если движение выключено или «минимум». */
export const flipMs = () => (level() === 'full' ? 220 : 0);

/**
 * Смена экрана через View Transitions API: старый гаснет 120 мс, новый приходит со сдвигом 12 px со стороны
 * направления (dir: 1 — вперёд по вкладкам, -1 — назад), 220 мс. Без поддержки или при «выкл» — сразу.
 * update — функция, меняющая состояние (внутри вызывается flushSync).
 */
export function viewTransition(update, dir = 1) {
  const lv = level();
  if (lv === 'off' || typeof document === 'undefined' || !document.startViewTransition) { update(); return; }
  document.documentElement.dataset.vtDir = dir < 0 ? 'back' : 'fwd';
  // Ввод не ждёт анимацию: если переход пропущен (окно скрыто, начался другой) — состояние меняем всё равно, один раз.
  let done = false;
  const run = () => { if (!done) { done = true; update(); } };
  try {
    const t = document.startViewTransition(run);
    t.updateCallbackDone?.catch(run);
    t.ready?.catch(() => {});
    t.finished?.catch(() => {});
  } catch { run(); }
  setTimeout(run, 300);
}
