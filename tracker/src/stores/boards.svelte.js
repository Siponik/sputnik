// Доски: шаблоны и свои доски списков (docs/design-v2.md — «Шаблон и список — раздельно»).
// Шаблон — заготовка: его правка меняет списки, которые идут за ним. Список со своей копией колонок и полей
// («своё») шаблон не трогает; «Вернуть как в шаблоне» убирает копию. Расчёты — lib/templates.js.
import * as T from '../lib/templates.js';
import { layer, touch, save } from './layer.svelte.js';
import { board } from './tasks.svelte.js';
import { say } from './toast.svelte.js';

const lay = () => layer.data;
const moveAll = (moves) => { for (const m of moves) touch('tasks', m.id, { status: m.status }); };

/** Сохранить шаблон; removed — удалённые колонки [{ id, to }]: задачи списков, идущих за шаблоном, переезжают. */
export function saveTemplate(id, draft, removed = []) {
  const moves = Object.fromEntries(removed.map((r) => [r.id, r.to]));
  for (const l of board.lists) {
    if (T.isHabitList(l, lay()) || !T.follows(l.id, lay(), id)) continue;
    moveAll(T.relocate(board.tasks[l.id], lay().tasks, moves));
  }
  if (T.isBuiltin(id)) touch('templatesEdit', id, { ...draft, removed: false });
  else touch('templates', id, { ...draft, removed: false });
  save();
  say(`Шаблон «${draft.name}» сохранён`);
}

/** Сохранить доску только для этого списка — он становится «своим». */
export function saveList(listId, draft, removed = []) {
  const p = T.saveListPlan(lay(), listId, draft, board.tasks[listId], removed);
  moveAll(p.moves);
  touch('lists', listId, p.patch);
  save();
}

/** «Вернуть как в шаблоне». */
export function resetList(listId) {
  const p = T.resetListPlan(lay(), listId, board.tasks[listId]);
  moveAll(p.moves);
  touch('lists', listId, p.patch);
  save();
  say(p.moves.length ? `Список снова как в шаблоне · переехало задач: ${p.moves.length}` : 'Список снова как в шаблоне');
}
