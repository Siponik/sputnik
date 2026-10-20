// «Когда» словами → день и время. Используют окно выбора даты (DateTimePicker) и строка быстрого добавления на «Сегодня».
//   parseWhen('завтра 15:00', today)        → { day: '2026-10-21', time: '15:00', rest: '' }
//   parseWhen('скетч в пятницу 17.30')     → { day: <ближайшая пятница>, time: '17:30', rest: 'скетч' }
// Понимает: сегодня, завтра, послезавтра; дни недели («в пятницу», «пн») — ближайший будущий;
// «через N дней / недель»; «25 окт», «25 октября», «25.10»; время «15:00», «15.00», «в 15»; «весь день».
import { ymd } from './api.js';

const WEEK = [/^(?:в|во)?\s*(понедельник|пн)$/, /^(?:в|во)?\s*(вторник|вт)$/, /^(?:в|во)?\s*(сред[ау]|ср)$/, /^(?:в|во)?\s*(четверг|чт)$/,
  /^(?:в|во)?\s*(пятниц[ау]|пт)$/, /^(?:в|во)?\s*(суббот[ау]|сб)$/, /^(?:в|во)?\s*(воскресенье|вс)$/];
const WEEK_WORD = /(?:^|\s)(?:(?:в|во)\s+)?(понедельник|вторник|сред[ау]|четверг|пятниц[ау]|суббот[ау]|воскресенье|пн|вт|ср|чт|пт|сб|вс)(?=\s|$|[,.!?])/i;
const MONTHS = ['янв', 'фев', 'мар', 'апр', 'ма', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

const addDays = (d, n) => { const x = new Date(d); x.setHours(0, 0, 0, 0); x.setDate(x.getDate() + n); return x; };
const dowMon = (d) => (d.getDay() + 6) % 7; // пн = 0

/** Разбирает фразу. today — Date (по умолчанию сейчас). Нераспознанный текст возвращается в rest. */
export function parseWhen(text, today = new Date()) {
  let t = ` ${String(text ?? '').replace(/\s+/g, ' ')} `;
  const base = addDays(today, 0);
  let day = null, time = null, allDay = false;
  const take = (re, fn) => { const m = t.match(re); if (m) { fn(m); t = t.replace(m[0], ' '); return true; } return false; };

  take(/\s(весь день)(?=\s)/i, () => (allDay = true));
  // время: 15:00 (двоеточие — всегда время), 15.00 / 17.30 (точка — время, только если час 6–23 и минуты кратны 5,
  // иначе это дата: «3.11» — 3 ноября), «в 15»
  take(/\s(?:в\s)?([01]?\d|2[0-3]):([0-5]\d)(?=\s|[,.!?]\s)/, (m) => (time = `${m[1].padStart(2, '0')}:${m[2]}`))
    || take(/\s(?:в\s)?([6-9]|0[6-9]|1\d|2[0-3])\.([0-5][05])(?=\s|[,!?]\s)/, (m) => (time = `${m[1].padStart(2, '0')}:${m[2]}`))
    || take(/\sв\s([01]?\d|2[0-3])(?=\s)(?!\s*(?:янв|фев|мар|апр|ма|июн|июл|авг|сен|окт|ноя|дек))/i, (m) => (time = `${m[1].padStart(2, '0')}:00`));

  take(/\s(послезавтра)(?=\s|[,.!?])/i, () => (day = addDays(base, 2)))
    || take(/\s(завтра)(?=\s|[,.!?])/i, () => (day = addDays(base, 1)))
    || take(/\s(сегодня)(?=\s|[,.!?])/i, () => (day = base))
    || take(/\sчерез\s(\d{1,3}|неделю|день)\s?(дн[еяй]+|день|недел[июь]+)?(?=\s|[,.!?])/i, (m) => {
      const n = m[1] === 'неделю' ? 7 : m[1] === 'день' ? 1 : Number(m[1]) * (/недел/i.test(m[2] ?? '') ? 7 : 1);
      day = addDays(base, n);
    })
    || take(/\s(\d{1,2})\s(янв|фев|мар|апр|мая|май|июн|июл|авг|сен|окт|ноя|дек)[а-я]*\.?(?=\s|[,!?])/i, (m) => {
      const mi = MONTHS.indexOf(m[2].toLowerCase().slice(0, 3) === 'май' ? 'ма' : m[2].toLowerCase().slice(0, m[2].toLowerCase().startsWith('ма') ? 2 : 3));
      day = nearestDate(base, mi, Number(m[1]));
    })
    || take(/\s(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?(?=\s|[,!?])/, (m) => {
      if (m[3]) { const y = Number(m[3].length === 2 ? `20${m[3]}` : m[3]); day = new Date(y, Number(m[2]) - 1, Number(m[1])); }
      else day = nearestDate(base, Number(m[2]) - 1, Number(m[1]));
    })
    || take(WEEK_WORD, (m) => {
      const i = WEEK.findIndex((re) => re.test(m[1].toLowerCase()));
      day = addDays(base, ((i - dowMon(base) + 7) % 7) || 7);
    });

  if (allDay) time = null;
  return { day: day && !isNaN(day) ? ymd(day) : null, time, allDay, rest: t.replace(/\s+/g, ' ').trim() };
}

const MONG = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
const WDS = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/** Подпись поля «Срок»: { date: 'Завтра, 21 октября', time: '15:00–16:00' | 'весь день' | '' }. */
export function whenText(day, slot, today = new Date()) {
  if (!day) return { date: 'Без срока', time: '' };
  const [y, m, d] = day.split('-').map(Number);
  const x = new Date(y, m - 1, d);
  const t0 = addDays(today, 0);
  const diff = Math.round((x - t0) / 864e5);
  const rel = diff === 0 ? 'Сегодня' : diff === 1 ? 'Завтра' : diff === 2 ? 'Послезавтра' : diff === -1 ? 'Вчера' : WDS[dowMon(x)][0].toUpperCase() + WDS[dowMon(x)].slice(1);
  return { date: `${rel}, ${d} ${MONG[m - 1]}${y !== t0.getFullYear() ? ` ${y}` : ''}`, time: slot?.s ? `${slot.s}–${slot.e}` : 'весь день' };
}

/** «25 окт» без года — ближайшее такое число: в этом году или, если уже прошло, в следующем. */
function nearestDate(base, month, date) {
  const d = new Date(base.getFullYear(), month, date);
  return d < base ? new Date(base.getFullYear() + 1, month, date) : d;
}
