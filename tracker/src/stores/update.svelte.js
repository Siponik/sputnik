// Обновление из приложения (tauri-plugin-updater, lib/updater.js): проверка через 30 с после запуска и раз в 6 ч,
// «Ставить ночью» — в 3:00, если компьютер не спит. Чип «✦ Версия …» в шапке и строки в «Состоянии» и Настройках
// читают upd отсюда. settings.update = { skip, remindAt, auto, night, beta } — в слое.
import * as updater from '../lib/updater.js';
import * as shell from '../lib/shell.js';
import { layer, touch, save } from './layer.svelte.js';
import { say } from './toast.svelte.js';

/** version — текущая; found — вышедшая версия (null — нет); busy/progress — идёт установка; err/note — для ручной проверки. */
export const upd = $state({ version: '', found: null, busy: false, progress: 0, err: '', fail: '', note: '', checkedAt: null });

const pref = () => layer.data.settings?.update ?? {};

export async function check(manual = false) {
  if (upd.busy) return;
  upd.err = '';
  upd.note = manual ? 'Проверяю…' : '';
  try {
    upd.found = await updater.findUpdate(!!pref().beta); // бета-канал — только у владельца
    upd.checkedAt = new Date();
    upd.note = manual && !upd.found ? 'У тебя последняя версия.' : '';
  } catch (e) {
    upd.note = '';
    if (manual) upd.err = 'Не удалось проверить обновления: ' + e;
  }
}

export async function install() {
  if (!upd.found || upd.busy) return;
  upd.busy = true;
  upd.err = ''; upd.fail = '';
  upd.progress = 0;
  try { await updater.install(upd.found, (p) => (upd.progress = p)); }
  catch (e) { upd.fail = 'Не удалось обновиться: ' + e; upd.busy = false; }
}

/** «Вечером» — напомнить в 20:00. */
export function later() { touch('settings', 'update', { remindAt: shell.eveningAt() }); save(); say('Напомню про обновление вечером, в 20:00'); }
/** «Пропустить» — не показывать чип для этой версии (точка «версия» в «Состоянии» остаётся). */
export function skip() { touch('settings', 'update', { skip: upd.found.version, remindAt: null }); save(); say(`Версию ${upd.found.version} пропускаю — поставить можно в «Состоянии»`); }

/** Канал сменился (бета вкл/выкл) — проверить сразу. */
export function recheck() { upd.found = null; check(true); }

/** Раз в минуту из App: «Ставить ночью». */
export function minute() { if (upd.found && !upd.busy && shell.nightNow(pref())) install(); }

/** Проверки по расписанию; «Проверять самому» (settings.update.auto) выключено — только вручную. Возвращает остановку. */
export function start() {
  updater.currentVersion().then((v) => (upd.version = v));
  const auto = () => { if (pref().auto !== false) check(); };
  const first = setTimeout(auto, import.meta.env.MODE === 'demo' ? 1500 : 30e3); // в демо — сразу
  const every = setInterval(auto, 6 * 3600e3);
  return () => { clearTimeout(first); clearInterval(every); };
}
