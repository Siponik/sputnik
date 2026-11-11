//! Шаблоны досок (G_Templates): список шаблонов и правка выбранного — название, вид, колонки, поля карточки.
use super::*;
use crate::Opt;
use serde_json::json;
use sputnik_core::templates as tp;

/// Открытый шаблон: id и черновик (сохраняется кнопкой).
#[derive(Clone, Default)]
pub struct Tp {
    pub id: String,
    pub draft: Value,
    pub fresh: bool,
}

fn now() -> u64 { crate::state::now_ms() as u64 }

pub fn open(app: &App, id: &str) -> Tp {
    let all = tp::templates_from(&app.layer);
    let x = all.iter().find(|x| x["id"] == id).cloned().unwrap_or_else(|| all[0].clone());
    Tp { id: text(&x["id"]), draft: x, fresh: false }
}

fn used(app: &App, id: &str) -> Vec<String> {
    app.board_lists().iter().filter(|l| tp::follows(s(&l["id"]), &app.layer, id)).map(|l| text(&l["title"])).collect()
}

pub fn render(app: &App, u: &Ui, g: &S) {
    g.set_tp_open(u.tp.is_some());
    let Some(t0) = &u.tp else { return };
    let d = &t0.draft;
    let mut rows: Vec<Opt> = tp::templates_from(&app.layer).iter().map(|x| {
        let id = text(&x["id"]);
        let n = used(app, &id).len();
        let kind = if t(&x["mine"]) { "свой" } else { "встроенный" };
        Opt { id: ss(&id), label: ss(text(&x["name"]).max(text(&x["title"]))), hint: ss(format!("{kind} · {n}")),
            hue: color(&tp::col_color(&a(&x["cols"]).get(1).cloned().unwrap_or(Value::Null))), on: id == t0.id }
    }).collect();
    if t0.fresh { rows.push(Opt { id: ss(&t0.id), label: ss(text(&d["name"])), hint: ss("новый · не сохранён"), hue: color(""), on: true }); }
    g.set_tp_list(model(rows));
    g.set_tp_id(ss(&t0.id));
    g.set_tp_name(ss(text(&d["name"]).max(text(&d["title"]))));
    g.set_tp_builtin(tp::is_builtin(&json!(t0.id)));
    g.set_tp_view(ss(s(&d["view"]).max("kanban")));
    let cols = a(&d["cols"]);
    let last = cols.len().saturating_sub(1);
    g.set_tp_cols(model(cols.iter().enumerate().map(|(i, c)| Opt { id: ss(text(&c["id"])), label: ss(text(&c["name"])),
        hint: ss(match c["limit"].as_i64().unwrap_or(0) { 0 => "—".to_string(), n => n.to_string() }), hue: color(&tp::col_color(c)), on: i == last }).collect()));
    let fs = a(&d["fields"]);
    g.set_tp_fields(model(a(&tp::fields_list()).iter().map(|f| Opt { id: ss(text(&f["id"])), label: ss(text(&f["name"])), hint: ss(""), hue: color(""),
        on: fs.iter().any(|x| x == &f["id"]) }).collect()));
    let us = used(app, &t0.id);
    g.set_tp_used(ss(match us.len() { 0 => "Ни один список пока не идёт за этим шаблоном".to_string(), 1 => us[0].clone(), n => format!("{} и ещё {}", us[0], n - 1) }));
}

pub fn set(u: &mut Ui, key: &str, v: &str) {
    let Some(t0) = u.tp.as_mut() else { return };
    let d = &mut t0.draft;
    match key {
        "name" => { d["name"] = json!(v.trim()); d["title"] = json!(v.trim()); }
        "view" => d["view"] = json!(v),
        "field" => {
            let mut fs: Vec<Value> = a(&d["fields"]).to_vec();
            if let Some(i) = fs.iter().position(|x| x == v) { fs.remove(i); } else { fs.push(json!(v)); }
            d["fields"] = json!(fs);
        }
        "col-add" => {
            let mut cs: Vec<Value> = a(&d["cols"]).to_vec();
            let at = cs.len().saturating_sub(1);
            cs.insert(at, json!({"id": format!("c{}", now()), "name": "Колонка", "color": 1, "limit": 0}));
            d["cols"] = json!(cs);
        }
        _ => {}
    }
}

pub fn col(u: &mut Ui, i: i32, key: &str, v: &str) {
    let Some(t0) = u.tp.as_mut() else { return };
    let mut cs: Vec<Value> = a(&t0.draft["cols"]).to_vec();
    let i = i as usize;
    if i >= cs.len() { return; }
    let last = cs.len() - 1;
    match key {
        "name" => { if !v.trim().is_empty() { cs[i]["name"] = json!(v.trim()); } }
        "limit" => { let n = (cs[i]["limit"].as_i64().unwrap_or(0) + v.parse::<i64>().unwrap_or(0)).clamp(0, 20); cs[i]["limit"] = json!(n); }
        "color" => { let n = (cs[i]["color"].as_i64().unwrap_or(0) + 1) % a(&tp::palette()).len() as i64; cs[i]["color"] = json!(n); }
        "del" => { if i != last && cs.len() > 2 { cs.remove(i); } }
        "left" => { if i > 0 && i != last { cs.swap(i, i - 1); } }
        "right" => { if i + 1 < last { cs.swap(i, i + 1); } }
        _ => {}
    }
    t0.draft["cols"] = json!(cs);
}

pub fn save(app: &mut App, u: &mut Ui) {
    let Some(t0) = u.tp.as_mut() else { return };
    let d = &t0.draft;
    let patch = json!({"name": d["name"], "view": d["view"], "fields": d["fields"], "cols": d["cols"], "removed": false});
    if tp::is_builtin(&json!(t0.id)) { app.touch("templatesEdit", &t0.id, patch); } else { app.touch("templates", &t0.id, patch); }
    t0.fresh = false;
    app.say("Шаблон сохранён — списки по нему обновились");
}

pub fn new(u: &mut Ui) {
    let id = format!("t{}", now());
    u.tp = Some(Tp { id, draft: tp::blank_template("Новый шаблон", now()), fresh: true });
}

pub fn dup(u: &mut Ui) {
    let Some(t0) = &u.tp else { return };
    let mut d = t0.draft.clone();
    d["name"] = json!(format!("{} — копия", text(&d["name"]).max(text(&d["title"]))));
    u.tp = Some(Tp { id: format!("t{}", now()), draft: d, fresh: true });
}

pub fn reset(app: &mut App, u: &mut Ui) {
    let Some(t0) = u.tp.clone() else { return };
    if tp::is_builtin(&json!(t0.id)) { app.touch("templatesEdit", &t0.id, json!({"removed": true})); }
    u.tp = Some(open(app, &t0.id));
}
