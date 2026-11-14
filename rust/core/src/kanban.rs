//! Канбан: чистая логика перетаскивания и клавиш.
//! Лимиты колонок не блокируют перенос (как стрелка «→» на карточке) —
//! переполнение только подсвечивается в окне.

/// Соседняя колонка для клавиш ←/→ (A/D): id колонки `dir` шагов от `cur`.
/// За краем — None.
pub fn neighbor(ids: &[String], cur: &str, dir: i64) -> Option<String> {
    let i = ids.iter().position(|x| x == cur)?;
    let j = i as i64 + dir;
    if j < 0 || j >= ids.len() as i64 {
        return None;
    }
    Some(ids[j as usize].clone())
}

/// Новый порядок колонки после переноса карточки `id` на позицию `at`.
/// Карточка сначала убирается из списка (перенос внутри колонки),
/// потом встаёт на место `at` (по оставшимся карточкам).
pub fn insert_at(ids: &[String], id: &str, at: usize) -> Vec<String> {
    let mut v: Vec<String> = ids.iter().filter(|x| x.as_str() != id).cloned().collect();
    v.insert(at.min(v.len()), id.to_string());
    v
}

/// Соседняя карточка в колонке для клавиш ↑/↓: индекс от `cur`, за краем — None.
pub fn neighbor_card(ids: &[String], cur: &str, dir: i64) -> Option<String> {
    neighbor(ids, cur, dir)
}
