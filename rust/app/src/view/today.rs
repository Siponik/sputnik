//! Модели «Сегодня».
use super::*;
use crate::{Chip, HabitChip, InboxRow, SrcNode, SrcRow, TaskRow, Wire};
use sputnik_core::{habits as hb, route, today as td};

pub fn row(app: &App, list: &str, t: &Value) -> TaskRow {
    let l = app.lt(s(&t["id"]));
    let (when, late) = due_text(t, &l["slot"]);
    let subs = app.subtasks(list, s(&t["id"]));
    let sub = if subs.is_empty() { String::new() } else { format!("{}/{}", subs.iter().filter(|x| App::is_done(x)).count(), subs.len()) };
    let when = if when == "сегодня" { String::new() } else { when.replace("сегодня, ", "") };
    // коротко, как в макете: «11:00», «ВЧЕРА», «08.11»
    let when = match when.strip_prefix("просрочено · ") {
        Some(w) if w.starts_with("вчера") => "вчера".to_string(),
        Some(_) => { let d = day10(&t["due"]); if d.len() == 10 { format!("{}.{}", &d[8..10], &d[5..7]) } else { d } }
        None => when,
    };
    let when = if late || when.len() != 5 { when.to_uppercase() } else { when };
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
    let all_rows: Vec<TaskRow> = over.iter().chain(now.iter()).cloned().collect();
    // п.39: много задач или списков — видно не больше 6 открытых, остальные под «Ещё N», сделанные — в «Сделано · N»
    let _lists_n = { let mut v: Vec<&String> = items.iter().map(|x| &x.0).collect(); v.sort(); v.dedup(); v.len() };
    let open_rows: Vec<TaskRow> = all_rows.iter().filter(|r| !r.done).cloned().collect();
    let done_rows: Vec<TaskRow> = all_rows.iter().filter(|r| r.done).cloned().collect();
    // новый вид «Сегодня» (G_TodayMany) — всегда; свёртки появляются, только когда есть что прятать
    let many = true;
    g.set_today_many(many);
    let (rows, more_n, fold_n, k_open) = if !many { (all_rows.clone(), 0, 0, all_rows.len()) } else {
        let k = if u.today_more { open_rows.len() } else { open_rows.len().min(6) };
        let mut v: Vec<TaskRow> = open_rows[..k].to_vec();
        if u.today_done { v.extend(done_rows.iter().cloned()); }
        (v, open_rows.len() - k, done_rows.len(), k)
    };
    g.set_overdue(model(over));
    g.set_today(model(now));
    let d = sputnik_core::dates::parse_ymd(&tdy).unwrap();
    let wd = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"];
    g.set_today_label(ss(format!("{} {}", wd[chrono::Datelike::weekday(&d).num_days_from_monday() as usize], d.format("%d.%m"))));
    let _ = d;

    // схема дня по макету G_Today: холст 1220 px, источники слева → строки в середине; координаты холста
    // считаются здесь (окно только рисует). Строка 40 + 6, строка «Дальше» выше на 46.
    const TOP: f32 = 20.0;
    let rows_top = 90.0 + if u.quick.trim().is_empty() { 0.0 } else { 24.0 };
    let open0: Vec<Value> = items.iter().filter(|x| !App::is_done(&x.1)).map(|x| json!({"task": x.1, "list": x.0})).collect();
    let nx0 = sputnik_core::small::pick_next(&open0, &app.layer["tasks"], &tdy);
    let next_at = rows.iter().position(|r| nx0.is_object() && r.id.as_str() == text(&nx0["task"]["id"]));
    // место каждой строки: строка 40 + 6, «Дальше» выше на 46, свёртки по 41 (G_TodayMany)
    let mut ys: Vec<f32> = vec![];
    let mut yy = rows_top;
    let (mut more_y, mut fold_y) = (-1.0f32, -1.0f32);
    for i in 0..rows.len() {
        if many && i == k_open {
            if more_n > 0 || (u.today_more && open_rows.len() > 6) { more_y = yy; yy += 41.0; }
            if fold_n > 0 { fold_y = yy; yy += 41.0; }
        }
        ys.push(yy);
        yy += if Some(i) == next_at { 92.0 } else { 46.0 };
    }
    if many && k_open >= rows.len() {
        if more_n > 0 || (u.today_more && open_rows.len() > 6) { more_y = yy; yy += 41.0; }
        if fold_n > 0 { fold_y = yy; yy += 41.0; }
    }
    let row_y = |i: usize| ys[i] + 20.0;
    let rows_end = if rows.is_empty() && more_y < 0.0 && fold_y < 0.0 { rows_top + 160.0 } else { yy };
    g.set_row_ys(model(ys.clone()));
    g.set_more_y(more_y);
    g.set_more_n(if u.today_more { 0 } else { more_n as i32 });
    g.set_fold_y(fold_y);
    g.set_fold_n(fold_n as i32);
    g.set_fold_open(u.today_done);
    let node_h = |n: usize| 30.0 + n as f32 * 28.0 + 2.0;
    let mut src: Vec<SrcNode> = vec![];
    let mut wires: Vec<Wire> = vec![];
    let mut y = TOP;
    let mut order: Vec<String> = vec![];
    for (l, _) in &items {
        if !order.contains(l) { order.push(l.clone()) }
    }
    // п.39: много — одна нода «СПИСКИ»: строка на список «осталось / всего», все провода в один вход (hub)
    const HUB: f32 = 48.0;
    g.set_hub_y(HUB);
    if many {
        let mut srows: Vec<SrcRow> = vec![];
        for (j, l) in order.iter().enumerate() {
            let its: Vec<&(String, Value)> = items.iter().filter(|x| &x.0 == l).collect();
            let left = its.iter().filter(|x| !App::is_done(&x.1)).count();
            srows.push(SrcRow { title: ss(app.list_name(l)), right: ss(format!("{left} / {}", its.len())), done: false, accent: false, fold: false, hue: list_hue(app, l) });
            wires.push(Wire { y1: y + 42.0 + j as f32 * 28.0, y2: 20.0 + HUB, hue: list_hue(app, l), dashed: false });
        }
        let empty = app.board_lists().iter().filter(|l| !order.iter().any(|o| o == s(&l["id"]))).count();
        if empty > 0 {
            srows.push(SrcRow { title: ss(format!("Ещё {} · сегодня пусто", super::spheres::plural(empty, "список", "списка", "списков"))), right: ss(""), done: false, accent: false, fold: true, hue: Color::default() });
        }
        let h = node_h(srows.len());
        src.push(SrcNode { title: ss("СПИСКИ"), label: ss("ОСТАЛОСЬ / ВСЕГО"), hue: color(""), y, h, rows: model(srows), dashed: false });
        y += h + 20.0;
    }
    for l in order.iter().filter(|_| !many) {
        let idx: Vec<usize> = rows.iter().enumerate().filter(|(_, r)| r.list_id.as_str() == l).map(|(i, _)| i).collect();
        let hue = list_hue(app, l);
        let label = match board::view_of(app, l).as_str() { "pipe" => "КОНВЕЙЕР", "stickers" => "СТИКЕРЫ", "list" => "СПИСОК", _ => "КАНБАН" };
        let srows: Vec<SrcRow> = idx.iter().map(|&i| {
            let r = &rows[i];
            SrcRow { title: r.title.clone(), right: if r.when.is_empty() { ss("ДЕНЬ") } else { r.when.clone() }, done: r.done, accent: Some(i) == next_at, fold: false, hue: Color::default() }
        }).collect();
        for (j, &i) in idx.iter().enumerate() {
            wires.push(Wire { y1: y + 42.0 + j as f32 * 28.0, y2: 20.0 + row_y(i), hue: if rows[i].done { color("#7C7E88") } else { hue }, dashed: Some(i) == next_at });
        }
        let h = node_h(srows.len());
        src.push(SrcNode { title: ss(app.list_name(l).to_uppercase()), label: ss(label), hue, y, h, rows: model(srows), dashed: false });
        y += h + 28.0;
    }
    let ib = app.inbox_items();
    let claude_y = rows_end + 2.0 + 19.0;
    if !ib.is_empty() {
        let srows: Vec<SrcRow> = if many { vec![SrcRow { title: ss(format!("{} без дня", super::spheres::plural(ib.len(), "задача", "задачи", "задач"))), right: ss(""), done: false, accent: false, fold: false, hue: Color::default() }] } else { ib.iter().take(4).map(|x| SrcRow { title: ss(text(&x["task"]["title"])), right: ss(format!("→ {}", short(&app.list_name(&text(&x["listId"])), 8).to_uppercase())), done: false, accent: false, fold: false, hue: Color::default() }).collect() };
        for j in 0..srows.len() {
            wires.push(Wire { y1: y + 42.0 + j as f32 * 28.0, y2: 20.0 + claude_y, hue: color("#A3A5AE"), dashed: true });
        }
        let h = node_h(srows.len());
        src.push(SrcNode { title: ss("ОТ CLAUDE"), label: ss(if many { format!("ЖДУТ {}", ib.len()) } else { "ЖДУТ".into() }), hue: color("#A3A5AE"), y, h, rows: model(srows), dashed: true });
        y += h + if many { 20.0 } else { 28.0 };
    }
    let log0 = app.habit_log();
    let hs0: Vec<Value> = app.habits().iter().filter(|h| hb::scheduled_on(h, log0, &tdy)).cloned().collect();
    let habits_top = if ib.is_empty() { rows_end + 6.0 } else { rows_end + 52.0 };
    let habits_y = habits_top + 38.0;
    if !hs0.is_empty() {
        let hd = hs0.iter().filter(|h| hb::is_done(log0, &h["id"], &tdy)).count();
        let srows: Vec<SrcRow> = if many { vec![SrcRow { title: ss(hs0.iter().map(|h| text(&h["name"])).collect::<Vec<_>>().join(", ")), right: ss(""), done: false, accent: false, fold: false, hue: Color::default() }] } else { hs0.iter().map(|h| {
            let c = habit_chip(h, log0, &tdy);
            SrcRow { title: c.name.clone(), right: ss(if c.goal > 1 { format!("{}/{}", c.count, c.goal) } else if c.done { "✓".into() } else { String::new() }), done: false, accent: c.done, fold: false, hue: Color::default() }
        }).collect() };
        for j in 0..srows.len() {
            wires.push(Wire { y1: y + 42.0 + j as f32 * 28.0, y2: 20.0 + habits_y, hue: color("gold"), dashed: false });
        }
        let h = node_h(srows.len());
        src.push(SrcNode { title: ss("ПРИВЫЧКИ"), label: ss(if many { format!("{hd} / {}", hs0.len()) } else { "СЕГОДНЯ".into() }), hue: color("gold"), y, h, rows: model(srows), dashed: false });
    }
    g.set_center_h(habits_top + if hs0.is_empty() { 0.0 } else { 92.0 } + 16.0);
    let src_end = src.iter().map(|n| n.y + n.h).fold(0.0f32, f32::max);
    g.set_today_h((TOP + habits_top + if hs0.is_empty() { 0.0 } else { 92.0 } + 16.0 + 40.0).max(src_end + 20.0));
    g.set_habits_top(habits_top);
    // загрузка дня по часам 09–21: цвет списка, где в этот час задача со временем
    let mut cells = vec![Color::from_argb_u8(0, 0, 0, 0); 12];
    for r in &rows {
        if let Some(h) = r.when.get(0..2).and_then(|x| x.parse::<usize>().ok()).filter(|_| r.when.len() == 5) {
            if (9..21).contains(&h) { cells[h - 9] = r.hue; }
        }
    }
    g.set_hour_cells(model(cells));
    g.set_today_src(model(src));
    g.set_today_wires(model(wires));
    g.set_rows_top(rows_top);
    g.set_claude_y(claude_y);
    g.set_habits_y(habits_y);
    g.set_habits_done(hs0.iter().filter(|h| hb::is_done(log0, &h["id"], &tdy)).count() as i32);

    // «Дальше»
    let open: Vec<Value> = items.iter().filter(|x| !App::is_done(&x.1)).map(|x| json!({"task": x.1, "list": x.0})).collect();
    let nx = sputnik_core::small::pick_next(&open, &app.layer["tasks"], &tdy);
    let at = next_at;
    g.set_next_at(at.map(|x| x as i32).unwrap_or(-1));
    if let Some(i) = at {
        g.set_next_time(rows[i].when.clone());
        g.set_next_meta(ss(format!("{} · {}", rows[i].when, rows[i].list.to_uppercase())));
    }
    g.set_day_rows(model(rows.clone()));
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
