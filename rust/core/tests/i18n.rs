//! Язык интерфейса: подстановки, множественное число, даты и покрытие перевода.
use sputnik_core::i18n::{self, Lang};
use std::path::{Path, PathBuf};

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
}

#[test]
fn fill_and_pick() {
    assert_eq!(i18n::fill("Ошибка: {}", &["нет сети".into()]), "Ошибка: нет сети");
    assert_eq!(i18n::fill("{1} и {0}", &["а".into(), "б".into()]), "б и а");
    assert_eq!(i18n::fill("{{x}} {}", &["1".into()]), "{x} 1");
    assert_eq!(i18n::pick("sys", Some("en-US")), Lang::En);
    assert_eq!(i18n::pick("sys", Some("ru-RU")), Lang::Ru);
    assert_eq!(i18n::pick("sys", None), Lang::Ru);
    assert_eq!(i18n::pick("ru", Some("en-US")), Lang::Ru);
    assert_eq!(i18n::pick("en", Some("ru")), Lang::En);
    let po = i18n::parse_po("msgid \"\"\nmsgstr \"h\"\n\n# c\nmsgid \"А\\\"б\"\nmsgstr \"\"\n\"A\"\n\"b\"\n\nmsgid \"x\"\nmsgid_plural \"xs\"\nmsgstr[0] \"y\"\nmsgstr[1] \"ys\"\n");
    assert_eq!(po, vec![("А\"б".to_string(), "Ab".to_string()), ("x".to_string(), "y".to_string())]);
}

// Всё, где язык переключается, — в одном тесте: язык общий на процесс.
#[test]
fn switching() {
    i18n::set_lang(Lang::Ru);
    assert_eq!(i18n::plural(5, ["задача", "задачи", "задач"]), "задач");
    assert_eq!(i18n::plural(22, ["задача", "задачи", "задач"]), "задачи");
    assert_eq!(i18n::day_month(12, 10), "12 ноября");
    assert_eq!(i18n::day_range(30, 10, 6, 11), "30 ноября – 6 декабря");
    assert_eq!(i18n::day_range(16, 10, 22, 10), "16 – 22 ноября");
    assert_eq!(sputnik_core::t!("Как в системе"), "Как в системе");
    i18n::set_lang(Lang::En);
    assert_eq!(sputnik_core::t!("Как в системе"), "System");
    assert_eq!(sputnik_core::t!("Нет такой строки {}", 3), "Нет такой строки 3");
    assert_eq!(i18n::plural(1, ["задача", "задачи", "задач"]), "task");
    assert_eq!(i18n::plural(3, ["задача", "задачи", "задач"]), "tasks");
    assert_eq!(i18n::day_month(12, 10), "Nov 12");
    assert_eq!(i18n::month_year(10, 2026), "November 2026");
    assert_eq!(i18n::day_range(30, 10, 6, 11), "Nov 30 – Dec 6");
    assert_eq!(i18n::day_range(16, 10, 22, 10), "Nov 16 – 22");
    assert_eq!(i18n::wd(0), "Mo");
    i18n::set_lang(Lang::Ru);
}

fn files(dir: &Path, ext: &str, out: &mut Vec<PathBuf>) {
    for e in std::fs::read_dir(dir).unwrap().flatten() {
        let p = e.path();
        if p.is_dir() {
            files(&p, ext, out);
        } else if p.extension().and_then(|x| x.to_str()) == Some(ext) {
            out.push(p);
        }
    }
}

/// Строковые литералы сразу после `marker` (`@tr(` или `t!(`), с учётом `\"`.
fn literals(src: &str, marker: &str) -> Vec<String> {
    let mut v = Vec::new();
    let mut rest = src;
    while let Some(i) = rest.find(marker) {
        let before = rest[..i].chars().last();
        rest = &rest[i + marker.len()..];
        if before.is_some_and(|c| c.is_alphanumeric() || c == '_') {
            continue;
        }
        let r = rest.trim_start();
        let Some(r) = r.strip_prefix('"') else { continue };
        let mut s = String::new();
        let mut it = r.chars();
        while let Some(c) = it.next() {
            match c {
                '\\' => { if let Some(x) = it.next() { s.push(match x { 'n' => '\n', x => x }); } }
                '"' => break,
                c => s.push(c),
            }
        }
        v.push(s);
    }
    v
}

fn holes(s: &str) -> usize {
    s.replace("{{", "").matches('{').count()
}

/// Каждая строка в `@tr("…")` и `t!("…")` есть в .po, перевод не пустой, `{}` столько же.
#[test]
fn coverage() {
    let po: std::collections::HashMap<String, String> = i18n::parse_po(i18n::PO).into_iter().collect();
    let mut bad = Vec::new();
    let mut fs = Vec::new();
    files(&root().join("app/ui"), "slint", &mut fs);
    let n_slint = fs.len();
    files(&root().join("app/src"), "rs", &mut fs);
    files(&root().join("core/src"), "rs", &mut fs);
    for (k, f) in fs.iter().enumerate() {
        if f.ends_with("i18n.rs") {
            continue;
        }
        let src: String = std::fs::read_to_string(f).unwrap().lines().filter(|l| !l.trim_start().starts_with("//")).collect::<Vec<_>>().join("\n");
        let marker = if k < n_slint { "@tr(" } else { "t!(" };
        for s in literals(&src, marker) {
            match po.get(&s) {
                None => bad.push(format!("{}: нет перевода «{}»", f.display(), s)),
                Some(en) if en.is_empty() => bad.push(format!("{}: пустой перевод «{}»", f.display(), s)),
                Some(en) if holes(en) != holes(&s) && !s.contains('|') => bad.push(format!("{}: разное число {{}} в «{}» → «{}»", f.display(), s, en)),
                _ => {}
            }
        }
    }
    assert!(bad.is_empty(), "Перевод:\n{}", bad.join("\n"));
}

/// Сколько русских строк ещё без перевода — по файлам разметки (для работы, не проверка):
/// `cargo test -p sputnik-core --test i18n left -- --ignored --nocapture`
#[test]
#[ignore]
fn left() {
    let mut fs = Vec::new();
    files(&root().join("app/ui"), "slint", &mut fs);
    for f in fs {
        let src = std::fs::read_to_string(&f).unwrap();
        let n = src.lines().filter(|l| !l.trim_start().starts_with("//")).map(|l| {
            l.split('"').enumerate().filter(|(i, part)| i % 2 == 1 && part.chars().any(|c| ('а'..='я').contains(&c.to_lowercase().next().unwrap_or(c)) || c == 'ё')).count()
                .saturating_sub(l.matches("@tr(\"").count())
        }).sum::<usize>();
        if n > 0 {
            println!("{n:4}  {}", f.file_name().unwrap().to_string_lossy());
        }
    }
}
