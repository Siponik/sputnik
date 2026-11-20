//! Правка заметки по строкам (как в «Знаниях»): Enter режет строку, список продолжается.

/// Enter в строке `t` с курсором на байте `at`: что встаёт на место строки (две строки через \n или пустая)
/// и где курсор в новой строке. Список продолжается («- », «- [ ] », «* », «> »); Enter на пустом пункте — пункт кончается.
pub fn split(t: &str, at: usize) -> (String, usize) {
    let at = at.min(t.len());
    let at = (0..=at).rev().find(|k| t.is_char_boundary(*k)).unwrap_or(0);
    let (a, b) = t.split_at(at);
    let lead = a.trim_start();
    let pre = if lead.starts_with("- [") { "- [ ] " } else if lead.starts_with("- ") { "- " } else if lead.starts_with("* ") { "* " } else if lead.starts_with("> ") { "> " } else { "" };
    if !pre.is_empty() && a.trim() == pre.trim() && b.trim().is_empty() {
        return (String::new(), 0);
    }
    (format!("{a}\n{pre}{}", b.trim_start()), pre.len())
}
