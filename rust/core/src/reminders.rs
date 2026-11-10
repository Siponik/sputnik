//! Напоминания: правила слоя tasks[id].remind и пункты файла для бота. Порт app/lib/core/reminders.dart.
//!   { kind: 'before', days, time } · { kind: 'at', at: 'YYYY-MM-DDTHH:MM' } · { kind: 'lead', min }
use crate::calendar::habit_day;
use crate::dates::{add_days, parse_ymd, ymd};
use crate::habits::{habit_win, now as clock, remind_at};
use crate::j::*;
use crate::rx;
use chrono::{DateTime, Datelike, Duration, Local, NaiveDateTime, TimeZone, Timelike, Utc};
use std::sync::Mutex;

pub type At = DateTime<Utc>;

pub const BEFORE: [(i64, &str); 6] = [(0, "В день срока"), (1, "За 1 день"), (2, "За 2 дня"), (3, "За 3 дня"), (7, "За неделю"), (30, "За месяц")];
pub const LEADS: [(i64, &str); 7] = [(0, "В момент начала"), (5, "За 5 минут"), (15, "За 15 минут"), (60, "За час"), (1440, "За день"), (10080, "За неделю"), (43200, "За месяц")];
pub const BDAY_LEADS: [(i64, &str); 5] = [(0, "В день рождения"), (1440, "За день"), (4320, "За 3 дня"), (10080, "За неделю"), (43200, "За месяц")];

pub fn leads_for(kind: &str) -> &'static [(i64, &'static str)] {
    if kind == "birthday" { &BDAY_LEADS } else { &LEADS }
}

struct Cfg {
    default_time: String,
    no_time_off: bool,
    last_body: String,
}
static CFG: Mutex<Cfg> = Mutex::new(Cfg { default_time: String::new(), no_time_off: false, last_body: String::new() });

pub fn default_time() -> String {
    let c = CFG.lock().unwrap();
    if c.default_time.is_empty() { "10:00".into() } else { c.default_time.clone() }
}
fn no_time_off() -> bool {
    CFG.lock().unwrap().no_time_off
}
/// Час для задач без времени: «ЧЧ:ММ» или 'off' (молчать).
pub fn set_default_time(tm: Option<&str>) {
    let mut c = CFG.lock().unwrap();
    c.no_time_off = tm == Some("off");
    c.default_time = match tm {
        Some(x) if rx::is(r"^\d\d:\d\d$", x) => x.into(),
        _ => "10:00".into(),
    };
}
/// Тело последнего записанного файла напоминаний (прошедшее «до начала» из него не выкидываем).
pub fn set_last_body(b: &str) {
    CFG.lock().unwrap().last_body = b.into();
}

pub fn now_at() -> At {
    local(clock())
}

pub fn local(d: NaiveDateTime) -> At {
    Local.from_local_datetime(&d).earliest().map(|x| x.with_timezone(&Utc)).unwrap_or_else(|| Utc.from_utc_datetime(&d))
}

pub fn iso(d: At) -> String {
    d.format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string()
}

pub fn parse_any(s: &str) -> Option<At> {
    if let Ok(d) = DateTime::parse_from_rfc3339(s) {
        return Some(d.with_timezone(&Utc));
    }
    for f in ["%Y-%m-%dT%H:%M", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%d %H:%M:%S"] {
        if let Ok(d) = NaiveDateTime::parse_from_str(s, f) {
            return Some(local(d));
        }
    }
    parse_ymd(s).map(|d| local(d.and_hms_opt(0, 0, 0).unwrap()))
}

const DEFAULTS: [(&str, &[i64]); 3] = [("task", &[60]), ("event", &[15]), ("birthday", &[1440, 0])];

pub fn default_mins(settings: &Value, kind: &str) -> Value {
    let r = &settings["remind"];
    if r.is_object() && r[kind].is_array() {
        return r[kind].clone();
    }
    if kind == "task" && r.is_object() && r.as_object().unwrap().contains_key("min") {
        return if r["min"].is_null() { json!([]) } else { json!([r["min"]]) };
    }
    json!(DEFAULTS.iter().find(|d| d.0 == kind).map(|d| d.1).unwrap_or(&[]))
}

pub fn default_rule(settings: &Value) -> Value {
    mins_to_rule(a(&default_mins(settings, "task")))
}

