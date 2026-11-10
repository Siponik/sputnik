//! Демо без Google (SPUTNIK_DEMO=1): примерные списки, задачи, события и привычки, сеть выключена.
//! Нужно, чтобы посмотреть и проверить окно, не входя в аккаунт; ничего не пишется на диск.
use super::{today_ymd, App};
use serde_json::{json, Value};
use sputnik_core::dates::{add_days, parse_ymd, ymd};

pub fn on() -> bool {
    std::env::var("SPUTNIK_DEMO").is_ok_and(|v| v == "1")
}

fn day(k: i64) -> String {
    ymd(add_days(parse_ymd(&today_ymd()).unwrap(), k))
}
fn due(k: i64) -> String {
    format!("{}T00:00:00.000Z", day(k))
}

fn task(id: &str, title: &str, k: Option<i64>, done: bool) -> Value {
    let mut t = json!({"id": id, "title": title, "status": if done { "completed" } else { "needsAction" }, "position": id, "notes": ""});
    if let Some(k) = k {
        t["due"] = json!(due(k));
    }
    if done {
        t["completed"] = json!(format!("{}T10:00:00.000Z", day(0)));
    }
    t
}

fn ev(id: &str, title: &str, k: i64, s: &str, e: &str) -> Value {
    json!({"id": id, "calId": "primary", "summary": title, "status": "confirmed",
        "start": {"dateTime": format!("{}T{s}:00+03:00", day(k))}, "end": {"dateTime": format!("{}T{e}:00+03:00", day(k))}})
}

