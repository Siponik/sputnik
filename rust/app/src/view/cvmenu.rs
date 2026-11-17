//! Холст: меню по правому клику (G_NotesCanvasKit, п. 44). На карточке — правка, открыть, цвет, копировать,
//! вырезать, дублировать, в группу, удалить; на пустом месте — карточка, заметка, картинка, вставить, выделить всё.
//! Здесь же сами действия, которые зовут и меню, и кнопки холста.
use super::*;
use crate::MItem;

fn it(id: &str, label: &str, icon: &str, key: &str) -> MItem {
    MItem { id: ss(id), label: ss(label), icon: ss(icon), key: ss(key), ..Default::default() }
}

/// Цвета холстов Obsidian: "" — без цвета, "1"…"6".
const COLORS: [(&str, &str); 7] = [("", "Без цвета"), ("1", "Красный"), ("2", "Оранжевый"), ("3", "Жёлтый"), ("4", "Зелёный"), ("5", "Голубой"), ("6", "Фиолетовый")];

/// Точка холста, где открыли меню на пустом месте: id меню — «x,y».
fn at(id: &str) -> (f64, f64) {
    let (x, y) = id.split_once(',').unwrap_or(("0", "0"));
    (x.parse().unwrap_or(0.0), y.parse().unwrap_or(0.0))
}

pub fn items(u: &Ui, m: &menu::Menu) -> (String, Vec<MItem>) {
    if m.kind == "cv-bg" {
        let paste = !u.cv_clip.is_empty();
        return (String::from("Холст"), vec![
            it("cv-card", "Карточка здесь", "plus", ""),
            it("cv-note", "Заметка…", "note", ""),
            it("cv-image", "Картинка…", "image", ""),
            MItem { sep: true, off: !paste, ..it("cv-paste", "Вставить", "copy", "Ctrl V") },
            it("cv-all", "Выделить всё", "check", "Ctrl A"),
        ]);
    }
    let Some(c) = u.cv.as_ref() else { return (String::new(), vec![]) };
    if m.sub == "color" {
        return (String::from("Цвет"), COLORS.iter().map(|(k, l)| it(&format!("cv-color:{k}"), l, if k.is_empty() { "circle" } else { "accent" }, "")).collect());
    }
    let n = c.doc.node(&m.id);
    let kind = n.map(|n| if n.kind() == "file" && super::canvas::is_image(n.file()) { "image" } else { n.kind() }).unwrap_or("");
    let many = c.sel.len() > 1;
    let title = if many { format!("Выбрано: {}", c.sel.len()) } else {
        match kind { "file" => "Заметка", "image" => "Картинка", "link" => "Ссылка", "group" => "Группа", _ => "Карточка" }.to_string()
    };
    let mut v = vec![];
    if !many && matches!(kind, "text" | "group" | "file") {
        v.push(it("cv-edit", "Править", "edit", ""));
    }
    if !many && matches!(kind, "file" | "image" | "link") {
        v.push(it("cv-open", if kind == "file" { "Открыть заметку" } else { "Открыть" }, "open", ""));
    }
    v.push(MItem { sub: true, ..it("sub:color", "Цвет", "accent", "") });
    v.push(MItem { sep: true, ..it("cv-copy", "Копировать", "copy", "Ctrl C") });
    v.push(it("cv-cut", "Вырезать", "copy", "Ctrl X"));
    v.push(it("cv-dup", "Дублировать", "copy", "Ctrl D"));
    v.push(it("cv-group", "В группу", "canvas", "Ctrl G"));
    v.push(MItem { sep: true, red: true, ..it("cv-delete", "Удалить", "trash", "Del") });
    (title, v)
}

pub fn pick(app: &mut App, u: &mut Ui, m: &menu::Menu, id: &str) {
    let (x, y) = at(&m.id);
    let key = |app: &mut App, u: &mut Ui, k: &str| super::canvas::key(app, u, k, x, y);
    match id {
        "cv-card" => add(app, u, "text", x, y),
        "cv-note" => u.cv_pick += 1,
        "cv-image" => add_image(app, u, x, y),
        "cv-paste" => key(app, u, "paste"),
        "cv-all" => key(app, u, "all"),
        "cv-edit" => key(app, u, "edit"),
        "cv-open" => key(app, u, "open"),
        "cv-copy" => key(app, u, "copy"),
        "cv-cut" => key(app, u, "cut"),
        "cv-dup" => key(app, u, "dup"),
        "cv-group" => key(app, u, "group"),
        "cv-delete" => key(app, u, "delete"),
        c if c.starts_with("cv-color:") => key(app, u, &format!("color:{}", &c["cv-color:".len()..])),
        _ => {}
    }
}

