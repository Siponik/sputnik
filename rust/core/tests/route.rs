mod common;
use serde_json::{json, Value};
use sputnik_core::j::*;
use sputnik_core::route as r;

#[test]
fn route() {
    let today = chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap();
    let now = today.and_hms_opt(0, 0, 0).unwrap().and_local_timezone(chrono::Local).unwrap().timestamp_millis() as f64;
    let tk = |id: &str, title: &str, extra: Value| {
        let mut m = json!({"id": id, "title": title, "status": "needsAction"});
        extend(m.as_object_mut().unwrap(), o(&extra));
        m
    };
    let lists = vec![
        json!({"id": "Lwork", "title": "Иконки для клиента"}),
        json!({"id": "L3d", "title": "3D-проекты"}),
        json!({"id": "Lhome", "title": "Дела по дому"}),
        json!({"id": "Lstudy", "title": "Курс Blender"}),
    ];
    let layer = json!({
        "lists": {"Lwork": {"template": "work"}, "L3d": {"template": "asset3d", "view": "pipe"},
                  "Lhome": {"template": "personal", "view": "stickers"}, "Lstudy": {"template": "study"}},
        "tasks": {"a1": {"project": "Башня"}, "a2": {"project": "Башня"}, "a3": {"project": "Таверна"}, "a4": {"project": "Таверна"}},
        "settings": {}
    });
    let e = json!({});
    let tasks = json!({
        "Lwork": [tk("w1", "Смета по набору иконок", e.clone()), tk("w2", "Референсы для набора «Зимние»", e.clone()),
                  tk("w3", "Ревью набора «Погода»", e.clone()),
                  tk("w4", "Старое сделанное письмо", json!({"status": "completed", "completed": "2026-08-01T00:00:00Z"})),
                  tk("w5", "Свежий отчёт", json!({"status": "completed", "completed": "2026-10-20T00:00:00Z"})),
                  tk("w6", "Подзадача иконок", json!({"parent": "w1"}))],
        "L3d": [tk("a1", "Башня lowpoly", e.clone()), tk("a2", "Пропсы для башни", e.clone()), tk("a3", "Сундук с золотом", e.clone()),
                tk("a4", "Таверна", e.clone()), tk("a5", "Без проекта", json!({"parent": "a1"}))],
        "Lhome": [tk("h1", "Лампочки в коридор", e.clone()), tk("h2", "Позвонить бабушке", e.clone())],
        "Lstudy": [tk("s1", "Урок 3: материалы", e.clone())]
    });
    let mut learned = layer.clone();
    learned["settings"] = json!({"route": {"разоб": {"list": "Lstudy", "n": 3}, "батар": {"list": "Lhome", "topic": "buy", "n": 1},
                                           "плохо": "x", "смета": {"list": "L3d", "n": 9}}});
    common::run("route.json", |f, x| {
        Some(match f {
            "words" => json!(r::words(s(&x["s"]))),
            "stem" => json!(r::stem(s(&x["s"]))),
            "sameWord" => json!(r::same_word(s(&x["a"]), s(&x["b"]))),
            "parseLine" => r::parse_line(s(&x["s"]), today, &x["off"]),
            "projectsOf" => json!(r::projects_of(&x["t"], &x["lay"])),
            "findList" => r::find_list(&lists, s(&x["w"])).cloned().unwrap_or(Value::Null),
            "viewOf" => json!(r::view_of(s(&x["id"]), &layer)),
            "route" => json!(r::route(s(&x["text"]), if x["empty"] == true { &[] } else { &lists },
                if x["learned"] == true { &learned } else { &layer }, &tasks, x["current"].as_str(), now)),
            "learn" => r::learn(&x["cur"], s(&x["title"]), s(&x["list"]), &x["topic"]),
            _ => return None,
        })
    });
}
