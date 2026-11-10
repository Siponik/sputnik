mod common;
use serde_json::{json, Value};
use sputnik_core::j::*;
use sputnik_core::reminders as r;

fn at(v: &Value) -> Option<chrono::NaiveDateTime> {
    use chrono::TimeZone;
    Some(chrono::Local.timestamp_millis_opt(int(v)?).unwrap().naive_local())
}

#[test]
fn reminders() {
    sputnik_core::habits::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0));
    common::run("reminders.json", |f, x| {
        r::set_default_time(Some(if f == "collectOff" { "off" } else if x["dt"].is_string() { s(&x["dt"]) } else { "10:00" }));
        Some(match f {
            "defaultMins" => r::default_mins(&x["s"], if x["k"].is_string() { s(&x["k"]) } else { "task" }),
            "defaultRule" => r::default_rule(&x["s"]),
            "minsToRule" => r::mins_to_rule(a(&x["m"])),
            "rulesOf" => json!(r::rules_of(&x["r"])),
            "leadName" => json!(r::lead_name(n(&x["m"])?, if x["k"].is_string() { s(&x["k"]) } else { "task" })),
            "leadsText" => json!(r::leads_text(a(&x["m"]), if x["k"].is_string() { s(&x["k"]) } else { "task" })),
            "fireAt" => r::fire_at(&x["r"], &x["t"], &x["sl"]).map(|d| json!(r::iso(d))).unwrap_or(Value::Null),
            "remindLabel" => json!(r::remind_label(&x["r"], &x["t"], &x["sl"])),
            "collect" | "collectOff" => json!(r::collect(a(&x["lists"]), &x["tasks"], &x["lay"], &x["hl"], a(&x["cheers"]), a(&x["events"]))),
            "assignedItems" => json!(r::assigned_items(a(&x["lists"]), &x["tasks"], &x["lay"], n(&x["now"]))),
            "habitItems" => json!(r::habit_items(a(&x["habits"]), &x["log"], at(&x["now"]))),
            "habitWinDue" => json!(r::habit_win_due(a(&x["habits"]), &x["log"], a(&x["sent"]), at(&x["now"])).iter().map(|h| h["id"].clone()).collect::<Vec<_>>()),
            _ => return None,
        })
    });
}
