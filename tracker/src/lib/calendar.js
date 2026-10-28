// Календарь: раскладка событий, задач и привычек по дням. Только расчёты, без интерфейса.
// Время задачи (в Google Tasks его нет) хранится в слое: tasks[id].slot = { s: 'ЧЧ:ММ', e: 'ЧЧ:ММ' }.
import { ymd, dueToYmd } from './api.js';
import { dow, isDone, scheduledOn, habitSpan } from './habits.js';

// Рабочие часы — для свободного окна и загрузки недели. Сетка недели — все сутки.
export const GRID_START = 9 * 60;
export const GRID_END = 21 * 60;
export const HOUR_PX = 40; // час, где за неделю что-то есть
export const HOUR_EMPTY = 12; // пустой час — сжат
export const BAND_MAX = 36; // полоса пустых часов подряд — не выше

/** Высоты часов сетки недели: занятые часы (и hot — текущий, черновик, свободное окно) — 40 px, пустые — 12 px.
 *  Y[h] — верх часа h, yAt(минуты) — координата, bands — подряд идущие пустые часы, lines — линии между обычными часами. */
export function hourLayout(timedItems, hot = [], fit = 0) {
  const busy = Array(24).fill(false);
  for (const h of hot) if (h >= 0 && h < 24) busy[h] = true;
  for (const it of timedItems) {
    const a = Math.max(0, Math.floor(it.s / 60)), b = Math.min(24, Math.ceil(Math.max(it.e, it.s + 30) / 60));
    for (let q = a; q < b; q++) busy[q] = true;
  }
  // Подряд идущие пустые часы — одна полоса: 12 px на час, но вся полоса не выше BAND_MAX (ночь 00–09 не съедает сетку).
  const runs = [];
  for (let h = 0; h < 24;) {
    if (busy[h]) { h++; continue; }
    const a = h;
    while (h < 24 && !busy[h]) h++;
    runs.push({ a, b: h, h: Math.min((h - a) * HOUR_EMPTY, BAND_MAX) });
  }
  const nBusy = busy.filter(Boolean).length;
  // fit — высота, в которую надо уложить сутки (окно на весь экран): занятые часы растягиваются или сжимаются (30–72 px).
  let full = HOUR_PX;
  if (fit > 0 && nBusy) full = Math.max(30, Math.min(72, Math.floor((fit - runs.reduce((n, r) => n + r.h, 0)) / nBusy)));
  const HT = [], Y = [0];
  for (const r of runs) for (let q = r.a; q < r.b; q++) HT[q] = r.h / (r.b - r.a);
  for (let q = 0; q < 24; q++) { if (busy[q]) HT[q] = full; Y[q + 1] = Math.round((Y[q] + HT[q]) * 100) / 100; }
  const yAt = (min) => { const m = Math.max(0, Math.min(1440, min)); const hh = Math.min(23, Math.floor(m / 60)); return Y[hh] + ((m - hh * 60) / 60) * HT[hh]; };
  const labels = [], lines = [], bands = [];
  for (let h = 0; h < 24; h++) {
    if (!busy[h]) continue;
    labels.push({ key: `h${h}`, text: `${String(h).padStart(2, '0')}:00`, top: h === 0 ? 2 : Y[h] - 7, small: false });
    if (h > 0 && busy[h - 1]) lines.push(Y[h]);
  }
  for (const r of runs) {
    const text = `${String(r.a).padStart(2, '0')}–${String(r.b === 24 ? 0 : r.b).padStart(2, '0')}`;
    bands.push({ top: Y[r.a], h: r.h, a: r.a, b: r.b, text });
    // Узкой полосе (1–2 часа) подпись не помещается между соседними часами — она в подсказке полосы.
    if (r.h >= BAND_MAX) labels.push({ key: `b${r.a}`, text, top: Y[r.a] + r.h / 2 - 7, small: true });
  }
  return { HT, Y, yAt, height: Y[24], labels, lines, bands, busy };
}

export const WD_SHORT = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
export const WD_FULL = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
export const MONTH_GEN = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
export const MONTH_NOM = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

export const parseYmd = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
export const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
export const startOfWeek = (d) => { const x = new Date(d); x.setHours(0, 0, 0, 0); x.setDate(x.getDate() - dow(x)); return x; };
export const toMin = (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; };
export const fromMin = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
export const nowMin = () => { const d = new Date(); return d.getHours() * 60 + d.getMinutes(); };

/** Дни периода: неделя (7) или сетка месяца (42, с понедельника). */
export function periodDays(selYmd, mode) {
  const sel = parseYmd(selYmd);
  const first = mode === 'week' ? startOfWeek(sel) : startOfWeek(new Date(sel.getFullYear(), sel.getMonth(), 1));
  return Array.from({ length: mode === 'week' ? 7 : 42 }, (_, i) => ymd(addDays(first, i)));
}

