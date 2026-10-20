// Учёт времени по задаче. В слое: tasks[id].spent — минут уже набрано, tasks[id].timer = { start } — идёт сейчас.
// Таймер живёт в слое, поэтому переживает перезапуск трекера (и через синхронизацию слоя виден на другом компьютере).
// Идёт не больше одного таймера: запуск другого останавливает текущий.

const MAX_RUN_MS = 12 * 3600e3; // забыли выключить на ночь — больше 12 ч за раз не засчитываем

/** Сколько минут набрано вместе с идущим таймером. */
export function spentMin(L, now = Date.now()) {
  const run = L?.timer?.start ? Math.min(Math.max(0, now - L.timer.start), MAX_RUN_MS) : 0;
  return (L?.spent ?? 0) + run / 60e3;
}

/** Id задачи, у которой идёт таймер, или null. */
export function runningId(layTasks) {
  let best = null;
  for (const [id, L] of Object.entries(layTasks ?? {})) {
    if (L?.timer?.start && (!best || L.timer.start > layTasks[best].timer.start)) best = id;
  }
  return best;
}

/** Патчи слоя: [[id, patch], …]: остановить всё, что идёт; если у id таймер не шёл — запустить его. */
export function toggle(layTasks, id, now = Date.now()) {
  const out = [];
  const wasRunning = !!layTasks?.[id]?.timer?.start;
  for (const [tid, L] of Object.entries(layTasks ?? {})) {
    if (L?.timer?.start) out.push([tid, stopPatch(L, now)]);
  }
  if (!wasRunning) out.push([id, { timer: { start: now } }]);
  return out;
}

/** Остановить таймер задачи (если идёт): набранное переходит в spent. */
export function stopPatch(L, now = Date.now()) {
  return { spent: Math.round(spentMin(L, now) * 10) / 10, timer: null };
}

/** «1 ч 05 мин», «12 мин», «меньше минуты». */
export function fmtMin(min) {
  const m = Math.floor(min);
  if (m < 1) return 'меньше минуты';
  const h = Math.floor(m / 60);
  return h ? `${h} ч ${String(m % 60).padStart(2, '0')} мин` : `${m} мин`;
}

/** Часы на шапке: «0:12:07». */
export function clock(ms) {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}
