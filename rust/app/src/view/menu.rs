//! Меню по правому клику (G_ListMenu): какие пункты показать и что они делают.
use super::*;
use crate::MItem;
use serde_json::json;

#[derive(Clone, Default)]
pub struct Menu {
    pub kind: String,
    pub id: String,
    pub x: f32,
    pub y: f32,
    /// Открытое подменю: "" — основное.
    pub sub: String,
}

fn it(id: &str, label: &str, icon: &str, key: &str) -> MItem {
    MItem { id: ss(id), label: ss(label), icon: ss(icon), key: ss(key), ..Default::default() }
}

const VIEWS: [(&str, &str, &str); 4] = [("kanban", "Канбан", "board"), ("pipe", "Конвейер", "stage"), ("list", "Список", "sort"), ("stickers", "Стикеры", "pin")];

fn items(app: &App, m: &Menu) -> (String, Vec<MItem>) {
    match m.kind.as_str() {
        "list" => {
            let ll = app.ll(&m.id);
            let name = app.list_name(&m.id);
            match m.sub.as_str() {
                "view" => {
                    let cur = s(&ll["view"]);
                    (format!("{name} · вид"), VIEWS.iter().enumerate().map(|(i, (id, l, ic))| MItem {
                        on: cur == *id || (cur.is_empty() && *id == "kanban"), ..it(&format!("view:{id}"), l, ic, &(i + 1).to_string()) }).collect())
                }
                "sphere" => {
                    let cur = s(&ll["sphere"]);
                    let mut v = vec![MItem { on: cur.is_empty(), ..it("sphere:", "Без сферы", "circle", "") }];
                    v.extend(app.spheres().iter().map(|x| MItem { on: cur == s(&x["id"]), ..it(&format!("sphere:{}", text(&x["id"])), &text(&x["name"]), "spheres", "") }));
                    (format!("{name} · сфера"), v)
                }
                _ => {
                    let main = app.lists.first().map(|l| l["id"] == m.id.as_str()).unwrap_or(false);
                    let mut del = MItem { red: !main, off: main, sep: true, ..it("delete", if main { "Основной список не удаляется" } else { "Удалить список…" }, "trash", if main { "" } else { "Del" }) };
                    del.sep = true;
                    (name, vec![
                        it("open", "Открыть", "open", ""),
                        it("settings", "Переименовать", "edit", ""),
                        it("settings", "Настроить список…", "settings", "Ctrl ."),
                        MItem { sep: true, sub: true, ..it("sub:view", "Вид", "board", "") },
                        MItem { sub: true, ..it("sub:sphere", "Сфера", "spheres", "") },
                        MItem { sep: true, ..it("today", if ll["hidden"] == true { "Показывать в «Сегодня»" } else { "Скрыть из «Сегодня»" }, if ll["hidden"] == true { "eye" } else { "eyeoff" }, "") },
                        it("quiet", if ll["quiet"] == true { "Вернуть в сводку и бота" } else { "Без сводки и бота" }, "bell", ""),
                        it("arch", "В архив", "archive", ""),
                        del,
                    ])
                }
            }
        }
        "sphere" => super::spheres::menu_items(app, &m.id),
        "note" => {
            let title = app.notes.notes.iter().find(|n| n.path == m.id).map(|n| n.title.clone()).unwrap_or_default();
            (format!("Заметка · {title}"), vec![
                it("note-open", "Открыть", "open", ""),
                it("note-graph", "Показать на графе", "graph", ""),
                MItem { sep: true, ..it("note-dir", "Показать в папке Windows", "folder", "") },
                it("note-file", "Открыть в другой программе", "share", ""),
                MItem { sep: true, ..it("note-rename", "Переименовать…", "edit", "") },
                MItem { red: true, ..it("note-trash", "Удалить в корзину", "trash", "") },
            ])
        }
        "newnote" => {
            let mut v = vec![it("new:", "Пустая заметка", "note", "")];
            v.extend(super::notefile::templates(app).into_iter().map(|(p, t)| it(&format!("tpl:{p}"), &t, "copy", "")));
            (String::from("Новая заметка · шаблон"), v)
        }
        "tab" => (String::from("Вкладка"), vec![
            it("tab-close", "Закрыть", "close", "Ctrl W"),
            it("tab-others", "Закрыть остальные", "close", ""),
            MItem { sep: true, ..it("note-dir", "Показать в папке Windows", "folder", "") },
        ]),
        _ => (String::new(), vec![]),
    }
}

