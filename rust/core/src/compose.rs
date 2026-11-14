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

/// Быстрые сроки окна «Создать» (§18): id → день (None — без срока).
pub fn quick_days(today: NaiveDate) -> Vec<(&'static str, &'static str, Option<String>)> {
    let wd = today.weekday().num_days_from_monday() as i64;
    let mon = dates::add_days(today, 7 - wd);
    vec![
        ("today", "Сегодня", Some(dates::ymd(today))),
        ("tomorrow", "Завтра", Some(dates::ymd(dates::add_days(today, 1)))),
        ("mon", "Пн", Some(dates::ymd(mon))),
        ("week", "След. неделя", Some(dates::ymd(dates::add_days(today, 7)))),
        ("none", "Без срока", None),
    ]
}

const WD: [&str; 7] = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"];
const MON3: [&str; 12] = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];

/// Полоса из 7 дней с сегодняшнего: (день «ГГГГ-ММ-ДД», «ПТ», «6»).
pub fn strip(today: NaiveDate) -> Vec<(String, String, String)> {
    (0..7).map(|i| {
        let d = dates::add_days(today, i);
        (dates::ymd(d), WD[d.weekday().num_days_from_monday() as usize].to_string(), d.day().to_string())
    }).collect()
}

/// Время с шагом 15 минут: «00:00» … «23:45».
pub fn times() -> Vec<String> {
    (0..96).map(|i| format!("{:02}:{:02}", i / 4, i % 4 * 15)).collect()
}

/// «→ Попадёт»: колонка доски; со сроком — ещё день в «Сегодня» и неделя в календаре.
pub fn lands(day: &Value, slot: &Value, col: &str, today: NaiveDate) -> Vec<String> {
    let mut v = vec![format!("Доска · колонка «{col}»")];
    let Some(d) = day.as_str().and_then(dates::parse_ymd) else { return v };
    let at = slot["s"].as_str().map(|s| format!(" · {s}")).unwrap_or_default();
    let wd = WD[d.weekday().num_days_from_monday() as usize].to_lowercase();
    v.push(if d == today { format!("«Сегодня» сразу{at}") } else { format!("«Сегодня» в {wd} {}{at}", d.day()) });
    let a = dates::add_days(d, -(d.weekday().num_days_from_monday() as i64));
    let b = dates::add_days(a, 6);
    let m = |x: NaiveDate| MON3[x.month0() as usize];
    v.push(if a.month() == b.month() { format!("Календарь · неделя {}–{} {}", a.day(), b.day(), m(b)) } else { format!("Календарь · неделя {} {}–{} {}", a.day(), m(a), b.day(), m(b)) });
    v
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

/// Ввод времени в выборе времени (§21): «1730», «17», «17:30», «5pm», «+15»/«-15» (колесо — от `cur`),
/// «hour» — через час от `now` (кратно 15 минутам). None — не понял.
pub fn time_input(raw: &str, cur: &str, now: &str) -> Option<String> {
    let t = raw.trim().to_lowercase().replace(['.', ' ', '-'], ":").replace("::", ":");
    let fmt = |m: i64| { let m = m.rem_euclid(24 * 60); format!("{:02}:{:02}", m / 60, m % 60) };
    if raw.trim() == "+15" || raw.trim() == "-15" {
        let base = if cur.is_empty() { cr::to_min(now) / 15 * 15 } else { cr::to_min(cur) };
        return Some(fmt(base + if raw.trim() == "+15" { 15 } else { -15 }));
    }
    // «h17» — час кнопкой (минуты остаются), «m30» — минуты кнопкой (час остаётся, без часа — 09)
    if let Some(h) = t.strip_prefix('h').and_then(|x| x.parse::<i64>().ok()) {
        let m = if cur.is_empty() { 0 } else { cr::to_min(cur) % 60 };
        return (0..24).contains(&h).then(|| fmt(h * 60 + m));
    }
    if let Some(m) = t.strip_prefix('m').and_then(|x| x.parse::<i64>().ok()) {
        let h = if cur.is_empty() { 9 } else { cr::to_min(cur) / 60 };
        return (0..60).contains(&m).then(|| fmt(h * 60 + m));
    }
    if t == "hour" {
        return Some(fmt((cr::to_min(now) + 60 + 14) / 15 * 15));
    }
    let (body, pm, am) = if let Some(b) = t.strip_suffix("pm") { (b.to_string(), true, false) } else if let Some(b) = t.strip_suffix("am") { (b.to_string(), false, true) } else { (t.clone(), false, false) };
    let body = body.trim_matches(':').to_string();
    let (h, m): (i64, i64) = if let Some((a, b)) = body.split_once(':') {
        (a.parse().ok()?, if b.is_empty() { 0 } else { b.parse().ok()? })
    } else {
        if body.is_empty() || !body.chars().all(|c| c.is_ascii_digit()) { return None; }
        match body.len() {
            1 | 2 => (body.parse().ok()?, 0),
            3 => (body[..1].parse().ok()?, body[1..].parse().ok()?),
            4 => (body[..2].parse().ok()?, body[2..].parse().ok()?),
            _ => return None,
        }
    };
    let h = if pm && h < 12 { h + 12 } else if am && h == 12 { 0 } else { h };
    if !(0..24).contains(&h) || !(0..60).contains(&m) { return None; }
    Some(fmt(h * 60 + m))
}
