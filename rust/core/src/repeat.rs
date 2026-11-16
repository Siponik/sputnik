//! Повторяющиеся задачи: правило в слое tasks[id].repeat = { every }. Порт tracker/src/lib/repeat.js.
use crate::dates::{add_days, js_date, parse_ymd, ymd};
use crate::j::*;
use crate::rx;
use chrono::Datelike;

pub const REPEATS: [(&str, &str, &str); 5] = [
    ("day", "Каждый день", "каждый день"),
    ("weekdays", "По будням", "по будням"),
    ("week", "Каждую неделю", "каждую неделю"),
    ("month", "Каждый месяц", "каждый месяц"),
    ("year", "Каждый год", "каждый год"),
];

pub fn repeat_label(rule: &Value) -> String {
    let e = s(&rule["every"]);
    REPEATS.iter().find(|r| r.0 == e).map(|r| r.2.to_string()).unwrap_or_default()
}

fn step(every: &str, day: &str, n: i32, anchor: &str) -> String {
    let mut d = parse_ymd(day).unwrap();
    match every {
        "day" => return ymd(add_days(d, 1)),
        "weekdays" => {
            loop {
                d = add_days(d, 1);
                if d.weekday().num_days_from_monday() < 5 {
                    break;
                }
            }
            return ymd(d);
        }
        "week" => return ymd(add_days(d, 7)),
        _ => {}
    }
    let a = parse_ymd(anchor).unwrap();
    let months = if every == "year" { 12 * n } else { n };
    let m0 = a.month0() as i32 + months;
    let (y, m) = (a.year() + m0.div_euclid(12), m0.rem_euclid(12));
    let last = js_date(y, m + 1, 0).day() as i32;
    ymd(js_date(y, m, (a.day() as i32).min(last)))
}

/// Новый срок: следующий по правилу после старого, но не раньше сегодня. Без срока — от сегодня.
pub fn next_due(rule: &Value, due: &str, today: &str) -> Option<String> {
    let e = s(&rule["every"]);
    if !REPEATS.iter().any(|r| r.0 == e) {
        return None;
    }
    let base = if due.is_empty() { today } else { due };
    let mut day = base.to_string();
    for n in 1..5000 {
        day = step(e, &day, n, base);
        if day.as_str() >= today && day.as_str() > base {
            return Some(day);
        }
    }
    None
}

/// Какие задачи пора продолжить: выполненные, с правилом и без repeatNext.
pub fn due_repeats(lists: &[Value], tasks: &Value, lay_tasks: &Value) -> Vec<Value> {
    let mut out = vec![];
    for l in lists {
        for tk in a(&tasks[s(&l["id"])]) {
            let lt = &lay_tasks[s(&tk["id"])];
            let every = &lt["repeat"]["every"];
            if t(&tk["parent"]) || s(&tk["status"]) != "completed" || !t(every) || t(&lt["repeatNext"]) || t(&tk["deleted"]) {
                continue;
            }
            out.push(json!({"listId": l["id"], "task": tk, "rule": lt["repeat"]}));
        }
    }
    out
}

/// Следующая копия уже есть: то же название, срок day, тот же список.
pub fn existing_next(list: &[Value], task: &Value, day: &str) -> Value {
    let name = s(&task["title"]).trim();
    list.iter()
        .find(|x| x["id"] != task["id"] && !t(&x["parent"]) && !t(&x["deleted"]) && s(&x["title"]).trim() == name && day10(&x["due"]) == day)
        .cloned()
        .unwrap_or(Value::Null)
}

/// Поля слоя, которые переходят к следующей задаче.
pub const CARRY: [&str; 11] = ["type", "priority", "project", "slot", "remind", "repeat", "client", "money", "tags", "topic", "pin"];

const WORDS: [(&str, &str); 5] = [
    (r"(?i)(^|\s)(каждый\s+день|ежедневно)(?=\s|$)", "day"),
    (r"(?i)(^|\s)(по\s+будням|каждый\s+будний\s+день)(?=\s|$)", "weekdays"),
    (r"(?i)(^|\s)(каждую\s+неделю|еженедельно)(?=\s|$)", "week"),
    (r"(?i)(^|\s)(каждый\s+месяц|ежемесячно)(?=\s|$)", "month"),
    (r"(?i)(^|\s)(каждый\s+год|ежегодно)(?=\s|$)", "year"),
];

/// Повтор в тексте: (правило { every } или Null, текст без этих слов).
pub fn take_repeat(text: &str) -> (Value, String) {
    for (p, every) in WORDS {
        let r = rx::rx(p);
        if let Ok(Some(c)) = r.captures(text) {
            let m = c.get(0).unwrap();
            let rest = format!("{}{}{}", &text[..m.start()], c.get(1).map_or("", |x| x.as_str()), &text[m.end()..]);
            return (json!({"every": every}), rx::all(r"\s{2,}", &rest, " ").trim().to_string());
        }
    }
    (Value::Null, text.to_string())
}