pub fn mins_to_rule(mins: &[Value]) -> Value {
    let mut u: Vec<f64> = vec![];
    for m in mins.iter().filter_map(n) {
        if !u.contains(&m) {
            u.push(m);
        }
    }
    u.sort_by(|a, b| b.partial_cmp(a).unwrap());
    let rules: Vec<Value> = u.iter().map(|m| json!({"kind": "lead", "min": num(*m)})).collect();
    match rules.len() {
        0 => Value::Null,
        1 => rules[0].clone(),
        _ => Value::Array(rules),
    }
}

pub fn rules_of(r: &Value) -> Vec<Value> {
    if !t(r) {
        vec![]
    } else if let Some(x) = r.as_array() {
        x.clone()
    } else {
        vec![r.clone()]
    }
}

pub fn lead_name(min: f64, kind: &str) -> String {
    for (m, name) in leads_for(kind).iter().chain(LEADS.iter()) {
        if *m as f64 == min {
            return (*name).into();
        }
    }
    format!("За {} мин", text(&num(min)))
}

pub fn leads_text(mins: &[Value], kind: &str) -> String {
    let mut v: Vec<f64> = mins.iter().filter_map(n).collect();
    v.sort_by(|a, b| b.partial_cmp(a).unwrap());
    v.iter().map(|m| lead_name(*m, kind).to_lowercase()).collect::<Vec<_>>().join(" и ")
}

fn hm(s: &str) -> (i64, i64) {
    let mut p = s.split(':').map(|x| x.parse::<i64>().unwrap_or(0));
    (p.next().unwrap_or(0), p.next().unwrap_or(0))
}

fn at_local(day: &str, h: i64, m: i64, shift_days: i64) -> Option<At> {
    let d = add_days(parse_ymd(day)?, -shift_days);
    Some(local(d.and_hms_opt(0, 0, 0)? + Duration::minutes(h * 60 + m)))
}

pub fn fire_at(remind: &Value, task: &Value, slot: &Value) -> Option<At> {
    if !remind.is_object() {
        return None;
    }
    let due = day10(&task["due"]);
    match s(&remind["kind"]) {
        "lead" => {
            if due.is_empty() || (!t(&slot["s"]) && no_time_off()) {
                return None;
            }
            let tm = if t(&slot["s"]) { s(&slot["s"]).to_string() } else { default_time() };
            let (h, m) = hm(&tm);
            at_local(&due, h, m - n(&remind["min"]).unwrap_or(0.0) as i64, 0)
        }
        "at" => {
            if t(&remind["at"]) { parse_any(s(&remind["at"])) } else { None }
        }
        "before" => {
            if due.is_empty() {
                return None;
            }
            let tm = if t(&remind["time"]) { s(&remind["time"]).to_string() } else { default_time() };
            let (h, m) = hm(&tm);
            at_local(&due, h, m, n(&remind["days"]).unwrap_or(0.0) as i64)
        }
        _ => None,
    }
}

pub const MON_SHORT: [&str; 12] = ["янв.", "февр.", "мар.", "апр.", "мая", "июн.", "июл.", "авг.", "сент.", "окт.", "нояб.", "дек."];

pub fn remind_label(remind: &Value, task: &Value, slot: &Value) -> String {
    let mut all: Vec<At> = rules_of(remind).iter().filter_map(|r| fire_at(r, task, slot)).collect();
    all.sort();
    if all.is_empty() {
        return String::new();
    }
    let now = now_at();
    let at = all.iter().find(|d| **d > now).copied().unwrap_or(*all.last().unwrap()).with_timezone(&Local);
    format!("{} {}, {:02}:{:02}", at.day(), MON_SHORT[at.month0() as usize], at.hour(), at.minute())
}

fn published() -> Vec<String> {
    let body = CFG.lock().unwrap().last_body.clone();
    if body.is_empty() {
        return vec![];
    }
    let b: Value = serde_json::from_str(&body).unwrap_or(Value::Null);
    let xs = if b.is_array() { b } else { b["items"].clone() };
    a(&xs).iter().map(|x| text(&x["key"])).collect()
}

fn first_line(v: &Value) -> String {
    s(v).split('\n').next().unwrap_or("").chars().take(200).collect()
}

/// Имя именинника из названия события: «🎂 Аня», «День рождения: Аня» (контакты Google).
pub fn bday_name(v: &Value) -> String {
    let x = rx::first(r"^🎂\s*", &text(v), "");
    let x = rx::first(r"(?i)^(день рождения|birthday)[:\s–—-]*", &x, "");
    let x = x.trim();
    if x.is_empty() { "День рождения".into() } else { x.into() }
}

