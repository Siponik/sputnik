//! Серии привычек, календарь месяца, окно времени, отметки, советы. Порт app/lib/core/habits.dart.
//! Отметки: log["<habitId>|ГГГГ-ММ-ДД"] = { done, rest, skip, n, t }. Привычка — запись слоя habits[id] с полем id.
//! «Сейчас» — [now()], в тестах подменяется [set_clock].
use crate::dates::{add_days, js_date, parse_ymd, ymd};
use crate::j::*;
use crate::rx;
use chrono::{Datelike, NaiveDate, NaiveDateTime};
use std::cell::Cell;

thread_local! {
    static CLOCK: Cell<Option<NaiveDateTime>> = const { Cell::new(None) };
}

/// Подменить «сейчас» (тесты). None — настоящее время.
pub fn set_clock(t: Option<NaiveDateTime>) {
    CLOCK.with(|c| c.set(t));
}

pub fn now() -> NaiveDateTime {
    CLOCK.with(|c| c.get()).unwrap_or_else(|| chrono::Local::now().naive_local())
}

fn today_d() -> NaiveDate {
    now().date()
}

pub const WEEKDAYS: [&str; 7] = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"];
pub const MILESTONES: [i64; 4] = [7, 21, 50, 100];
pub const MONTH_NAMES: [&str; 12] = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
const MONTH_SHORT: [&str; 12] = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
pub const MONTH_GEN: [&str; 12] = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
const WEEKDAY_FULL: [&str; 7] = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"];

fn round(x: f64) -> i64 {
    (x + 0.5).floor() as i64
}

pub fn day_offset(k: i64) -> NaiveDate {
    add_days(today_d(), k)
}

pub fn dow(d: NaiveDate) -> i64 {
    d.weekday().num_days_from_monday() as i64
}

pub fn log_key(id: &Value, date: &str) -> String {
    format!("{}|{date}", if id.is_null() { "null".into() } else { text(id) })
}

fn entry<'a>(log: &'a Value, id: &Value, date: &str) -> &'a Value {
    &log[log_key(id, date).as_str()]
}

pub fn is_done(log: &Value, id: &Value, date: &str) -> bool {
    t(&entry(log, id, date)["done"])
}

pub fn is_off(log: &Value, id: &Value, date: &str) -> bool {
    let e = entry(log, id, date);
    (t(&e["rest"]) || t(&e["skip"])) && !is_done(log, id, date)
}

pub fn next_milestone(k: f64) -> i64 {
    MILESTONES.iter().copied().find(|m| *m as f64 > k).unwrap_or(100)
}

pub fn milestone_pos(k: f64) -> f64 {
    let pts = [0.0, 7.0, 21.0, 50.0, 100.0];
    for q in 1..pts.len() {
        if k <= pts[q] {
            return ((q as f64 - 1.0 + (k - pts[q - 1]) / (pts[q] - pts[q - 1])) / 4.0) * 100.0;
        }
    }
    100.0
}

pub fn plural<'a>(k: i64, forms: [&'a str; 3]) -> &'a str {
    let (a, b) = (k % 10, k % 100);
    if a == 1 && b != 11 {
        forms[0]
    } else if (2..=4).contains(&a) && !(12..=14).contains(&b) {
        forms[1]
    } else {
        forms[2]
    }
}

fn days_of(h: &Value) -> Vec<i64> {
    let d = a(&h["days"]);
    if d.is_empty() { (0..7).collect() } else { d.iter().filter_map(int).collect() }
}

fn per_week(h: &Value) -> f64 {
    n(&h["perWeek"]).unwrap_or(0.0)
}

fn created(h: &Value) -> Option<String> {
    t(&h["createdAt"]).then(|| day10(&h["createdAt"]))
}

fn monday_of(d: NaiveDate) -> NaiveDate {
    add_days(d, -dow(d))
}

fn pd(x: &str) -> NaiveDate {
    parse_ymd(x).unwrap_or_else(|| NaiveDate::from_ymd_opt(1970, 1, 1).unwrap())
}

