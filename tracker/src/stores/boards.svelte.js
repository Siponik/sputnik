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

/** Сохранить окно списка: «Основное» всегда; доску — только если меняли колонки или поля (тогда список «своё»).
 *  Сменили только вид — список по-прежнему идёт за шаблоном. */
export function saveListSettings(listId, { sphere, sort, quiet, archive, draft, removed = [] }, { shared = false } = {}) {
  touch('lists', listId, { sort, quiet, archive, ...(shared ? {} : { sphere: sphere ?? null }) });
  if (draft) {
    const cur = T.boardOf(listId, lay());
    const onlyView = !T.isOwn(lay().lists?.[listId]) && T.sameShape(cur, draft);
    if (onlyView) touch('lists', listId, { view: draft.view });
    else {
      const p = T.saveListPlan(lay(), listId, draft, board.tasks[listId], removed);
      moveAll(p.moves);
      touch('lists', listId, p.patch);
    }
  }
  save();
}

/** «Сохранить как новый шаблон…»: шаблон из доски списка, и список дальше идёт за ним (своя копия убирается). */
export function listAsTemplate(listId, name, draft) {
  const id = 'tpl' + Date.now().toString(36);
  const p = T.ownPatch(draft);
  touch('templates', id, { name, view: p.view, fields: p.fields, cols: p.cols, removed: false });
  const plan = T.saveListPlan(lay(), listId, draft, board.tasks[listId]);
  moveAll(plan.moves);
  touch('lists', listId, { template: id, ...T.resetPatch() });
  save();
  say(`Шаблон «${name}» создан — список идёт за ним`);
  return id;
}

