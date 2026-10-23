// Обмен с Google идёт секунды, а пользователь в это время отмечает, создаёт и удаляет задачи.
// Ответ, запрошенный до этих правок, не должен их затирать (иначе отмеченный стикер «переоткрывается»
// до следующей синхронизации через 2 мин).

/**
 * Свести свежий ответ Google по одному списку с тем, что трекер успел сделать сам, пока ждал ответа.
 * fetched — задачи из ответа; local — задачи списка в трекере сейчас; before — id задач списка в трекере
 * на момент запроса; touched — Map id → когда трекер сам менял задачу (мс); t0 — когда ушёл запрос.
 */
export function keepLocal(fetched, local = [], before = new Set(), touched = new Map(), t0 = 0) {
  const now = new Map(local.map((t) => [t.id, t]));
  const got = new Set(fetched.map((t) => t.id));
  const out = [];
  for (const t of fetched) {
    if (before.has(t.id) && !now.has(t.id)) continue; // удалили, пока ждали ответа
    out.push((touched.get(t.id) ?? 0) > t0 && now.has(t.id) ? now.get(t.id) : t);
  }
  for (const t of local) if (!got.has(t.id) && !before.has(t.id)) out.push(t); // создали, пока ждали ответа
  return out;
}