export function periodTitle(selYmd, mode) {
  const sel = parseYmd(selYmd);
  if (mode === 'month') return `${MONTH_NOM[sel.getMonth()]} ${sel.getFullYear()}`;
  const a = startOfWeek(sel), b = addDays(a, 6);
  if (a.getMonth() === b.getMonth()) return `${a.getDate()} – ${b.getDate()} ${MONTH_GEN[b.getMonth()]}`;
  return `${a.getDate()} ${MONTH_GEN[a.getMonth()]} – ${b.getDate()} ${MONTH_GEN[b.getMonth()]}`;
}

/** Сдвиг выбранного дня на период вперёд или назад. */
export function shiftPeriod(selYmd, mode, dir) {
  const sel = parseYmd(selYmd);
  if (mode === 'week') return ymd(addDays(sel, 7 * dir));
  const day = Math.min(sel.getDate(), new Date(sel.getFullYear(), sel.getMonth() + dir + 1, 0).getDate());
  return ymd(new Date(sel.getFullYear(), sel.getMonth() + dir, day));
}

// Тип задачи пока берём из шаблона её списка — свои типы появятся позже.
const TYPE_BY_TEMPLATE = { work: 'work', asset3d: 'creative', personal: 'personal', study: 'study' };
export const typeOfTemplate = (tplId) => TYPE_BY_TEMPLATE[tplId] ?? 'work';
export const typeColor = (type) => `var(--type-${type})`;

/** События Google по дням: { 'YYYY-MM-DD': [item] }. Многодневные режутся по дням. */
export function eventsByDay(events, days) {
  const inRange = new Set(days);
  const out = {};
  const put = (day, item) => { if (inRange.has(day)) (out[day] ??= []).push(item); };
  for (const e of events) {
    const base = { kind: e.kind ?? 'event', title: e.summary || 'Без названия', cal: e.calendar, event: e };
    if (e.start?.date) {
      // Событие на весь день: end.date — следующий день после последнего.
      const end = e.end?.date > e.start.date ? e.end.date : ymd(addDays(parseYmd(e.start.date), 1));
      for (let d = parseYmd(e.start.date); ymd(d) < end; d = addDays(d, 1)) {
        put(ymd(d), { ...base, id: `${e.id}|${ymd(d)}`, s: null, e: null });
      }
      continue;
    }
    if (!e.start?.dateTime) continue;
    const a = new Date(e.start.dateTime), b = new Date(e.end?.dateTime ?? e.start.dateTime);
    let d = new Date(a.getFullYear(), a.getMonth(), a.getDate());
    do {
      const dayEnd = addDays(d, 1);
      const sm = Math.round((Math.max(a, d) - d) / 60e3), em = Math.round((Math.min(b, dayEnd) - d) / 60e3);
      const whole = sm === 0 && em >= 1440;
      put(ymd(d), { ...base, id: `${e.id}|${ymd(d)}`, s: whole ? null : sm, e: whole ? null : Math.max(em, sm) });
      d = dayEnd;
    } while (d < b);
  }
  return out;
}

/** Задачи со сроком по дням. typeOf(listId) — тип для цвета. */
export function tasksByDay(lists, tasksByList, layTasks, typeOf, days) {
  const inRange = new Set(days);
  const today = ymd(new Date());
  const out = {};
  for (const l of lists) {
    for (const t of tasksByList[l.id] ?? []) {
      if (t.parent || !t.due) continue;
      const day = dueToYmd(t.due);
      if (!inRange.has(day)) continue;
      const slot = layTasks?.[t.id]?.slot;
      const done = t.status === 'completed';
      (out[day] ??= []).push({
        kind: 'task', id: t.id, title: t.title || 'Без названия', task: t, listId: l.id, list: l.title,
        type: typeOf(l.id, t.id), done, overdue: !done && day < today,
        s: slot?.s ? toMin(slot.s) : null, e: slot?.e ? toMin(slot.e) : slot?.s ? toMin(slot.s) + 60 : null,
      });
    }
  }
  return out;
}

/** Блоки сетки недели: позиция и колонка, если пересекаются. Пересечение — по высоте на экране:
 *  короткий блок (полчаса в сжатом часе) тянется до 20 px и не должен наезжать на следующий. */
