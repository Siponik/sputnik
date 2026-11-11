//! Модели «Настроек».
use super::*;
use super::dialogs::opt;
use crate::Opt;

pub const STARTS: [(&str, &str); 4] = [("today", "Сегодня"), ("calendar", "Календарь"), ("board", "Доска"), ("habits", "Привычки")];
pub const REMINDS: [(i64, &str); 5] = [(-1, "не напоминать"), (0, "в момент начала"), (15, "за 15 мин"), (60, "за час"), (1440, "за день")];
pub const HOURS: [&str; 5] = ["08:00", "09:00", "10:00", "12:00", "off"];

pub fn render(app: &App, _u: &Ui, g: &S) {
    let st = &app.layer["settings"];
    let start = st["start"]["v"].as_str().unwrap_or("today");
    g.set_set_start(model(STARTS.iter().map(|(id, l)| opt(*id, *l, *id == start)).collect()));
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
