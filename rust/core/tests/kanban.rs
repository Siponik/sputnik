//! Канбан: соседняя колонка и порядок карточек при перетаскивании.
use sputnik_core::kanban::{insert_at, neighbor, neighbor_card};

fn ids(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

#[test]
fn neighbor_col_steps() {
    let cols = ids(&["new", "work", "done"]);
    assert_eq!(neighbor(&cols, "new", 1).as_deref(), Some("work"));
    assert_eq!(neighbor(&cols, "work", -1).as_deref(), Some("new"));
    assert_eq!(neighbor(&cols, "work", 1).as_deref(), Some("done"));
    // за краем — None
    assert_eq!(neighbor(&cols, "new", -1), None);
    assert_eq!(neighbor(&cols, "done", 1), None);
    // нет такой колонки — None
    assert_eq!(neighbor(&cols, "zzz", 1), None);
}

#[test]
fn insert_moves_between_cols() {
    // перенос в другую колонку: карточки в ней ещё нет
    let col = ids(&["a", "b", "c"]);
    assert_eq!(insert_at(&col, "x", 0), ids(&["x", "a", "b", "c"]));
    assert_eq!(insert_at(&col, "x", 1), ids(&["a", "x", "b", "c"]));
    assert_eq!(insert_at(&col, "x", 3), ids(&["a", "b", "c", "x"]));
    // позиция за концом — в конец
    assert_eq!(insert_at(&col, "x", 99), ids(&["a", "b", "c", "x"]));
}

#[test]
fn insert_reorders_inside_col() {
    // внутри колонки: сначала убираем, потом вставляем по оставшимся
    let col = ids(&["a", "b", "c", "d"]);
    assert_eq!(insert_at(&col, "a", 2), ids(&["b", "c", "a", "d"]));
    assert_eq!(insert_at(&col, "d", 0), ids(&["d", "a", "b", "c"]));
    // на своё место — порядок не меняется
    assert_eq!(insert_at(&col, "b", 1), ids(&["a", "b", "c", "d"]));
    assert_eq!(insert_at(&col, "b", 2), ids(&["a", "b", "c", "d"]));
}

#[test]
fn neighbor_card_steps() {
    let col = ids(&["a", "b", "c"]);
    assert_eq!(neighbor_card(&col, "b", -1).as_deref(), Some("a"));
    assert_eq!(neighbor_card(&col, "b", 1).as_deref(), Some("c"));
    assert_eq!(neighbor_card(&col, "a", -1), None);
    assert_eq!(neighbor_card(&col, "c", 1), None);
}