fn note_file(app: &App, path: &str) -> Option<std::path::PathBuf> {
    let p = std::path::PathBuf::from(path);
    if p.is_absolute() { Some(p) } else { app.notes.root.as_ref().map(|r| r.join(p)) }
}

fn note_pick(app: &mut App, u: &mut Ui, m: &Menu, id: &str) {
    let p = m.id.clone();
    match id {
        "note-open" => { u.note_graph = false; super::wire::open_note_tab(app, u, &p); }
        "note-graph" => { super::wire::open_note_tab(app, u, &p); u.note_graph = true; }
        "note-dir" => { if let Some(f) = note_file(app, &p) { let _ = open::that(f.parent().unwrap_or(&f)); } }
        "note-file" => { if let Some(f) = note_file(app, &p) { let _ = open::that(f); } }
        "note-rename" => super::notefile::ask_rename(u, p),
        "note-trash" => super::notefile::ask_trash(app, u, p),
        "tab-close" => {
            if u.note_path == p { super::wire::save_draft(app, u); }
            u.note_tabs.retain(|t| t != &p);
            if u.note_path == p { u.note_path = u.note_tabs.last().cloned().unwrap_or_default(); }
        }
        "tab-others" => {
            if u.note_path != p { super::wire::save_draft(app, u); }
            u.note_tabs.retain(|t| t == &p);
            if u.note_path != p { super::wire::open_note_tab(app, u, &p); }
        }
        _ => {}
    }
}

pub fn render(app: &App, u: &Ui, g: &S) {
    g.set_menu_open(u.menu.is_some());
    let Some(m) = &u.menu else { return };
    let (title, v) = items(app, m);
    g.set_menu_x(m.x);
    g.set_menu_y(m.y);
    g.set_menu_title(ss(title));
    // меню сферы — с шапкой цвета сферы (G_Spheres)
    g.set_menu_head(if m.kind == "sphere" { app.spheres().iter().find(|x| x["id"] == m.id.as_str()).map(|x| super::spheres::head(&sputnik_core::spheres::sphere_color(x))).unwrap_or_default() } else { slint::Color::default() });
    g.set_menu_items(model(v));
}

pub fn pick(app: &mut App, u: &mut Ui, id: &str) {
    let Some(m) = u.menu.clone() else { return };
    if let Some(sub) = id.strip_prefix("sub:") {
        if let Some(mm) = u.menu.as_mut() { mm.sub = sub.into(); }
        return;
    }
    u.menu = None;
    if m.kind == "note" || m.kind == "tab" { note_pick(app, u, &m, id); return; }
    if m.kind == "newnote" { super::notefile::create(app, u, &m.id, id.strip_prefix("tpl:").unwrap_or("")); return; }
    if m.kind == "sphere" {
        let sid = m.id.clone();
        match id {
            "sph-edit" => { u.tab = 2; u.arch = false; u.sph = Some(sid); }
            "sph-list" => { u.tab = 2; u.arch = false; u.sph = Some(sid); u.sph_add = true; }
            "sph-arch" => super::spheres::archive(app, u, "sphere", &sid, true),
            "sph-del" => super::spheres::ask_delete(app, u, sid),
            _ => {}
        }
        return;
    }
    if m.kind != "list" { return; }
    let l = m.id.clone();
    let (k, v) = id.split_once(':').unwrap_or((id, ""));
    match k {
        "open" => { u.board = l; u.arch = false; }
        "settings" => { u.board = l; u.arch = false; u.ls = true; }
        "view" => app.set_list_field(&l, json!({"view": v})),
        "sphere" => app.set_list_field(&l, json!({"sphere": if v.is_empty() { Value::Null } else { json!(v) }})),
        "arch" => super::spheres::archive(app, u, "list", &l, true),
        "today" => { let h = app.ll(&l)["hidden"] == true; app.set_list_field(&l, json!({"hidden": !h})); }
        "quiet" => { let q = app.ll(&l)["quiet"] == true; app.set_list_field(&l, json!({"quiet": !q})); }
        "delete" => {
            let n0 = app.tasks_of(&l).len();
            super::wire::ask(u, format!("Удалить список «{}» и {} задач в нём? В Google Tasks он удалится насовсем.", app.list_name(&l), n0), "Удалить", move |app, u| {
                app.delete_list(&l);
                u.board.clear();
            });
        }
        _ => {}
    }
}
