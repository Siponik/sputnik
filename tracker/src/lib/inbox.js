// «Входящие от Claude»: задачи, которые Apps Script (reminders/Inbox.gs) создал по запросам из чатов.
// Трекер узнаёт их по статусу (api.inboxStatus) и показывает на «Сегодня», пока их не примут или не отклонят.
// Решение хранится в слое: tasks[id].inbox = 'accepted' | 'rejected'.

/** taskId → { from, at } для задач, созданных из чатов (без дублей и отметок «выполнено»). */
export function claudeTasks(status) {
  const out = {};
  for (const p of Object.values(status?.processed ?? {})) {
    if (!p?.ok) continue;
    for (const c of p.created ?? []) {
      if (c?.op === 'task.create' && c.taskId && !c.existed) out[c.taskId] = { from: p.from || '', at: p.at };
    }
  }
  return out;
}

/** Ещё не разобранные: задача есть, открыта и решения по ней нет. */
export function pending(status, lists, tasksByList, layTasks) {
  const ids = claudeTasks(status);
  const items = [];
  for (const l of lists) {
    for (const t of tasksByList[l.id] ?? []) {
      if (!ids[t.id] || t.status === 'completed' || layTasks?.[t.id]?.inbox) continue;
      items.push({ task: t, listId: l.id, list: l.title, ...ids[t.id] });
    }
  }
  return items.sort((a, b) => (b.at || '').localeCompare(a.at || ''));
}

// Типы из навыка sputnik-tasks → наши цвета. plain — без своего типа (цвет от шаблона списка).
const TYPE = { work: 'work', meeting: 'work', creative: 'creative', study: 'study', personal: 'personal' };

/** Поля слоя из pendingLayer, которые ещё не перенесены в наш слой: [[taskId, patch], …]. */
export function layerPatches(status, layTasks) {
  const out = [];
  for (const [id, f] of Object.entries(status?.pendingLayer ?? {})) {
    if (layTasks?.[id]?.pulled) continue;
    const patch = { pulled: true };
    if (TYPE[f.type]) patch.type = TYPE[f.type];
    if (typeof f.project === 'string') patch.project = f.project;
    if (Array.isArray(f.tags)) patch.tags = f.tags.filter((x) => typeof x === 'string');
    if ([1, 2, 3].includes(f.priority)) patch.priority = f.priority;
    if (typeof f.stage === 'string') patch.stage = f.stage;
    out.push([id, patch]);
  }
  return out;
}
