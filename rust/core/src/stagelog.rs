//! Время по этапам конвейера (п.33): `stageLog: [{ stage, at }]` в слое задачи.
//! Запись добавляется при каждой смене этапа, в том числе назад.
use crate::j::*;
use chrono::{Local, NaiveDate, TimeZone};

/// Новая запись в журнал; повтор того же этапа подряд не пишется.
pub fn push(log: &Value, stage: &str, at: f64) -> Value {
    let mut v: Vec<Value> = a(log).to_vec();
    if v.last().map(|x| s(&x["stage"]) == stage).unwrap_or(false) {
        return json!(v);
    }
    v.push(json!({"stage": stage, "at": at as i64}));
    json!(v)
}

fn day(ms: f64) -> Option<NaiveDate> {
    Local.timestamp_millis_opt(ms as i64).single().map(|d| d.date_naive())
}

/// Отрезки по этапам: { stage, from, to (YYYY-MM-DD), days, cur }. Дни — календарные, не меньше 1.
/// Последний отрезок идёт до `now` и помечен cur.
pub fn spans(log: &Value, now: f64) -> Vec<Value> {
    let v = a(log);
    let mut out = vec![];
    for (i, e) in v.iter().enumerate() {
        let from = n(&e["at"]).unwrap_or(0.0);
        let cur = i + 1 == v.len();
        let to = if cur { now } else { n(&v[i + 1]["at"]).unwrap_or(now) };
        let (Some(a0), Some(b0)) = (day(from), day(to)) else { continue };
        let days = (b0 - a0).num_days().max(1);
        out.push(json!({"stage": e["stage"], "from": crate::dates::ymd(a0), "to": crate::dates::ymd(b0), "days": days, "cur": cur}));
    }
    out
}

/// Дней от первой записи до now (не меньше 1), 0 — журнала нет.
pub fn total_days(log: &Value, now: f64) -> i64 {
    let Some(first) = a(log).first().and_then(|e| n(&e["at"])) else { return 0 };
    match (day(first), day(now)) {
        (Some(a0), Some(b0)) => (b0 - a0).num_days().max(1),
        _ => 0,
    }
}

/// Сумма дней по этапу (этап мог проходиться несколько раз).
pub fn days_in(log: &Value, stage: &str, now: f64) -> i64 {
    spans(log, now).iter().filter(|x| s(&x["stage"]) == stage).map(|x| x["days"].as_i64().unwrap_or(0)).sum()
}
