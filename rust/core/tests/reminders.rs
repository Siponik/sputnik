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
            "bdayName" => json!(r::bday_name(&x["x"])),
            _ => return None,
        })
    });
}

#[test]
fn birthdays_get_default_reminders() {
    let evs = vec![
        json!({"id": "c1", "calId": "addressbook#contacts@group.v.calendar.google.com", "summary": "День рождения: Аня", "start": {"date": "2026-10-25"}}),
        json!({"id": "s1", "summary": "🎂 Петя", "extendedProperties": {"private": {"sputnik": "birthday"}}, "start": {"date": "2026-10-26"}}),
        json!({"id": "s2", "summary": "🎂 Оля", "extendedProperties": {"private": {"sputnik": "birthday", "sputnikR": "1", "sputnikRemind": "0"}}, "start": {"date": "2026-10-27"}}),
        json!({"id": "e1", "summary": "Созвон", "start": {"dateTime": "2026-10-25T10:00:00+03:00"}}),
    ];
    let got = r::with_bday_defaults(&evs, &json!({}));
    let ids: Vec<&str> = got.iter().map(|e| s(&e["id"])).collect();
    assert_eq!(ids, ["c1", "s1", "s2"]);
    assert_eq!(got[0]["extendedProperties"]["private"]["sputnikRemind"], "1440,0");
    assert_eq!(got[2]["extendedProperties"]["private"]["sputnikRemind"], "0"); // своё не трогаем
    // «за день и в день» по умолчанию выключены — контакты молчат
    assert_eq!(r::with_bday_defaults(&evs, &json!({"remind": {"birthday": []}})).len(), 1);
    sputnik_core::habits::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 24).unwrap().and_hms_opt(9, 0, 0));
    r::set_default_time(Some("10:00"));
    let items = r::collect(&[], &json!({}), &json!({}), &Value::Null, &[], &got);
    assert!(items.iter().any(|x| x["title"] == "Аня" && x["kind"] == "birthday"));
}

#[test]
fn settings_checkboxes_pick_several() {
    // отметить второй вариант — первый остаётся
    assert_eq!(r::toggle_min(&[60], 15), vec![60, 15]);
    assert_eq!(r::toggle_min(&[60, 15], 0), vec![60, 15, 0]);
    // снять отмеченный
    assert_eq!(r::toggle_min(&[60, 15, 0], 15), vec![60, 0]);
    assert_eq!(r::toggle_min(&[60], 60), Vec::<i64>::new());
    // «не напоминать» снимает всё
    assert_eq!(r::toggle_min(&[1440, 60], -1), Vec::<i64>::new());
}
