//! Ссылки `[[…]]` на «Знания» в заметках задач (п.37).

/// Что набрано после незакрытой `[[` в конце текста (без переноса строки), иначе None.
pub fn query(text: &str) -> Option<String> {
    let i = text.rfind("[[")?;
    let rest = &text[i + 2..];
    if rest.contains("]]") || rest.contains('\n') || rest.contains('[') {
        return None;
    }
    Some(rest.to_string())
}

/// Заменить незакрытую `[[запрос` в конце текста на `[[Название]]`.
pub fn insert(text: &str, title: &str) -> String {
    match text.rfind("[[") {
        Some(i) if query(text).is_some() => format!("{}[[{}]]", &text[..i], title),
        _ => format!("{text}[[{title}]]"),
    }
}

/// Все ссылки `[[Название]]` (или `[[Название|подпись]]`) по порядку, без повторов.
pub fn links(text: &str) -> Vec<String> {
    let mut out: Vec<String> = vec![];
    let mut rest = text;
    while let Some(i) = rest.find("[[") {
        let after = &rest[i + 2..];
        let Some(j) = after.find("]]") else { break };
        let inner = after[..j].split('|').next().unwrap_or("").trim().to_string();
        if !inner.is_empty() && !inner.contains('\n') && !out.contains(&inner) {
            out.push(inner);
        }
        rest = &after[j + 2..];
    }
    out
}
