//! Модели «Календаря»: неделя (сетка суток со сжатыми часами) и месяц, панель дня.
use super::*;
use super::today::{event_chip, habit_color};
use crate::{Band, Block, Chip, Day, Label, Opt};
use sputnik_core::calendar as cal;
use sputnik_core::habits as hb;

pub const FILTERS: [(&str, &str, &str); 4] = [("events", "События", "#A3A5AE"), ("tasks", "Задачи", "clay"), ("habits", "Привычки", "gold"), ("bdays", "Дни рождения", "violet")];

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

/// Привычки дня: «2/3» и точки (1 — сделано, 2 — сегодня, ещё нет, 0 — не сделано, 3 — впереди/не по расписанию).
fn habits_line(app: &App, day: &str) -> (String, Vec<i32>) {
    let hs = app.habits();
    let log = app.habit_log();
    let tdy = today_s();
    let mut dots = vec![];
    let mut done = 0;
    for h in &hs {
        let x = cal::habit_day(h, log, day, &tdy);
        let d = x["done"] == true;
        if d { done += 1; }
        dots.push(if d { 1 } else if x["sched"] != true || day > tdy.as_str() { 3 } else if day == tdy { 2 } else { 0 });
    }
    if hs.is_empty() {
        return (String::new(), dots);
    }
    (format!("{}/{}", done, hs.len()), dots)
}

const MONTHS_UP: [&str; 12] = ["ЯНВАРЬ", "ФЕВРАЛЬ", "МАРТ", "АПРЕЛЬ", "МАЙ", "ИЮНЬ", "ИЮЛЬ", "АВГУСТ", "СЕНТЯБРЬ", "ОКТЯБРЬ", "НОЯБРЬ", "ДЕКАБРЬ"];
const MONTHS_GEN_UP: [&str; 12] = ["ЯНВАРЯ", "ФЕВРАЛЯ", "МАРТА", "АПРЕЛЯ", "МАЯ", "ИЮНЯ", "ИЮЛЯ", "АВГУСТА", "СЕНТЯБРЯ", "ОКТЯБРЯ", "НОЯБРЯ", "ДЕКАБРЯ"];

fn pd(d: &str) -> chrono::NaiveDate {
    chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").unwrap_or_default()
}

/// «ЧТ 05».
fn short_up(d: &str) -> String {
    let dl = cal::day_label(d);
    format!("{} {:02}", text(&dl["short"]).to_uppercase(), dl["n"].as_u64().unwrap_or(0))
}

