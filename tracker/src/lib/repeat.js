// Повторяющиеся задачи. В Google Tasks повтора нет, поэтому правило живёт в слое: tasks[id].repeat = { every }.
// Когда такую задачу выполнили (в трекере, в боте, в телефоне — неважно), трекер при синхронизации
// создаёт следующую с новым сроком и помечает старую: tasks[id].repeatNext = id новой (второй раз не создаст).

export const REPEATS = [
  { id: 'day', label: 'Каждый день', short: 'каждый день' },
  { id: 'weekdays', label: 'По будням', short: 'по будням' },
  { id: 'week', label: 'Каждую неделю', short: 'каждую неделю' },
  { id: 'month', label: 'Каждый месяц', short: 'каждый месяц' },
  { id: 'year', label: 'Каждый год', short: 'каждый год' },
];

export const repeatLabel = (rule) => REPEATS.find((r) => r.id === rule?.every)?.short ?? '';

const parse = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Следующая дата по правилу после day (ГГГГ-ММ-ДД). Месяц и год держатся за исходное число: 31 → 30 → 31. */
function step(rule, day, n, anchor) {
  const d = parse(day);
  if (rule.every === 'day') d.setDate(d.getDate() + 1);
  else if (rule.every === 'weekdays') { do d.setDate(d.getDate() + 1); while (d.getDay() === 0 || d.getDay() === 6); }
  else if (rule.every === 'week') d.setDate(d.getDate() + 7);
  else {
    const a = parse(anchor);
    const months = rule.every === 'year' ? 12 * n : n;
    const y = a.getFullYear() + Math.floor((a.getMonth() + months) / 12), m = (a.getMonth() + months) % 12;
    const last = new Date(y, m + 1, 0).getDate();
    return fmt(new Date(y, m, Math.min(a.getDate(), last)));
  }
  return fmt(d);
}

/** Новый срок: следующий по правилу после старого срока, но не раньше сегодняшнего дня.
 *  Без срока считаем от дня выполнения (или сегодня). */
export function nextDue(rule, due, today) {
  if (!REPEATS.some((r) => r.id === rule?.every)) return null;
  const base = due || today;
  let day = base;
  for (let n = 1; n < 5000; n++) {
    day = step(rule, day, n, base);
    if (day >= today && day > base) return day;
  }
  return null;
}

/** Какие задачи пора продолжить: выполненные, с правилом повтора и без отметки repeatNext. */
export function dueRepeats(lists, tasks, layTasks) {
  const out = [];
  for (const l of lists) {
    for (const t of tasks[l.id] ?? []) {
      const L = layTasks?.[t.id];
      if (t.parent || t.status !== 'completed' || !L?.repeat?.every || L.repeatNext || t.deleted) continue;
      out.push({ listId: l.id, task: t, rule: L.repeat });
    }
  }
  return out;
}

/** Поля слоя, которые переходят к следующей задаче. Этап, учёт времени и порядок начинаются заново. */
export const CARRY = ['type', 'priority', 'project', 'slot', 'remind', 'repeat', 'client', 'money', 'tags', 'topic', 'pin'];

// Повтор словами в строке быстрого добавления и в боте: «полить цветы каждую неделю», «отчёт по будням».
const WORDS = [
  [/(^|\s)(каждый\s+день|ежедневно)(?=\s|$)/i, 'day'],
  [/(^|\s)(по\s+будням|каждый\s+будний\s+день)(?=\s|$)/i, 'weekdays'],
  [/(^|\s)(каждую\s+неделю|еженедельно)(?=\s|$)/i, 'week'],
  [/(^|\s)(каждый\s+месяц|ежемесячно)(?=\s|$)/i, 'month'],
  [/(^|\s)(каждый\s+год|ежегодно)(?=\s|$)/i, 'year'],
];
/** Находит повтор в тексте: { rule: { every } | null, rest — текст без этих слов }. */
export function takeRepeat(text) {
  for (const [re, every] of WORDS) {
    const m = text.match(re);
    if (m) return { rule: { every }, rest: (text.slice(0, m.index) + m[1] + text.slice(m.index + m[0].length)).replace(/\s{2,}/g, ' ').trim() };
  }
  return { rule: null, rest: text };
}
