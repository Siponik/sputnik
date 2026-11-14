mod common;
use serde_json::{json, Value};
use sputnik_core::habits as h;
use sputnik_core::j::*;

#[test]
fn habits() {
    h::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0));
    let cases = common::load("habits.json");
    let habits = cases[0]["habits"].clone();
    let log = cases[0]["log"].clone();
    let hb = |id: &Value| a(&habits).iter().find(|x| x["id"] == *id).cloned().unwrap_or(json!({}));
    common::run("habits.json", |f, x| {
        let hh = hb(&x["id"]);
        let (y, m) = (int(&x["y"]).unwrap_or(0) as i32, int(&x["m"]).unwrap_or(0) as i32);
        Some(match f {
            "setup" => x["out"].clone(),
            "stats" => h::stats(&hh, &log),
            "monthGrid" => h::month_grid(&hh, &log, y, m),
            "monthRow" => h::month_row(&hh, &log, y, m),
            "dayState" => json!(h::day_state(&hh, &log, s(&x["d"]), None)),
            "scheduledOn" => json!(h::scheduled_on(&hh, &log, s(&x["d"]))),
            "countOn" => json!(h::count_on(&log, &hh, s(&x["d"]))),
            "nextMark" => h::next_mark(&log, &hh, s(&x["d"])),
            "dayMark" => h::day_mark(&hh, s(&x["st"])),
            "last7" => json!(h::last7(&hh, &log)),
            "milestoneDate" => json!(h::milestone_date(&hh, &log, int(&x["s"])?)),
            "broken" => h::broken(&hh, &log),
            "partOf" => json!(h::part_of(&hh)),
            "partName" => json!(h::part_name(&hh)),
            "habitWin" => h::habit_win(&hh),
            "winLabel" => json!(h::win_label(&hh)),
            "remindAt" => h::remind_at(&hh),
            "habitSpan" => h::habit_span(&hh),
            "spanLabel" => json!(h::span_label(&hh)),
            "unitForms" => json!(h::unit_forms(&hh)),
            "scheduleLine" => json!(h::schedule_line(&hh)),
            "goalN" => json!(h::goal_n(&hh)),
            "cardLine" => json!(h::card_line(&hh, &log)),
            "totalDone" => json!(h::total_done(&hh, &log)),
            "moveWin" => h::move_win(&hh, &x["t"]),
            "moveEnd" => json!(h::move_end(&hh, &x["t"])),
            "monthSummary" => h::month_summary(a(&habits), &log, y, m),
            "habitTip" => match h::habit_tip(a(&habits), &log) {
                None => Value::Null,
                Some(tp) => json!({"habit": tp.habit["id"], "anchor": tp.anchor["id"], "time": tp.time, "misses": tp.misses}),
            },
            "sortHabits" => json!(h::sort_habits(a(&habits)).iter().map(|e| e["id"].clone()).collect::<Vec<_>>()),
            "milestonePos" => num(h::milestone_pos(n(&x["n"])?)),
            "nextMilestone" => json!(h::next_milestone(n(&x["n"])?)),
            "plural" => json!(h::plural(int(&x["n"])?, ["день", "дня", "дней"])),
            "scheduleLabel" => json!(h::schedule_label(&x["d"])),
            "partWin" => h::part_win(&x["p"]),
            "cleanWin" => h::clean_win(&x["w"]),
            "wholePart" => json!(h::whole_part(&x["w"])),
            "winFields" => h::win_fields(&x["w"]),
            "normTime" => h::norm_time(&x["r"], x["e"] == true),
            "normEnd" => json!(h::norm_end(&x["t"], &x["e"])),
            "endAfter" => json!(h::end_after(&x["t"], int(&x["m"]).unwrap_or(60))),
            "dayOffset" => json!(sputnik_core::dates::ymd(h::day_offset(int(&x["i"])?))),
            _ => return None,
        })
    });
}

/// Патчи окна правки привычки (#193): расписание, «когда», цель.
#[test]
fn habit_edit_patches() {
    h::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0));
    // расписание: daily | weekdays | days (custom) | week
    assert_eq!(h::edit_schedule("daily", &[], 0), json!({"days": [0, 1, 2, 3, 4, 5, 6], "perWeek": Value::Null, "custom": Value::Null}));
    assert_eq!(h::edit_schedule("weekdays", &[], 0)["days"], json!([0, 1, 2, 3, 4]));
    assert_eq!(h::edit_schedule("days", &[4, 2, 2, 9], 0), json!({"days": [2, 4], "perWeek": Value::Null, "custom": true}));
    // пустые «свои дни» — сегодня (среда 21.10.2026 → 2), расписание не остаётся пустым
    assert_eq!(h::edit_schedule("days", &[], 0)["days"], json!([2]));
    assert_eq!(h::edit_schedule("week", &[], 8), json!({"days": [0, 1, 2, 3, 4, 5, 6], "perWeek": 6, "custom": Value::Null}));
    // «когда»: обе границы — своё окно и часть дня сброшена; без границ — только часть дня
    assert_eq!(h::edit_when("morning", &Value::Null, &Value::Null), json!({"part": "morning", "win": Value::Null, "time": Value::Null, "end": Value::Null}));
    assert_eq!(h::edit_when("day", &json!("07:00"), &json!("09:00")), json!({"win": {"s": "07:00", "e": "09:00"}, "time": "07:00", "end": "09:00", "part": Value::Null}));
    // конец «24:00» хранится в win, поле end пустое
    assert_eq!(h::edit_when("any", &json!("21:00"), &json!("24:00")), json!({"win": {"s": "21:00", "e": "24:00"}, "time": "21:00", "end": Value::Null, "part": Value::Null}));
    // кривое окно (конец раньше начала) — часть дня
    assert_eq!(h::edit_when("evening", &json!("09:00"), &json!("07:00")), json!({"part": "evening", "win": Value::Null, "time": Value::Null, "end": Value::Null}));
    // неизвестная часть дня — «когда угодно»
    assert_eq!(h::edit_when("ночь", &Value::Null, &Value::Null)["part"], json!("any"));
    // цель
    assert_eq!(h::edit_goal(0), json!({"goal": Value::Null}));
    assert_eq!(h::edit_goal(8), json!({"goal": {"n": 8, "unit": "раз"}}));
    assert_eq!(h::edit_goal(1000)["goal"]["n"], json!(999));
}
