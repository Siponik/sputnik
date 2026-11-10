//! Модели «Доски»: колонка списков по сферам, доска в одном из четырёх видов.
use super::*;
use crate::{Card, Column, PipeRow, SideRow};
use sputnik_core::{stickers as stk, templates as tpl};

pub fn view_of(app: &App, list: &str) -> String {
    let b = app.board(list);
    let v = s(&b["view"]);
    if v.is_empty() { "kanban".into() } else { v.into() }
}

fn card(app: &App, list: &str, t: &Value) -> Card {
    let id = s(&t["id"]);
    let l = app.lt(id);
    let (due, late) = due_text(t, &l["slot"]);
    let subs = app.subtasks(list, id);
    let who = if list.starts_with("sh:") && t_(&l["who"]) {
        let w = s(&l["who"]);
        if w == app.shared.me { "я".to_string() } else { sputnik_core::sharedcore::name_of(&l["who"]) }
    } else { String::new() };
    Card {
        list_id: ss(list),
        id: ss(id),
        title: ss(text(&t["title"])),
        hue: list_hue(app, list),
        due: ss(due),
        overdue: late && !App::is_done(t),
        prio: n(&l["priority"]).unwrap_or(2.0) as i32,
        subs: ss(if subs.is_empty() { String::new() } else { format!("{}/{}", subs.iter().filter(|x| App::is_done(x)).count(), subs.len()) }),
        note: !s(&t["notes"]).trim().is_empty(),
        done: App::is_done(t),
        who: ss(who),
        topic: ss(text(&l["topic"])),
        pin: t_(&l["pin"]),
    }
}

fn t_(v: &Value) -> bool {
    sputnik_core::j::t(v)
}

pub fn side(app: &App, cur: &str) -> Vec<SideRow> {
    let lists = app.board_lists();
    let ch = sputnik_core::spheres::list_choices(&lists, &app.layer);
    let mut out = vec![];
    let mut groups: Vec<Value> = a(&ch["groups"]).to_vec();
    // общие сферы — тоже группы
    for sp in app.shared.sphere_items() {
        groups.push(json!({"id": sp["id"], "name": sp["name"], "color": sputnik_core::spheres::sphere_color(&sp)}));
    }
    if groups.is_empty() {
        groups.push(json!({"id": "", "name": "", "color": ""}));
    }
    for gr in groups {
        let gid = text(&gr["id"]);
        let ls: Vec<&Value> = lists.iter().filter(|l| app.sphere_of(s(&l["id"])).unwrap_or_default() == gid).collect();
        if ls.is_empty() {
            continue;
        }
        if !s(&gr["name"]).is_empty() {
            out.push(SideRow { id: ss(gid.clone()), name: ss(text(&gr["name"])), count: 0, header: true, hue: color(s(&gr["color"])), active: false, view: ss("") });
        }
        for l in ls {
            let id = s(&l["id"]);
            let open = app.tasks_of(id).iter().filter(|t| App::top(t) && !App::is_done(t)).count();
            out.push(SideRow { id: ss(id), name: ss(text(&l["title"])), count: open as i32, header: false, hue: list_hue(app, id), active: id == cur, view: ss(view_of(app, id)) });
        }
    }
    out
}

