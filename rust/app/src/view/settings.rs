//! Модели «Настроек».
use super::*;
use super::dialogs::opt;
use crate::Opt;

pub const STARTS: [(&str, &str); 4] = [("today", "Сегодня"), ("calendar", "Календарь"), ("board", "Доска"), ("habits", "Привычки")];
pub const REMINDS: [(i64, &str); 5] = [(-1, "не напоминать"), (0, "в момент начала"), (15, "за 15 мин"), (60, "за час"), (1440, "за день")];
pub const HOURS: [&str; 5] = ["08:00", "09:00", "10:00", "12:00", "off"];

/// Акценты «Вида»: название, акцент, акцент-светлый, подложка, линия, текст на акценте, шапка главной ноды.
pub const ACCENTS: [(&str, u32, u32, u32, u32, u32, u32); 6] = [
    ("Оранж", 0xF0A04B, 0xFFD29C, 0x2E2722, 0x6A5238, 0x2A1A0A, 0x9A5A22),
    ("Голубой", 0x6FA2F2, 0xB9D1FA, 0x222A38, 0x3A5170, 0x0A1626, 0x2F4F86),
    ("Фиолет", 0xB48CF0, 0xDBC4FA, 0x2A2238, 0x57407A, 0x17092A, 0x5E3F92),
    ("Зелень", 0x7FD18C, 0xBCE8C4, 0x222E24, 0x3E5E42, 0x0A220F, 0x2E6B3E),
    ("Золото", 0xE8C65A, 0xF6E2A4, 0x332E20, 0x6E5E2E, 0x2A220A, 0x7A6620),
    ("Красный", 0xF0785F, 0xFABDB0, 0x332320, 0x704338, 0x2A0F0A, 0x8A3A2E),
];
pub const ANIMS: [&str; 3] = ["Полные", "Минимум", "Выкл"];

/// Применить акцент к токенам G (вызывается при старте и из настроек).
pub fn apply_accent(w: &crate::AppWindow, i: i64) {
    let a = &ACCENTS[(i.clamp(0, 5)) as usize];
    let g = w.global::<crate::G>();
    g.set_accent(hex(a.1));
    g.set_accent_ink(hex(a.2));
    g.set_accent_wash(hex(a.3));
    g.set_accent_line(hex(a.4));
    g.set_on_accent(hex(a.5));
    g.set_head_main(hex(a.6));
}

/// Анимации: 0 полные, 1 минимум, 2 выкл.
pub fn apply_anim(w: &crate::AppWindow, i: i64) {
    let g = w.global::<crate::G>();
    let (f, m) = match i {
        2 => (0, 0),
        1 => (60, 100),
        _ => (120, 200),
    };
    g.set_fast(f);
    g.set_mid(m);
}

/// Порядок разделов в шапке (0 Сегодня … 4 Знания); по умолчанию подряд.
pub fn tab_order(app: &App) -> Vec<i32> {
    let v: Vec<i32> = a(&app.layer["settings"]["tabOrder"]["v"]).iter().filter_map(|x| x.as_i64().map(|n| n as i32)).collect();
    if v.len() == 5 && (0..5).all(|i| v.contains(&i)) { v } else { vec![0, 1, 2, 3, 4] }
}

