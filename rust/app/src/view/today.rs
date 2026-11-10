//! Модели «Сегодня».
use super::*;
use crate::{Chip, HabitChip, InboxRow, TaskRow};
use sputnik_core::{habits as hb, route, today as td};

pub fn row(app: &App, list: &str, t: &Value) -> TaskRow {
    let l = app.lt(s(&t["id"]));
    let (when, late) = due_text(t, &l["slot"]);
    let subs = app.subtasks(list, s(&t["id"]));
    let sub = if subs.is_empty() { String::new() } else { format!("{}/{}", subs.iter().filter(|x| App::is_done(x)).count(), subs.len()) };
    let when = if when == "сегодня" { String::new() } else { when.replace("сегодня, ", "") };
    TaskRow {
        list_id: ss(list),
        id: ss(s(&t["id"])),
        title: ss(text(&t["title"])),
        list: ss(app.list_name(list)),
        hue: list_hue(app, list),
        when: ss(when),
        overdue: late && !App::is_done(t),
        done: App::is_done(t),
        prio: n(&l["priority"]).unwrap_or(2.0) as i32,
        sub: ss(sub),
    }
}

pub fn render(app: &App, u: &Ui, g: &S) {
    let tdy = today_s();
    let items = app.today_items();
    let (mut over, mut now) = (vec![], vec![]);
    for (l, t) in &items {
        let r = row(app, l, t);
        if !App::is_done(t) && day10(&t["due"]) < tdy { over.push(r) } else { now.push(r) }
    }
    let done = items.iter().filter(|x| App::is_done(&x.1)).count();
    g.set_done_count(done as i32);
    g.set_total_count(items.len() as i32);
    g.set_today_count((items.len() - done) as i32);
    g.set_overdue(model(over));
    g.set_today(model(now));
    let d = sputnik_core::dates::parse_ymd(&tdy).unwrap();
    g.set_today_label(ss(sputnik_core::stickers::today_sub(&tdy).split(" · ").next().unwrap_or("").to_uppercase()));
    let _ = d;

    // «Дальше»
    let open: Vec<Value> = items.iter().filter(|x| !App::is_done(&x.1)).map(|x| json!({"task": x.1, "list": x.0})).collect();
    let nx = sputnik_core::small::pick_next(&open, &app.layer["tasks"], &tdy);
    if nx.is_object() {
        g.set_next_title(ss(text(&nx["task"]["title"])));
        let why = sputnik_core::small::next_reason(&nx["task"], &app.layer["tasks"], &tdy, |due| {
            sputnik_core::when::when_text(&due[..10.min(due.len())], None, d).0.to_lowercase()
        });
        g.set_next_why(ss(why));
    } else {
        g.set_next_title("".into());
        g.set_next_why("".into());
    }

    // встречи
    let evs: Vec<Chip> = app.events_on(&tdy).iter().map(|e| event_chip(e)).collect();
    g.set_today_events(model(evs));

    // привычки
    let log = app.habit_log();
    let hs: Vec<HabitChip> = app.habits().iter().filter(|h| hb::scheduled_on(h, log, &tdy)).map(|h| habit_chip(h, log, &tdy)).collect();
    g.set_today_habits(model(hs));

    // входящие
    let inbox: Vec<InboxRow> = app.inbox_items().iter().map(|x| {
        let lid = text(&x["listId"]);
        InboxRow { list_id: ss(lid.clone()), id: ss(text(&x["task"]["id"])), title: ss(text(&x["task"]["title"])),
            list: ss(app.list_name(&lid)), when: ss(day10(&x["task"]["due"])) }
    }).collect();
    g.set_inbox(model(inbox));

    // разбор строки
    let (und, dest) = understood(app, &u.quick);
    g.set_understood(strings(und));
    g.set_dest(ss(dest));
}

pub fn understood(app: &App, line: &str) -> (Vec<String>, String) {
    if line.trim().is_empty() {
        return (vec![], String::new());
    }
    let tdy = today_s();
    let p = route::parse_line(line, hb::now().date(), &json!({}));
    let und: Vec<String> = td::understood(&p, &tdy).iter().map(|x| text(&x["text"])).collect();
    let r = route::route(line, &app.board_lists(), &app.layer, &app.tasks, None, crate::state::now_ms());
    let dest = r.first().map(|x| app.list_name(s(&x["listId"]))).unwrap_or_default();
    (und, dest)
}

pub fn event_chip(e: &Value) -> Chip {
    let time = sputnik_core::calendar::local_dt(s(&e["start"]["dateTime"])).map(|d| d.format("%H:%M").to_string()).unwrap_or_default();
    let bd = App::is_birthday(e);
    Chip {
        title: ss(text(&e["summary"])),
        hue: if bd { color("gold") } else { color("work") },
        done: false,
        kind: if bd { 3 } else { 0 },
        list_id: ss(text(&e["calId"])),
        id: ss(format!("{}|{}", text(&e["calId"]), text(&e["id"]))),
        time: ss(if time.is_empty() { "весь день".to_string() } else { time }),
    }
}

pub fn habit_color(h: &Value) -> Color {
    let c = s(&h["color"]);
    if c.is_empty() { color("gold") } else { color(c) }
}

/// Значок привычки — первая буква названия в кружке цвета привычки (эмодзи в шрифтах окна нет).
pub fn habit_icon(h: &Value) -> String {
    text(&h["name"]).chars().next().map(|c| c.to_uppercase().collect()).unwrap_or_else(|| "·".into())
}

pub fn habit_chip(h: &Value, log: &Value, day: &str) -> HabitChip {
    HabitChip {
        id: ss(text(&h["id"])),
        name: ss(text(&h["name"])),
        icon: ss(habit_icon(h)),
        hue: habit_color(h),
        done: hb::is_done(log, &h["id"], day),
        count: hb::count_on(log, h, day) as i32,
        goal: hb::goal_n(h) as i32,
    }
}