/// Текущая серия, лучшая серия и сетка за 13 недель.
pub fn stats(h: &Value, log: &Value) -> Value {
    if per_week(h) > 0.0 {
        return week_stats(h, log);
    }
    let days = days_of(h);
    let sched = |d: NaiveDate| days.contains(&dow(d));
    let cr = created(h).unwrap_or_else(|| ymd(day_offset(-365)));
    let id = &h["id"];
    let today_done = is_done(log, id, &ymd(day_offset(0)));
    let mut streak = 0;
    for i in (if today_done { 0 } else { 1 })..=730 {
        let d = day_offset(-i);
        let st = ymd(d);
        if st < cr && !is_done(log, id, &st) {
            break;
        }
        if !sched(d) || is_off(log, id, &st) {
            continue;
        }
        if is_done(log, id, &st) { streak += 1 } else { break }
    }
    let (mut best, mut run) = (0, 0);
    for i in (0..=730).rev() {
        let d = day_offset(-i);
        let st = ymd(d);
        if !sched(d) || is_off(log, id, &st) {
            continue;
        }
        if is_done(log, id, &st) {
            run += 1;
            best = best.max(run);
        } else if i != 0 && st >= cr {
            run = 0;
        }
    }
    let today = day_offset(0);
    let monday = day_offset(-dow(today) - 7 * 12);
    let (mut cells, mut months) = (vec![], vec![]);
    for w in 0..13 {
        for k in 0..7 {
            let d = add_days(monday, w * 7 + k);
            let st = ymd(d);
            let diff = (d - today).num_days();
            let state = if diff > 0 {
                if sched(d) { "plan" } else { "future" }
            } else if is_done(log, id, &st) {
                "done"
            } else if !sched(d) {
                "rest"
            } else if st < cr {
                "before"
            } else if is_off(log, id, &st) {
                "off"
            } else if diff == 0 {
                "today"
            } else {
                "miss"
            };
            cells.push(json!({"date": st, "state": state, "today": diff == 0, "title": format!("{} {}", d.day(), MONTH_GEN[d.month0() as usize])}));
            if k == 0 && (w == 0 || d.day() <= 7) {
                months.push(json!({"col": w, "name": MONTH_SHORT[d.month0() as usize]}));
            }
        }
    }
    if months.len() > 1 && int(&months[1]["col"]).unwrap() - int(&months[0]["col"]).unwrap() < 3 {
        months.remove(0);
    }
    json!({"streak": streak, "best": best, "todayDone": today_done, "cells": cells, "months": months})
}

/// Календарь одного месяца (month — с 0, как в JS).
pub fn month_grid(h: &Value, log: &Value, year: i32, month: i32) -> Value {
    let days = days_of(h);
    let cr = created(h).unwrap_or_else(|| "0000".into());
    let today = ymd(day_offset(0));
    let first = js_date(year, month, 1);
    let dim = js_date(year, month + 1, 0).day() as i64;
    let lead = dow(first);
    let mut cells = vec![];
    let (mut done, mut sched) = (0, 0);
    let total = ((lead + dim) as f64 / 7.0).ceil() as i64 * 7;
    for i in 0..total {
        let k = i - lead + 1;
        if k < 1 || k > dim {
            cells.push(json!({"key": format!("b{i}"), "n": "", "state": "blank", "title": ""}));
            continue;
        }
        let d = js_date(year, month, k as i32);
        let st = ymd(d);
        let dd = is_done(log, &h["id"], &st);
        let sch = days.contains(&dow(d));
        let (state, what) = if st > today {
            ("fut", if sch { "по плану" } else { "не по расписанию" })
        } else if dd {
            done += 1;
            sched += 1;
            (if st == today { "today done" } else { "done" }, "сделано")
        } else if st == today {
            if sch {
                sched += 1;
            }
            (if sch { "today" } else { "off" }, if sch { "сегодня" } else { "не по расписанию" })
        } else if st < cr {
            ("off", "привычки ещё не было")
        } else if !sch {
            ("off", "не по расписанию")
        } else if is_off(log, &h["id"], &st) {
            ("off", "выходной, серия сохранена")
        } else {
            sched += 1;
            ("miss", "пропуск")
        };
        cells.push(json!({"key": st, "n": k, "state": state, "title": format!("{k} {} · {what}", MONTH_GEN[month as usize])}));
    }
    json!({"cells": cells, "done": done, "sched": sched})
}

