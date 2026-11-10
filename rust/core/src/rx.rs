//! Регулярки с просмотром вперёд (как в JS) — fancy-regex. Ошибка в шаблоне — ошибка программы.
pub use fancy_regex::{Captures, Regex};
use std::collections::HashMap;
use std::sync::Mutex;

/// Скомпилированная регулярка; одинаковые шаблоны компилируются один раз.
pub fn rx(p: &str) -> Regex {
    static CACHE: std::sync::OnceLock<Mutex<HashMap<String, Regex>>> = std::sync::OnceLock::new();
    let c = CACHE.get_or_init(Default::default);
    let mut g = c.lock().unwrap();
    g.entry(p.to_string()).or_insert_with(|| Regex::new(p).unwrap_or_else(|e| panic!("регулярка {p}: {e}"))).clone()
}

pub fn is(p: &str, text: &str) -> bool {
    rx(p).is_match(text).unwrap_or(false)
}

/// Заменить все совпадения (в замене $1 — группы, как в JS).
pub fn all(p: &str, text: &str, to: &str) -> String {
    rx(p).replace_all(text, to).into_owned()
}

/// Заменить первое совпадение.
pub fn first(p: &str, text: &str, to: &str) -> String {
    rx(p).replace(text, to).into_owned()
}

pub fn esc(s: &str) -> String {
    fancy_regex::escape(s).into_owned()
}

/// Группы первого совпадения (None — нет совпадения; группа без совпадения — None).
pub fn cap(p: &str, text: &str) -> Option<Vec<Option<String>>> {
    let r = rx(p);
    let c = r.captures(text).ok()??;
    Some((0..c.len()).map(|i| c.get(i).map(|m| m.as_str().to_string())).collect())
}
