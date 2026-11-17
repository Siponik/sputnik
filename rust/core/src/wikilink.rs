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

/// Заметки «про эту задачу» (блок «Заметки» в окне задачи): сначала те, на что ссылается заметка задачи `[[…]]`,
/// потом те, чьё название целым словом есть в названии задачи (ё = е, регистр не важен). Ответ — номера в `titles`.
pub fn about(task_title: &str, task_notes: &str, titles: &[String]) -> Vec<usize> {
    let norm = |s: &str| s.to_lowercase().replace('ё', "е");
    let mut out: Vec<usize> = vec![];
    for l in links(task_notes) {
        if let Some(i) = titles.iter().position(|t| norm(t) == norm(&l)) {
            if !out.contains(&i) {
                out.push(i);
            }
        }
    }
    let words: Vec<String> = norm(task_title).split(|c: char| !c.is_alphanumeric()).filter(|w| !w.is_empty()).map(String::from).collect();
    for (i, t) in titles.iter().enumerate() {
        let tw: Vec<String> = norm(t).split(|c: char| !c.is_alphanumeric()).filter(|w| !w.is_empty()).map(String::from).collect();
        if tw.is_empty() || out.contains(&i) {
            continue;
        }
        // все слова названия заметки идут подряд в названии задачи
        if words.windows(tw.len()).any(|w| w == tw.as_slice()) && tw.iter().map(|w| w.chars().count()).sum::<usize>() >= 3 {
            out.push(i);
        }
    }
    out
}
