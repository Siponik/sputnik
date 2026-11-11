//! Окно «Создать»: что получится из строки и ручного выбора (как в окне «Создать» старого трекера).
//! Правила:
//! - дата, время, «!!!», @список, #тип и повтор вырезаются из названия;
//! - выбранное кнопками (срок, приоритет, повтор) главнее текста, текст при этом не переписывается;
//! - «×» у распознанного куска возвращает его в название (`off[вид] = true`);
//! - без даты в строке и без выбора задача без срока (время без даты — сегодня).
use crate::{create as cr, dates, j, route, small, when};
use chrono::{Datelike, NaiveDate};
use serde_json::{json, Value};

/// Срок, выбранный кнопками или в окне «Когда»: день (None — «без срока») и время «с — до».
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Picked {
    pub day: Option<String>,
    pub slot: Option<(String, String)>,
}

/// Что выбрано в окне руками.
#[derive(Clone, Debug, Default)]
pub struct Manual {
    /// Куски строки, которые вернули в название крестиком: when | prio | repeat | at | tag.
    pub off: Vec<String>,
    pub when: Option<Picked>,
    /// 0 — снят руками, 1…3 — выбран.
    pub prio: Option<i64>,
    /// Some(Null) — повтор снят руками.
    pub repeat: Option<Value>,
}

impl Manual {
    pub fn off_json(&self) -> Value {
        Value::Object(self.off.iter().map(|k| (k.clone(), json!(true))).collect())
    }
}

/// Предлоги, которые остаются висеть после вырезанной даты: «купить хлеб на», «отчёт к».
const HANG: [&str; 7] = ["в", "во", "на", "до", "к", "ко", "с"];

fn tidy(title: &str, cut_when: bool) -> String {
    let mut w: Vec<&str> = title.split_whitespace().collect();
    if cut_when {
        while w.len() > 1 && w.last().map(|x| HANG.contains(&x.to_lowercase().as_str())).unwrap_or(false) {
            w.pop();
        }
    }
    let t = w.join(" ");
    let mut ch = t.chars();
    match ch.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + ch.as_str(),
    }
}

/// Итог строки и ручного выбора.
/// kind: 0 задача · 1 событие · 3 день рождения (привычку разбирает `create::parse_habit`).
/// dur — длительность события в минутах (-1 — весь день), для задачи не нужна.
pub fn resolve(text: &str, kind: i32, m: &Manual, dur: i64, today: NaiveDate) -> Value {
    let p = route::parse_line(text, today, &m.off_json());
    let tdy = dates::ymd(today);
    let cut_when = !p["day"].is_null() || !p["time"].is_null();
    let title = tidy(j::s(&p["title"]), cut_when);
    // срок
    let (day, slot): (Option<String>, Option<(String, String)>) = match &m.when {
        Some(w) => (w.day.clone(), w.slot.clone()),
        None => {
            let st = p["time"].as_str().map(|s| s.to_string());
            let len = if kind == 1 { if dur == 0 { 60 } else { dur } } else { 60 };
            let slot = st.filter(|_| len > 0).map(|s| { let e = cr::add_min(&s, len); (s, e) });
            let day = p["day"].as_str().map(|s| s.to_string());
            (day.or_else(|| if slot.is_some() || kind != 0 { Some(tdy.clone()) } else { None }), slot)
        }
    };
    let day = if kind != 0 && day.is_none() && kind != 3 { Some(tdy.clone()) } else { day };
    let slot = if kind == 3 { None } else { slot };
    let priority = m.prio.unwrap_or_else(|| p["priority"].as_i64().unwrap_or(0));
    let repeat = match &m.repeat {
        Some(r) => r.clone(),
        None => p["repeat"].clone(),
    };
    // распознанное в строке — чипы «Понял» с крестиком
    let mut toks = vec![];
    if cut_when {
        let d = p["day"].as_str().map(|d| short(d, today)).unwrap_or_else(|| "сегодня".into());
        let l = match p["time"].as_str() { Some(t) => format!("{d} · {t}"), None => d };
        toks.push(json!({"k": "when", "l": l, "over": m.when.is_some()}));
    }
    if let Some(pr) = p["priority"].as_i64() {
        let o = small::priority_of(&json!(pr));
        toks.push(json!({"k": "prio", "l": format!("{} {}", j::s(&o["mark"]), j::s(&o["label"]).to_lowercase()), "over": m.prio.is_some()}));
    }
    if p["repeat"].is_object() {
        toks.push(json!({"k": "repeat", "l": format!("↻ {}", crate::repeat::repeat_label(&p["repeat"])), "over": m.repeat.is_some()}));
    }
    if let Some(at) = p["at"].as_str() {
        toks.push(json!({"k": "at", "l": format!("@{at}"), "over": false}));
    }
    if let Some(tag) = p["tag"].as_str() {
        toks.push(json!({"k": "tag", "l": format!("#{tag}"), "over": false}));
    }
    json!({
        "title": title,
        "day": day,
        "slot": slot.map(|(s, e)| json!({"s": s, "e": e})),
        "priority": priority,
        "repeat": if repeat.is_object() { repeat } else { Value::Null },
        "at": p["at"], "tag": p["tag"],
        "marks": p["marks"],
        "toks": toks,
        "parsed": p,
    })
}