pub fn render(app: &App, u: &mut Ui, g: &S) {
    if u.cal_sel.is_empty() {
        u.cal_sel = today_s();
    }
    let mode = if u.cal_mode == "month" { "month" } else { "week" };
    let days = cal::period_days(&u.cal_sel, mode);
    g.set_cal_mode(ss(mode));
    let sd = pd(&u.cal_sel);
    use chrono::Datelike;
    g.set_cal_title(ss(format!("{} {}", MONTHS_UP[sd.month0() as usize], sd.year())));
    let mdays = { let (y, m) = (sd.year(), sd.month()); let nx = if m == 12 { chrono::NaiveDate::from_ymd_opt(y + 1, 1, 1) } else { chrono::NaiveDate::from_ymd_opt(y, m + 1, 1) }; nx.map(|x| x.pred_opt().unwrap().day()).unwrap_or(30) };
    g.set_cal_sub(ss(if mode == "week" { format!("НЕДЕЛЯ {}", sd.iso_week().week()) } else { format!("{} ИЗ {}", sd.day(), mdays) }));
    g.set_free_col(-1);
    g.set_free_free(-1);
    u.cal_free = None;
    g.set_cal_filters(model(FILTERS.iter().map(|(id, l, c)| Opt { id: ss(*id), label: ss(l.to_uppercase()), hint: ss(""), hue: color(c), on: on(u, id) }).collect()));
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
                Block { title: it.chip.title.clone(), sub: ss(if it.chip.kind == 1 { it.chip.time.to_string() } else { it.sub.clone() }), y: n(&b["top"]).unwrap_or(0.0) as f32, h: n(&b["height"]).unwrap_or(20.0) as f32,
                    x: (col / cols) as f32, w: (1.0 / cols) as f32, hue: it.chip.hue, done: it.chip.done, kind: it.chip.kind,
                    list_id: it.chip.list_id.clone(), id: it.chip.id.clone() }
            }).collect();
            let all: Vec<Chip> = items.iter().filter(|x| x.s.is_none()).map(|x| x.chip.clone()).collect();
            let more = all.len().saturating_sub(3) as i32;
            let dl = cal::day_label(d);
            let (hl, hd) = habits_line(app, d);
            Day { ymd: ss(d.clone()), label: ss(short_up(d)), num: ss(dl["n"].to_string()), today: *d == tdy, sel: *d == u.cal_sel,
                all: model(all), blocks: model(blocks), habits: ss(hl), load: 0.0, more, in_month: true, hdots: model(hd) }
        }).collect();
        g.set_days(model(out));
        // свободное окно недели
        let mut m = Json::new();
        for (d, items) in &per_day {
            m.insert(d.clone(), Value::Array(items.iter().filter_map(|x| x.s.map(|(a0, b0)| json!({"s": a0, "e": b0}))).collect()));
        }
        let fut: Vec<String> = days.iter().filter(|d| d.as_str() >= tdy.as_str()).cloned().collect();
        let bw = cal::best_window(&Value::Object(m), &fut);
        let (a0, b0) = (days.first().map(|x| pd(x)).unwrap_or_default(), days.last().map(|x| pd(x)).unwrap_or_default());
        g.set_cal_head(ss(if a0.month() == b0.month() { format!("НЕДЕЛЯ · {:02}–{:02} {}", a0.day(), b0.day(), MONTHS_GEN_UP[b0.month0() as usize]) }
            else { format!("НЕДЕЛЯ · {:02} {} – {:02} {}", a0.day(), &MONTHS_GEN_UP[a0.month0() as usize][..6], b0.day(), &MONTHS_GEN_UP[b0.month0() as usize][..6]) }));
        let busy: f64 = per_day.iter().flat_map(|(_, it)| it.iter().filter(|x| x.chip.kind != 2).filter_map(|x| x.s.map(|(a0, b0)| b0 - a0))).sum();
        let hrs = (busy / 60.0).round() as i64;
        g.set_cal_head_r(ss(format!("ЗАНЯТО {} Ч", hrs)));
        let dues = per_day.iter().flat_map(|(_, it)| it.iter().filter(|x| x.chip.kind == 1 && x.s.is_none())).count();
        g.set_cal_foot(ss(format!("ЗАГРУЗКА {} Ч · СРОКИ {}", hrs, dues)));
        let free_day = per_day.iter().position(|(d, it)| d.as_str() >= tdy.as_str() && it.iter().all(|x| x.chip.kind == 2));
        g.set_free_free(free_day.map(|x| x as i32).unwrap_or(-1));
        if bw.is_object() {
            let (fs, fe) = (n(&bw["s"]).unwrap_or(0.0), n(&bw["e"]).unwrap_or(0.0));
            let dd = s(&bw["day"]).to_string();
            let (ts, te) = (cal::from_min(fs as i64), cal::from_min(fe as i64));
            g.set_free_hint(ss(format!("Свободно {}–{}", ts, te)));
            g.set_cal_foot_hl(ss(format!("СВОБОДНЕЕ ВСЕГО · {} {}–{}", text(&cal::day_label(&dd)["short"]).to_uppercase(), (fs / 60.0) as i64, (fe / 60.0).ceil() as i64)));
            if let Some(i) = days.iter().position(|x| *x == dd) {
                g.set_free_col(i as i32);
                g.set_free_y(lay.y_at(fs) as f32);
                g.set_free_h((lay.y_at(fe) - lay.y_at(fs)) as f32);
            }
            u.cal_free = Some((dd, ts));
        } else {
            g.set_free_hint("".into());
            g.set_cal_foot_hl("".into());
        }
        g.set_cal_rule(ss("ПН — ВС · 7 ДНЕЙ · ЗАНЯТЫЕ ЧАСЫ КРУПНО, ОСТАЛЬНОЕ СЖАТО"));
        let evs = per_day.iter().flat_map(|(_, it)| it.iter().filter(|x| x.chip.kind == 0)).count();
        let tks = per_day.iter().flat_map(|(_, it)| it.iter().filter(|x| x.chip.kind == 1)).count();
        g.set_cal_stamp(model(vec![ss("ЛИСТ · КАЛЕНДАРЬ · НЕДЕЛЯ"), ss(sd_stamp()), ss(format!("СОБЫТИЙ {:02}", evs)), ss(format!("ЗАДАЧ {:02}", tks))]));
    } else {
        let out: Vec<Day> = per_day.iter().map(|(d, items)| {
            let mut chips: Vec<&Item> = items.iter().collect();
            chips.sort_by(|a0, b0| a0.s.map(|x| x.0).unwrap_or(-1.0).partial_cmp(&b0.s.map(|x| x.0).unwrap_or(-1.0)).unwrap());
            let all: Vec<Chip> = chips.iter().filter(|x| x.chip.kind != 2).map(|x| x.chip.clone()).collect();
            let busy: f64 = items.iter().filter(|x| x.chip.kind != 2).filter_map(|x| x.s.map(|(a0, b0)| b0 - a0)).sum();
            let dl = cal::day_label(d);
            let (hl, hd) = habits_line(app, d);
            Day { ymd: ss(d.clone()), label: ss(""), num: ss(format!("{:02}", dl["n"].as_u64().unwrap_or(0))), today: *d == tdy, sel: *d == u.cal_sel,
                more: all.len().saturating_sub(3) as i32, all: model(all), blocks: model(vec![]), habits: ss(hl),
                load: (busy / 480.0) as f32, in_month: &d[..7] == sel_month, hdots: model(hd) }
        }).collect();
        let cnt = per_day.iter().filter(|(d, _)| &d[..7] == sel_month).flat_map(|(_, it)| it.iter().filter(|x| x.chip.kind != 2)).count();
        let bds = per_day.iter().filter(|(d, _)| &d[..7] == sel_month).flat_map(|(_, it)| it.iter().filter(|x| x.chip.kind == 3)).count();
        g.set_cal_head(ss(format!("{} {}", MONTHS_UP[sd.month0() as usize], sd.year())));
        g.set_cal_head_r(ss(format!("{} ДНЕЙ · {} ДЕЛ", mdays, cnt)));
        g.set_days(model(out));
        g.set_free_hint("".into());
        g.set_now_col(-1);
        g.set_cal_foot(ss("ПОЛОСКА ВНИЗУ КЛЕТКИ"));
        g.set_cal_foot_hl(ss("ЗОЛОТО — ПРИВЫЧКИ СДЕЛАНЫ"));
        let (a0, b0) = (days.first().map(|x| pd(x)).unwrap_or_default(), days.last().map(|x| pd(x)).unwrap_or_default());
        g.set_cal_rule(ss(format!("{} — {} · {} НЕДЕЛЬ", a0.format("%d.%m"), b0.format("%d.%m"), days.len() / 7)));
        g.set_cal_stamp(model(vec![ss("ЛИСТ · КАЛЕНДАРЬ · МЕСЯЦ"), ss(sd_stamp()), ss(format!("ДЕЛ {:02}", cnt)), ss(format!("ДР {:02}", bds))]));
    }
    // панель дня
    let dl = cal::day_label(&u.cal_sel);
    g.set_day_title(ss(format!("{}, {}", text(&dl["weekday"]), text(&dl["title"]))));
    let rel = if u.cal_sel == tdy { " · СЕГОДНЯ".to_string() } else if u.cal_sel == (pd(&tdy) + chrono::Duration::days(1)).format("%Y-%m-%d").to_string() { " · ЗАВТРА".into() } else { String::new() };
    g.set_day_head(ss(format!("{}{}", short_up(&u.cal_sel), rel)));
    let mut items = day_items(app, u, &u.cal_sel);
    // привычки дня — отдельным разделом
    let log = app.habit_log();
    let hs = app.habits();
    let hopts: Vec<Opt> = hs.iter().filter(|h| hb::scheduled_on(h, log, &u.cal_sel)).map(|h| {
        let goal = hb::goal_n(h);
        let hint = if goal > 1 { format!("{}/{}", hb::count_on(log, h, &u.cal_sel), goal) } else {
            let k = hb::stats(h, log)["streak"].as_i64().unwrap_or(0);
            let weekly = n(&h["perWeek"]).unwrap_or(0.0) > 0.0;
            if k == 0 { String::new() } else { format!("{} {}", k, if weekly { "НЕД" } else { "ДН" }) }
        };
        Opt { id: ss(text(&h["id"])), label: ss(text(&h["name"])), hint: ss(hint), hue: habit_color(h), on: hb::is_done(log, &h["id"], &u.cal_sel) }
    }).collect();
    g.set_day_habits_sum(ss(format!("ПРИВЫЧКИ · {} / {}", hopts.iter().filter(|o| o.on).count(), hopts.len())));
    g.set_day_habits(model(hopts));
    items.retain(|x| x.chip.kind != 2);
    items.sort_by(|a0, b0| a0.s.map(|x| x.0).unwrap_or(9999.0).partial_cmp(&b0.s.map(|x| x.0).unwrap_or(9999.0)).unwrap());
    g.set_day_count(ss(format!("{} {}", items.len(), hb::plural(items.len() as i64, ["ДЕЛО", "ДЕЛА", "ДЕЛ"]))));
    let nm = cal::now_min() as f64;
    let next = if u.cal_sel == tdy { items.iter().position(|x| !x.chip.done && x.s.map(|(_, e)| e > nm).unwrap_or(false)) } else { None };
    g.set_day_next(next.map(|x| x as i32).unwrap_or(-1));
    g.set_day_items(model(items.into_iter().map(|x| {
        let mut c = x.chip;
        if c.time.is_empty() || x.s.is_none() {
            c.time = ss("ДЕНЬ");
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

fn sd_stamp() -> String {
    pd(&today_s()).format("%d.%m.%y").to_string()
}
