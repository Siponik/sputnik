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