/// «сегодня», «завтра», «пт, 14 ноя».
pub fn short(day: &str, today: NaiveDate) -> String {
    let Some(d) = dates::parse_ymd(day) else { return String::new() };
    match (d - today).num_days() {
        0 => "сегодня".into(),
        1 => "завтра".into(),
        2 => "послезавтра".into(),
        _ => cr::short_day(day),
    }
}

/// Подпись выбранного срока для строки «Когда»: «Завтра, 12 ноября · 15:00–16:00» или «Без срока».
pub fn when_label(day: &Value, slot: &Value, today: NaiveDate) -> String {
    let Some(d) = day.as_str() else { return "Без срока".into() };
    let (a, _) = when::when_text(d, None, today);
    match (slot["s"].as_str(), slot["e"].as_str()) {
        (Some(s), Some(e)) if s != e => format!("{a} · {s}–{e}"),
        (Some(s), _) => format!("{a} · {s}"),
        _ => a,
    }
}

/// Быстрые сроки окна «Создать»: id → день (None — без срока).
pub fn quick_days(today: NaiveDate) -> Vec<(&'static str, &'static str, Option<String>)> {
    let wd = today.weekday().num_days_from_monday() as i64;
    let fri = dates::add_days(today, if wd < 4 { 4 - wd } else { 11 - wd });
    let mon = dates::add_days(today, 7 - wd);
    vec![
        ("none", "Без срока", None),
        ("today", "Сегодня", Some(dates::ymd(today))),
        ("tomorrow", "Завтра", Some(dates::ymd(dates::add_days(today, 1)))),
        ("fri", "Пт", Some(dates::ymd(fri))),
        ("mon", "Пн", Some(dates::ymd(mon))),
    ]
}

/// Какой быстрый срок сейчас выбран ("" — другой день).
pub fn quick_of(day: &Value, today: NaiveDate) -> &'static str {
    let d = day.as_str().map(|s| s.to_string());
    quick_days(today).into_iter().find(|q| q.2 == d).map(|q| q.0).unwrap_or("")
}

/// Быстрый срок кнопкой: время из строки или прошлого выбора остаётся.
pub fn pick_quick(id: &str, cur_slot: &Value, today: NaiveDate) -> Option<Picked> {
    let q = quick_days(today).into_iter().find(|q| q.0 == id)?;
    let slot = match (cur_slot["s"].as_str(), cur_slot["e"].as_str()) {
        (Some(s), Some(e)) if q.2.is_some() => Some((s.to_string(), e.to_string())),
        _ => None,
    };
    Some(Picked { day: q.2, slot })
}
