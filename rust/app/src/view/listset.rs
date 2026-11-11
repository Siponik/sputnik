//! Настройки списка (G_ListSettings): название, сфера, порядок, «Сегодня», сводка.
use super::*;
use crate::Opt;
use serde_json::json;

pub fn render(app: &App, u: &Ui, g: &S) {
    g.set_ls_open(u.ls);
    if !u.ls { return; }
    let id = u.board.as_str();
    let ll = app.ll(id);
    let title = app.lists.iter().find(|x| x["id"] == id).map(|x| text(&x["title"])).unwrap_or_default();
    g.set_ls_name(ss(&title));
    let cur = s(&ll["sphere"]);
    let mut sp = vec![Opt { id: ss(""), label: ss("Без сферы"), hint: ss(""), hue: color(""), on: cur.is_empty() }];
    sp.extend(app.spheres().iter().map(|x| Opt { id: ss(text(&x["id"])), label: ss(text(&x["name"])), hint: ss(""),
        hue: color(&sputnik_core::spheres::sphere_color(x)), on: cur == s(&x["id"]) }));
    g.set_ls_spheres(model(sp));
    g.set_ls_sort(ss(match s(&ll["sort"]) { "due" => "due", "prio" => "prio", _ => "own" }));
    g.set_ls_today(ll["hidden"] != true);
    g.set_ls_quiet(ll["quiet"] == true);
    g.set_ls_tpl(g.get_board_tpl());
}

pub fn set(app: &mut App, u: &mut Ui, key: &str, v: &str) {
    let id = u.board.clone();
    if id.is_empty() { return; }
    match key {
        "name" => { if !v.trim().is_empty() { app.rename_list(&id, v.trim()); } }
        "sphere" => app.set_list_field(&id, json!({"sphere": if v.is_empty() { Value::Null } else { json!(v) }})),
        "sort" => app.set_list_field(&id, json!({"sort": v})),
        "today" => { let h = app.ll(&id)["hidden"] == true; app.set_list_field(&id, json!({"hidden": !h})); }
        "quiet" => { let q = app.ll(&id)["quiet"] == true; app.set_list_field(&id, json!({"quiet": !q})); }
        _ => {}
    }
}