pub fn schedule_label(days: &Value) -> String {
    let d = a(days);
    if d.is_empty() || d.len() == 7 {
        return "Каждый день".into();
    }
    let has = |x: i64| d.iter().any(|v| int(v) == Some(x));
    if d.len() == 5 && (0..5).all(has) {
        return "По будням".into();
    }
    let mut v: Vec<&Value> = d.iter().collect();
    v.sort_by(|x, y| cmp16(&text(x), &text(y)));
    v.iter().map(|x| WEEKDAYS[int(x).unwrap_or(0).clamp(0, 6) as usize]).collect::<Vec<_>>().join(" · ")
}

// ---------- карточки ----------

pub fn parts() -> Value {
    json!([
        {"id": "morning", "name": "Утро", "win": {"s": "06:00", "e": "12:00"}},
        {"id": "day", "name": "День", "win": {"s": "12:00", "e": "18:00"}},
        {"id": "evening", "name": "Вечер", "win": {"s": "18:00", "e": "24:00"}},
        {"id": "any", "name": "Когда угодно", "win": null},
    ])
}

pub const PART_IDS: [&str; 4] = ["morning", "day", "evening", "any"];

pub fn part_of(h: &Value) -> String {
    let p = s(&h["part"]);
    if PART_IDS.contains(&p) {
        return p.into();
    }
    match rx::cap(r"^(\d{1,2}):", s(&h["time"])) {
        None => "any".into(),
        Some(c) => {
            let hh: i64 = c[1].as_ref().unwrap().parse().unwrap_or(0);
            if hh < 12 { "morning" } else if hh < 18 { "day" } else { "evening" }.into()
        }
    }
}

pub fn part_name(h: &Value) -> String {
    let p = part_of(h);
    s(&a(&parts()).iter().find(|x| s(&x["id"]) == p).unwrap()["name"]).into()
}

fn min_of(v: &Value) -> Option<i64> {
    let c = rx::cap(r"^(\d{1,2}):(\d{2})$", s(v))?;
    let (h, m): (i64, i64) = (c[1].as_ref()?.parse().ok()?, c[2].as_ref()?.parse().ok()?);
    (h < 24 && m < 60).then_some(h * 60 + m)
}

pub fn hhmm(m: i64) -> String {
    format!("{:02}:{:02}", m / 60, m % 60)
}

fn min_end(v: &Value) -> Option<i64> {
    if s(v) == "24:00" { Some(1440) } else { min_of(v) }
}

fn hhmm_end(m: i64) -> String {
    if m >= 1440 { "24:00".into() } else { hhmm(m) }
}

pub fn part_win(p: &Value) -> Value {
    a(&parts()).iter().find(|x| x["id"] == *p).map(|x| x["win"].clone()).unwrap_or(Value::Null)
}

pub fn clean_win(w: &Value) -> Value {
    match (min_of(&w["s"]), min_end(&w["e"])) {
        (Some(st), Some(e)) if e > st => json!({"s": hhmm(st), "e": hhmm_end(e)}),
        _ => Value::Null,
    }
}

pub fn whole_part(w: &Value) -> bool {
    a(&parts()).iter().any(|p| !p["win"].is_null() && w.is_object() && p["win"]["s"] == w["s"] && p["win"]["e"] == w["e"])
}

pub fn habit_win(h: &Value) -> Value {
    let w = clean_win(&h["win"]);
    if !w.is_null() {
        return w;
    }
    if let Some(st) = min_of(&h["time"]) {
        let e = norm_end(&h["time"], &h["end"]).map(Value::String).unwrap_or_else(|| part_win(&json!(part_of(&json!({"time": h["time"]}))))["e"].clone());
        return json!({"s": hhmm(st), "e": e});
    }
    part_win(&json!(part_of(h)))
}

pub fn win_fields(win: &Value) -> Value {
    let w = clean_win(win);
    if w.is_null() {
        return json!({"win": null, "time": null, "end": null});
    }
    let end = if s(&w["e"]) == "24:00" { Value::Null } else { w["e"].clone() };
    json!({"win": w, "time": w["s"], "end": end})
}