pub fn render(app: &App, _u: &Ui, g: &S) {
    let st = &app.layer["settings"];
    let start = st["start"]["v"].as_str().unwrap_or("today");
    g.set_set_start(model(STARTS.iter().map(|(id, l)| opt(*id, *l, *id == start)).collect()));
    let acc = st["accent"]["v"].as_i64().unwrap_or(0);
    g.set_set_accent(model(ACCENTS.iter().enumerate().map(|(i, a)| Opt { id: ss(i.to_string()), label: ss(a.0), hint: ss(""), hue: hex(a.1), on: i as i64 == acc }).collect()));
    let anim = st["anim"]["v"].as_i64().unwrap_or(0);
    g.set_set_anim(model(ANIMS.iter().enumerate().map(|(i, l)| opt(i.to_string(), *l, i as i64 == anim)).collect()));
    g.set_set_flags(model(vec![
        Opt { id: ss("notify"), label: ss("Уведомления Windows"), hint: ss("окно привычки, задачи «за N минут»"), hue: color("clay"), on: st["notify"]["v"] != false },
    ]));
    g.set_set_lists(model(app.lists.iter().filter(|l| !sputnik_core::templates::is_habit_list(l, &app.layer)).map(|l| {
        let id = s(&l["id"]);
        let ll = app.ll(id);
        Opt { id: ss(id), label: ss(text(&l["title"])), hint: ss(if ll["quiet"] == true { "тихий" } else { "" }), hue: list_hue(app, id), on: ll["hidden"] != true }
    }).collect()));
    g.set_set_cals(model(app.calendars.iter().filter(|c| !s(&c["summary"]).starts_with("Спутник · ") && !s(&c["description"]).contains("sputnik-sphere")).map(|c| {
        Opt { id: ss(text(&c["id"])), label: ss(text(&c["summary"])), hint: ss(if t(&c["primary"]) { "основной" } else { "" }), hue: color(s(&c["backgroundColor"])), on: app.cal_shown(c) }
    }).collect()));
    let cur: Vec<i64> = a(&sputnik_core::reminders::default_mins(st, "task")).iter().filter_map(|x| x.as_i64()).collect();
    g.set_set_remind_task(model(REMINDS.iter().map(|(m, l)| opt(m.to_string(), *l, if *m < 0 { cur.is_empty() } else { cur.contains(m) })).collect()));
    // умолчания напоминаний для событий и дней рождения — те же наборы, что в старом трекере (core::reminders::leads_for)
    let leads_model = |kind: &str| {
        let cur: Vec<i64> = a(&sputnik_core::reminders::default_mins(st, kind)).iter().filter_map(|x| x.as_i64()).collect();
        let mut v = vec![opt("-1", "не напоминать", cur.is_empty())];
        v.extend(sputnik_core::reminders::leads_for(kind).iter().map(|(m, l)| opt(m.to_string(), *l, cur.contains(m))));
        model(v)
    };
    g.set_set_remind_event(leads_model("event"));
    g.set_set_remind_bday(leads_model("birthday"));
    let hour = st["remindHour"]["v"].as_str().unwrap_or("10:00");
    g.set_set_remind_hour(model(HOURS.iter().map(|h| opt(*h, if *h == "off" { "не напоминать" } else { *h }, *h == hour)).collect()));
    let tg = &st["tgbot"];
    g.set_bot_name(ss(if t(&tg["key"]) { text(&tg["name"]).max("бот".into()) } else { String::new() }));
    g.set_bot_status(ss(if !app.bot_err.is_empty() { format!("Ошибка: {}", app.bot_err) } else if let Some(at) = app.bot_at { format!("Последний обмен — {}", super::hm(at)) } else { String::new() }));
    let f = &app.flags;
    g.set_sync_info(ss(format!(
        "Google: {}. Слой Спутника на Drive: {}. Правок в очереди: {}. Запуск за {} мс.",
        if f.need_login { "не выполнен вход".to_string() } else if f.offline { "нет связи".into() } else { f.synced_at.map(|x| format!("синхронизировано в {}", super::hm(x))).unwrap_or("ещё не синхронизировано".into()) },
        f.cloud_err.clone().map(|e| format!("ошибка — {e}")).unwrap_or_else(|| f.cloud_at.map(|x| format!("сверен в {}", super::hm(x))).unwrap_or("ещё не сверялся".into())),
        app.outbox.ops.len(), f.load_ms)));
    g.set_backup_info(ss(match crate::data::store::last_backup() {
        Some(b) => format!("Резервные копии слоя — раз в день, хранятся 14. Последняя: {b}"),
        None => "Резервные копии слоя — раз в день, хранятся 14. Пока ни одной.".into(),
    }));
    g.set_notes_root(ss(app.notes.root.as_ref().map(|p| p.display().to_string()).unwrap_or_default()));
}
