//! Модели окон: задача, «Создать», поиск.
use super::*;
use crate::{Opt, Sub};
use sputnik_core::{create as cr, habits as hb, reminders as rem, route, today as td, when};

/// Состояние окна «Создать».
#[derive(Clone, Default)]
pub struct Create {
    pub kind: i32,
    pub text: String,
    pub dest: Option<String>,
    pub cal: Option<String>,
    pub dur: i64,
    pub remind: Option<Vec<i64>>,
}

pub fn opt(id: impl Into<String>, label: impl Into<String>, on: bool) -> Opt {
    Opt { id: ss(id), label: ss(label), hint: ss(""), hue: color("clay"), on }
}

pub fn list_opts(app: &App, cur: &str) -> Vec<Opt> {
    app.board_lists().iter().map(|l| {
        let id = s(&l["id"]);
        let sp = app.sphere_of(id).and_then(|x| app.spheres().into_iter().find(|y| y["id"] == x.as_str())).map(|x| text(&x["name"])).unwrap_or_default();
        Opt { id: ss(id), label: ss(text(&l["title"])), hint: ss(sp), hue: list_hue(app, id), on: id == cur }
    }).collect()
}

/// Минуты напоминаний из правил слоя (только «за N минут»).
pub fn lead_mins(r: &Value) -> Vec<i64> {
    rem::rules_of(r).iter().filter(|x| x["kind"] == "lead").filter_map(|x| x["min"].as_i64()).collect()
}

pub fn render(app: &App, u: &mut Ui, g: &S) {
    // окно задачи
    match u.task.clone().and_then(|(l, id)| app.task(&l, &id).cloned().map(|t0| (l, t0))) {
        Some((l, t0)) => task(app, u, g, &l, &t0),
        None => {
            u.task = None;
            g.set_task_open(false);
        }
    }
    // «Создать»
    match u.create.clone() {
        Some(c) => create(app, &c, g),
        None => g.set_create_open(false),
    }
    // поиск
    g.set_search_open(u.search.is_some());
    g.set_found(model(u.found.iter().map(|x| x.0.clone()).collect()));
}

fn task(app: &App, u: &Ui, g: &S, list: &str, t0: &Value) {
    let id = s(&t0["id"]);
    let l = app.lt(id);
    g.set_task_open(true);
    g.set_t_list(ss(list));
    g.set_t_id(ss(id));
    g.set_t_title(ss(text(&t0["title"])));
    g.set_t_notes(ss(text(&t0["notes"])));
    g.set_t_list_name(ss(app.list_name(list)));
    let day = day10(&t0["due"]);
    let slot = &l["slot"];
    let due_in = match (day.is_empty(), slot["s"].as_str()) {
        (true, _) => String::new(),
        (false, Some(st)) => format!("{} {st}", cr::day_month(&day)),
        (false, None) => cr::day_month(&day),
    };
    g.set_t_due(ss(due_in));
    let (a0, b0) = when::when_text(&day, slot["s"].as_str().map(|x| (x, slot["e"].as_str().unwrap_or(x))), hb::now().date());
    g.set_t_due_label(ss(if b0.is_empty() { a0 } else { format!("{a0}, {b0}") }));
    g.set_t_prio(n(&l["priority"]).unwrap_or(0.0) as i32);
    let cols = app.columns(list);
    let cur = app.col_of(t0, &cols.iter().map(|c| c.0.clone()).collect::<Vec<_>>());
    g.set_t_cols(model(if cols.len() <= 1 { vec![] } else {
        cols.iter().map(|(c, ts)| {
            let lim = n(&c["limit"]).unwrap_or(0.0) as usize;
            Opt { id: ss(text(&c["id"])), label: ss(text(&c["name"])), hint: ss(if lim > 0 { format!("{}/{lim}", ts.len()) } else { String::new() }),
                hue: color(&sputnik_core::templates::col_color(c)), on: c["id"] == cur.as_str() }
        }).collect()
    }));
    g.set_t_subs(model(app.subtasks(list, id).iter().map(|x| Sub { id: ss(text(&x["id"])), title: ss(text(&x["title"])), done: App::is_done(x) }).collect()));
    let mins = lead_mins(&l["remind"]);
    g.set_t_reminds(model(rem::LEADS.iter().filter(|x| x.0 != 5 && x.0 != 43200).map(|(m, lab)| opt(m.to_string(), lab.replace("За ", "за ").replace("В момент начала", "в начале"), mins.contains(m))).collect()));
    let every = s(&l["repeat"]["every"]);
    let mut reps = vec![opt("", "нет", every.is_empty())];
    reps.extend([("day", "день"), ("weekdays", "будни"), ("week", "неделя"), ("month", "месяц"), ("year", "год")].iter().map(|(id2, lab)| opt(*id2, *lab, every == *id2)));
    g.set_t_repeats(model(reps));
    g.set_t_lists(model(list_opts(app, list)));
    let pending = app.outbox.pending_for(id);
    g.set_t_saved(ss(if pending { if app.flags.offline { "Нет связи — сохранится, когда появится".to_string() } else { "Сохраняю…".to_string() } } else if id.starts_with("tmp-") { "Сохраняю…".into() } else { u.saved.clone().max("Сохранено в Google Tasks".into()) }));
}

