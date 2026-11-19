//! Неделя календаря «Система G» (п. 47, `G_CalWeek`): видимые часы без сжатия, чипы «раньше/позже»,
//! дела в одно время — один блок «N дел», длинные привычки — фон, всплывашка при наведении.
//! Расчёты — `sputnik_core::calweek`.
use super::calendar::{day_items, Item};
use super::*;
use crate::{Block, BlockRow, CalTip, Chip, Day, Label, WkBg};
use sputnik_core::calendar as cal;
use sputnik_core::calweek::{self as cw, WItem, WeekGrid};

const MON3: [&str; 12] = ["ЯНВ", "ФЕВ", "МАР", "АПР", "МАЯ", "ИЮН", "ИЮЛ", "АВГ", "СЕН", "ОКТ", "НОЯ", "ДЕК"];

/// «08–17», а не ровно по часу — «08:30–17:00».
fn short_span(s: f64, e: f64) -> String {
    if cw::show_time(s) || cw::show_time(e) { format!("{}–{}", cal::from_min(s as i64), cal::from_min(e as i64)) } else { format!("{:02}–{:02}", s as i64 / 60, e as i64 / 60) }
}

fn witem(x: &Item) -> Option<WItem> {
    x.s.map(|(s, e)| WItem { s, e, kind: x.chip.kind.min(2), done: x.chip.done })
}

/// Видимые часы недели и дела по дням.
pub fn grid(app: &App, u: &Ui) -> (Vec<String>, Vec<Vec<Item>>, WeekGrid) {
    let days = cal::period_days(&u.cal_sel, "week");
    let items: Vec<Vec<Item>> = days.iter().map(|d| day_items(app, u, d)).collect();
    let w: Vec<Vec<WItem>> = items.iter().map(|it| it.iter().filter_map(witem).collect()).collect();
    let g = WeekGrid::new(&w, u.cal_up, u.cal_down);
    (days, items, g)
}

/// y в сетке → минуты (шаг 15).
pub fn min_at(app: &App, u: &Ui, y: f64) -> i64 {
    grid(app, u).2.min_at(y, 15.0) as i64
}

fn tip(day: &str, it: &Item) -> CalTip {
    let d = chrono::NaiveDate::parse_from_str(day, "%Y-%m-%d").unwrap_or_default();
    use chrono::Datelike;
    let wd = cal::day_label(day)["short"].as_str().unwrap_or("").to_uppercase();
    let mut when = format!("{} {} {}", wd, d.day(), MON3[d.month0() as usize]);
    if let Some((s, e)) = it.s {
        when += &format!(" · {}–{} · {}", cal::from_min(s as i64), cal::from_min((e as i64).min(1440)), cw::dur_text(e - s));
    }
    CalTip { title: it.chip.title.clone(), when: ss(when), src: ss(it.src.clone()), note: ss(it.note.chars().take(240).collect::<String>()), hue: it.chip.hue }
}

fn row(day: &str, it: &Item) -> BlockRow {
    BlockRow { chip: it.chip.clone(), tip: tip(day, it) }
}

