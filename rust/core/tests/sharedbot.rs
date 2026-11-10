mod common;
use serde_json::json;
use sputnik_core::j::*;
use sputnik_core::sharedbot as b;

#[test]
fn sharedbot() {
    sputnik_core::habits::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0));
    let today = chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap();
    let lists = vec![json!({"id": "Lwork", "title": "Иконки для клиента"}), json!({"id": "L3d", "title": "3D-проекты"}),
                     json!({"id": "Lhome", "title": "Дела по дому"}), json!({"id": "Lx", "title": ""})];
    let layer = json!({
        "lists": {"Lwork": {"template": "work"}, "L3d": {"template": "asset3d", "view": "pipe"}, "Lhome": {"template": "personal", "view": "stickers"}},
        "tasks": {"a1": {"project": "Башня", "slot": {"s": "10:00"}}, "w1": {"slot": {"s": "09:30"}}, "w2": {"slot": {}}},
        "settings": {"route": {"смета": {"list": "Lwork", "n": 2}, "башн": {"list": "L3d"}, "чужо": {"list": "nope", "n": 9},
                               "плохо": "x", "купит": {"list": "Lhome", "n": 5}}}
    });
    let tk = |id: &str, title: &str, due: Option<&str>, extra: Value| {
        let mut m = json!({"id": id, "title": title, "status": "needsAction"});
        if let Some(d) = due {
            m["due"] = json!(format!("{d}T00:00:00.000Z"));
        }
        extend(m.as_object_mut().unwrap(), o(&extra));
        m
    };
    let e = || json!({});
    let tasks = json!({
        "Lwork": [tk("w1", "Смета по набору иконок", Some("2026-10-21"), e()), tk("w2", "", Some("2026-10-28"), e()),
                  tk("w3", "Поздно", Some("2026-10-29"), e()), tk("w4", "Сделано", Some("2026-10-21"), json!({"status": "completed"})),
                  tk("w5", "Подзадача", Some("2026-10-21"), json!({"parent": "w1"})), tk("w6", "Без срока", None, e()),
                  tk("w7", "Просрочено", Some("2026-10-01"), e()), tk("w8", "Удалено", Some("2026-10-22"), json!({"deleted": true}))],
        "L3d": [tk("a1", "Башня lowpoly", Some("2026-10-21"), e()), tk("a2", "Пропсы для башни", Some("2026-10-21"), e())],
        "Lhome": [tk("h1", "Лампочки", Some("2026-10-25"), e())]
    });
    let lt = layer["tasks"].clone();
    let day = |x: &Value| sputnik_core::shell::ms_local(n(&x["now"]).unwrap()).date();
    common::run("sharedbot.json", |f, x| {
        Some(match f {
            "snapshot" => json!(b::snapshot(&lists, &tasks, &lt, day(x))),
            "snapshotNoLay" => json!(b::snapshot(&lists, &tasks, &Value::Null, day(x))),
            "guessCtx" => b::guess_ctx(&lists, &layer),
            "guessCtx0" => b::guess_ctx(&[], &Value::Null),
            "fromText" => b::from_text(&text(&x["s"]), &lists, &layer, &tasks, today),
            "fromTextNoLists" => b::from_text(&text(&x["s"]), &[], &layer, &tasks, today),
            "fromDraft" => b::from_draft(&x["x"], &lists, &layer, &tasks, today),
            "fromDraftNoLists" => b::from_draft(&x["x"], &[], &layer, &tasks, today),
            "consts" => json!([b::BOT_URL, b::BOT_NAME, b::BOT_LINK]),
            _ => return None,
        })
    });
}