pub fn move_win(h: &Value, time: &Value) -> Value {
    let w = habit_win(h);
    let Some(st) = min_of(time) else { return w };
    let len = if w.is_null() { 60 } else { min_end(&w["e"]).unwrap() - min_of(&w["s"]).unwrap() };
    clean_win(&json!({"s": hhmm(st), "e": hhmm_end((st + len).min(1440))}))
}

pub fn norm_time(raw: &Value, end: bool) -> Value {
    let tt = rx::all(r"[.,\-\s]", text(raw).trim(), ":");
    let Some(c) = rx::cap(r"^(\d{1,2})(?::?(\d{2}))?$", &tt) else { return Value::Null };
    let h: i64 = c[1].as_ref().unwrap().parse().unwrap_or(99);
    let m: i64 = c[2].as_ref().map(|x| x.parse().unwrap_or(99)).unwrap_or(0);
    if end && h == 24 && m == 0 {
        return json!("24:00");
    }
    if h < 24 && m < 60 { json!(hhmm(h * 60 + m)) } else { Value::Null }
}

pub fn win_label(h: &Value) -> String {
    let w = habit_win(h);
    if w.is_null() { String::new() } else { format!("{}–{}", s(&w["s"]), s(&w["e"])) }
}

pub fn remind_at(h: &Value) -> Value {
    habit_win(h)["s"].clone()
}

pub const HABIT_LEN: i64 = 30;

pub fn norm_end(time: &Value, end: &Value) -> Option<String> {
    match (min_of(time), min_of(end)) {
        (Some(st), Some(e)) if e > st => Some(hhmm(e)),
        _ => None,
    }
}

pub fn habit_span(h: &Value) -> Value {
    if t(&h["win"]) {
        let w = clean_win(&h["win"]);
        return if w.is_null() || whole_part(&w) { Value::Null } else { json!({"s": min_of(&w["s"]), "e": min_end(&w["e"]), "end": true}) };
    }
    let Some(st) = min_of(&h["time"]) else { return Value::Null };
    match norm_end(&h["time"], &h["end"]).and_then(|e| min_of(&json!(e))) {
        Some(e) => json!({"s": st, "e": e, "end": true}),
        None => json!({"s": st, "e": (st + HABIT_LEN).min(1440), "end": false}),
    }
}

pub fn end_after(time: &Value, min: i64) -> Option<String> {
    let st = min_of(time)?;
    norm_end(time, &json!(hhmm((st + min).min(1439))))
}

pub fn move_end(h: &Value, time: &Value) -> Option<String> {
    let sp = habit_span(h);
    if sp["end"] == true { end_after(time, int(&sp["e"]).unwrap() - int(&sp["s"]).unwrap()) } else { None }
}

pub fn span_label(h: &Value) -> String {
    let sp = habit_span(h);
    if sp.is_null() {
        return String::new();
    }
    let (a_, b_) = (hhmm(int(&sp["s"]).unwrap()), hhmm(int(&sp["e"]).unwrap()));
    if sp["end"] == true { format!("{a_}–{b_}") } else { a_ }
}

/// Порядок карточек: по части дня, внутри — по времени.
pub fn sort_habits(list: &[Value]) -> Vec<Value> {
    let pi = |h: &Value| { let p = part_of(h); PART_IDS.iter().position(|x| *x == p).unwrap_or(9) };
    let tm = |h: &Value| if h["time"].is_null() { "99".to_string() } else { text(&h["time"]) };
    let mut v = list.to_vec();
    v.sort_by(|x, y| pi(x).cmp(&pi(y)).then_with(|| cmp16(&tm(x), &tm(y))));
    v
}

pub fn goal_n(h: &Value) -> i64 {
    match n(&h["goal"]["n"]) { Some(x) if x > 1.0 => round(x), _ => 0 }
}

pub fn count_on(log: &Value, h: &Value, day: &str) -> i64 {
    let e = entry(log, &h["id"], day);
    if e.is_null() || t(&e["gone"]) {
        return 0;
    }
    if let Some(x) = n(&e["n"]) {
        return x as i64;
    }
    if t(&e["done"]) { if goal_n(h) > 0 { goal_n(h) } else { 1 } } else { 0 }
}

