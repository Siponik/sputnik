//! Поиск по задачам и переходам (окно Ctrl+K). Порт tracker/src/lib/search.js.
use crate::j::*;
use crate::rx;
use std::cmp::Ordering;

/// Строчные, ё = е, пробелы схлопнуты.
pub fn norm(v: &str) -> String {
    rx::all(r"\s+", &v.to_lowercase().replace('ё', "е"), " ").trim().to_string()
}

pub fn norm_v(v: &Value) -> String {
    match v {
        Value::Null => String::new(),
        Value::String(x) => norm(x),
        x => norm(&x.to_string()),
    }
}

/// Насколько задача подходит (0 — нет): все слова запроса — в названии или заметке.
pub fn score(q: &str, title: &Value, notes: &Value) -> i64 {
    let words: Vec<String> = norm(q).split(' ').filter(|w| !w.is_empty()).map(String::from).collect();
    if words.is_empty() {
        return 0;
    }
    let (t, nn) = (norm_v(title), norm_v(notes));
    let mut sc = 0;
    for w in &words {
        if t.starts_with(w.as_str()) {
            sc += 6;
        } else if rx::is(&format!("(^|[\\s«\"(\\-]){}", rx::esc(w)), &t) {
            sc += 4;
        } else if t.contains(w.as_str()) {
            sc += 2;
        } else if nn.contains(w.as_str()) {
            sc += 1;
        } else {
            return 0;
        }
    }
    sc
}

/// Приближение localeCompare(…, 'ru').
pub fn ru_compare(a: &str, b: &str) -> Ordering {
    let f = |x: &str| x.to_lowercase().replace('ё', "е");
    cmp16(&f(a), &f(b)).then_with(|| cmp16(&a.to_lowercase(), &b.to_lowercase())).then_with(|| cmp16(a, b).reverse())
}

pub struct Found {
    pub task: Value,
    pub list: Value,
    pub parent: Option<Value>,
    pub s: i64,
}

/// Задачи всех списков под запрос: открытые выше, лучшие совпадения выше.
pub fn find_tasks(q: &str, lists: &[Value], tasks_by_list: &Value, limit: usize) -> Vec<Found> {
    let mut out = vec![];
    for l in lists {
        let all = a(&tasks_by_list[s(&l["id"])]);
        for tk in all {
            let notes = if tk["notes"].is_null() { Value::String(String::new()) } else { tk["notes"].clone() };
            let sc = score(q, &tk["title"], &notes);
            if sc == 0 {
                continue;
            }
            let has_parent = t(&tk["parent"]);
            let parent = if has_parent { all.iter().find(|p| p["id"] == tk["parent"]).cloned() } else { None };
            let bonus = if s(&tk["status"]) == "completed" { 0 } else { 100 } + if has_parent { 0 } else { 1 };
            out.push(Found { task: tk.clone(), list: l.clone(), parent, s: sc + bonus });
        }
    }
    out.sort_by(|x, y| y.s.cmp(&x.s).then_with(|| ru_compare(s(&x.task["title"]), s(&y.task["title"]))));
    out.truncate(limit);
    out
}

/// Переходы (разделы, списки), чьё имя подходит под запрос.
pub fn find_places(q: &str, places: &[Value]) -> Vec<Value> {
    let qq = norm(q);
    if qq.is_empty() {
        return places.to_vec();
    }
    places
        .iter()
        .filter(|p| norm_v(&p["name"]).contains(&qq) || a(&p["alias"]).iter().any(|x| norm_v(x).starts_with(&qq)))
        .cloned()
        .collect()
}
