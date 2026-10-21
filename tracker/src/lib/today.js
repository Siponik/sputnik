// «Сегодня» 0.6: строка быстрого добавления = умная строка окна «Создать» (docs/design-v2.md — «Сегодня» в 0.6).
//   understood(p, today)              → чипы «Понял:» [{ kind: 'when' | 'prio' | 'repeat' | 'type', text }]
//   taskFrom(p, today, dest, r)        → { title, listId, due, slot, layer } для oncreate
// p — результат route.parseLine, r — выбранная строка route.route (тема стикеров, проект Конвейера).
import { whenText } from './when.js';
import { priorityOf, typeLabel } from './meta.js';
import { repeatLabel } from './repeat.js';

/** #тег → тип задачи (как в «Создать»; старые русские теги тоже). */
export const TYPE_TAG = { asset: 'creative', work: 'work', client: 'work', study: 'study', personal: 'personal',
  'ассет': 'creative', 'работа': 'work', 'клиент': 'work', 'учеба': 'study', 'учёба': 'study', 'личное': 'personal' };

const dateOf = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const toMin = (t) => { const [h, m] = t.split(':').map(Number); return h * 60 + m; };
const hhmm = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

/** Что понято из строки. Без даты задача ляжет на сегодня — так и пишем. */
export function understood(p, today) {
  if (!p?.title) return [];
  const day = p.day ?? today;
  const date = day === today ? 'сегодня' : whenText(day, null, dateOf(today)).date.toLowerCase();
  const out = [{ kind: 'when', text: p.time ? `${date} · ${p.time}` : date }];
  const pr = priorityOf(p.priority);
  if (pr) out.push({ kind: 'prio', text: `${pr.mark} ${pr.label.toLowerCase()}` });
  if (p.repeat) out.push({ kind: 'repeat', text: `↻ ${repeatLabel(p.repeat)}` });
  const type = p.tag && TYPE_TAG[p.tag.toLowerCase()];
  if (type) out.push({ kind: 'type', text: `#${typeLabel(type)}` });
  return out;
}

/** Задача из строки: срок — дата из строки или сегодня, время — час по умолчанию, поля Спутника — в layer. */
export function taskFrom(p, today, dest, r = {}) {
  const layer = {};
  const type = p.tag && TYPE_TAG[p.tag.toLowerCase()];
  if (type) layer.type = type;
  if (p.tag?.toLowerCase() === 'client' || p.tag?.toLowerCase() === 'клиент') layer.tags = ['client'];
  if (p.priority) layer.priority = p.priority;
  if (p.repeat) layer.repeat = p.repeat;
  if (r.listId === dest && r.topic) layer.topic = r.topic;
  if (r.listId === dest && r.project) layer.project = r.project;
  const slot = p.time ? { s: p.time, e: hhmm(Math.min(toMin(p.time) + 60, 1439)) } : null;
  return { title: p.title, listId: dest, due: p.day ?? today, slot, layer };
}
