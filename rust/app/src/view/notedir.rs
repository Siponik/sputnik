//! «Знания»: меню папки в дереве — цвет, «удалить только папку» (содержимое поднимается выше), «удалить со всем» (в `.trash`).
use sputnik_core::t;
use super::*;
use crate::MItem;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

/// Цвета на выбор (тона сфер), «» — по умолчанию.
const COLORS: [(&str, &str); 7] = [("F0A04B", "Оранжевый"), ("B48CF0", "Сиреневый"), ("6FA2F2", "Синий"), ("7FD18C", "Зелёный"), ("E8C65A", "Жёлтый"), ("F0785F", "Красный"), ("5FB3C4", "Бирюзовый")];

thread_local! {
    static COLS: RefCell<Option<BTreeMap<String, String>>> = const { RefCell::new(None) };
}

/// Свои цвета папок (путь → «RRGGBB»), хранятся в папке настроек.
pub fn colors() -> BTreeMap<String, String> {
    COLS.with(|c| c.borrow_mut().get_or_insert_with(|| {
        crate::data::store::read("note-dir-colors.json").and_then(|v| serde_json::from_value(v).ok()).unwrap_or_default()
    }).clone())
}

fn save(v: BTreeMap<String, String>) {
    let _ = crate::data::store::write_json("note-dir-colors.json", &serde_json::json!(v));
    COLS.with(|c| *c.borrow_mut() = Some(v));
}

/// Свой цвет папки, если задан.
pub fn color_of(dir: &str) -> Option<slint::Color> {
    colors().get(dir).and_then(|h| u32::from_str_radix(h, 16).ok()).map(|v| slint::Color::from_argb_encoded(0xFF00_0000 | v))
}

fn it(id: &str, label: &str, icon: &str) -> MItem {
    MItem { id: ss(id), label: ss(label), icon: ss(icon), ..Default::default() }
}

pub fn items(m: &super::menu::Menu) -> (String, Vec<MItem>) {
    let name = m.id.rsplit('/').next().unwrap_or(&m.id).to_string();
    if m.sub == "color" {
        let cur = colors().get(&m.id).cloned().unwrap_or_default();
        let mut v = vec![MItem { on: cur.is_empty(), ..it("dir-color:", t!("По умолчанию"), "circle") }];
        v.extend(COLORS.iter().map(|(h, l)| MItem { on: cur == *h, hue: super::canvas::hex_color(&format!("#{h}")).unwrap_or_default(), ..it(&format!("dir-color:{h}"), sputnik_core::i18n::tr(l), "circle") }));
        return (t!("{} · цвет", name), v);
    }
    (t!("Папка · {}", name), vec![
        MItem { sub: true, ..it("sub:color", t!("Цвет"), "spheres") },
        MItem { sep: true, ..it("dir-dir", t!("Показать в папке Windows"), "folder") },
        MItem { sep: true, red: true, ..it("dir-lift", t!("Удалить только папку…"), "trash") },
        MItem { red: true, ..it("dir-trash", t!("Удалить со всем содержимым…"), "trash") },
    ])
}

pub fn pick(app: &mut App, u: &mut Ui, dir: String, id: &str) {
    if let Some(h) = id.strip_prefix("dir-color:") {
        let mut v = colors();
        if h.is_empty() { v.remove(&dir); } else { v.insert(dir, h.to_string()); }
        save(v);
        return;
    }
    let Some(root) = app.notes.root.clone() else { return };
    let name = dir.rsplit('/').next().unwrap_or(&dir).to_string();
    let n = files(&root.join(&dir)).len();
    match id {
        "dir-dir" => { let _ = open::that(root.join(&dir)); }
        "dir-lift" => super::wire::ask(u, t!("Удалить папку «{}»? Её файлы ({}) останутся — переедут на уровень выше.", name, n), t!("Удалить папку"), move |app, u| lift(app, u, &dir)),
        "dir-trash" => super::wire::ask(u, t!("Удалить папку «{}» со всем содержимым ({})? Всё ляжет в папку .trash внутри папки заметок.", name, n), t!("Удалить всё"), move |app, u| trash(app, u, &dir)),
        _ => {}
    }
}

/// Все файлы внутри папки (полные пути).
fn files(d: &Path) -> Vec<PathBuf> {
    let mut out = vec![];
    let Ok(rd) = std::fs::read_dir(d) else { return out };
    for e in rd.flatten() {
        let p = e.path();
        if p.is_dir() { out.extend(files(&p)); } else { out.push(p); }
    }
    out
}

fn rel(root: &Path, p: &Path) -> String {
    p.strip_prefix(root).unwrap_or(p).to_string_lossy().replace('\\', "/")
}

/// Свободное имя: «x.md», «x 2.md», …
fn free(path: &str, taken: impl Fn(&str) -> bool) -> String {
    if !taken(path) {
        return path.to_string();
    }
    let (stem, ext) = match path.rfind('.') {
        Some(k) if k > path.rfind('/').map_or(0, |s| s + 1) => (&path[..k], &path[k..]),
        _ => (path, ""),
    };
    (2..).map(|i| format!("{stem} {i}{ext}")).find(|p| !taken(p)).unwrap_or(path.to_string())
}

fn lift(app: &mut App, u: &mut Ui, dir: &str) {
    let Some(root) = app.notes.root.clone() else { return };
    super::wire::save_draft(app, u);
    let mut moved = 0;
    for f in files(&root.join(dir)) {
        let old = rel(&root, &f);
        let new = free(&sputnik_core::notefile::lift_path(&old, dir), |p| root.join(p).exists());
        if let Some(d) = root.join(&new).parent() { let _ = std::fs::create_dir_all(d); }
        if std::fs::rename(&f, root.join(&new)).is_ok() {
            moved += 1;
            for t in u.note_tabs.iter_mut().filter(|t| **t == old) { *t = new.clone(); }
            if u.note_path == old { u.note_path = new.clone(); }
        }
    }
    let _ = std::fs::remove_dir_all(root.join(dir));
    forget(dir);
    u.cv = None;
    app.notes.rescan();
    super::canvas::ensure(app, u);
    app.say(t!("Папка удалена, файлов поднято выше: {}", moved));
}

fn trash(app: &mut App, u: &mut Ui, dir: &str) {
    let Some(root) = app.notes.root.clone() else { return };
    if u.note_path.starts_with(&format!("{dir}/")) {
        super::wire::save_draft(app, u);
        u.note_dirty = false;
    }
    let to = free(&format!(".trash/{dir}"), |p| root.join(p).exists());
    if let Some(d) = root.join(&to).parent() { let _ = std::fs::create_dir_all(d); }
    if let Err(e) = std::fs::rename(root.join(dir), root.join(&to)) {
        app.say(t!("Не удалилось: {}", e));
        return;
    }
    let inside = |p: &str| p.starts_with(&format!("{dir}/"));
    u.note_tabs.retain(|t| !inside(t));
    if inside(&u.note_path) { u.note_path = u.note_tabs.last().cloned().unwrap_or_default(); }
    forget(dir);
    u.cv = None;
    app.notes.rescan();
    super::canvas::ensure(app, u);
    app.say(t!("Папка «{}» — в корзине (.trash)", dir.rsplit('/').next().unwrap_or(dir)));
}

/// Забыть цвет и раскрытость удалённой папки.
fn forget(dir: &str) {
    let mut v = colors();
    if v.remove(dir).is_some() { save(v); }
}
