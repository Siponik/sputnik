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
    let all = app.habits();
    let sch: Vec<&Value> = all.iter().filter(|h| hb::scheduled_on(h, log, &tdy)).collect();
    g.set_habit_meta(ss(format!("{} {} · СЕГОДНЯ {} / {}", all.len(), hb::plural(all.len() as i64, ["ПРИВЫЧКА", "ПРИВЫЧКИ", "ПРИВЫЧЕК"]), sch.iter().filter(|h| hb::is_done(log, &h["id"], &tdy)).count(), sch.len())));
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
            week: model(hb::week_row(h, log).iter().map(|x| if s(&x["st"]) == "f" { 6 } else { st_num(s(&x["st"]), t(&x["today"])) }).collect()),
            off: !hb::scheduled_on(h, log, &tdy),
            sched_up: ss(sched_up(h)),
            unit_up: ss(if k == 0 && hb::broken(h, log).is_object() { "СЕРИЯ НА ПАУЗЕ".to_string() } else if weekly { "НЕД ПОДРЯД".into() } else { "ДН ПОДРЯД".into() }),
            foot: ss(foot(h, log, k, &tdy).0),
            foot_hi: foot(h, log, k, &tdy).1,
            now_i: hb::dow(hb::now().date()) as i32,
            letter: ss(text(&h["name"]).chars().next().map(|c| c.to_uppercase().to_string()).unwrap_or_default()),
        }
    }).collect();
    g.set_habits(model(cards));
    let tip = hb::habit_tip(&hs, log).map(|t0| format!("«{}» срывается {} раз — попробуй сразу после «{}», в {}", text(&t0.habit["name"]), t0.misses, text(&t0.anchor["name"]), t0.time));
    g.set_habit_tip(ss(tip.unwrap_or_default()));
    // панель выбранной привычки
    let sel = hs.iter().find(|h| text(&h["id"]) == u.habit_sel).or(hs.first());
    if let Some(h) = sel {
        let st = hb::stats(h, log);
        let k = st["streak"].as_i64().unwrap_or(0);
        let weekly = n(&h["perWeek"]).unwrap_or(0.0) > 0.0;
        let nd = hb::now().date();
        g.set_hp_id(ss(text(&h["id"])));
        g.set_hp_name(ss(text(&h["name"]).to_uppercase()));
        g.set_hp_hue(habit_color(h));
        g.set_hp_sched(ss(hb::schedule_label(&h["days"]).to_uppercase()));
        g.set_hp_streak(k as i32);
        let passed = [7, 21, 50, 100].iter().any(|m| k == *m) || (k > 7 && [7i64, 21, 50, 100].contains(&k));
        g.set_hp_label(ss(format!("{}{}", if weekly { "НЕД ПОДРЯД" } else { if k % 10 == 1 && k % 100 != 11 { "ДЕНЬ ПОДРЯД" } else { "ДН ПОДРЯД" } }, if passed || k >= 7 { " · ВЕХА ПРОЙДЕНА" } else { "" })));
        g.set_hp_ms((hb::milestone_pos(k as f64) / 100.0) as f32);
        const MN: [&str; 12] = ["ЯНВАРЬ", "ФЕВРАЛЬ", "МАРТ", "АПРЕЛЬ", "МАЙ", "ИЮНЬ", "ИЮЛЬ", "АВГУСТ", "СЕНТЯБРЬ", "ОКТЯБРЬ", "НОЯБРЬ", "ДЕКАБРЬ"];
        g.set_hp_month(ss(MN[nd.month0() as usize]));
        let mg = hb::month_grid(h, log, nd.year(), nd.month0() as i32);
        let mut cells: Vec<Opt> = a(&mg["cells"]).iter().map(|c| {
            let stt = s(&c["state"]);
            let hint = if stt.contains("done") { "done" } else if stt.starts_with("today") { "today" } else { stt };
            Opt { id: ss(c["n"].as_i64().map(|x| x.to_string()).unwrap_or_default()), label: ss(""), hint: ss(hint), hue: habit_color(h), on: false }
        }).collect();
        while cells.last().map(|c| c.hint.as_str() == "blank").unwrap_or(false) { cells.pop(); }
        g.set_hp_cells(model(cells));
        let mr = hb::month_row(h, log, nd.year(), nd.month0() as i32);
        g.set_hp_stats(strings(vec![st["best"].as_i64().unwrap_or(0).to_string(), hb::total_done(h, log).to_string(), mr["pct"].as_i64().map(|x| format!("{x}%")).unwrap_or("—".into())]));
        let w = hb::habit_win(h);
        g.set_hp_win(ss(if w.is_object() { format!("{} — {}", text(&w["s"]), text(&w["e"])) } else { "в любое время".into() }));
        g.set_hp_part(ss(hb::part_name(h).to_uppercase()));
        g.set_hp_tg(h["remind"]["tg"] != false);
        g.set_hp_winrem(h["remind"]["win"] != false);
    } else {
        g.set_hp_id("".into());
    }
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
        const WD: [&str; 7] = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"];
        g.set_hm_wd(strings((1..=dim as u32).map(|d| WD[chrono::NaiveDate::from_ymd_opt(y, nd.month(), d).map(|x| x.weekday().num_days_from_monday() as usize).unwrap_or(0)].to_string()).collect()));
        g.set_hm_pct(strings(hs.iter().map(|h| hb::month_row(h, log, y, m0)["pct"].as_i64().map(|x| x.to_string()).unwrap_or("—".into())).collect()));
        g.set_hm_today(nd.day() as i32);
        const MN: [&str; 12] = ["ЯНВАРЬ", "ФЕВРАЛЬ", "МАРТ", "АПРЕЛЬ", "МАЙ", "ИЮНЬ", "ИЮЛЬ", "АВГУСТ", "СЕНТЯБРЬ", "ОКТЯБРЬ", "НОЯБРЬ", "ДЕКАБРЬ"];
        g.set_hm_title(ss(format!("{} {} · {} {}", MN[nd.month0() as usize], y, all.len(), hb::plural(all.len() as i64, ["ПРИВЫЧКА", "ПРИВЫЧКИ", "ПРИВЫЧЕК"]))));
        let sm = hb::month_summary(&hs, log, y, m0);
        let clean: Vec<String> = a(&sm["clean"]).iter().map(|x| text(x)).collect();
        let pct = sm["pct"].as_i64();
        let prev = sm["prev"].as_i64();
        let mut sums = vec![
            format!("Лучший месяц|{}", if clean.is_empty() { "Пока без чистых серий".into() } else { format!("{} — без пропусков", clean.join(" и ")) }),
            format!("Средний процент|{}", match (pct, prev) { (Some(p), Some(q)) => format!("{p}% · на {}% {} прошлого месяца", (p - q).abs(), if p >= q { "лучше" } else { "хуже" }), (Some(p), None) => format!("{p}%"), _ => "—".into() }),
        ];
        let br: Vec<String> = hs.iter().filter_map(|h| { let b = hb::broken(h, log); if b.is_object() { Some(text(&h["name"])) } else { None } }).collect();
        sums.push(format!("Сорвалось|{}", if br.is_empty() { "Ничего — так держать".into() } else { br.join(", ") }));
        g.set_hm_sum(strings(sums.iter().flat_map(|x| { let (a0, b0) = x.split_once('|').unwrap_or((x, "")); [a0.to_string(), b0.to_string()] }).collect()));
    }
}

