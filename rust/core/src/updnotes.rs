//! «Что нового» у версии: текст заметок из latest.json (строки коммитов сборки) → короткий список
//! понятных пунктов для карточки «Обновления» в настройках (#203).
use crate::rx;

/// Пункты из текста заметок: по строкам «- …», без пустых и служебных строк
/// («Merge…», «Слил свежую бету/main»), хвост «(#123)» снимается. Не больше `cap`.
pub fn items(notes: &str, cap: usize) -> Vec<String> {
    let mut out = Vec::new();
    for line in notes.lines() {
        let l = line.trim().trim_start_matches(['-', '•', '*', ' ']).trim();
        if l.is_empty() {
            continue;
        }
        let low = l.to_lowercase();
        if low.starts_with("merge") || low.starts_with("слил") || low.starts_with("слива") {
            continue;
        }
        let clean = rx::all(r"\s*\(#\d+\)\s*$", l, "").trim().to_string();
        if clean.is_empty() {
            continue;
        }
        out.push(clean);
        if out.len() >= cap {
            break;
        }
    }
    out
}
