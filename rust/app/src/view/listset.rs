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
    // п.24: колонки списка; последняя — «Готово», её не удалить и не двигать
    let cols = app.columns(id);
    let n = cols.len();
    g.set_ls_cols(model(cols.iter().enumerate().map(|(i, (c, ts))| {
        let lim = int(&c["limit"]).unwrap_or(0);
        Opt { id: ss(lim.to_string()), label: ss(text(&c["name"])), hint: ss(ts.len().to_string()),
            hue: color(&sputnik_core::templates::col_color(c)), on: i + 1 == n }
    }).collect()));
}

fn save_cols(app: &mut App, id: &str, cols: Vec<Value>) {
    let d = json!({"cols": cols});
    app.set_list_field(id, json!({"cols": sputnik_core::templates::own_patch(&d)["cols"]}));
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
        _ if key.starts_with("col-") => col_edit(app, &id, key, v),
        _ => {}
    }
}

/// Правки колонок из окна настроек: v — «номер» или «номер|значение».
fn col_edit(app: &mut App, id: &str, key: &str, v: &str) {
    use sputnik_core::boardedit as be;
    let cols: Vec<Value> = a(&app.board(id)["cols"]).to_vec();
    let (i, rest) = match v.split_once('|') { Some((a, b)) => (a, b), None => (v, "") };
    let i: i64 = i.parse().unwrap_or(-1);
    let ok = i >= 0 && (i as usize) < cols.len();
    let mut out = cols.clone();
    match key {
        "col-add" => { let at = out.len().saturating_sub(1); out.insert(at, be::new_col(crate::state::now_ms() as u64)); }
        "col-name" if ok => { let nm = rest.trim(); if nm.is_empty() { return; } out[i as usize]["name"] = json!(nm); }
        "col-color" if ok => out[i as usize] = be::recolor(&cols[i as usize]),
        "col-limit" if ok => out[i as usize] = be::relimit(&cols[i as usize], rest.parse().unwrap_or(0)),
        "col-move" if ok => out = be::move_col(&cols, i, rest.parse().unwrap_or(i)),
        "col-del" if ok => {
            let r = be::drop_col(&cols, i, &[], 0);
            if r.is_null() { return; }
            // задачи удалённой колонки уходят в соседнюю
            let from = text(&cols[i as usize]["id"]);
            let to = text(&r["removed"][0]["to"]);
            let moving: Vec<Value> = app.columns(id).into_iter().find(|c| text(&c.0["id"]) == from).map(|c| c.1).unwrap_or_default();
            for t in moving { app.set_stage(id, &t, &to); }
            out = a(&r["cols"]).to_vec();
        }
        _ => return,
    }
    save_cols(app, id, out);
}