fn sched_up(h: &Value) -> String {
    let pw = n(&h["perWeek"]).unwrap_or(0.0);
    let first = if pw > 0.0 { format!("{} В НЕД", pw as i64) } else if hb::goal_n(h) > 1 {
        format!("{} {}", hb::goal_n(h), text(&h["goal"]["unit"]).to_uppercase())
    } else { hb::schedule_label(&h["days"]).to_uppercase() };
    let p = hb::part_of(h);
    if hb::goal_n(h) > 1 || p == "any" || p.is_empty() { first } else { format!("{} · {}", first, hb::part_name(h).to_uppercase()) }
}

/// Нижняя строка карточки: веха, счётчик или окно; true — золотом.
fn foot(h: &Value, log: &Value, k: i64, tdy: &str) -> (String, bool) {
    let pw = n(&h["perWeek"]).unwrap_or(0.0);
    if pw > 0.0 {
        let c = hb::week_row(h, log).iter().filter(|x| s(&x["st"]) == "d").count();
        return (format!("{} / {} НА НЕДЕЛЕ", c, pw as i64), false);
    }
    if hb::goal_n(h) > 1 {
        return (format!("{} / {} СЕГОДНЯ", hb::count_on(log, h, tdy), hb::goal_n(h)), false);
    }
    if hb::broken(h, log).is_object() {
        return ("ВЧЕРА ПРОПУСК".into(), false);
    }
    if k > 0 {
        let m = hb::next_milestone(k as f64);
        return (format!("→ {} · ЧЕРЕЗ {} ДН", m, m - k), true);
    }
    let w = hb::habit_win(h);
    if w.is_object() { (format!("ОКНО {}–{}", text(&w["s"]), text(&w["e"])), false) } else { (String::new(), false) }
}
