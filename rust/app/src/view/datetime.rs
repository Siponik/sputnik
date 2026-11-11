//! Выбор даты и времени (G_DateTime): месяц, быстрые чипы, сетка часов, минуты, «до», поле словами.
use super::*;
use crate::DpCell;
use chrono::{Datelike, Duration, NaiveDate, Timelike};
use sputnik_core::{create as cr, habits as hb, when};

#[derive(Clone, Default)]
pub struct Dp {
    /// Чья дата: (список, задача).
    pub task: (String, String),
    pub title: String,
    pub day: Option<NaiveDate>,
    pub hour: Option<u32>,
    pub min: u32,
    /// Длительность в минутах, 0 — без конца.
    pub dur: i64,
    /// Показанный месяц: первое число.
    pub month: NaiveDate,
    pub said: String,
    /// Выбор для окна «Создать», а не для задачи.
    pub for_create: bool,
}

const MONTHS: [&str; 12] = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
const WD: [&str; 7] = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

fn first(d: NaiveDate) -> NaiveDate {
    d.with_day(1).unwrap_or(d)
}

/// Открыть для задачи: берёт срок и время из задачи.
pub fn open(app: &App, l: &str, id: &str) -> Option<Dp> {
    let t0 = app.task(l, id)?;
    let lt = app.lt(id);
    let day = NaiveDate::parse_from_str(&day10(&t0["due"]), "%Y-%m-%d").ok();
    let (hour, min, dur) = match (lt["slot"]["s"].as_str(), lt["slot"]["e"].as_str()) {
        (Some(a0), e) => {
            let st = cr::to_min(a0);
            let d = e.map(|b0| cr::to_min(b0) - st).filter(|x| *x > 0).unwrap_or(0);
            (Some((st / 60) as u32), (st % 60) as u32, d)
        }
        _ => (None, 0, 0),
    };
    let base = day.unwrap_or_else(|| hb::now().date());
    Some(Dp { task: (l.into(), id.into()), title: text(&t0["title"]), day, hour, min, dur, month: first(base), said: String::new(), for_create: false })
}

/// Открыть для окна «Создать»: срок и время — из того, что уже понято (`compose::resolve`).
pub fn for_create(x: &Value, kind: i32) -> Dp {
    let day = x["day"].as_str().and_then(|d| NaiveDate::parse_from_str(d, "%Y-%m-%d").ok());
    let (hour, min, dur) = match (x["slot"]["s"].as_str(), x["slot"]["e"].as_str()) {
        (Some(a0), e) if kind != 3 => {
            let st = cr::to_min(a0);
            let d = e.map(|b0| cr::to_min(b0) - st).filter(|x| *x > 0).unwrap_or(0);
            (Some((st / 60) as u32), (st % 60) as u32, d)
        }
        _ => (None, 0, 0),
    };
    let base = day.unwrap_or_else(|| hb::now().date());
    let title = text(&x["title"]);
    Dp { title: if title.is_empty() { "новое".into() } else { title }, day, hour, min, dur, month: first(base), for_create: true, ..Default::default() }
}

/// Выбранное в окне — для «Создать».
pub fn picked(d: &Dp) -> sputnik_core::compose::Picked {
    let day = d.day.map(|x| x.format("%Y-%m-%d").to_string());
    let slot = match (day.is_some(), d.hour) {
        (true, Some(h)) => {
            let st = h as i64 * 60 + d.min as i64;
            Some((hhmm(st), hhmm(if d.dur > 0 { st + d.dur } else { st + 60 })))
        }
        _ => None,
    };
    sputnik_core::compose::Picked { day, slot }
}

/// Разобрать «словами».
pub fn words(d: &mut Dp, t: &str) {
    let w = when::parse_when(t, hb::now().date());
    if let Some(day) = w.day.as_deref().and_then(|x| NaiveDate::parse_from_str(x, "%Y-%m-%d").ok()) {
        d.day = Some(day);
        d.month = first(day);
    }
    if let Some(tm) = &w.time {
        let m = cr::to_min(tm);
        d.hour = Some((m / 60) as u32);
        d.min = (m % 60) as u32;
    }
    d.said = if w.day.is_none() && w.time.is_none() { "Не понял — попробуй «пт 17:00» или «25.11»".into() } else { format!("Понял: {}", summary(d)) };
}