/// Куда ляжет задача из строки: выбранный руками список или угаданный.
pub fn dest_of(app: &App, c: &Create) -> (String, String) {
    if let Some(d) = &c.dest {
        return (d.clone(), "выбрано".into());
    }
    let r = route::route(&c.text, &app.board_lists(), &app.layer, &app.tasks, None, crate::state::now_ms());
    match r.first() {
        Some(x) => (text(&x["listId"]), text(&x["why"])),
        None => (app.board_lists().first().map(|l| text(&l["id"])).unwrap_or_default(), String::new()),
    }
}

pub fn cal_of(app: &App, c: &Create) -> String {
    c.cal.clone().unwrap_or_else(|| app.calendars.iter().find(|x| t(&x["primary"])).map(|x| text(&x["id"])).unwrap_or_else(|| "primary".into()))
}

pub fn default_mins(app: &App, kind: i32) -> Vec<i64> {
    let k = match kind { 1 => "event", 3 => "birthday", _ => "task" };
    a(&rem::default_mins(&app.layer["settings"], k)).iter().filter_map(|x| x.as_i64()).collect()
}

fn create(app: &App, c: &Create, g: &S) {
    g.set_create_open(true);
    g.set_c_kind(c.kind);
    g.set_c_text(ss(c.text.clone()));
    let tdy = today_s();
    let p = route::parse_line(&c.text, hb::now().date(), &json!({}));
    let (und, hint): (Vec<String>, String) = match c.kind {
        2 => {
            let h = cr::parse_habit(&c.text, &json!({}));
            (a(&h["toks"]).iter().map(|x| text(&x["l"])).collect(), "Привычка: цель («8 стаканов»), частота («по будням», «3 раза в неделю») и часть дня («утром»).".into())
        }
        3 => (if c.text.trim().is_empty() { vec![] } else {
            let w = when::parse_when(&c.text, hb::now().date());
            w.day.map(|d| vec![cr::day_month(&d)]).unwrap_or_default()
        }, "Имя и дата: «Мама 12 марта». Каждый год, задача «Подарок» заведётся сама.".into()),
        1 => (td::understood(&p, &tdy).iter().map(|x| text(&x["text"])).collect(), "Событие в Google Календаре: день и время словами — «в пт 14:00».".into()),
        _ => {
            let sk = cr::suggest_kind(&c.text, &p);
            let h = if s(&sk["kind"]) == "event" { "Похоже на встречу — можно сделать событием: вкладка «Событие» сверху".to_string() } else { "Дата, время, @список, #тип, !!! — прямо в строке.".to_string() };
            (td::understood(&p, &tdy).iter().map(|x| text(&x["text"])).collect(), h)
        }
    };
    g.set_c_understood(strings(if c.text.trim().is_empty() { vec![] } else { und }));
    g.set_c_hint(ss(hint));
    let (dest, why) = dest_of(app, c);
    g.set_c_dest(ss(app.list_name(&dest)));
    g.set_c_dest_hue(list_hue(app, &dest));
    g.set_c_dest_why(ss(why));
    g.set_c_lists(model(list_opts(app, &dest)));
    let cal = cal_of(app, c);
    g.set_c_cals(model(app.writable_cals().iter().map(|x| Opt { id: ss(text(&x["id"])), label: ss(text(&x["summaryOverride"]).max(text(&x["summary"]))), hint: ss(""),
        hue: color(s(&x["backgroundColor"])), on: x["id"] == cal.as_str() }).collect()));
    let dur = if c.dur == 0 { 60 } else { c.dur };
    g.set_c_durs(model([(15, "15 мин"), (30, "30 мин"), (60, "1 час"), (120, "2 часа"), (-1, "весь день")].iter().map(|(m, l)| opt(m.to_string(), *l, *m == dur)).collect()));
    let leads = if c.kind == 3 { &rem::BDAY_LEADS[..] } else { &rem::LEADS[..] };
    let mins = c.remind.clone().unwrap_or_else(|| default_mins(app, c.kind));
    g.set_c_reminds(model(leads.iter().filter(|x| x.0 != 5).enumerate().filter(|(i, x)| mins.contains(&x.0) || *i < 3).map(|(_, (m, l))| opt(m.to_string(), l.replace("За ", "за ").replace("В момент начала", "в начале"), mins.contains(m))).take(4).collect()));
    // событие: свободно ли
    let free = if c.kind == 1 && t(&p["time"]) {
        let day = if p["day"].is_null() { tdy.clone() } else { text(&p["day"]) };
        let st = text(&p["time"]);
        let en = cr::add_min(&st, dur.max(15));
        let f = cr::free_check(&app.events_on(&day), &day, &json!({"s": st, "e": en}));
        if f["clash"].is_string() { format!("⚠ пересекается с «{}»", text(&f["clash"])) } else if f["until"].is_string() { format!("свободно до {}", text(&f["until"])) } else { "весь вечер свободен".into() }
    } else { String::new() };
    g.set_c_free(ss(free));
}
