//! Модели «Календаря»: неделя (сетка суток со сжатыми часами) и месяц, панель дня.
use super::*;
use super::today::{event_chip, habit_color};
use crate::{Band, Block, Chip, Day, Label, Opt};
use sputnik_core::calendar as cal;
use sputnik_core::habits as hb;

pub const FILTERS: [(&str, &str, &str); 4] = [("events", "События", "work"), ("tasks", "Задачи", "clay"), ("habits", "Привычки", "gold"), ("bdays", "Дни рождения", "gold")];

/// Всё, что есть у дня: (минуты начала/конца или None для «весь день», элемент-чип).
pub struct Item {
    pub s: Option<(f64, f64)>,
    pub chip: Chip,
    pub sub: String,
}

fn on(u: &Ui, f: &str) -> bool {
    !u.cal_off.iter().any(|x| x == f)
}

pub fn day_items(app: &App, u: &Ui, day: &str) -> Vec<Item> {
    let tdy = today_s();
    let mut out = vec![];
    for e in app.events_on(day) {
        let bd = App::is_birthday(&e);
        if (bd && !on(u, "bdays")) || (!bd && !on(u, "events")) {
            continue;
        }
        let chip = event_chip(&e);
        let st = cal::local_dt(s(&e["start"]["dateTime"]));
        let en = cal::local_dt(s(&e["end"]["dateTime"]));
        let span = match (st, en) {
            (Some(a0), Some(b0)) if !bd => {
                let sm = (a0.time() - chrono::NaiveTime::MIN).num_minutes() as f64;
                let em = if b0.date() > a0.date() { 1440.0 } else { (b0.time() - chrono::NaiveTime::MIN).num_minutes() as f64 };
                Some((sm, em.max(sm + 15.0)))
            }
            _ => None,
        };
        let sub = match (st, en) { (Some(a0), Some(b0)) => format!("{}–{}", a0.format("%H:%M"), b0.format("%H:%M")), _ => String::new() };
        out.push(Item { s: span, chip, sub });
    }
    if on(u, "tasks") {
        for (l, t) in app.tasks_on(day) {
            if l.starts_with("sh:") && !app.mine(&t) {
                continue;
            }
            let lt = app.lt(s(&t["id"]));
            let slot = &lt["slot"];
            let span = slot["s"].as_str().map(|a0| {
                let sm = cal::to_min(a0) as f64;
                let em = slot["e"].as_str().map(|b0| cal::to_min(b0) as f64).unwrap_or(sm + 60.0);
                (sm, em.max(sm + 15.0))
            });
            let time = slot["s"].as_str().unwrap_or("").to_string();
            out.push(Item {
                s: span,
                sub: if time.is_empty() { String::new() } else { format!("{}–{}", time, slot["e"].as_str().unwrap_or("")) },
                chip: Chip { title: ss(text(&t["title"])), hue: list_hue(app, &l), done: App::is_done(&t), kind: 1, list_id: ss(l.clone()), id: ss(text(&t["id"])), time: ss(time) },
            });
        }
    }
    if on(u, "habits") {
        let hs = app.habits();
        for b in cal::habit_blocks(&hs, app.habit_log(), day, &tdy) {
            let h = &b["h"];
            out.push(Item {
                s: Some((n(&b["s"]).unwrap_or(0.0), n(&b["e"]).unwrap_or(30.0))),
                sub: hb::span_label(h),
                chip: Chip { title: ss(text(&h["name"])), hue: habit_color(h), done: t(&b["done"]), kind: 2, list_id: ss(""), id: ss(text(&h["id"])), time: ss(s(&b["s"]).to_string()) },
            });
        }
    }
    out
}

fn habits_line(app: &App, day: &str) -> String {
    let hs = app.habits();
    let log = app.habit_log();
    let sched: Vec<&Value> = hs.iter().filter(|h| hb::scheduled_on(h, log, day)).collect();
    if sched.is_empty() || day > today_s().as_str() {
        return String::new();
    }
    format!("◆ {}/{}", sched.iter().filter(|h| hb::is_done(log, &h["id"], day)).count(), sched.len())
}

