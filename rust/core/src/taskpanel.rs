//! Окно задачи v2: счётчики колонок, вид этапа, подписи напоминаний, «▸ Ещё». Порт app/lib/core/taskpanel.dart.
use crate::j::*;
use crate::reminders::{rules_of, BEFORE, LEADS};

/// Открытые задачи верхнего уровня по колонкам. Колонка — из слоя (status), иначе первая.
pub fn col_counts(list_tasks: &[Value], cols: &[Value], lay_tasks: &Value) -> Value {
    let mut m = Json::new();
    for c in cols {
        m.insert(text(&c["id"]), json!(0));
    }
    if cols.is_empty() {
        return Value::Object(m);
    }
    for tk in list_tasks {
        if t(&tk["parent"]) || tk["status"] == "completed" {
            continue;
        }
        let st = &lay_tasks[s(&tk["id"])]["status"];
        let c = if t(st) && st != "done" && m.contains_key(s(st)) { text(st) } else { text(&cols[0]["id"]) };
        let v = m[&c].as_i64().unwrap_or(0) + 1;
        m.insert(c, json!(v));
    }
    Value::Object(m)
}

pub fn stage_mode(view: &str, cols: usize) -> &'static str {
    if view == "pipe" { "track" } else if cols <= 4 { "chips" } else { "menu" }
}

pub fn lead_chip(min: f64) -> String {
    LEADS.iter().find(|l| l.0 as f64 == min).map(|l| l.1.to_lowercase()).unwrap_or_else(|| format!("за {} мин", text(&num(min))))
}

pub fn custom_chip(rule: &Value) -> String {
    if rule.is_null() {
        return String::new();
    }
    if rule["kind"] == "at" {
        let at = text(&rule["at"]);
        let mut parts = at.splitn(2, 'T');
        let d = parts.next().unwrap_or("");
        let tm = parts.next();
        let ymd: Vec<Option<i64>> = d.split('-').map(|x| x.parse().ok()).collect();
        let g = |i: usize| ymd.get(i).copied().flatten().filter(|x| *x != 0);
        let (Some(y), Some(mo), Some(dd)) = (g(0), g(1), g(2)) else { return "точное время".into() };
        let date = crate::dates::js_date(y as i32, mo as i32 - 1, dd as i32);
        use chrono::Datelike;
        let tt = match tm {
            Some(x) if !x.is_empty() => format!(" в {}", x.chars().take(5).collect::<String>()),
            _ => String::new(),
        };
        return format!("{} {}{tt}", date.day(), crate::reminders::MON_SHORT[date.month0() as usize]);
    }
    let days = if rule["days"].is_null() { json!(0) } else { rule["days"].clone() };
    let name = BEFORE.iter().filter(|b| n(&days) == Some(b.0 as f64)).last().map(|b| b.1.to_string());
    let name = name.unwrap_or_else(|| format!("За {} дн.", if rule["days"].is_null() { "null".into() } else { text(&rule["days"]) }));
    let time = if rule["time"].is_null() { "10:00".into() } else { text(&rule["time"]) };
    format!("{} в {time}", name.to_lowercase())
}

pub fn split_remind(remind: &Value) -> Value {
    let all = rules_of(remind);
    let leads: Vec<Value> = all.iter().filter(|r| r["kind"] == "lead").map(|r| r["min"].clone()).collect();
    let custom = all.iter().find(|r| r["kind"] != "lead").cloned().unwrap_or(Value::Null);
    json!({"leads": leads, "custom": custom})
}

pub fn join_remind(leads: &[Value], custom: &Value) -> Value {
    let mut all: Vec<Value> = leads.iter().map(|m| json!({"kind": "lead", "min": m})).collect();
    if !custom.is_null() {
        all.push(custom.clone());
    }
    match all.len() {
        0 => Value::Null,
        1 => all.remove(0),
        _ => Value::Array(all),
    }
}

pub fn more_filled(l: &Value) -> bool {
    t(&l["repeat"]["every"]) || t(&l["type"]) || t(&l["preview"])
}
