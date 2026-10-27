// Обмен с Google: один цикл за раз, раз в 2 минуты, по фокусу окна (если прошло больше 30 с) и через минуту,
// пока нет связи. Что именно забирать, решает App (configure({ pull })) — стор следит за порядком,
// состоянием (для точек «Состояния») и ошибками.
import * as api from '../lib/api.js';
import { say } from './toast.svelte.js';

/** busy — идёт обмен; err — последняя ошибка; at — время удачного обмена; flash — короткая вспышка точки по окончании. */
export const sync = $state({ busy: false, err: '', at: null, flash: false });

let hooks = { pull: async () => {}, ready: () => false, onAuthLost: async () => {} };
export function configure(h) { hooks = { ...hooks, ...h }; }

/** Нет связи с Google (а не другая ошибка). */
export const offline = () => !!sync.err && api.isOffline(sync.err);

let retryTimer;
export async function refresh() {
  if (sync.busy) return;
  sync.busy = true;
  sync.err = '';
  try {
    await hooks.pull();
    sync.at = new Date();
  } catch (e) {
    sync.err = String(e);
    if (/войдите|sign in|invalid_grant/i.test(sync.err)) await hooks.onAuthLost();
    else if (!api.isOffline(e)) say('Не удалось обновить: ' + e);
  } finally {
    sync.busy = false;
    if (!sync.err) { sync.flash = true; setTimeout(() => (sync.flash = false), 650); }
    // Нет связи — пробуем снова через минуту.
    clearTimeout(retryTimer);
    if (offline()) retryTimer = setTimeout(() => { if (hooks.ready()) refresh(); }, 60e3);
  }
}

/** Опрос раз в 2 мин и по фокусу окна; возвращает функцию остановки. */
export function start() {
  const timer = setInterval(() => { if (hooks.ready()) refresh(); }, 120000);
  const onFocus = () => { if (hooks.ready() && (!sync.at || Date.now() - sync.at > 30000)) refresh(); };
  window.addEventListener('focus', onFocus);
  return () => { clearInterval(timer); clearTimeout(retryTimer); window.removeEventListener('focus', onFocus); };
}
