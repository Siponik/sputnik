// Шапка 0.6, «Состояние», обновления, левая колонка и настройки — чистая логика (тесты: tests/shell.test.js).
// Спецификация — docs/design-v2.md, раздел «Шапка, левая колонка доски, «Состояние», обновления и настройки».

export const hm = (d) => (d ? new Date(d).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) : '');

/**
 * Три точки «Состояния»: Google, между компьютерами, версия. Цвет: '' — всё хорошо (бирюзовая), 'w' — нужно действие
 * (золотая), 'e' — ошибка (красная); busy — идёт обмен (точка пульсирует).
 * sync = { busy, err, at }, offline — нет связи; cloud = { state: idle|busy|ok|login|err }; upd = { found, err }.
 */
export function statusDots({ sync, offline = false, cloud, upd }) {
  const g = { c: sync.err ? 'e' : '', busy: !!sync.busy };
  const l = { c: cloud.state === 'login' ? 'w' : cloud.state === 'err' ? 'e' : '', busy: cloud.state === 'busy' };
  const v = { c: upd.found ? 'w' : upd.err ? 'e' : '', busy: !!upd.busy };
  let label = hm(sync.at);
  if (offline) label = 'Нет связи';
  else if (cloud.state === 'login') label = 'Нужен вход';
  else if (sync.err) label = 'Ошибка';
  return { dots: [g, l, v], label };
}

/** Подпись строки «Google Задачи и Календарь» в «Состоянии». */
export function googleLine(sync, offline = false) {
  if (sync.busy) return { text: 'обновляю…', cls: '' };
  if (offline) return { text: 'нет связи — повторю через минуту', cls: 'e' };
  if (sync.err) return { text: sync.err, cls: 'e' };
  if (!sync.at) return { text: 'ещё не обновлялось', cls: '' };
  return { text: `обновлено в ${hm(sync.at)} · раз в 2 минуты`, cls: 'ok' };
}

/** Подпись строки «Между компьютерами». */
export function cloudLine(cloud) {
  if (cloud.state === 'login') return { text: 'нужно разрешить скрытую папку на Drive', cls: 'w' };
  if (cloud.state === 'err') return { text: cloud.err || 'не удалось синхронизировать', cls: 'e' };
  if (cloud.state === 'busy') return { text: 'синхронизирую…', cls: '' };
  if (cloud.state === 'ok' && cloud.at) return { text: `синхронизировано в ${hm(cloud.at)}`, cls: 'ok' };
  return { text: 'ещё не синхронизировано', cls: '' };
}

/** Подпись строки «Спутник <версия>». upd = { found, err, busy, progress, checkedAt }. */
export function versionLine(upd) {
  if (upd.busy) return { text: `ставлю ${upd.found?.version ?? ''} · ${Math.round((upd.progress || 0) * 100)}%`, cls: 'w' };
  if (upd.found) return { text: `вышла ${upd.found.version} · меньше минуты`, cls: 'c' };
  if (upd.err) return { text: upd.err, cls: 'e' };
  if (upd.checkedAt) return { text: `последняя версия · проверено в ${hm(upd.checkedAt)}`, cls: 'ok' };
  return { text: 'обновления проверяются сами', cls: '' };
}

/** Подпись строки «Напоминания в Telegram». rem = { at, n, err }. */
export function remindLine(rem) {
  if (rem?.err) return { text: rem.err, cls: 'e' };
  if (!rem?.at) return { text: 'файл ещё не обновлялся', cls: '' };
  return { text: `файл обновлён ${hm(rem.at)} · ${rem.n} впереди`, cls: 'ok' };
}

/** «Что нового»: первые n пунктов списка из заметки релиза (строки «- …», «* …», «• …»; иначе — строки как есть). */
export function notesOf(text, n = 3) {
  const lines = String(text ?? '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  const items = lines.filter((s) => /^[-*•✦]\s+/.test(s)).map((s) => s.replace(/^[-*•✦]\s+/, ''));
  return (items.length ? items : lines).slice(0, n);
}

/**
 * Показывать ли чип обновления в шапке: есть версия, она не пропущена и «Вечером» ещё не наступило.
 * pref = settings.update = { skip: '0.6.3', remindAt: <мс> }.
 */
export function showUpdChip(found, pref = {}, now = Date.now()) {
  if (!found) return false;
  if (pref.skip && pref.skip === found.version) return false;
  if (pref.remindAt && now < pref.remindAt) return false;
  return true;
}

/** «Вечером» — сегодня в 20:00, а если уже позже — завтра в 20:00. */
export function eveningAt(now = new Date()) {
  const d = new Date(now);
  d.setHours(20, 0, 0, 0);
  if (d <= now) d.setDate(d.getDate() + 1);
  return d.getTime();
}

/** Ночная установка: включена и сейчас 3:00–3:59. */
export const nightNow = (pref = {}, now = new Date()) => !!pref.night && now.getHours() === 3;
