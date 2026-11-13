//! Окно «Создать»: строка + ручной выбор → название, срок, приоритет, повтор.
use chrono::NaiveDate;
use serde_json::json;
use sputnik_core::compose::{self as c, Manual, Picked};

fn today() -> NaiveDate {
    NaiveDate::from_ymd_opt(2026, 11, 11).unwrap() // среда
}

fn r(text: &str) -> serde_json::Value {
    c::resolve(text, 0, &Manual::default(), 0, today())
}

#[test]
fn title_has_no_dates() {
    for (s, title, day, time) in [
        ("Сделать иконки для клиента завтра 15:00 @работа !!", "Сделать иконки для клиента", Some("2026-11-12"), Some("15:00")),
        ("позвонить маме до пятницы", "Позвонить маме", Some("2026-11-13"), None),
        ("отчёт к понедельнику", "Отчёт", Some("2026-11-16"), None),
        ("купить хлеб на завтра", "Купить хлеб", Some("2026-11-12"), None),
        ("созвон в пт в 14", "Созвон", Some("2026-11-13"), Some("14:00")),
        ("встреча к 15:00", "Встреча", Some("2026-11-11"), Some("15:00")),
        ("встреча в 15 часов", "Встреча", Some("2026-11-11"), Some("15:00")),
        ("сдать макет 15 ноября в 12:00", "Сдать макет", Some("2026-11-15"), Some("12:00")),
    ] {
        let x = r(s);
        assert_eq!(x["title"], title, "{s}");
        assert_eq!(x["day"].as_str(), day, "{s}");
        assert_eq!(x["slot"]["s"].as_str(), time, "{s}");
    }
}

#[test]
fn no_date_no_due() {
    let x = r("Купить молоко");
    assert!(x["day"].is_null());
    assert!(x["slot"].is_null());
    // событие без даты — сегодня
    let e = c::resolve("Созвон", 1, &Manual::default(), 30, today());
    assert_eq!(e["day"], "2026-11-11");
}

#[test]
fn manual_wins_over_text() {
    let m = Manual { when: Some(Picked { day: Some("2026-11-20".into()), slot: None }), prio: Some(3), ..Default::default() };
    let x = c::resolve("Отчёт завтра !!!", 0, &m, 0, today());
    assert_eq!(x["title"], "Отчёт");
    assert_eq!(x["day"], "2026-11-20");
    assert_eq!(x["priority"], 3);
    // «без срока» кнопкой
    let m = Manual { when: Some(Picked::default()), ..Default::default() };
    assert!(c::resolve("Отчёт завтра", 0, &m, 0, today())["day"].is_null());
    // повтор снят руками
    let m = Manual { repeat: Some(serde_json::Value::Null), ..Default::default() };
    assert!(c::resolve("Зарядка каждый день", 0, &m, 0, today())["repeat"].is_null());
}

#[test]
fn cross_returns_piece_to_title() {
    let m = Manual { off: vec!["when".into()], ..Default::default() };
    let x = c::resolve("Фильм Завтра 15:00", 0, &m, 0, today());
    assert_eq!(x["title"], "Фильм Завтра 15:00");
    assert!(x["day"].is_null());
    let x = r("Фильм завтра 15:00 !!");
    let ks: Vec<_> = x["toks"].as_array().unwrap().iter().map(|t| t["k"].as_str().unwrap().to_string()).collect();
    assert_eq!(ks, ["when", "prio"]);
    assert_eq!(x["toks"][0]["l"], "завтра · 15:00");
}

#[test]
fn event_duration_and_birthday() {
    let e = c::resolve("Созвон в пт 14:00", 1, &Manual::default(), 30, today());
    assert_eq!(e["slot"], json!({"s": "14:00", "e": "14:30"}));
    let b = c::resolve("Мама 12 марта", 3, &Manual::default(), 0, today());
    assert_eq!(b["title"], "Мама");
    assert_eq!(b["day"], "2027-03-12");
}

#[test]
fn quick_days() {
    let q = c::quick_days(today());
    assert_eq!(q[2].2.as_deref(), Some("2026-11-16"));
    assert_eq!(q[3].2.as_deref(), Some("2026-11-18"));
    assert_eq!(q[4].2, None);
    assert_eq!(c::quick_of(&json!("2026-11-12"), today()), "tomorrow");
    assert_eq!(c::quick_of(&serde_json::Value::Null, today()), "none");
    let p = c::pick_quick("tomorrow", &json!({"s": "15:00", "e": "16:00"}), today()).unwrap();
    assert_eq!(p.slot, Some(("15:00".into(), "16:00".into())));
    assert_eq!(c::pick_quick("none", &json!({"s": "15:00", "e": "16:00"}), today()).unwrap(), Picked::default());
    assert_eq!(c::when_label(&json!("2026-11-12"), &json!({"s": "15:00", "e": "16:00"}), today()), "Завтра, 12 ноября · 15:00–16:00");
}

#[test]
fn strip_and_lands() {
    let st = c::strip(today());
    assert_eq!(st.len(), 7);
    assert_eq!(st[0], ("2026-11-11".to_string(), "СР".to_string(), "11".to_string()));
    assert_eq!(st[6].1, "ВТ");
    assert_eq!(c::times().len(), 96);
    assert_eq!(c::times()[69], "17:15");
    let none = c::lands(&serde_json::Value::Null, &serde_json::Value::Null, "Входящие", today());
    assert_eq!(none, vec!["Доска · колонка «Входящие»"]);
    let fri = c::lands(&json!("2026-11-13"), &json!({"s": "17:00", "e": "17:00"}), "Входящие", today());
    assert_eq!(fri[1], "«Сегодня» в пт 13 · 17:00");
    assert_eq!(fri[2], "Календарь · неделя 9–15 ноя");
    let x = c::lands(&json!("2026-12-01"), &serde_json::Value::Null, "К", today());
    assert_eq!(x[2], "Календарь · неделя 30 ноя–6 дек");
    assert_eq!(c::lands(&json!("2026-11-11"), &serde_json::Value::Null, "К", today())[1], "«Сегодня» сразу");
}