pub fn render(app: &App, u: &mut Ui, g: &S) {
    if u.cal_sel.is_empty() {
        u.cal_sel = today_s();
    }
    let mode = if u.cal_mode == "month" { "month" } else { "week" };
    let days = cal::period_days(&u.cal_sel, mode);
    g.set_cal_mode(ss(mode));
    g.set_cal_title(ss(cal::period_title(&u.cal_sel, mode)));
    g.set_cal_filters(model(FILTERS.iter().map(|(id, l, c)| Opt { id: ss(*id), label: ss(*l), hint: ss(""), hue: color(c), on: on(u, id) }).collect()));
    let tdy = today_s();
    let sel_month = &u.cal_sel[..7];
    let per_day: Vec<(String, Vec<Item>)> = days.iter().map(|d| (d.clone(), day_items(app, u, d))).collect();

    if mode == "week" {
        let all_timed: Vec<Value> = per_day.iter().flat_map(|(_, it)| it.iter().filter_map(|x| x.s.map(|(a0, b0)| json!({"s": a0, "e": b0})))).collect();
        let mut hot: Vec<i64> = vec![];
        for a0 in &u.cal_bands {
            hot.extend(*a0..24);
        }
        // раскрытая полоса раскрывает только себя: найдём её конец по сетке без неё
        let base = cal::hour_layout(&all_timed, &[], 0.0);
        let mut hot2 = vec![];
        for b in a(&base.to_json()["bands"]) {
            if u.cal_bands.contains(&b["a"].as_i64().unwrap_or(-1)) {
                hot2.extend(b["a"].as_i64().unwrap_or(0)..b["b"].as_i64().unwrap_or(0));
            }
        }
        let _ = hot;
        let lay = cal::hour_layout(&all_timed, &hot2, 0.0);
        let lj = lay.to_json();
        g.set_grid_h(lay.height as f32);
        g.set_hours(model(a(&lj["labels"]).iter().map(|l| Label { text: ss(text(&l["text"])), y: n(&l["top"]).unwrap_or(0.0) as f32, small: t(&l["small"]) }).collect()));
        g.set_bands(model(a(&lj["bands"]).iter().map(|b| Band { y: n(&b["top"]).unwrap_or(0.0) as f32, h: n(&b["h"]).unwrap_or(0.0) as f32, text: ss(text(&b["text"])), a: b["a"].as_i64().unwrap_or(0) as i32 }).collect()));
        let now_col = days.iter().position(|d| *d == tdy).map(|x| x as i32).unwrap_or(-1);
        g.set_now_col(now_col);
        g.set_now_y(lay.y_at(cal::now_min() as f64) as f32);
        let out: Vec<Day> = per_day.iter().map(|(d, items)| {
            let timed: Vec<Value> = items.iter().enumerate().filter_map(|(i, x)| x.s.map(|(a0, b0)| json!({"s": a0, "e": b0, "i": i}))).collect();
            let blocks: Vec<Block> = cal::layout_blocks(&timed, &|m| lay.y_at(m)).iter().map(|b| {
                let it = &items[b["i"].as_u64().unwrap_or(0) as usize];
                let cols = b["cols"].as_f64().unwrap_or(1.0).max(1.0);
                let col = b["col"].as_f64().unwrap_or(0.0);
                Block { title: it.chip.title.clone(), sub: ss(it.sub.clone()), y: n(&b["top"]).unwrap_or(0.0) as f32, h: n(&b["height"]).unwrap_or(20.0) as f32,
                    x: (col / cols) as f32, w: (1.0 / cols) as f32, hue: it.chip.hue, done: it.chip.done, kind: it.chip.kind,
                    list_id: it.chip.list_id.clone(), id: it.chip.id.clone() }
            }).collect();
            let all: Vec<Chip> = items.iter().filter(|x| x.s.is_none()).map(|x| x.chip.clone()).collect();
            let more = all.len().saturating_sub(3) as i32;
            let dl = cal::day_label(d);
            Day { ymd: ss(d.clone()), label: ss(text(&dl["short"]).to_uppercase()), num: ss(dl["n"].to_string()), today: *d == tdy, sel: *d == u.cal_sel,
                all: model(all), blocks: model(blocks), habits: ss(habits_line(app, d)), load: 0.0, more, in_month: true }
        }).collect();
        g.set_days(model(out));
        // свободное окно недели
        let mut m = Json::new();
        for (d, items) in &per_day {
            m.insert(d.clone(), Value::Array(items.iter().filter_map(|x| x.s.map(|(a0, b0)| json!({"s": a0, "e": b0}))).collect()));
        }
        let fut: Vec<String> = days.iter().filter(|d| d.as_str() >= tdy.as_str()).cloned().collect();
        let bw = cal::best_window(&Value::Object(m), &fut);
        g.set_free_hint(ss(if bw.is_object() {
            let dl = cal::day_label(s(&bw["day"]));
            format!("Самое свободное окно: {} {}, {}–{}", text(&dl["short"]), text(&dl["title"]), cal::from_min(n(&bw["s"]).unwrap_or(0.0) as i64), cal::from_min(n(&bw["e"]).unwrap_or(0.0) as i64))
        } else { String::new() }));
    } else {
        let out: Vec<Day> = per_day.iter().map(|(d, items)| {
            let mut chips: Vec<&Item> = items.iter().collect();
            chips.sort_by(|a0, b0| a0.s.map(|x| x.0).unwrap_or(-1.0).partial_cmp(&b0.s.map(|x| x.0).unwrap_or(-1.0)).unwrap());
            let all: Vec<Chip> = chips.iter().filter(|x| x.chip.kind != 2).map(|x| x.chip.clone()).collect();
            let busy: f64 = items.iter().filter(|x| x.chip.kind != 2).filter_map(|x| x.s.map(|(a0, b0)| b0 - a0)).sum();
            let dl = cal::day_label(d);
            Day { ymd: ss(d.clone()), label: ss(""), num: ss(dl["n"].to_string()), today: *d == tdy, sel: *d == u.cal_sel,
                more: all.len().saturating_sub(3) as i32, all: model(all), blocks: model(vec![]), habits: ss(habits_line(app, d)),
                load: (busy / 480.0) as f32, in_month: &d[..7] == sel_month }
        }).collect();
        g.set_days(model(out));
        g.set_free_hint("".into());
        g.set_now_col(-1);
    }
    // панель дня
    let dl = cal::day_label(&u.cal_sel);
    g.set_day_title(ss(format!("{}, {}", text(&dl["weekday"]), text(&dl["title"]))));
    let mut items = day_items(app, u, &u.cal_sel);
    items.sort_by(|a0, b0| a0.s.map(|x| x.0).unwrap_or(-1.0).partial_cmp(&b0.s.map(|x| x.0).unwrap_or(-1.0)).unwrap());
    g.set_day_items(model(items.into_iter().map(|x| {
        let mut c = x.chip;
        if c.time.is_empty() || x.s.is_none() {
            c.time = ss(if c.kind == 2 { String::new() } else { "день".to_string() });
        }
        c
    }).collect()));
    g.set_add_time(ss(u.add_time.clone()));
}

/// y в сетке недели → минуты (шаг 15).
pub fn min_at(app: &App, u: &Ui, y: f64) -> i64 {
    let days = cal::period_days(&u.cal_sel, "week");
    let all: Vec<Value> = days.iter().flat_map(|d| day_items(app, u, d).into_iter().filter_map(|x| x.s.map(|(a0, b0)| json!({"s": a0, "e": b0})))).collect();
    let base = cal::hour_layout(&all, &[], 0.0);
    let mut hot = vec![];
    for b in a(&base.to_json()["bands"]) {
        if u.cal_bands.contains(&b["a"].as_i64().unwrap_or(-1)) {
            hot.extend(b["a"].as_i64().unwrap_or(0)..b["b"].as_i64().unwrap_or(0));
        }
    }
    let lay = cal::hour_layout(&all, &hot, 0.0);
    let mut lo = 0.0;
    let mut hi = 1440.0;
    for _ in 0..40 {
        let mid = (lo + hi) / 2.0;
        if lay.y_at(mid) < y { lo = mid } else { hi = mid }
    }
    (((lo / 15.0).round() * 15.0) as i64).clamp(0, 1425)
}