pub fn fill(app: &mut App) {
    app.flags.need_login = false;
    app.flags.demo = true;
    app.lists = vec![
        json!({"id": "work", "title": "Работа"}),
        json!({"id": "icons", "title": "Иконки для клиента"}),
        json!({"id": "home", "title": "Дела по дому"}),
        json!({"id": "study", "title": "Учёба Blender"}),
        json!({"id": "hab", "title": "Привычки"}),
    ];
    app.tasks = json!({
        "work": [task("w1", "Созвон с заказчиком про сроки", Some(0), false), task("w2", "Отправить смету", Some(-1), false),
                 task("w3", "Подготовить портфолио", Some(2), false), task("w4", "Ответить на письма", Some(0), true),
                 task("w5", "Обновить договор", None, false)],
        "icons": [task("i1", "Иконка «Сундук»", Some(1), false), task("i2", "Иконка «Меч»", Some(3), false),
                  task("i3", "Иконка «Зелье»", None, false), task("i4", "Иконка «Щит»", None, false), task("i5", "Иконка «Карта»", Some(-2), true)],
        "home": [task("h1", "Купить корм коту", Some(0), false), task("h2", "Позвонить в управляющую", Some(1), false),
                 task("h3", "Записаться к врачу", Some(5), false), task("h4", "Оплатить интернет", Some(0), false)],
        "study": [task("s1", "Урок 12: скульптинг", Some(0), false), task("s2", "Урок 13: ретопология", Some(4), false)],
        "hab": [task("hb1", "Вода", None, false), task("hb2", "Зарядка", None, false), task("hb3", "Чтение", None, false)],
    });
    app.tasks["work"].as_array_mut().unwrap().push(json!({"id": "w1a", "title": "Список вопросов", "parent": "w1", "status": "needsAction", "position": "1"}));
    app.calendars = vec![json!({"id": "primary", "summary": "Основной", "primary": true, "accessRole": "owner", "selected": true, "backgroundColor": "#6FA2F2"})];
    app.events = vec![ev("e1", "Планёрка", 0, "10:00", "10:30"), ev("e2", "Обед с Олей", 1, "13:00", "14:00"), ev("e3", "Ревью ассетов", 2, "16:00", "17:30"),
        ev("e4", "Тренировка", 3, "19:00", "20:00")];
    let t = 1.0;
    app.layer["spheres"] = json!({"sp1": {"name": "Работа", "color": "clay", "icon": "case", "order": 1, "t": t}, "sp2": {"name": "Личное", "color": "personal", "icon": "home", "order": 2, "t": t}});
    app.layer["lists"] = json!({
        "work": {"template": "work", "sphere": "sp1", "t": t},
        "icons": {"template": "asset3d", "sphere": "sp1", "view": "pipe", "t": t},
        "home": {"template": "personal", "sphere": "sp2", "view": "stickers", "t": t},
        "study": {"template": "study", "sphere": "sp2", "view": "list", "t": t},
        "hab": {"template": "habits", "t": t},
    });
    app.layer["tasks"] = json!({
        "w1": {"slot": {"s": "11:00", "e": "12:00"}, "priority": 1, "status": "doing", "t": t},
        "w2": {"status": "doing", "t": t},
        "w3": {"status": "review", "t": t},
        "i1": {"status": "model", "project": "RPG-набор", "t": t},
        "i2": {"status": "sculpt", "project": "RPG-набор", "t": t},
        "h1": {"topic": "buy", "t": t}, "h4": {"topic": "docs", "t": t}, "h2": {"topic": "call", "t": t}, "h3": {"topic": "health", "t": t},
        "s1": {"slot": {"s": "18:00", "e": "19:30"}, "t": t},
    });
    app.layer["habits"] = json!({
        "hb1": {"days": [0, 1, 2, 3, 4, 5, 6], "goal": {"n": 8, "unit": "стаканов"}, "icon": "💧", "color": "work", "createdAt": day(-30), "t": t},
        "hb2": {"days": [0, 1, 2, 3, 4], "part": "morning", "icon": "🏃", "color": "personal", "createdAt": day(-30), "t": t},
        "hb3": {"days": [0, 1, 2, 3, 4, 5, 6], "part": "evening", "icon": "📖", "color": "study", "createdAt": day(-30), "win": {"s": "21:00", "e": "22:00"}, "t": t},
    });
    let mut log = serde_json::Map::new();
    for k in 1..12 {
        log.insert(format!("hb2|{}", day(-k)), json!({"done": true, "t": t}));
        if k % 3 != 0 {
            log.insert(format!("hb3|{}", day(-k)), json!({"done": true, "t": t}));
        }
        log.insert(format!("hb1|{}", day(-k)), json!({"n": 8, "done": true, "t": t}));
    }
    log.insert(format!("hb1|{}", day(0)), json!({"n": 3, "t": t}));
    app.layer["log"] = Value::Object(log);
    app.inbox_st = json!({"processed": [{"created": [{"listId": "work", "taskId": "w5"}], "at": format!("{}T08:00:00Z", day(0))}]});
    // заметки — только в памяти (root = None: сохранять некуда, папка не трогается)
    let ns = [("Идеи/Сундук.md", "Сундук", "Для [[Иконки RPG]]. Дерево, [[Металл]]."), ("Идеи/Меч.md", "Меч", "[[Иконки RPG]], [[Металл]], [[Ковка]]."),
        ("Иконки RPG.md", "Иконки RPG", "Набор для клиента. [[Палитра]], [[Сундук]], [[Меч]]."), ("Палитра.md", "Палитра", "Тёплые тона, акцент [[Металл]]."),
        ("Металл.md", "Металл", "Блики, [[Палитра]]."), ("Blender/Скульптинг.md", "Скульптинг", "Урок 12. [[Ретопология]] дальше."),
        ("Blender/Ретопология.md", "Ретопология", "После [[Скульптинг]]."), ("Входящие.md", "Входящие", "Разобрать.")];
    app.notes.root = None;
    app.notes.notes = ns.iter().map(|(p, t, b)| crate::notes::Note { path: p.to_string(), title: t.to_string(), body: b.to_string(), links: crate::notes::links_of(b) }).collect();
    app.notes.relayout();
}