pub fn next_mark(log: &Value, h: &Value, day: &str) -> Value {
    let g = goal_n(h);
    if g == 0 {
        return json!({"done": !is_done(log, &h["id"], day), "rest": false, "skip": false});
    }
    if is_done(log, &h["id"], day) {
        return json!({"done": false, "n": 0, "skip": false});
    }
    let k = count_on(log, h, day) + 1;
    json!({"done": k >= g, "n": k, "skip": false})
}

pub fn day_mark(h: &Value, state: &str) -> Value {
    let g = goal_n(h);
    let mut m = match state {
        "done" => json!({"done": true, "rest": false, "skip": false}),
        "skip" => json!({"done": false, "rest": false, "skip": true}),
        _ => json!({"done": false, "rest": false, "skip": false}),
    };
    if g > 0 {
        m["n"] = json!(if state == "done" { g } else { 0 });
    }
    m
}

fn week_count(h: &Value, log: &Value, monday: NaiveDate) -> (i64, i64) {
    let (mut done, mut skip) = (0, 0);
    for k in 0..7 {
        let st = ymd(add_days(monday, k));
        if is_done(log, &h["id"], &st) {
            done += 1;
        } else if is_off(log, &h["id"], &st) {
            skip += 1;
        }
    }
    (done, skip)
}

fn week_need(h: &Value, skip: i64) -> f64 {
    per_week(h).min((7 - skip) as f64).max(1.0)
}

fn week_stats(h: &Value, log: &Value) -> Value {
    let today = day_offset(0);
    let cr = created(h).unwrap_or_else(|| ymd(day_offset(-365)));
    let mon0 = monday_of(today);
    let cur = week_count(h, log, mon0);
    let mut streak = if cur.0 as f64 >= week_need(h, cur.1) { 1 } else { 0 };
    for w in 1..=104 {
        let mon = add_days(mon0, -7 * w);
        let c = week_count(h, log, mon);
        if ymd(add_days(mon, 6)) < cr && c.0 == 0 {
            break;
        }
        if c.0 as f64 >= week_need(h, c.1) { streak += 1 } else { break }
    }
    let (mut best, mut run) = (0, 0);
    for w in (0..=104).rev() {
        let mon = add_days(mon0, -7 * w);
        let c = week_count(h, log, mon);
        if c.0 as f64 >= week_need(h, c.1) {
            run += 1;
            best = best.max(run);
        } else if w != 0 && ymd(add_days(mon, 6)) >= cr {
            run = 0;
        }
    }
    json!({"streak": streak, "best": best, "todayDone": is_done(log, &h["id"], &ymd(today)), "week": cur.0, "cells": [], "months": []})
}

pub fn scheduled_on(h: &Value, log: &Value, day: &str) -> bool {
    let d = pd(day);
    if per_week(h) > 0.0 {
        if is_done(log, &h["id"], day) {
            return true;
        }
        let c = week_count(h, log, monday_of(d));
        return (c.0 as f64) < week_need(h, c.1);
    }
    days_of(h).contains(&dow(d))
}

pub fn unit_forms(h: &Value) -> [&'static str; 3] {
    if per_week(h) > 0.0 {
        return ["неделя", "недели", "недель"];
    }
    let d = &h["days"];
    if !d.is_array() || a(d).is_empty() || a(d).len() == 7 { ["день", "дня", "дней"] } else { ["занятие", "занятия", "занятий"] }
}

/// d — сделано, p — частично, m — пропуск, k — не считать, o — не по расписанию / не было, f — будущее, w — свободный день.
pub fn day_state(h: &Value, log: &Value, day: &str, today: Option<&str>) -> &'static str {
    let td = today.map(String::from).unwrap_or_else(|| ymd(day_offset(0)));
    let e = entry(log, &h["id"], day);
    if is_done(log, &h["id"], day) {
        return "d";
    }
    if day > td.as_str() {
        return "f";
    }
    if t(&e["skip"]) || t(&e["rest"]) {
        return "k";
    }
    if goal_n(h) > 0 && count_on(log, h, day) > 0 {
        return "p";
    }
    let cr = created(h).unwrap_or_else(|| "0000".into());
    if day < cr.as_str() {
        return "o";
    }
    if per_week(h) > 0.0 {
        return "w";
    }
    if !days_of(h).contains(&dow(pd(day))) {
        return "o";
    }
    if day == td { "w" } else { "m" }
}