/// Карточка (`text`) или группа в точке (x, y) холста — сразу на правку.
pub fn add(app: &mut App, u: &mut Ui, kind: &str, x: f64, y: f64) {
    let kind = kind.to_string();
    super::canvas::change(app, u, |c| {
        let (w, h) = if kind == "group" { (500.0, 340.0) } else { (260.0, 120.0) };
        let label = if kind == "group" { "Группа" } else { "" };
        let made = if kind == "group" && !c.sel.is_empty() {
            c.doc.group_around(&c.sel.clone(), label).unwrap_or_default()
        } else {
            c.doc.add(&kind, x - w / 2.0, y - h / 2.0, w, h, label)
        };
        c.sel = vec![made.clone()];
        c.edit = made;
    });
}

/// Картинка с компьютера в точку (x, y): из папки заметок — ссылкой, иначе копией в «Вложения/».
pub fn add_image(app: &mut App, u: &mut Ui, x: f64, y: f64) {
    let Some(src) = rfd::FileDialog::new().set_title("Картинка на канвас").add_filter("Картинки", &["png", "jpg", "jpeg", "webp", "gif"]).pick_file() else { return };
    let Some(root) = app.notes.root.clone() else { return };
    let name = src.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "картинка.png".into());
    // уже в папке заметок — ссылаемся как есть; иначе копия в «Вложения/»
    let rel = match src.strip_prefix(&root) {
        Ok(r) => r.to_string_lossy().replace('\\', "/"),
        Err(_) => {
            let dir = root.join("Вложения");
            let _ = std::fs::create_dir_all(&dir);
            let (stem, ext) = name.rsplit_once('.').unwrap_or((&name, "png"));
            let file = (1..).map(|i| if i == 1 { name.clone() } else { format!("{stem} {i}.{ext}") }).find(|f| !dir.join(f).exists()).unwrap();
            if let Err(e) = std::fs::copy(&src, dir.join(&file)) {
                app.say(format!("Картинка не скопировалась: {e}"));
                return;
            }
            format!("Вложения/{file}")
        }
    };
    super::canvas::change(app, u, |c| {
        let id = c.doc.add("file", x - 160.0, y - 120.0, 320.0, 240.0, &rel);
        c.sel = vec![id];
    });
}

/// Открыть ноду: заметку — во вкладке, картинку и ссылку — снаружи, карточку — на правку.
pub fn open_node(app: &mut App, u: &mut Ui, id: &str) {
    let Some(c) = u.cv.as_ref() else { return };
    let Some(n) = c.doc.node(id) else { return };
    match n.kind() {
        "file" if super::canvas::is_image(n.file()) => { if let Some(p) = super::canvas::file_of(app, n.file()) { let _ = open::that(p); } }
        "file" => {
            let p = n.file().to_string();
            if app.notes.notes.iter().any(|x| x.path == p) { super::wire::open_note_tab(app, u, &p); } else { app.say("Заметки нет в папке"); }
        }
        "link" => { let _ = open::that(n.url()); }
        _ => { let id = id.to_string(); if let Some(c) = u.cv.as_mut() { c.edit = id; } }
    }
}

/// Сохранить текст заметки, правленный на холсте (шапку YAML оставить как была).
pub fn save_note(app: &mut App, path: &str, body: &str) {
    let Some(old) = app.notes.notes.iter().find(|n| n.path == path).map(|n| n.body.clone()) else { return };
    let front = &old[..old.len() - crate::notes::body_without_front(&old).len()];
    if crate::notes::body_without_front(&old) == body {
        return;
    }
    if let Err(e) = app.notes.save(path, &format!("{front}{body}")) {
        app.say(format!("Заметка не сохранилась: {e}"));
    }
}