pub fn summary(d: &Dp) -> String {
    let Some(day) = d.day else { return "Без срока".into() };
    let mut s0 = format!("{}, {}", WD[day.weekday().num_days_from_monday() as usize], cr::day_month(&day.format("%Y-%m-%d").to_string()));
    if let Some(h) = d.hour {
        let st = h as i64 * 60 + d.min as i64;
        s0 += &format!(" · {}", hhmm(st));
        if d.dur > 0 {
            s0 += &format!("–{}", hhmm(st + d.dur));
        }
    }
    s0
}

fn hhmm(m: i64) -> String {
    let m = m.rem_euclid(24 * 60);
    format!("{:02}:{:02}", m / 60, m % 60)
}

/// Применить к задаче.
pub fn apply(app: &mut App, d: &Dp) {
    let (l, id) = &d.task;
    let Some(tk) = app.task(l, id).cloned() else { return };
    match d.day {
        None => {
            app.set_due(l, &tk, None);
            app.set_task(id, json!({"slot": null}));
        }
        Some(day) => {
            let ds = day.format("%Y-%m-%d").to_string();
            let slot = match d.hour {
                None => Value::Null,
                Some(h) => {
                    let st = h as i64 * 60 + d.min as i64;
                    let en = if d.dur > 0 { st + d.dur } else { st };
                    json!({"s": hhmm(st), "e": hhmm(en)})
                }
            };
            app.schedule(l, &tk, &ds, slot);
        }
    }
}

pub fn render(app: &App, u: &Ui, g: &S) {
    let Some(d) = &u.dp else {
        g.set_dp_open(false);
        return;
    };
    g.set_dp_open(true);
    g.set_dp_title(ss(d.title.to_uppercase()));
    g.set_dp_month(ss(format!("{} {}", MONTHS[d.month.month0() as usize], d.month.year())));
    let today = hb::now().date();
    let start = d.month - Duration::days(d.month.weekday().num_days_from_monday() as i64);
    let cells: Vec<DpCell> = (0..42).map(|i| start + Duration::days(i)).take_while(|x| *x < d.month + Duration::days(31) || x.weekday().num_days_from_monday() != 0)
        .map(|x| DpCell { n: x.day() as i32, day: ss(x.format("%Y-%m-%d").to_string()), other: x.month() != d.month.month(), today: x == today, sel: Some(x) == d.day })
        .collect();
    g.set_dp_cells(model(cells));
    // занятые часы выбранного дня — по событиям календаря
    let mut busy = vec![0; 24];
    if let Some(day) = d.day {
        for e in app.events_on(&day.format("%Y-%m-%d").to_string()) {
            let (Some(a0), Some(b0)) = (sputnik_core::calendar::local_dt(s(&e["start"]["dateTime"])), sputnik_core::calendar::local_dt(s(&e["end"]["dateTime"]))) else { continue };
            let (h0, h1) = (a0.hour(), if b0.date() > a0.date() { 24 } else { b0.hour() + (b0.minute() > 0) as u32 });
            for h in h0..h1.min(24) {
                busy[h as usize] = 1;
            }
        }
    }
    g.set_dp_busy(model(busy));
    g.set_dp_hour(d.hour.map(|h| h as i32).unwrap_or(-1));
    g.set_dp_min(d.min as i32);
    g.set_dp_exact(ss(d.hour.map(|h| hhmm(h as i64 * 60 + d.min as i64)).unwrap_or_default()));
    g.set_dp_dur(d.dur as i32);
    let end = d.hour.map(|h| hhmm(h as i64 * 60 + d.min as i64 + 120)).unwrap_or_default();
    g.set_dp_dur_long(ss(if end.is_empty() { "2 часа".into() } else { format!("2 часа · до {end}") }));
    g.set_dp_summary(ss(summary(d)));
    g.set_dp_said(ss(d.said.clone()));
    let tom = today + Duration::days(1);
    let wkend = today + Duration::days(((5 - today.weekday().num_days_from_monday() as i64) + 7) % 7);
    let next = today + Duration::days(7);
    g.set_dp_quick(model([("today", "Сегодня", Some(today)), ("tomorrow", "Завтра", Some(tom)), ("weekend", "В выходные", Some(wkend)), ("week", "Через неделю", Some(next)), ("none", "Без срока", None)]
        .iter().map(|(id, l, x)| super::dialogs::opt(*id, *l, d.day == *x)).collect()));
}