pub fn render(app: &App, u: &Ui, g: &S) -> Vec<(String, Vec<Item>)> {
    let (days, items, gr) = grid(app, u);
    let tdy = today_s();
    g.set_grid_h(gr.height() as f32);
    g.set_hours(model((gr.r0..gr.r1).map(|h| Label { text: ss(format!("{h:02}")), y: gr.y[(h - gr.r0) as usize] as f32, small: false }).collect()));
    let now_col = days.iter().position(|d| *d == tdy).map(|x| x as i32).unwrap_or(-1);
    let nm = cal::now_min() as f64;
    let now_in = nm >= gr.r0 as f64 * 60.0 && nm <= gr.r1 as f64 * 60.0;
    g.set_now_col(if now_in { now_col } else { -1 });
    g.set_today_col(now_col);
    g.set_now_y(gr.y_at(nm) as f32);
    g.set_cal_up(u.cal_up.is_some());
    g.set_cal_down(u.cal_down.is_some());
    let out: Vec<Day> = days.iter().zip(items.iter()).map(|(d, its)| {
        let w: Vec<WItem> = its.iter().map(|x| witem(x).unwrap_or(WItem { s: -1.0, e: -1.0, kind: 9, done: false })).collect();
        // за краем — чипы
        let timed: Vec<WItem> = w.iter().filter(|x| x.kind != 9).cloned().collect();
        let ((nb, fb), (na, fa)) = cw::outside(&timed, gr.r0, gr.r1);
        // фон: длинные привычки
        let bg: Vec<WkBg> = its.iter().zip(w.iter()).filter(|(_, x)| x.kind != 9 && cw::is_background(x)).map(|(it, x)| {
            let (y0, y1) = (gr.y_at(x.s), gr.y_at(x.e));
            WkBg { y: y0 as f32, h: (y1 - y0) as f32, text: ss(format!("{} {}", it.chip.title.to_uppercase(), short_span(x.s, x.e))), top: x.s >= gr.r0 as f64 * 60.0, bot: x.e <= gr.r1 as f64 * 60.0 }
        }).filter(|b| b.h > 0.0).collect();
        let blocks: Vec<Block> = cw::clusters(&w, gr.r0, gr.r1).into_iter().map(|c| {
            let s = c.iter().map(|&i| w[i].s).fold(f64::MAX, f64::min);
            let e = c.iter().map(|&i| w[i].e).fold(f64::MIN, f64::max);
            if c.len() == 1 {
                let (it, x) = (&its[c[0]], &w[c[0]]);
                let (y, h) = gr.place(x.s, x.e);
                let r = row(d, it);
                Block { title: it.chip.title.clone(), sub: ss(if cw::show_time(x.s) { cal::from_min(x.s as i64) } else { String::new() }),
                    y: y as f32, h: h as f32, x: 0.0, w: 1.0, hue: it.chip.hue, done: it.chip.done, kind: it.chip.kind,
                    list_id: it.chip.list_id.clone(), id: it.chip.id.clone(), one: cw::one_line(x), tip: r.tip, rows: model(vec![]), more: 0 }
            } else {
                let (y, h) = gr.place(s, e.max(s + 30.0));
                let (shown, more) = cw::stack_fit(h, c.len());
                let rows: Vec<BlockRow> = c.iter().take(shown).map(|&i| row(d, &its[i])).collect();
                Block { title: ss(cw::stack_head(c.len(), s, e.max(s + 30.0))), sub: ss(""), y: y as f32, h: h as f32, x: 0.0, w: 1.0,
                    hue: crate::view::color("accent"), done: false, kind: 4, list_id: ss(""), id: ss(format!("stack{}", c[0])), one: false,
                    tip: CalTip::default(), rows: model(rows), more: more as i32 }
            }
        }).collect();
        let all: Vec<Chip> = its.iter().filter(|x| x.s.is_none()).map(|x| x.chip.clone()).collect();
        let dl = cal::day_label(d);
        let (hl, hd) = super::calendar::habits_line(app, d);
        Day { ymd: ss(d.clone()), label: ss(super::calendar::short_up(d)), num: ss(dl["n"].to_string()), today: *d == tdy, sel: *d == u.cal_sel,
            more: all.len().saturating_sub(1) as i32, all: model(all), blocks: model(blocks), habits: ss(hl), load: 0.0, in_month: true, hdots: model(hd),
            bg: model(bg), up: ss(fb.map(|f| cw::chip_text(true, nb, f)).unwrap_or_default()), down: ss(fa.map(|f| cw::chip_text(false, na, f)).unwrap_or_default()),
            up_h: fb.map(|f| (f / 60.0).floor() as i32).unwrap_or(-1), down_h: fa.map(|f| ((f + 60.0) / 60.0).ceil() as i32).unwrap_or(-1) }
    }).collect();
    g.set_cal_any_up(out.iter().any(|d| !d.up.is_empty()));
    g.set_cal_any_down(out.iter().any(|d| !d.down.is_empty()));
    g.set_days(model(out));
    days.into_iter().zip(items).collect()
}

/// Самое свободное окно недели — его место в сетке.
pub fn free_y(app: &App, u: &Ui, s: f64, e: f64) -> (f32, f32) {
    let gr = grid(app, u).2;
    (gr.y_at(s) as f32, (gr.y_at(e) - gr.y_at(s)) as f32)
}
