//! Модели окон: задача, «Создать», поиск.
use super::*;
use crate::{Opt, Sub};
use sputnik_core::{compose as cr2, create as cr, habits as hb, reminders as rem, route, when};

/// Состояние окна «Создать».
#[derive(Clone, Default)]
pub struct Create {
    pub kind: i32,
    pub text: String,
    pub dest: Option<String>,
    pub cal: Option<String>,
    pub dur: i64,
    pub remind: Option<Vec<i64>>,
    /// Выбранное кнопками: срок, приоритет, повтор, возвращённые в название куски.
    pub m: cr2::Manual,
    pub notes: String,
    /// Этап (колонка доски); None — первая.
    pub col: Option<String>,
    pub subs: Vec<String>,
    /// Открытый выбор в «Свойствах».
    pub popen: String,
    /// Событие: место.
    pub place: String,
    /// Привычка: частота кнопками (Null — из строки), часть дня ("" — из строки), своё окно, значок.
    pub hfreq: Value,
    pub hpart: String,
    pub hwin: Option<(String, String)>,
    pub hicon: String,
    /// День рождения: год (строкой, проверяется при создании) и «подарок заранее» в днях (None — за неделю).
    pub year: String,
    pub gift: Option<i64>,
}

/// Итог строки и выбранного руками (название без дат, срок, приоритет, повтор).
pub fn resolved(c: &Create) -> Value {
    cr2::resolve(&c.text, c.kind, &c.m, if c.dur == 0 { 60 } else { c.dur }, hb::now().date())
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
    g.set_c_notes(ss(c.notes.clone()));
    let tdy = hb::now().date();
    let x = resolved(c);
    let p = &x["parsed"];
    let empty = c.text.trim().is_empty();
    let habit = (c.kind == 2).then(|| cr::parse_habit(&c.text, &c.m.off_json()));
    let marks = match &habit { Some(h) => h["marks"].clone(), None => p["marks"].clone() };
    g.set_c_line_md(line_md(&c.text, &marks));
    g.set_c_title(ss(match &habit { Some(h) => text(&h["name"]), None => text(&x["title"]) }));
    g.set_c_prio(x["priority"].as_i64().unwrap_or(0) as i32);
    // понятое из строки — чипы с «×»
    g.set_c_toks(model(if c.kind == 2 { vec![] } else {
        a(&x["toks"]).iter().filter(|k| c.kind == 0 || k["k"] != "prio").map(|k| Opt { id: ss(text(&k["k"])), label: ss(text(&k["l"])), hint: ss(""), hue: color("clay"), on: t(&k["over"]) }).collect()
    }));
    g.set_c_understood(strings(match &habit { Some(h) if !empty => a(&h["toks"]).iter().map(|x| text(&x["l"])).collect(), _ => vec![] }));
    // срок
    g.set_c_when(ss(cr2::when_label(&x["day"], &x["slot"], tdy)));
    let q = cr2::quick_of(&x["day"], tdy);
    g.set_c_quick(model(cr2::quick_days(tdy).iter().filter(|d| c.kind == 0 || d.0 != "none").map(|(id, l, _)| opt(*id, *l, *id == q)).collect()));
    let every = s(&x["repeat"]["every"]);
    g.set_c_reps(model([("", "нет"), ("day", "каждый день"), ("weekdays", "по будням"), ("week", "каждую неделю"), ("month", "каждый месяц")].iter().map(|(id, l)| opt(*id, *l, every == *id)).collect()));
    let meta: Vec<String> = {
        let mut v = vec![if c.kind == 3 { x["day"].as_str().map(cr::day_month).unwrap_or_else(|| "дата?".into()) } else { cr2::when_label(&x["day"], &x["slot"], tdy) }];
        if let Some(pr) = x["priority"].as_i64().filter(|p| *p > 0 && c.kind == 0) { v.push(["", "!!! высокий", "!! средний", "! низкий"][pr as usize].into()); }
        if !every.is_empty() { v.push(format!("↻ {}", sputnik_core::repeat::repeat_label(&x["repeat"]))); }
        v
    };
    g.set_c_meta(ss(match &habit { Some(h) => a(&h["toks"]).iter().map(|x| text(&x["l"])).collect::<Vec<_>>().join(" · "), None => meta.join(" · ") }));
    let hint = match c.kind {
        2 => "Привычка: цель («8 стаканов»), частота («по будням», «3 раза в неделю») и часть дня («утром»).".to_string(),
        3 => "Имя и дата: «Мама 12 марта». Каждый год, задача «Подарок» заведётся сама.".into(),
        1 => "Событие в Google Календаре: день и время словами — «в пт 14:00» — или кнопкой «Выбрать…» (Alt+D).".into(),
        _ => {
            let sk = cr::suggest_kind(&c.text, p);
            if s(&sk["kind"]) == "event" { "Похоже на встречу — можно сделать событием: Alt+2".to_string() } else { "Дата, время, @список, #тип, !!! — прямо в строке, в название они не попадут. Срок можно выбрать и кнопкой.".to_string() }
        }
    };
    g.set_c_hint(ss(hint));
    let (dest, why) = dest_of(app, c);
    g.set_c_dest(ss(app.list_name(&dest)));
    g.set_c_dest_hue(list_hue(app, &dest));
    g.set_c_dest_why(ss(why));
    g.set_c_lists(model(list_opts(app, &dest).into_iter().enumerate().map(|(i, mut o)| { if i < 9 { o.hint = ss(format!("{}   {}", o.hint, i + 1).trim().to_string()); } o }).collect()));
    let cal = cal_of(app, c);
    g.set_c_cals(model(app.writable_cals().iter().map(|x| Opt { id: ss(text(&x["id"])), label: ss(text(&x["summaryOverride"]).max(text(&x["summary"]))), hint: ss(""),
        hue: color(s(&x["backgroundColor"])), on: x["id"] == cal.as_str() }).collect()));
    let dur = if c.dur == 0 { 60 } else { c.dur };
    g.set_c_durs(model([(15, "15 мин"), (30, "30 мин"), (60, "1 час"), (120, "2 часа"), (-1, "весь день")].iter().map(|(m, l)| opt(m.to_string(), *l, *m == dur)).collect()));
    let leads = if c.kind == 3 { &rem::BDAY_LEADS[..] } else { &rem::LEADS[..] };
    let mins = c.remind.clone().unwrap_or_else(|| default_mins(app, c.kind));
    g.set_c_reminds(model(leads.iter().filter(|x| x.0 != 5).enumerate().filter(|(i, x)| mins.contains(&x.0) || *i < 3).map(|(_, (m, l))| opt(m.to_string(), l.replace("За ", "за ").replace("В момент начала", "в начале"), mins.contains(m))).take(4).collect()));
    // событие: свободно ли
    let free = match (c.kind, x["day"].as_str(), x["slot"]["s"].as_str(), x["slot"]["e"].as_str()) {
        (1, Some(day), Some(st), Some(en)) => {
            let f = cr::free_check(&app.events_on(day), day, &json!({"s": st, "e": en}));
            if f["clash"].is_string() { format!("⚠ пересекается с «{}»", text(&f["clash"])) } else if f["until"].is_string() { format!("свободно до {}", text(&f["until"])) } else { "весь вечер свободен".into() }
        }
        _ => String::new(),
    };
    g.set_c_free_warn(free.starts_with('⚠'));
    g.set_c_free(ss(free));
    // событие: место; день рождения: год и «подарок заранее»; привычка: значок, частота, окно и часть дня
    g.set_c_place(ss(c.place.clone()));
    g.set_c_year(ss(c.year.clone()));
    g.set_c_gift(model([(0i64, "Не надо"), (7, "За неделю"), (14, "За 2 недели"), (30, "За месяц")].iter().map(|(n2, l)| opt(n2.to_string(), *l, c.gift.unwrap_or(7) == *n2)).collect()));
    let h0 = habit.clone().unwrap_or_else(|| json!({}));
    let fr = cr::habit_freq_of(&h0, &c.hfreq);
    g.set_c_hfreq(model([("daily", "Каждый день"), ("weekdays", "По будням"), ("days", "Свои дни"), ("week", "N раз в неделю")].iter().map(|(k, l)| opt(*k, *l, s(&fr["kind"]) == *k)).collect()));
    let dsel: Vec<i64> = a(&fr["days"]).iter().filter_map(|x| x.as_i64()).collect();
    g.set_c_hdays(model(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"].iter().enumerate().map(|(i, l)| opt(i.to_string(), *l, dsel.contains(&(i as i64)))).collect()));
    let per = n(&fr["perWeek"]).unwrap_or(0.0) as i64;
    g.set_c_hper(model((2..=6).map(|nn| opt(nn.to_string(), cr::plural(nn, "раз", "раза", "раз"), per == nn)).collect()));
    g.set_c_hicons(model(cr::HABIT_ICONS.iter().map(|i| opt(*i, *i, c.hicon == *i)).collect()));
    let part_eff = if !c.hpart.is_empty() { c.hpart.clone() } else { let p = s(&h0["part"]); if p.is_empty() { "any".into() } else { p.into() } };
    let win_eff = c.hwin.clone().map(|(a0, b0)| json!({"s": a0, "e": b0})).unwrap_or_else(|| hb::part_win(&json!(part_eff)));
    let custom_win = !win_eff.is_null() && !hb::whole_part(&win_eff);
    g.set_c_hpart(model([("morning", "Утро"), ("day", "День"), ("evening", "Вечер"), ("any", "Любое")].iter().map(|(k, l)| opt(*k, *l, part_eff == *k && !custom_win)).collect()));
    g.set_c_hwin_s(ss(s(&win_eff["s"])));
    g.set_c_hwin_e(ss(s(&win_eff["e"])));
    props(app, c, g, &x, &dest, &mins, &every);
}

/// §18–19: «Когда», полоса дней, «Попадёт», «Свойства» (состав панели — по виду окна).
fn props(app: &App, c: &Create, g: &S, x: &Value, dest: &str, mins: &[i64], every: &str) {
    let tdy = hb::now().date();
    let day = x["day"].as_str().unwrap_or("");
    g.set_c_time(ss(x["slot"]["s"].as_str().unwrap_or("")));
    g.set_c_day(ss(match sputnik_core::dates::parse_ymd(day) {
        Some(d) => { let l = cr::short_day(day); let _ = d; let mut ch = l.chars(); ch.next().map(|f| f.to_uppercase().collect::<String>() + ch.as_str()).unwrap_or_default() }
        None => "Без срока".into(),
    }));
    g.set_c_times(strings(cr2::times()));
    g.set_c_strip(model(cr2::strip(tdy).into_iter().map(|(id, wd, n)| Opt { on: id == day, id: ss(id), label: ss(wd), hint: ss(n), hue: color("clay") }).collect()));
    let cols = app.columns(dest);
    let col = c.col.clone().filter(|k| cols.iter().any(|x| x.0["id"] == k.as_str())).or_else(|| cols.first().map(|x| text(&x.0["id"])));
    let col_name = cols.iter().find(|x| Some(text(&x.0["id"])) == col).map(|x| text(&x.0["name"])).unwrap_or_else(|| "Входящие".into());
    let mut lands = cr2::lands(&x["day"], &x["slot"], &col_name, tdy);
    let rest = if lands.len() > 2 { lands.split_off(2) } else { vec![] };
    g.set_c_lands(strings(lands));
    g.set_c_lands2(strings(rest));
    let prio = x["priority"].as_i64().unwrap_or(0);
    let leads = if c.kind == 3 { &rem::BDAY_LEADS[..] } else { &rem::LEADS[..] };
    let lab = |l: &str| {
        let l = l.replace("За ", "за ").replace("В момент начала", "в начале");
        let mut ch = l.chars();
        ch.next().map(|f| f.to_lowercase().collect::<String>() + ch.as_str()).unwrap_or_default()
    };
    let lead = leads.iter().filter(|l| mins.contains(&l.0)).map(|l| lab(l.1)).collect::<Vec<_>>().join(", ");
    let row = |id: &str, l: &str, v: String| { let on = !v.is_empty(); Opt { id: ss(id), label: ss(l), hint: ss(if on { v } else { "—".into() }), hue: color("clay"), on } };
    let cal = cal_of(app, c);
    let cal_row = |app: &App| {
        let c0 = app.writable_cals().iter().find(|x| text(&x["id"]) == cal);
        let mut r = row("cal", "Календарь", c0.map(|x| text(&x["summaryOverride"]).max(text(&x["summary"]))).unwrap_or_else(|| "Основной".into()));
        r.hue = c0.map(|x| color(s(&x["backgroundColor"]))).unwrap_or_else(|| color("clay"));
        r
    };
    g.set_c_props(model(match c.kind {
        1 => vec![cal_row(app), row("remind", "Напомнить", if day.is_empty() { String::new() } else { lead }), row("repeat", "Повтор", if every.is_empty() { String::new() } else { sputnik_core::repeat::repeat_label(&x["repeat"]) })],
        2 => {
            let hid = app.habit_list().map(|l| text(&l["id"])).unwrap_or_default();
            let mut r = row("list", "Список", app.habit_list().map(|l| text(&l["title"])).unwrap_or_else(|| "Привычки".into()));
            r.hue = list_hue(app, &hid);
            vec![r]
        }
        3 => vec![cal_row(app), row("remind", "Напомнить", if day.is_empty() { String::new() } else { lead })],
        _ => vec![
            { let mut r = row("list", "Список", app.list_name(dest)); r.hue = list_hue(app, dest); r }
            , row("col", "Этап", if cols.len() > 1 { col_name.clone() } else { String::new() }),
            row("prio", "Приоритет", ["", "!!! Высокий", "!! Средний", "! Низкий"][prio.clamp(0, 3) as usize].into()),
            row("remind", "Напомнить", if day.is_empty() { String::new() } else { lead }),
            row("repeat", "Повтор", if every.is_empty() { String::new() } else { sputnik_core::repeat::repeat_label(&x["repeat"]) }),
            row("color", "Цвет", String::new()),
            row("image", "Картинка", String::new()),
            row("who", "Исполнитель", String::new()),
        ],
    }));
    g.set_c_popen(ss(c.popen.clone()));
    g.set_c_popts(model(match c.popen.as_str() {
        "list" if c.kind == 2 => {
            let hid = app.habit_list().map(|l| text(&l["id"])).unwrap_or_default();
            app.lists.iter().filter(|l| sputnik_core::templates::is_habit_list(l, &app.layer)).map(|l| Opt { id: ss(text(&l["id"])), label: ss(text(&l["title"])), hint: ss(""), hue: list_hue(app, &text(&l["id"])), on: text(&l["id"]) == hid }).collect()
        }
        "list" => list_opts(app, dest),
        "cal" => app.writable_cals().iter().map(|x| Opt { id: ss(text(&x["id"])), label: ss(text(&x["summaryOverride"]).max(text(&x["summary"]))), hint: ss(""), hue: color(s(&x["backgroundColor"])), on: x["id"] == cal.as_str() }).collect(),
        "col" => cols.iter().map(|(k, _)| Opt { id: ss(text(&k["id"])), label: ss(text(&k["name"])), hint: ss(""), hue: color(&sputnik_core::templates::col_color(k)), on: Some(text(&k["id"])) == col }).collect(),
        "prio" => [(1, "!!! Высокий"), (2, "!! Средний"), (3, "! Низкий"), (0, "Нет")].iter().map(|(n, l)| opt(n.to_string(), *l, prio == *n)).collect(),
        "remind" => leads.iter().filter(|l| c.kind == 3 || l.0 != 5).map(|(m, l)| opt(m.to_string(), lab(l.1), mins.contains(m))).collect(),
        "repeat" => [("", "нет"), ("day", "каждый день"), ("weekdays", "по будням"), ("week", "каждую неделю"), ("month", "каждый месяц"), ("year", "каждый год")].iter().map(|(id, l)| opt(*id, *l, every == *id)).collect(),
        _ => vec![],
    }));
    g.set_c_subs(strings(c.subs.clone()));
}

/// Строка «Создать» в разметке: распознанные куски цветом (дата и время — акцент, приоритет — красный, остальное — золото).
fn line_md(raw: &str, marks: &Value) -> slint::StyledText {
    let chars: Vec<char> = raw.chars().collect();
    let esc = |x: &str| -> String {
        let mut o = String::new();
        for ch in x.chars() {
            // пробелы — неразрывные: иначе разметка схлопывает их и подсветка уезжает от курсора
            if ch == ' ' { o.push('\u{a0}'); continue; }
            if "\\`*_[]<>#!-+.()&{}|~".contains(ch) { o.push('\\'); }
            o.push(ch);
        }
        o
    };
    let mut md = String::new();
    let mut at = 0;
    for m in a(marks) {
        let (f, t) = (m["from"].as_u64().unwrap_or(0) as usize, m["to"].as_u64().unwrap_or(0) as usize);
        if f < at || t > chars.len() || f >= t { continue; }
        md.push_str(&esc(&chars[at..f].iter().collect::<String>()));
        let col = match s(&m["kind"]) { "day" | "time" | "when" | "date" => "#F0A04B", "priority" | "prio" => "#F0785F", _ => "#E0A04A" };
        md.push_str(&format!("<font color=\"{col}\">{}</font>", esc(&chars[f..t].iter().collect::<String>())));
        at = t;
    }
    md.push_str(&esc(&chars[at..].iter().collect::<String>()));
    slint::StyledText::from_markdown(&md).unwrap_or_else(|_| slint::StyledText::from_plain_text(raw))
}