export function layoutBlocks(items, yAt) {
  const clamp = (m) => Math.min(1440, Math.max(0, m));
  const xs = items.filter((i) => i.s != null)
    .map((i) => {
      const a = clamp(i.s), top = yAt(a) + 1;
      const height = Math.max(20, yAt(Math.max(clamp(i.e), a)) - yAt(a) - 2);
      return { ...i, a, top, height, bot: Math.max(yAt(Math.max(clamp(i.e), a + 30)), top + height) };
    })
    .sort((x, y) => x.top - y.top || y.bot - x.bot);
  const out = [];
  let cluster = [], end = -1;
  const flush = () => {
    const cols = [];
    for (const it of cluster) {
      let c = cols.findIndex((last) => last <= it.top);
      if (c < 0) { c = cols.length; cols.push(0); }
      cols[c] = it.bot;
      it.col = c;
    }
    for (const it of cluster) it.cols = cols.length;
    out.push(...cluster);
    cluster = [];
  };
  for (const it of xs) {
    if (cluster.length && it.top >= end) flush();
    cluster.push(it);
    end = Math.max(end, it.bot);
  }
  if (cluster.length) flush();
  return out;
}

/** Занятые промежутки дня в пределах [lo, hi], слитые. Выполненные задачи не занимают время. */
export function busy(items, lo = GRID_START, hi = GRID_END) {
  const xs = items.filter((i) => i.s != null && !((i.kind === 'task' || i.kind === 'habit') && i.done))
    .map((i) => [Math.max(lo, i.s), Math.min(hi, i.e)])
    .filter(([a, b]) => b > a)
    .sort((x, y) => x[0] - y[0]);
  const out = [];
  for (const [a, b] of xs) {
    const last = out[out.length - 1];
    if (last && a <= last[1]) last[1] = Math.max(last[1], b);
    else out.push([a, b]);
  }
  return out;
}

export const busyMinutes = (items) => busy(items).reduce((m, [a, b]) => m + b - a, 0);

/** Самое длинное свободное окно (не меньше часа) с сегодняшнего дня; длина окна — до 3 часов.
 *  Сначала ищем в будни, выходные — только если в будни места нет. */
export function bestWindow(dayItems, days) {
  const work = days.filter((d) => dow(parseYmd(d)) < 5);
  return longestGap(dayItems, work) ?? longestGap(dayItems, days.filter((d) => !work.includes(d)));
}

function longestGap(dayItems, days) {
  const today = ymd(new Date());
  let best = null;
  for (const day of days) {
    if (day < today) continue;
    const lo = day === today ? Math.max(GRID_START, Math.ceil(nowMin() / 30) * 30) : GRID_START;
    if (lo > GRID_END - 60) continue;
    let from = lo;
    const gaps = [];
    for (const [a, b] of busy(dayItems[day] ?? [], lo)) { if (a > from) gaps.push([from, a]); from = Math.max(from, b); }
    if (GRID_END > from) gaps.push([from, GRID_END]);
    for (const [a, b] of gaps) {
      if (b - a >= 60 && (!best || b - a > best.len)) best = { day, s: a, e: a + Math.min(b - a, 180), len: b - a };
    }
  }
  return best;
}

/** Привычка в конкретный день: по расписанию ли, сделана ли. */
export function habitDay(habit, log, day, today) {
  // «N раз в неделю» (perWeek) — каждый день, пока норма недели не набрана (habits.scheduledOn).
  const done = isDone(log, habit.id, day);
  const before = !!habit.createdAt && day < habit.createdAt.slice(0, 10);
  return { sched: scheduledOn(habit, log, day) && (!before || done), done, isToday: day === today, future: day > today };
}

/** Привычки со временем на день — блоки сетки недели (kind 'habit'): только по расписанию, в своём интервале
 *  (без конца — полчаса, habits.habitSpan). Отмеченная (done) время больше не занимает, как выполненная задача. */
export function habitBlocks(habits, log, day, today) {
  const out = [];
  for (const h of habits) {
    const sp = habitSpan(h);
    if (!sp) continue;
    const x = habitDay(h, log, day, today);
    if (!x.sched) continue;
    out.push({ kind: 'habit', id: `hab:${h.id}|${day}`, title: h.name, h, s: sp.s, e: sp.e, end: sp.end, ...x });
  }
  return out;
}

export function dayLabel(day) {
  const d = parseYmd(day);
  return { weekday: WD_FULL[dow(d)], short: WD_SHORT[dow(d)], title: `${d.getDate()} ${MONTH_GEN[d.getMonth()]}`, n: d.getDate(), month: d.getMonth() };
}

/** «сегодня», «завтра» или «пн» — для списка сроков недели. */
export function whenLabel(day) {
  const today = ymd(new Date());
  if (day === today) return 'сегодня';
  if (day === ymd(addDays(new Date(), 1))) return 'завтра';
  if (day === ymd(addDays(new Date(), -1))) return 'вчера';
  return WD_SHORT[dow(parseYmd(day))];
}

export const hoursLabel = (min) => (min ? `${(Math.round(min / 6) / 10).toString().replace('.', ',')} ч` : '—');
