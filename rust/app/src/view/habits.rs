//! Модели «Привычек»: карточки на сегодня и таблица месяца.
use super::*;
use super::today::{habit_color, habit_icon};
use crate::{HabitCard, MonthRow, Opt};
use chrono::Datelike;
use sputnik_core::habits as hb;

/// Состояние дня числом для окна: 0 нет · 1 сделано · 2 частично · 3 не по расписанию · 4 сегодня · 5 не считать.
pub fn st_num(st: &str, today: bool) -> i32 {
    match st {
        "d" => 1,
        "p" => 2,
        "o" | "f" => 3,
        "k" => 5,
        _ if today => 4,
        _ => 0,
    }
}

pub fn render(app: &App, u: &Ui, g: &S) {
    let log = app.habit_log();
    let tdy = today_s();
    let hs: Vec<Value> = app.habits().into_iter().filter(|h| u.habit_part == "all" || hb::part_of(h) == u.habit_part).collect();
    g.set_habit_mode(ss(u.habit_mode.clone()));
    let mut parts = vec![Opt { id: ss("all"), label: ss("Все"), hint: ss(""), hue: color("clay"), on: u.habit_part == "all" }];
    for p in a(&hb::parts()) {
        parts.push(Opt { id: ss(text(&p["id"])), label: ss(text(&p["name"])), hint: ss(""), hue: color("clay"), on: u.habit_part == s(&p["id"]) });
    }
    g.set_parts(model(parts));
    let cards: Vec<HabitCard> = hs.iter().map(|h| {
        let st = hb::stats(h, log);
        let k = st["streak"].as_i64().unwrap_or(0);
        let weekly = n(&h["perWeek"]).unwrap_or(0.0) > 0.0;
        HabitCard {
            id: ss(text(&h["id"])),
            name: ss(text(&h["name"])),
            icon: ss(habit_icon(h)),
            hue: habit_color(h),
            streak: k as i32,
            streak_label: ss(if weekly { hb::plural(k, ["неделя", "недели", "недель"]).to_string() } else { hb::plural(k, hb::unit_forms(h)).to_string() }),
            line: ss(hb::card_line(h, log)),
            sched: ss(hb::schedule_line(h)),
            done: hb::is_done(log, &h["id"], &tdy),
            count: hb::count_on(log, h, &tdy) as i32,
            goal: hb::goal_n(h) as i32,
            week: model(hb::last7(h, log).iter().map(|x| st_num(s(&x["st"]), t(&x["today"]))).collect()),
            off: !hb::scheduled_on(h, log, &tdy),
        }
    }).collect();
    g.set_habits(model(cards));
    let tip = hb::habit_tip(&hs, log).map(|t0| format!("«{}» срывается {} раз — попробуй сразу после «{}», в {}", text(&t0.habit["name"]), t0.misses, text(&t0.anchor["name"]), t0.time));
    g.set_habit_tip(ss(tip.unwrap_or_default()));
    if u.habit_mode == "month" {
        let nd = hb::now().date();
        let (y, m0) = (nd.year(), nd.month0() as i32);
        let rows: Vec<MonthRow> = hs.iter().map(|h| {
            let r = hb::month_row(h, log, y, m0);
            MonthRow { id: ss(text(&h["id"])), name: ss(text(&h["name"])), icon: ss(habit_icon(h)), hue: habit_color(h),
                cells: model(a(&r["cells"]).iter().map(|c| st_num(s(&c["st"]), t(&c["today"]))).collect()) }
        }).collect();
        let dim = rows.first().map(|_| a(&hb::month_row(&hs[0], log, y, m0)["cells"]).len()).unwrap_or(30);
        g.set_month_days(strings((1..=dim).map(|d| d.to_string()).collect()));
        g.set_habit_month(model(rows));
    }
}