/// Текущая неделя пн–вс; дни после сегодня — future.
pub fn week_row(h: &Value, log: &Value) -> Vec<Value> {
    let nd = today_d();
    let today = ymd(nd);
    let mon = add_days(nd, -dow(nd));
    (0..7)
        .map(|i| {
            let st = ymd(add_days(mon, i));
            let fut = st > today;
            json!({"day": st, "wd": WEEKDAYS[i as usize], "st": if fut { "f" } else { day_state(h, log, &st, Some(&today)) }, "today": st == today, "future": fut})
        })
        .collect()
}

pub fn last7(h: &Value, log: &Value) -> Vec<Value> {
    let nd = today_d();
    let today = ymd(nd);
    (0..7)
        .rev()
        .map(|i| {
            let d = add_days(nd, -i);
            let st = ymd(d);
            json!({"day": st, "wd": WEEKDAYS[dow(d) as usize], "st": day_state(h, log, &st, Some(&today)), "today": i == 0})
        })
        .collect()
}

pub fn month_row(h: &Value, log: &Value, year: i32, month: i32) -> Value {
    let today = ymd(today_d());
    let dim = js_date(year, month + 1, 0).day() as i32;
    let mut cells = vec![];
    let (mut done, mut sched, mut miss) = (0i64, 0i64, 0i64);
    for k in 1..=dim {
        let st = ymd(js_date(year, month, k));
        let ds = day_state(h, log, &st, Some(&today));
        cells.push(json!({"day": st, "n": k, "st": ds, "today": st == today}));
        if ds == "d" { done += 1 }
        if ds == "m" { miss += 1 }
        if ds == "d" || ds == "m" || ds == "p" { sched += 1 }
    }
    if per_week(h) > 0.0 {
        let cr = created(h).unwrap_or_else(|| "0000".into());
        let past = cells.iter().filter(|c| s(&c["day"]) <= today.as_str() && s(&c["day"]) >= cr.as_str() && s(&c["st"]) != "k").count();
        let need = ((past as f64 / 7.0) * per_week(h)).ceil() as i64;
        sched = done.max(need);
        miss = 0;
    }
    let pct = if sched > 0 { json!(round(done as f64 / sched as f64 * 100.0)) } else { Value::Null };
    json!({"cells": cells, "done": done, "sched": sched, "miss": miss, "pct": pct})
}

pub fn month_summary(habits: &[Value], log: &Value, year: i32, month: i32) -> Value {
    let sum = |y: i32, m: i32| {
        let (mut done, mut sched) = (0i64, 0i64);
        let rows: Vec<(Value, Value)> = habits
            .iter()
            .map(|h| {
                let r = month_row(h, log, y, m);
                done += int(&r["done"]).unwrap();
                sched += int(&r["sched"]).unwrap();
                (h.clone(), r)
            })
            .collect();
        let pct = if sched > 0 { json!(round(done as f64 / sched as f64 * 100.0)) } else { Value::Null };
        (rows, pct)
    };
    let (rows, pct) = sum(year, month);
    let (_, prev) = if month > 0 { sum(year, month - 1) } else { sum(year - 1, 11) };
    let clean: Vec<Value> = rows.iter().filter(|(h, r)| !t(&h["perWeek"]) && int(&r["sched"]).unwrap() >= 3 && !t(&r["miss"])).map(|(h, _)| h["name"].clone()).collect();
    let mut wd = [[0i64; 2]; 7];
    for (_, r) in &rows {
        for c in a(&r["cells"]) {
            let st = s(&c["st"]);
            if st != "d" && st != "m" {
                continue;
            }
            let k = dow(pd(s(&c["day"]))) as usize;
            wd[k][1] += 1;
            if st == "d" {
                wd[k][0] += 1;
            }
        }
    }
    let mut weak: Option<usize> = None;
    for i in 0..7 {
        let x = wd[i];
        if x[1] >= 2 && x[0] < x[1] && weak.map_or(true, |w| (x[0] as f64 / x[1] as f64) < wd[w][0] as f64 / wd[w][1] as f64) {
            weak = Some(i);
        }
    }
    json!({"pct": pct, "prev": prev, "clean": clean, "weak": weak.map(|w| WEEKDAY_FULL[w])})
}

