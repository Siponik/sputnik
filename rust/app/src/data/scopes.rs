//! Какие доступы Google нужны Спутнику и чего не хватает.
//! Google даёт снять галочки с отдельных доступов на странице входа — тогда вход проходит,
//! а запросы падают с «403 insufficient authentication scopes». Поэтому проверяем сразу после входа.
//! Проверка модуля без Tauri: `rustc --edition 2021 --test src/scopes.rs`.

/// Доступы, без которых Спутник не работает, и как их назвать человеку.
pub const REQUIRED: [(&str, &str); 4] = [
    ("https://www.googleapis.com/auth/tasks", "Задачи"),
    ("https://www.googleapis.com/auth/calendar", "Календарь"),
    ("https://www.googleapis.com/auth/drive.file", "Файлы Спутника на Drive"),
    ("https://www.googleapis.com/auth/drive.appdata", "Скрытая папка Спутника на Drive"),
];

/// Что запрашиваем при входе: нужное плюс почта (имя в общих сферах).
pub fn requested() -> String {
    let mut all: Vec<&str> = REQUIRED.iter().map(|(s, _)| *s).collect();
    all.push("https://www.googleapis.com/auth/userinfo.email");
    all.join(" ")
}

/// Названия доступов, которых нет в выданных (строка `scope` из ответа Google, через пробел).
pub fn missing(granted: &str) -> Vec<&'static str> {
    let got: Vec<&str> = granted.split_whitespace().collect();
    REQUIRED
        .iter()
        .filter(|(s, _)| !got.contains(s))
        .map(|(_, name)| *name)
        .collect()
}

/// Ошибка Google про нехватку доступов (у токена нет нужной галочки).
pub fn is_insufficient(msg: &str) -> bool {
    let m = msg.to_lowercase();
    m.contains("insufficient authentication scopes")
        || m.contains("access_token_scope_insufficient")
}

/// Текст для человека. Начинается с «Войдите в Google заново» — по этим словам приложение открывает вход.
pub fn missing_text(names: &[&str]) -> String {
    if names.is_empty() {
        return "Войдите в Google заново: Google не дал Спутнику все доступы. На странице входа отметь все галочки.".to_string();
    }
    format!(
        "Войдите в Google заново: Google не дал доступ — {}. На странице входа отметь все галочки.",
        names.join(", ")
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_granted() {
        let g = "https://www.googleapis.com/auth/calendar openid https://www.googleapis.com/auth/tasks https://www.googleapis.com/auth/drive.appdata https://www.googleapis.com/auth/drive.file";
        assert!(missing(g).is_empty());
    }

    #[test]
    fn some_unchecked() {
        let g = "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/drive.file";
        assert_eq!(missing(g), vec!["Задачи", "Календарь", "Скрытая папка Спутника на Drive"]);
    }

    #[test]
    fn prefix_is_not_enough() {
        // calendar.readonly — не calendar.
        let g = "https://www.googleapis.com/auth/calendar.readonly";
        assert!(missing(g).contains(&"Календарь"));
    }

    #[test]
    fn detects_google_error() {
        assert!(is_insufficient("Google ответил 403: Request had insufficient authentication scopes."));
        assert!(!is_insufficient("Google ответил 403: The caller does not have permission"));
        assert!(missing_text(&["Задачи"]).starts_with("Войдите в Google заново"));
    }

    #[test]
    fn requested_has_all() {
        let r = requested();
        assert!(missing(&r).is_empty());
        assert!(r.contains("userinfo.email"));
    }
}
