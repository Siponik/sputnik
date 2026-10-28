// Окно задачи v2 (lib/TaskDrawer.svelte): чистые расчёты — сколько задач в колонках (для «3/3»), как показать
// этап (чипы / выпадающий список / дорожка), подписи напоминаний и когда «▸ Ещё» открыто сразу.
// Дизайн — docs/design-v2.md, «Окно задачи v2 и выпадающие списки»; макеты design/screens/TaskPanel*.dc.html.
import { BEFORE, LEADS, rulesOf } from './reminders.js';

/** Открытые задачи верхнего уровня по колонкам: { colId: n }. Колонка — из слоя (status), иначе первая. */
export function colCounts(listTasks = [], cols = [], layTasks = {}) {
  const n = Object.fromEntries(cols.map((c) => [c.id, 0]));
  if (!cols.length) return n;
  for (const t of listTasks) {
    if (t.parent || t.status === 'completed') continue;
    const s = layTasks?.[t.id]?.status;
    const c = s && s !== 'done' && n[s] !== undefined ? s : cols[0].id;
    n[c] += 1;
  }
  return n;
}

/** Как показать колонку/этап: track — дорожка (Конвейер), chips — до 4 колонок, menu — выпадающий список. */
export const stageMode = (view, cols = []) => (view === 'pipe' ? 'track' : cols.length <= 4 ? 'chips' : 'menu');

/** Подпись чипа «до начала»: «за час», «в момент начала». */
export const leadChip = (min) => (LEADS.find((l) => l.min === min)?.name ?? `За ${min} мин`).toLowerCase();

/** Подпись чипа «в своё время»: «за 1 день в 10:00», «29 окт. в 18:00». */
export function customChip(rule) {
  if (!rule) return '';
  if (rule.kind === 'at') {
    const [d, t] = String(rule.at ?? '').split('T');
    const [y, m, day] = (d ?? '').split('-').map(Number);
    if (!y || !m || !day) return 'точное время';
    const date = new Date(y, m - 1, day).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
    return `${date}${t ? ` в ${t.slice(0, 5)}` : ''}`;
  }
  const name = (BEFORE.find((b) => b.days === (rule.days ?? 0))?.name ?? `За ${rule.days} дн.`).toLowerCase();
  return `${name} в ${rule.time ?? '10:00'}`;
}

/** Напоминания задачи: минуты «до начала» и одно «в своё время» (или null). */
export function splitRemind(remind) {
  const all = rulesOf(remind);
  return { leads: all.filter((r) => r.kind === 'lead').map((r) => r.min), custom: all.find((r) => r.kind !== 'lead') ?? null };
}
/** Обратно в правило слоя: одно правило, массив или null. */
export function joinRemind(leads = [], custom = null) {
  const all = [...leads.map((min) => ({ kind: 'lead', min })), ...(custom ? [custom] : [])];
  return !all.length ? null : all.length === 1 ? all[0] : all;
}

/** «▸ Ещё» открыто сразу, если там что-то заполнено: повтор, цвет, картинка. */
export const moreFilled = (L = {}) => !!(L?.repeat?.every || L?.type || L?.preview);