/// Дни рождения без своих напоминаний (контакты Google, «🎂» с «Напомнить: Нет») получают напоминания
/// по умолчанию из settings.remind.birthday — как в трекере (App.loadRemindEvents). Остальные события — как есть.
pub fn with_bday_defaults(events: &[Value], settings: &Value) -> Vec<Value> {
    let mins: Vec<String> = a(&default_mins(settings, "birthday")).iter().map(text).collect();
    let bday = |e: &Value| e["extendedProperties"]["private"]["sputnik"] == "birthday" || e["eventType"] == "birthday" || s(&e["calId"]).contains("#contacts@");
    events
        .iter()
        .filter_map(|e| {
            let pv = &e["extendedProperties"]["private"];
            if t(&pv["sputnikRemind"]) {
                return (pv["sputnikR"] == "1").then(|| e.clone());
            }
            if mins.is_empty() || !bday(e) {
                return None;
            }
            let mut x = e.clone();
            x["extendedProperties"]["private"]["sputnik"] = json!("birthday");
            x["extendedProperties"]["private"]["sputnikRemind"] = json!(mins.join(","));
            Some(x)
        })
        .collect()
}

fn ms(d: At) -> f64 {
    d.timestamp_millis() as f64
}

pub fn collect(lists: &[Value], by_list: &Value, lay_tasks: &Value, habit_list: &Value, cheers: &[Value], events: &[Value]) -> Vec<Value> {
    let now = ms(now_at());
    let pubs = published();
    let was = |k: &str| pubs.iter().any(|p| p == k);
    let mut items: Vec<Value> = vec![];
    for l in lists {
        for tk in a(&by_list[s(&l["id"])]) {
            if tk["status"] == "completed" || t(&tk["deleted"]) {
                continue;
            }
            let lt = &lay_tasks[s(&tk["id"])];
            for r in rules_of(&lt["remind"]) {
                let Some(at) = fire_at(&r, tk, &lt["slot"]) else { continue };
                if ms(at) < now - 864e5 {
                    continue;
                }
                let key = format!("{}|{}", text(&tk["id"]), iso(at));
                if r["kind"] == "lead" && ms(at) < now - 120e3 && !was(&key) {
                    continue;
                }
                items.push(json!({"key": key, "taskId": tk["id"], "listId": l["id"], "list": l["title"],
                    "title": if t(&tk["title"]) { tk["title"].clone() } else { json!("Без названия") },
                    "note": first_line(&tk["notes"]), "due": day10(&tk["due"]),
                    "time": if t(&lt["slot"]["s"]) { lt["slot"]["s"].clone() } else { json!("") }, "fireAt": iso(at)}));
            }
        }
    }
    for e in events {
        let pv = &e["extendedProperties"]["private"];
        let mins: Vec<Option<f64>> = text(&pv["sputnikRemind"]).split(',').filter(|x| !x.is_empty()).map(|x| x.trim().parse::<f64>().ok()).collect();
        let start = &e["start"];
        let all_day = !t(&start["dateTime"]);
        let start_at = if all_day {
            let (h, m) = hm(&default_time());
            at_local(s(&start["date"]), h, m, 0)
        } else {
            parse_any(s(&start["dateTime"]))
        };
        let Some(start_at) = start_at else { continue };
        let birthday = pv["sputnik"] == "birthday";
        for min in mins.into_iter().flatten() {
            let at = start_at - Duration::milliseconds((min * 60e3).round() as i64);
            let key = format!("ev|{}|{}", text(&e["id"]), iso(at));
            let m = ms(at);
            if m < now - 120e3 && !(was(&key) && m > now - 864e5) {
                continue;
            }
            let title = if birthday {
                json!(bday_name(&e["summary"]))
            } else if t(&e["summary"]) {
                e["summary"].clone()
            } else {
                json!("Событие")
            };
            items.push(json!({"key": key, "kind": if birthday { "birthday" } else { "event" }, "title": title,
                "note": first_line(&e["description"]), "list": if birthday { "День рождения" } else { "Google Календарь" },
                "due": if all_day { start["date"].clone() } else { json!("") },
                "start": if all_day { json!("") } else { start["dateTime"].clone() },
                "lead": lead_name(min, if birthday { "birthday" } else { "event" }), "fireAt": iso(at)}));
        }
    }
    if !habit_list.is_null() {
        for c in cheers {
            items.push(json!({"key": format!("cheer|{}|{}", text(&c["habit"]["id"]), text(&c["key"])), "kind": "milestone",
                "taskId": c["habit"]["id"], "listId": habit_list["id"], "list": habit_list["title"],
                "title": format!("🎉 {}", text(&c["text"])), "note": "Новая веха серии. Енот празднует!", "due": "", "fireAt": c["at"]}));
        }
    }
    items.sort_by(|a, b| s(&a["fireAt"]).cmp(s(&b["fireAt"])));
    items
}

