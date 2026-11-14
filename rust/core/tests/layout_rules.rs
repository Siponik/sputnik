//! Проверка правил раскладки (docs/layout.md) по исходникам окна `app/ui/*.slint`.
//! Ловит то, что раньше вылезало или показывалось квадратами на Windows.
use std::fs;

fn ui_files() -> Vec<(String, String)> {
    let dir = concat!(env!("CARGO_MANIFEST_DIR"), "/../app/ui");
    let mut v: Vec<(String, String)> = fs::read_dir(dir).unwrap()
        .filter_map(|e| e.ok()).map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|x| x == "slint"))
        .map(|p| (p.file_name().unwrap().to_string_lossy().to_string(), fs::read_to_string(&p).unwrap()))
        .collect();
    v.sort();
    v
}

/// Строки кода без комментариев.
fn code_lines(src: &str) -> impl Iterator<Item = (usize, &str)> {
    src.lines().enumerate().map(|(i, l)| (i + 1, l.split("//").next().unwrap_or(""))).filter(|(_, l)| !l.trim().is_empty())
}

/// §4: никаких эмодзи и символов, которых нет в шрифтах Windows, — только иконки (Icon, Chev).
#[test]
fn no_emoji_or_missing_glyphs() {
    let bad = |c: char| (c as u32) >= 0x1F000 || "◷↻✦▾▸📅⏰".contains(c);
    let mut found = vec![];
    for (f, src) in ui_files() {
        for (n, l) in code_lines(&src) {
            if let Some(c) = l.chars().find(|c| bad(*c)) {
                found.push(format!("{f}:{n} «{c}»"));
            }
        }
    }
    assert!(found.is_empty(), "эмодзи или символы без шрифта — замени на Icon/Chev:\n{}", found.join("\n"));
}

/// §1: многострочный ввод растёт за рамку — бери ScrollInput (kit.slint).
/// Исключение — поле внутри прокручиваемой колонки, помеченное `// раскладка: в прокрутке`.
#[test]
fn multiline_input_scrolls() {
    let mut found = vec![];
    for (f, src) in ui_files() {
        if f == "kit.slint" { continue; }
        let lines: Vec<&str> = src.lines().collect();
        for (i, l) in lines.iter().enumerate() {
            if l.contains("single-line: false") {
                let ctx = lines[i.saturating_sub(12)..i].join("\n");
                if !ctx.contains("раскладка: в прокрутке") {
                    found.push(format!("{f}:{}", i + 1));
                }
            }
        }
    }
    assert!(found.is_empty(), "многострочный TextInput без прокрутки — замени на ScrollInput:\n{}", found.join("\n"));
}
