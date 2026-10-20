// Поиск по всем задачам и переходам (окно Ctrl+K, lib/Search.svelte). Только расчёты, без интерфейса.

/** Для сравнения: строчные, ё = е, лишние пробелы схлопнуты. */
export const norm = (s) => String(s ?? '').toLowerCase().replace(/ё/g, 'е').replace(/\s+/g, ' ').trim();

/** Насколько задача подходит под запрос (0 — не подходит). Все слова запроса должны найтись в названии или заметке. */
export function score(q, title, notes = '') {
  const words = norm(q).split(' ').filter(Boolean);
  if (!words.length) return 0;
  const t = norm(title), n = norm(notes);
  let s = 0;
  for (const w of words) {
    if (t.startsWith(w)) s += 6;
    else if (new RegExp(`(^|[\\s«"(\\-])${w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`).test(t)) s += 4; // начало слова
    else if (t.includes(w)) s += 2;
    else if (n.includes(w)) s += 1;
    else return 0;
  }
  return s;
}

/** Задачи всех списков под запрос: открытые выше выполненных, лучшие совпадения выше. */
export function findTasks(q, lists, tasksByList, limit = 30) {
  const out = [];
  for (const l of lists) {
    const all = tasksByList[l.id] ?? [];
    for (const t of all) {
      const s = score(q, t.title, t.notes);
      if (!s) continue;
      const parent = t.parent ? all.find((p) => p.id === t.parent) : null;
      out.push({ task: t, list: l, parent, s: s + (t.status === 'completed' ? 0 : 100) + (t.parent ? 0 : 1) });
    }
  }
  return out.sort((a, b) => b.s - a.s || (a.task.title ?? '').localeCompare(b.task.title ?? '', 'ru')).slice(0, limit);
}

/** Переходы: разделы и списки, чьё имя подходит под запрос. */
export function findPlaces(q, places) {
  const qq = norm(q);
  if (!qq) return places;
  return places.filter((p) => norm(p.name).includes(qq) || (p.alias ?? []).some((a) => norm(a).startsWith(qq)));
}