pub fn assigned_items(lists: &[Value], by_list: &Value, lay_tasks: &Value, now: Option<f64>) -> Vec<Value> {
    let now = now.unwrap_or_else(|| ms(now_at()));
    let mut items = vec![];
    for l in lists {
        for tk in a(&by_list[s(&l["id"])]) {
            let g = &lay_tasks[s(&tk["id"])]["given"];
            if !t(&g["at"]) || tk["status"] == "completed" || t(&tk["deleted"]) {
                continue;
            }
            let Some(d) = parse_any(s(&g["at"])) else { continue };
            if ms(d) <= now - 864e5 {
                continue;
            }
            items.push(json!({"key": format!("given|{}|{}", text(&tk["id"]), text(&g["at"])), "kind": "assigned",
                "title": if t(&tk["title"]) { tk["title"].clone() } else { json!("Без названия") },
                "note": format!("{} отдаёт тебе задачу", if t(&g["name"]) { text(&g["name"]) } else { "Участник".into() }),
                "list": l["title"], "due": day10(&tk["due"]), "fireAt": iso(d)}));
        }
    }
    items
}

pub fn habit_items(habits: &[Value], log: &Value, now: Option<NaiveDateTime>) -> Vec<Value> {
    let now = now.unwrap_or_else(clock);
    let today = ymd(now.date());
    let mut items = vec![];
    for h in habits {
        let ra = text(&remind_at(h));
        let Some(c) = rx::cap(r"^(\d{1,2}):(\d{2})$", &ra) else { continue };
        if h["remind"]["tg"] == false {
            continue;
        }
        let (hh, mm): (u32, u32) = (c[1].as_ref().unwrap().parse().unwrap(), c[2].as_ref().unwrap().parse().unwrap());
        for i in 0..7 {
            let d = add_days(now.date(), i);
            let at = d.and_hms_opt(hh.min(23), mm.min(59), 0).unwrap();
            let day = ymd(d);
            let x = habit_day(h, log, &day, &today);
            if x["sched"] != true || x["done"] == true || ms(local(at)) < ms(local(now)) - 120e3 {
                continue;
            }
            let goal = &h["goal"];
            let gn = n(&goal["n"]);
            let mut note = vec![];
            if gn.is_some_and(|g| g > 1.0) {
                note.push(format!("Цель на день: {} {}", text(&goal["n"]), if t(&goal["unit"]) { text(&goal["unit"]) } else { "раз".into() }));
            }
            note.push(format!("Отметь до {}", text(&habit_win(h)["e"])));
            items.push(json!({"key": format!("habit|{}|{day}", text(&h["id"])), "kind": "habit",
                "habitId": h["id"], "day": day, "title": h["name"],
                "note": note.join(" · "), "list": "Привычки", "due": "", "fireAt": iso(local(at))}));
        }
    }
    items
}

pub fn habit_win_due<'a>(habits: &'a [Value], log: &Value, sent: &[Value], now: Option<NaiveDateTime>) -> Vec<&'a Value> {
    let now = now.unwrap_or_else(clock);
    let today = ymd(now.date());
    let mins = |x: &Value| {
        let (h, m) = hm(s(x));
        h * 60 + m
    };
    habits
        .iter()
        .filter(|h| {
            if !t(&h["remind"]["win"]) || sent.iter().any(|x| s(x) == format!("{}|{today}", text(&h["id"]))) {
                return false;
            }
            let w = habit_win(h);
            if w.is_null() {
                return false;
            }
            let cur = (now.hour() * 60 + now.minute()) as i64;
            let d = habit_day(h, log, &today, &today);
            d["sched"] == true && d["done"] != true && cur >= mins(&w["s"]) && cur < mins(&w["e"])
        })
        .collect()
}

