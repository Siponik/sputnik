// Списки и задачи из Google (и общих сфер) + действия над задачами, которым не нужен экран:
// выполнить, повторить, удалить с «Отменить», дублировать, перенести в другой список.
// Поля Спутника пишутся в слой (stores/layer.svelte.js), ошибки и «Отменить» — плашкой (stores/toast.svelte.js).
import * as api from '../lib/api.js';
import * as repeat from '../lib/repeat.js';
import * as worktime from '../lib/timer.js';
import * as stickers from '../lib/stickers.js';
import * as shared from '../lib/shared.js';
import * as sh from '../lib/sharedcore.js';
import { isHabitList } from '../lib/templates.js';
import { layer, touch, save } from './layer.svelte.js';
import { say, busy as toastBusy } from './toast.svelte.js';

/** lists — списки; tasks — listId → задачи (вместе с подзадачами). */
export const board = $state({ lists: [], tasks: {} });

// Что App подставляет: задачу удалили (закрыть окно, если она открыта).
let hooks = { onRemoved: () => {} };
export function configure(h) { hooks = { ...hooks, ...h }; }

const L = (id) => layer.data.tasks?.[id] ?? {};
const untitled = (t) => t.title || 'Без названия';
export const find = (listId, id) => (board.tasks[listId] ?? []).find((t) => t.id === id);

/** Ошибка действия — плашкой «Не удалось …: причина»; результат fn или fail. */
export async function guard(what, fn, fail = undefined) {
  try { return await fn(); } catch (e) { say(`Не удалось ${what}: ${e}`); return fail; }
}

/** Правка с плашкой «Отменить»: run() — сейчас (false — не вышло, плашки нет), undo() — по кнопке. */
export async function undoable(msg, run, undo) {
  if ((await run()) === false) return false;
  say(msg, undo);
  return true;
}

// Когда задачу меняли здесь — ответ синхронизации, начатой раньше, её не затирает (lib/fresh.js keepLocal).
export const touchedAt = new Map();
/** Задача пришла от Google после правки — подменяем её в списке. */
export function replace(listId, updated) {
  touchedAt.set(updated.id, Date.now());
  board.tasks[listId] = (board.tasks[listId] ?? []).map((t) => (t.id === updated.id ? updated : t));
}
const prepend = (listId, t) => { board.tasks[listId] = [t, ...(board.tasks[listId] ?? [])]; };

// ---------- повтор: выполненная задача с правилом → следующая с новым сроком ----------
let rolling = false;
export async function rollRepeats(quiet = false) {
  if (rolling) return;
  rolling = true;
  try {
    const todo = repeat.dueRepeats(board.lists.filter((l) => !isHabitList(l, layer.data)), board.tasks, layer.data.tasks);
    for (const { listId, task, rule } of todo) {
      const day = repeat.nextDue(rule, api.dueToYmd(task.due), api.ymd(new Date()));
      if (!day) continue;
      try {
        // Копию мог уже сделать другой компьютер — тогда только ссылаемся на неё (иначе на двух ПК задачи двоились).
        const have = repeat.existingNext(board.tasks[listId], task, day);
        if (have) { touch('tasks', task.id, { repeatNext: have.id, repeatAt: Date.now() }); save(); continue; }
        const r = await api.createTask(listId, { title: task.title, notes: task.notes ?? '', due: api.ymdToDue(day) });
        prepend(listId, r);
        const was = L(task.id);
        touch('tasks', r.id, Object.fromEntries(repeat.CARRY.filter((k) => was[k] != null).map((k) => [k, was[k]])));
        touch('tasks', task.id, { repeatNext: r.id, repeatAt: Date.now() });
        save();
        if (!quiet && !toastBusy()) say(`Повтор: «${task.title}» — снова ${api.humanDue(r.due)}`);
      } catch (e) { say('Не удалось создать следующую повторяющуюся задачу: ' + e); break; }
    }
  } finally { rolling = false; }
}

// Отметку сняли сразу после выполнения («Отменить») — следующую копию убираем, пока её не трогали (10 мин).
async function unrollRepeat(task, listId) {
  const was = L(task.id);
  if (!was.repeatNext || Date.now() - (was.repeatAt ?? 0) > 10 * 60e3) return;
  const next = find(listId, was.repeatNext);
  touch('tasks', task.id, { repeatNext: null, repeatAt: null });
  save();
  if (!next || next.status === 'completed') return;
  board.tasks[listId] = board.tasks[listId].filter((x) => x.id !== next.id);
  await api.deleteTask(listId, next.id).catch(() => {});
}