pub fn milestone_date(h: &Value, log: &Value, streak: i64) -> Option<String> {
    if per_week(h) > 0.0 {
        return None;
    }
    let mut left = next_milestone(streak as f64) - streak;
    if left <= 0 {
        return None;
    }
    let mut d = today_d();
    if is_done(log, &h["id"], &ymd(d)) {
        d = add_days(d, 1);
    }
    for _ in 0..800 {
        if days_of(h).contains(&dow(d)) {
            left -= 1;
            if left == 0 {
                return Some(format!("{} {}", d.day(), MONTH_GEN[d.month0() as usize]));
            }
        }
        d = add_days(d, 1);
    }
    None
}

pub fn broken(h: &Value, log: &Value) -> Value {
    if per_week(h) > 0.0 {
        return Value::Null;
    }
    let nd = today_d();
    let today = ymd(nd);
    if is_done(log, &h["id"], &today) {
        return Value::Null;
    }
    let cr = created(h).unwrap_or_else(|| "0000".into());
    let mut d = add_days(nd, -1);
    let mut i = 0;
    while i < 60 {
        let st = ymd(d);
        if st < cr {
            return Value::Null;
        }
        let ds = day_state(h, log, &st, Some(&today));
        if ds == "m" || ds == "p" {
            break;
        }
        if ds == "d" {
            return Value::Null;
        }
        i += 1;
        d = add_days(d, -1);
    }
    if i >= 60 {
        return Value::Null;
    }
    let mut was = 0;
    d = add_days(d, -1);
    while was < 800 {
        let ds = day_state(h, log, &ymd(d), Some(&today));
        if ds == "d" {
            was += 1;
        } else if ds != "o" && ds != "k" {
            break;
        }
        d = add_days(d, -1);
    }
    if was >= 2 { json!({"was": was}) } else { Value::Null }
}

pub struct Tip {
    pub habit: Value,
    pub anchor: Value,
    pub time: String,
    pub misses: i64,
}

/// Совет енота: перенести сорвавшуюся привычку сразу после самой надёжной той же части дня.
pub fn habit_tip(habits: &[Value], log: &Value) -> Option<Tip> {
    let nd = today_d();
    let today = ymd(nd);
    let reliability = |h: &Value| {
        let (mut d, mut sc) = (0, 0);
        for i in 1..=14 {
            let ds = day_state(h, log, &ymd(add_days(nd, -i)), Some(&today));
            if ds == "d" {
                d += 1;
                sc += 1;
            } else if ds == "m" || ds == "p" {
                sc += 1;
            }
        }
        if sc > 0 { d as f64 / sc as f64 } else { 0.0 }
    };
    for h in habits {
        if !t(&h["time"]) || per_week(h) > 0.0 || (t(&h["tipHide"]) && s(&h["tipHide"]) >= today.as_str()) {
            continue;
        }
        let mut misses = 0;
        let mut i = 1;
        while i <= 21 && misses < 3 {
            let ds = day_state(h, log, &ymd(add_days(nd, -i)), Some(&today));
            if ds == "m" || ds == "p" {
                misses += 1;
            } else if ds == "d" {
                break;
            }
            i += 1;
        }
        if misses < 3 {
            continue;
        }
        let part = part_of(h);
        let mut cands: Vec<&Value> = habits.iter().filter(|x| x["id"] != h["id"] && t(&x["time"]) && part_of(x) == part && reliability(x) >= 0.7).collect();
        cands.sort_by(|x, y| {
            reliability(y).partial_cmp(&reliability(x)).unwrap().then_with(|| int(&stats(y, log)["streak"]).cmp(&int(&stats(x, log)["streak"])))
        });
        let Some(anchor) = cands.first() else { continue };
        let m = min_of(&anchor["time"]).unwrap() + 30;
        let time = format!("{:02}:{:02}", m / 60 % 24, m % 60);
        if time == s(&h["time"]) {
            continue;
        }
        return Some(Tip { habit: h.clone(), anchor: (*anchor).clone(), time, misses });
    }
    None
}

