mod common;
use serde_json::{json, Value};
use sputnik_core::calendar as c;
use sputnik_core::j::*;

fn sv(v: &Value) -> Vec<String> {
    a(v).iter().map(|x| s(x).to_string()).collect()
}

#[test]
fn calendar() {
    sputnik_core::habits::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0));
    let cases = common::load("calendar.json");
    let hb = cases.iter().find(|x| x["fn"] == "habitBlocks").unwrap().clone();
    let type_of = |l: &str, tk: &str| (if l == "L" { "work" } else if tk == "g" { "personal" } else { "study" }).to_string();
    common::run("calendar.json", |f, x| {
        Some(match f {
            "hourLayout" => {
                let hot: Vec<i64> = a(&x["hot"]).iter().filter_map(int).collect();
                let l = c::hour_layout(a(&x["it"]), &hot, n(&x["fit"]).unwrap_or(0.0));
                let mut j = l.to_json();
                j["ys"] = Value::Array([0., 1., 59., 60., 90., 600., 630., 1000., 1439., 1440., 1500., -5.].iter().map(|m| num(l.y_at(*m))).collect());
                j
            }
            "periodDays" => json!(c::period_days(s(&x["d"]), s(&x["m"]))),
            "periodTitle" => json!(c::period_title(s(&x["d"]), s(&x["m"]))),
            "shiftPeriod" => json!(c::shift_period(s(&x["d"]), s(&x["m"]), int(&x["dir"])?)),
            "toMin" => json!(c::to_min(s(&x["s"]))),
            "fromMin" => json!(c::from_min(int(&x["n"])?)),
            "typeOfTemplate" => json!(c::type_of_template(s(&x["t"]))),
            "typeColor" => json!(c::type_color(s(&x["t"]))),
            "eventsByDay" => c::events_by_day(a(&x["events"]), &sv(&x["days"])),
            "tasksByDay" => c::tasks_by_day(a(&x["lists"]), &x["tasks"], &x["lay"], &type_of, &sv(&x["days"])),
            "layoutBlocks" => {
                let it: Vec<Value> = a(&x["it"]).iter().filter(|e| !e["s"].is_null()).cloned().collect();
                let l = c::hour_layout(&it, &[], 0.0);
                json!(c::layout_blocks(a(&x["it"]), &|m| l.y_at(m)))
            }
            "busy" => json!(c::busy(a(&x["it"]), c::GRID_START, c::GRID_END).iter().map(|p| json!([num(p[0]), num(p[1])])).collect::<Vec<_>>()),
            "busyLo" => json!(c::busy(a(&x["it"]), 0.0, 1440.0).iter().map(|p| json!([num(p[0]), num(p[1])])).collect::<Vec<_>>()),
            "busyMinutes" => num(c::busy_minutes(a(&x["it"]))),
            "bestWindow" => c::best_window(&x["di"], &sv(&x["days"])),
            "habitDay" => {
                let h = a(&hb["habits"]).iter().find(|h| h["id"] == x["id"]).cloned().unwrap();
                c::habit_day(&h, &hb["log"], s(&x["d"]), "2026-10-21")
            }
            "habitBlocks" => json!(c::habit_blocks(a(&x["habits"]), &x["log"], s(&x["d"]), "2026-10-21")),
            "dayLabel" => c::day_label(s(&x["d"])),
            "whenLabel" => json!(c::when_label(s(&x["d"]))),
            "hoursLabel" => json!(c::hours_label(n(&x["n"]).unwrap_or(0.0))),
            _ => return None,
        })
    });
}
