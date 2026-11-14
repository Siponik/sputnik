mod common;
use serde_json::json;
use sputnik_core::j::*;
use sputnik_core::shell as sh;

fn slider(sc: &[Value]) -> Value {
    let mut sl = sh::Slider::default();
    let mut steps = vec![];
    for step in sc {
        let op = s(&step[0]);
        let a0 = step.get(1).cloned().unwrap_or(Value::Null);
        match op {
            "tick" => sl.tick(int(&a0).unwrap_or(0)),
            "enter" => sl.enter(),
            "leave" => sl.leave(),
            "hold" => sl.hold(a0 == true),
            "show" => sl.show(),
            "peek" => sl.peek(int(&a0).unwrap_or(1500)),
            "hide" => sl.hide(),
            "instant" => sl.instant(a0 == true),
            _ => {}
        }
        steps.push(json!([op, a0, sl.open(), sl.log.len()]));
    }
    json!({"steps": steps, "log": sl.log})
}

#[test]
fn shell() {
    let spheres = vec![json!({"id": "s1", "name": "Работа"}), json!({"id": "s2", "name": "Ёлки дом"}), json!({"id": "s3", "name": "Пусто"})];
    let lists_by = json!({"s1": [{"id": "a", "title": "Иконки"}, {"id": "b", "title": "Смета клиента"}], "s2": [{"id": "c", "title": "Покупки"}], "s3": []});
    let no_sph = vec![json!({"id": "d", "title": "Учёба Blender"}), json!({"id": "e", "title": "Иконки 2"})];
    common::run("shell.json", |f, x| {
        Some(match f {
            "hm" => json!(sh::hm(&x["d"])),
            "googleLine" => sh::google_line(&x["sync"], x["off"] == true),
            "statusDots" => sh::status_dots(&x["sync"], x["off"] == true, &x["cloud"], &x["upd"]),
            "cloudLine" => sh::cloud_line(&x["c"]),
            "versionLine" => sh::version_line(&x["u"]),
            "remindLine" => sh::remind_line(&x["r"]),
            "ownBot" => sh::own_bot(&x["s"], &x["i"]),
            "isBeta" => json!(sh::is_beta(&x["v"])),
            "betaShow" => json!(sh::beta_show(&x["own"], &x["v"], &x["pref"])),
            "notesOf" => json!(sh::notes_of(&x["t"], int(&x["n"]).unwrap_or(3) as usize)),
            "showUpdChip" => json!(sh::show_upd_chip(&x["f"], &x["p"], n(&x["now"]))),
            "eveningAt" => json!(sh::evening_at(sh::ms_local(n(&x["now"])?))),
            "nightNow" => json!(sh::night_now(&x["p"], sh::ms_local(n(&x["now"])?))),
            "slider" => slider(a(&x["sc"])),
            "filterSide" => sh::filter_side(s(&x["q"]), &spheres, &|id| a(&lists_by[s(id)]).to_vec(), &no_sph),
            "boardTips" => json!(sh::board_tips(a(&x["open"]), a(&x["cols"]), &|tk| tk["col"].clone(), &x["first"])),
            "SETTINGS_TABS" => sh::settings_tabs(),
            "SETTINGS_INDEX" => sh::settings_index(),
            "VIEW_TABS" => sh::view_tabs(),
            "searchSettings" => json!(sh::search_settings(s(&x["q"])).iter().map(|r| r["id"].clone()).collect::<Vec<_>>()),
            "stepTab" => json!(sh::step_tab(s(&x["c"]), int(&x["d"])?)),
            "tabOrder" => json!(sh::tab_order(&x["s"])),
            "moveTab" => json!(sh::move_tab(&a(&x["o"]).iter().map(|v| text(v)).collect::<Vec<_>>(), s(&x["id"]), int(&x["to"])?)),
            "tabsDefault" => json!(sh::tabs_default(&a(&x["o"]).iter().map(|v| text(v)).collect::<Vec<_>>())),
            "startView" => json!(sh::start_view(&x["p"], &x["l"])),
            _ => return None,
        })
    });
}

#[test]
fn search_in_own_index() {
    let idx = json!([
        {"tab": 2, "title": "Куда слать", "hint": "Telegram и Windows", "also": "уведомления телеграм"},
        {"tab": 3, "title": "Проверить обновления", "hint": "", "also": "версия"},
    ]);
    let ids = |q: &str| sh::search_in(&idx, q).iter().map(|r| r["tab"].clone()).collect::<Vec<_>>();
    assert_eq!(ids("телеграм"), vec![json!(2)]);
    assert_eq!(ids("Обновл"), vec![json!(3)]);
    assert_eq!(ids("уведомления windows"), vec![json!(2)]);
    assert!(ids("").is_empty());
    assert!(ids("клавиши").is_empty());
}

#[test]
fn tab_step_user_order() {
    let order = [2, 0, 1, 3, 4];
    assert_eq!(sh::tab_step(&order, 2, 1), 0);
    assert_eq!(sh::tab_step(&order, 2, -1), 4, "по кругу назад");
    assert_eq!(sh::tab_step(&order, 4, 1), 2, "по кругу вперёд");
    assert_eq!(sh::tab_step(&order, 5, -1), 4, "из настроек назад — последняя по порядку");
    assert_eq!(sh::tab_step(&order, 5, 1), 2, "из настроек вперёд — первая по порядку");
    assert_eq!(sh::tab_step(&[], 3, 1), 3, "пустой порядок — без смены");
    // порядок по умолчанию — старое поведение
    let def = [0, 1, 2, 3, 4];
    assert_eq!(sh::tab_step(&def, 0, -1), 4);
    assert_eq!(sh::tab_step(&def, 4, 1), 0);
}