pub fn card_line(h: &Value, log: &Value) -> String {
    let nd = today_d();
    let today = ymd(nd);
    let mut bits = vec![part_name(h)];
    if per_week(h) > 0.0 {
        let c = week_count(h, log, monday_of(nd));
        bits.push(format!("{} из {} на неделе", c.0, text(&h["perWeek"])));
    } else if goal_n(h) > 0 {
        let unit = &h["goal"]["unit"];
        bits.push(format!("{} из {} {}", count_on(log, h, &today), goal_n(h), if t(unit) { text(unit) } else { String::new() }).trim().to_string());
    } else if t(&h["win"]) || t(&h["time"]) {
        bits.push(win_label(h));
    }
    let d = a(&h["days"]);
    if !d.is_empty() && d.len() < 7 && !t(&h["perWeek"]) {
        bits.push(schedule_label(&h["days"]).to_lowercase());
    }
    bits.join(" · ")
}

pub fn schedule_line(h: &Value) -> String {
    let pw = per_week(h);
    let first = if pw > 0.0 { format!("{} {} в неделю", text(&h["perWeek"]), plural(pw as i64, ["раз", "раза", "раз"])) } else { schedule_label(&h["days"]).to_lowercase() };
    let mut bits = vec![first, part_name(h).to_lowercase()];
    if t(&h["win"]) || t(&h["time"]) {
        bits.push(win_label(h));
    }
    if t(&h["createdAt"]) {
        let d = pd(&day10(&h["createdAt"]));
        bits.push(format!("с {} {}", d.day(), MONTH_GEN[d.month0() as usize]));
    }
    bits.join(" · ")
}

pub fn total_done(h: &Value, log: &Value) -> usize {
    let pre = format!("{}|", text(&h["id"]));
    o(log).iter().filter(|(k, v)| k.starts_with(&pre) && v.is_object() && t(&v["done"]) && !t(&v["gone"])).count()
}

// ---------- окно правки (#193) ----------

/// Патч слоя для смены расписания из окна правки: kind — daily | weekdays | days | week.
/// «Свои дни» помечаются custom: выбранные кнопкой пн–пт не схлопываются в «по будням» (habit_freq_of).
/// Пустой набор своих дней превращается в сегодняшний день — расписание без дней ломало бы подсчёты.
pub fn edit_schedule(kind: &str, days: &[i64], per: i64) -> Value {
    const ALL: [i64; 7] = [0, 1, 2, 3, 4, 5, 6];
    match kind {
        "weekdays" => json!({"days": [0, 1, 2, 3, 4], "perWeek": Value::Null, "custom": Value::Null}),
        "days" => {
            let mut d: Vec<i64> = days.iter().copied().filter(|x| (0..=6).contains(x)).collect();
            d.sort_unstable();
            d.dedup();
            if d.is_empty() {
                d.push(dow(today_d()));
            }
            json!({"days": d, "perWeek": Value::Null, "custom": true})
        }
        "week" => json!({"days": ALL, "perWeek": per.clamp(1, 6), "custom": Value::Null}),
        _ => json!({"days": ALL, "perWeek": Value::Null, "custom": Value::Null}),
    }
}

/// Патч «когда»: обе границы заданы — своё окно (win + time/end, часть дня сброшена),
/// иначе — только часть дня (part, своего окна и времени нет).
pub fn edit_when(part: &str, s: &Value, e: &Value) -> Value {
    let w = clean_win(&json!({"s": s, "e": e}));
    if !w.is_null() {
        let mut f = o(&win_fields(&w)).clone();
        f.insert("part".into(), Value::Null);
        return Value::Object(f);
    }
    let p = if PART_IDS.contains(&part) { part } else { "any" };
    json!({"part": p, "win": Value::Null, "time": Value::Null, "end": Value::Null})
}

/// Патч цели: до 1 — просто «сделать» (без счётчика), иначе n раз в день.
pub fn edit_goal(n: i64) -> Value {
    if n > 1 { json!({"goal": {"n": n.min(999), "unit": "раз"}}) } else { json!({"goal": Value::Null}) }
}