pub fn render(app: &App, u: &mut Ui, g: &S) {
    let lists = app.board_lists();
    if u.board.is_empty() || !lists.iter().any(|l| l["id"] == u.board.as_str()) {
        u.board = lists.first().map(|l| text(&l["id"])).unwrap_or_default();
    }
    let id = u.board.clone();
    g.set_side(model(side(app, &id)));
    g.set_board_id(ss(id.clone()));
    if id.is_empty() {
        g.set_board_title("".into());
        return;
    }
    g.set_board_title(ss(app.list_name(&id)));
    let view = view_of(app, &id);
    g.set_board_view(ss(view.clone()));
    g.set_archived(app.archived(&id).len() as i32);
    let cols = app.columns(&id);
    match view.as_str() {
        "stickers" => g.set_columns(model(stickers(app, &id))),
        "pipe" => {
            g.set_stages(strings(cols.iter().map(|c| text(&c.0["name"])).collect()));
            let mut rows = vec![];
            for (ci, (c, ts)) in cols.iter().enumerate() {
                for t in ts {
                    let l = app.lt(s(&t["id"]));
                    let (due, late) = due_text(t, &l["slot"]);
                    rows.push(PipeRow {
                        list_id: ss(id.clone()), id: ss(s(&t["id"])), title: ss(text(&t["title"])), stage: ci as i32,
                        stage_name: ss(text(&c["name"])), project: ss(text(&l["project"])), due: ss(due), overdue: late && !App::is_done(t),
                        prio: n(&l["priority"]).unwrap_or(2.0) as i32, done: App::is_done(t),
                    });
                }
            }
            // открытые выше, по проекту
            rows.sort_by(|a0, b0| a0.done.cmp(&b0.done).then(a0.project.cmp(&b0.project)));
            g.set_pipe(model(rows));
        }
        _ => {
            let last = cols.len().saturating_sub(1);
            let out: Vec<Column> = cols.iter().enumerate().map(|(i, (c, ts))| {
                let limit = n(&c["limit"]).unwrap_or(0.0) as i32;
                let done_col = i == last || c["id"] == "done";
                let mut cards: Vec<Card> = ts.iter().map(|t| card(app, &id, t)).collect();
                if done_col && view == "kanban" && cards.len() > 6 {
                    cards.truncate(6);
                }
                Column {
                    id: ss(text(&c["id"])), name: ss(text(&c["name"])), count: ts.len() as i32, limit,
                    over: limit > 0 && ts.len() as i32 > limit, done: done_col, hue: color(&tpl::col_color(c)), cards: model(cards),
                }
            }).collect();
            g.set_columns(model(out));
        }
    }
}

/// Стикеры по темам списка; сделанные сегодня ещё видны, раньше — в «баночке» (архив).
fn stickers(app: &App, id: &str) -> Vec<Column> {
    let ll = app.ll(id);
    let topics = a(&stk::topics_of(ll)).to_vec();
    let tdy = today_s();
    let items: Vec<Value> = app.tasks_of(id).iter().filter(|t| App::top(t) && (!App::is_done(t) || day10(&t["completed"]) == tdy)).cloned().collect();
    let ordered = stk::order(&items, &app.layer["tasks"], &tdy, s(&ll["sort"]));
    let mut lanes: Vec<(Value, Vec<Value>)> = topics.iter().map(|t| (t.clone(), vec![])).collect();
    let mut misc = vec![];
    for t in ordered {
        let tp = s(&app.lt(s(&t["id"]))["topic"]).to_string();
        match lanes.iter_mut().find(|x| x.0["id"] == tp.as_str()) {
            Some(x) => x.1.push(t),
            None => misc.push(t),
        }
    }
    let mut out: Vec<Column> = lanes.into_iter().filter(|x| !x.1.is_empty()).map(|(tp, ts)| Column {
        id: ss(text(&tp["id"])), name: ss(text(&tp["name"])), count: ts.len() as i32, limit: 0, over: false, done: false,
        hue: color(&stk::topic_color(&tp)), cards: model(ts.iter().map(|t| card(app, id, t)).collect()),
    }).collect();
    out.push(Column { id: ss(""), name: ss("Разное"), count: misc.len() as i32, limit: 0, over: false, done: false, hue: color(""),
        cards: model(misc.iter().map(|t| card(app, id, t)).collect()) });
    // пустые темы — тоже колонкой, чтобы было куда добавить
    for tp in &topics {
        if !out.iter().any(|c| c.id.as_str() == s(&tp["id"])) {
            out.push(Column { id: ss(text(&tp["id"])), name: ss(text(&tp["name"])), count: 0, limit: 0, over: false, done: false,
                hue: color(&stk::topic_color(tp)), cards: model(vec![]) });
        }
    }
    out
}