/** Выполнить / вернуть. Повтор, таймер и «кто сделал» в общей сфере — следом. */
export async function toggle(task, done, listId, quiet = false) {
  try {
    replace(listId, await api.completeTask(listId, task.id, done));
  } catch (e) { say('Не удалось отметить: ' + e); return false; }
  if (done && L(task.id).repeat?.every) rollRepeats(quiet);
  if (!done) unrollRepeat(task, listId);
  if (done && !task.parent && !quiet) say(`«${task.title}» выполнено`);
  if (done && L(task.id).timer?.start) { touch('tasks', task.id, worktime.stopPatch(L(task.id))); save(); } // выполнено — таймер стоп
  // Общая сфера: кто сделал — кружок на штампе «сделано» у всех.
  const me = shared.myEmail();
  if (sh.isSharedId(listId) && !task.parent && (L(task.id).doneBy ?? null) !== (done ? me : null)) { touch('tasks', task.id, { doneBy: done ? me : null }); save(); }
  return true;
}

/** Стикер сделан / возвращён: плашка «Сделано: «…» · Отменить». */
export async function doneUndo(t, d, listId, onundo) {
  if (!d) return toggle(t, d, listId, true);
  return undoable(`Сделано: «${untitled(t)}»`, () => toggle(t, true, listId, true),
    () => { onundo?.(); const cur = find(listId, t.id); if (cur) toggle(cur, false, listId, true); });
}

// Удаление ждёт 6 с: задача сразу пропадает с экрана, а в Google удаляется, только если не нажали «Отменить».
const pendingDel = new Map(); // id → таймер удаления
export function removeUndo(t, listId) {
  const before = board.tasks[listId] ?? [];
  board.tasks[listId] = before.filter((x) => x.id !== t.id && x.parent !== t.id);
  hooks.onRemoved(t.id);
  pendingDel.set(t.id, setTimeout(async () => {
    pendingDel.delete(t.id);
    try { await api.deleteTask(listId, t.id); }
    catch (e) { board.tasks[listId] = before; say('Не удалось удалить: ' + e); }
  }, 6000));
  say(`«${untitled(t)}» удалена`, () => {
    clearTimeout(pendingDel.get(t.id));
    pendingDel.delete(t.id);
    const back = before.filter((x) => x.id === t.id || x.parent === t.id);
    board.tasks[listId] = [...back, ...(board.tasks[listId] ?? []).filter((x) => !back.some((b) => b.id === x.id))];
  });
}

export const duplicate = (t, listId) => guard('дублировать', async () => {
  const r = await api.createTask(listId, { title: t.title, notes: t.notes, due: t.due });
  prepend(listId, r);
  const was = L(t.id);
  const copy = Object.fromEntries(['type', 'priority', 'status', 'project', 'slot', 'client', 'money'].filter((k) => was[k] != null).map((k) => [k, was[k]]));
  if (Object.keys(copy).length) { touch('tasks', r.id, copy); save(); }
  say(`Копия «${t.title}» создана`);
});

/** Перенос в другой список; возвращает id задачи там (null — не вышло). */
export const moveToList = (t, dest, listId) => guard('перенести в другой список', async () => {
  const r = await api.moveTask(listId, t.id, dest);
  // Если Google выдал задаче в новом списке другой id — переносим её поля Спутника (статус, тип, время…).
  if (r?.id && r.id !== t.id && layer.data.tasks?.[t.id]) {
    const { t: _, ...rest } = layer.data.tasks[t.id];
    touch('tasks', r.id, rest);
    save();
  }
  const [a, b] = await Promise.all([api.listTasks(listId), api.listTasks(dest)]);
  board.tasks[listId] = a; board.tasks[dest] = b;
  say(`«${t.title}» → список «${board.lists.find((l) => l.id === dest)?.title ?? ''}»`);
  return r?.id ?? t.id;
}, null);

/** Тема стикера с «Отменить». */
export function topicUndo(t, id, listId) {
  const prev = L(t.id).topic ?? null;
  if (prev === id) return;
  const set = (v) => { touch('tasks', t.id, { topic: v }); save(); };
  const name = stickers.topicsOf(layer.data.lists?.[listId]).find((x) => x.id === id)?.name ?? stickers.MISC.name;
  undoable(`«${untitled(t)}» → ${name}`, () => set(id), () => set(prev));
}

/** Перенос по срокам: сегодня / на неделе / когда-нибудь. Время (slot) и напоминания идут за сроком. */
export async function whenUndo(t, target, listId) {
  const cur = api.dueToYmd(t.due) || null;
  const next = stickers.whenDue(target, cur, api.ymd(new Date()));
  if (next === cur) return;
  const setDue = (day, what) => guard(what, async () => { replace(listId, await api.patchTask(listId, t.id, { due: api.ymdToDue(day) })); }, false);
  const where = { today: 'сегодня', week: next ? api.humanDue(api.ymdToDue(next)) : 'на неделе', later: 'когда-нибудь' }[target];
  await undoable(`«${untitled(t)}» → ${where}`, () => setDue(next, 'перенести'), () => setDue(cur, 'вернуть срок'));
}
