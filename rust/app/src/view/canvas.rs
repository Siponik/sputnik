//! Канвас «Знаний»: файл `.canvas` (JSON Canvas, тот же открывает Obsidian) — ноды-заметки, карточки, картинки,
//! группы и провода. Логика файла — `sputnik_core::canvas`; здесь — открыть, показать, править, сохранить.
//! Камера (сдвиг и масштаб) живёт в окне (`canvas.slint`), сюда приходят только итоги действий в единицах холста.
use super::*;
use crate::{CvEdge, CvNode, MdRow, NoteRow};
use sputnik_core::canvas::{self as cv, Doc, History, Side};

/// Открытый канвас.
#[derive(Default)]
pub struct Cv {
    pub path: String,
    pub doc: Doc,
    /// Выбранные ноды.
    pub sel: Vec<String>,
    /// Выбранный провод.
    pub edge: String,
    /// Нода или провод, который правится на месте.
    pub edit: String,
    pub hist: History,
    /// Файл не прочитался — не перезаписываем, пока не исправят снаружи.
    pub err: String,
    /// Что мы сами записали последним — чтобы отличить свою запись от правки снаружи.
    pub last: String,
    /// Растёт при каждом открытии — окно по нему вписывает холст в экран.
    pub ver: i32,
}

pub fn is_canvas(path: &str) -> bool {
    path.ends_with(".canvas")
}

fn is_image(path: &str) -> bool {
    let p = path.to_lowercase();
    [".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"].iter().any(|e| p.ends_with(e))
}

fn file_of(app: &App, path: &str) -> Option<std::path::PathBuf> {
    app.notes.root.as_ref().map(|r| r.join(path))
}

/// Открыть канвас `path` (если ещё не открыт).
pub fn ensure(app: &App, u: &mut Ui) {
    if !is_canvas(&u.note_path) {
        return;
    }
    if u.cv.as_ref().is_some_and(|c| c.path == u.note_path) {
        return;
    }
    let ver = u.cv.as_ref().map_or(0, |c| c.ver) + 1;
    let text = file_of(app, &u.note_path).and_then(|p| std::fs::read_to_string(p).ok()).unwrap_or_default();
    let (doc, err) = match Doc::parse(&text) {
        Ok(d) => (d, String::new()),
        Err(e) => (Doc::default(), e),
    };
    u.cv = Some(Cv { path: u.note_path.clone(), doc, err, last: text, ver, ..Default::default() });
}

/// Файл изменили снаружи (Obsidian, другой компьютер) — перечитать, если это не наша запись.
pub fn reload_if_changed(app: &App, u: &mut Ui) {
    let Some(c) = &u.cv else { return };
    let text = file_of(app, &c.path).and_then(|p| std::fs::read_to_string(p).ok()).unwrap_or_default();
    if text == c.last || text.trim().is_empty() {
        return;
    }
    if let Ok(doc) = Doc::parse(&text) {
        let c = u.cv.as_mut().unwrap();
        c.hist.push(c.doc.encode());
        c.doc = doc;
        c.err.clear();
        c.last = text;
        c.sel.retain(|id| c.doc.node(id).is_some());
    }
}

/// Правка: запомнить «до» для Ctrl+Z, поменять, записать файл.
fn change(app: &mut App, u: &mut Ui, f: impl FnOnce(&mut Cv)) {
    ensure(app, u);
    let Some(c) = u.cv.as_mut() else { return };
    if !c.err.is_empty() {
        app.say("Канвас не читается — сначала поправь файл");
        return;
    }
    let before = c.doc.encode();
    f(c);
    let after = c.doc.encode();
    if after != before {
        c.hist.push(before);
        save(app, c);
    }
}

fn save(app: &mut App, c: &mut Cv) {
    let text = c.doc.encode();
    let Some(p) = file_of(app, &c.path) else { return };
    if let Some(d) = p.parent() {
        let _ = std::fs::create_dir_all(d);
    }
    match std::fs::write(&p, &text) {
        Ok(()) => c.last = text,
        Err(e) => app.say(format!("Канвас не сохранился: {e}")),
    }
}

/// Новый канвас в корне папки заметок (или в папке `dir`).
pub fn new_canvas(app: &mut App, u: &mut Ui, dir: &str) {
    if app.notes.root.is_none() {
        app.notes.root = Some(crate::data::store::own("notes"));
        app.notes.watch();
    }
    let root = app.notes.root.clone().unwrap_or_default();
    let base = if dir.is_empty() { "Новый канвас".to_string() } else { format!("{dir}/Новый канвас") };
    let path = (1..).map(|i| if i == 1 { format!("{base}.canvas") } else { format!("{base} {i}.canvas") })
        .find(|p| !root.join(p).exists()).unwrap();
    let _ = std::fs::create_dir_all(root.join(&path).parent().unwrap_or(&root));
    match std::fs::write(root.join(&path), "{\n\t\"nodes\":[],\n\t\"edges\":[]\n}") {
        Ok(()) => {
            app.notes.rescan();
            super::wire::open_note_tab(app, u, &path);
        }
        Err(e) => app.say(format!("Канвас не создался: {e}")),
    }
}

thread_local! {
    /// Модели нод и проводов живут, пока не сменится набор: строки меняются на месте — иначе окно
    /// пересоздаёт ноду под мышью и перетаскивание обрывается.
    static NODES: std::cell::RefCell<Option<std::rc::Rc<slint::VecModel<CvNode>>>> = const { std::cell::RefCell::new(None) };
    static EDGES: std::cell::RefCell<Option<std::rc::Rc<slint::VecModel<CvEdge>>>> = const { std::cell::RefCell::new(None) };
    static IMGS: std::cell::RefCell<std::collections::HashMap<String, slint::Image>> = Default::default();
}

fn image(app: &App, path: &str) -> slint::Image {
    IMGS.with(|m| {
        if let Some(i) = m.borrow().get(path) {
            return i.clone();
        }
        let im = file_of(app, path).and_then(|p| slint::Image::load_from_path(&p).ok()).unwrap_or_default();
        m.borrow_mut().insert(path.to_string(), im.clone());
        im
    })
}

/// Цвет шапки ноды-заметки по папке (стабильный для имени папки).
fn folder_hue(folder: &str) -> Color {
    const PAL: [u32; 5] = [0x5E3F92, 0x2F4F86, 0x2E6B3E, 0x7A6620, 0x8A3A2E];
    if folder.is_empty() {
        return Color::from_rgb_u8(0x3D, 0x3E, 0x45);
    }
    let h = folder.chars().fold(0u32, |a, c| a.wrapping_mul(31).wrapping_add(c as u32));
    let c = PAL[(h % PAL.len() as u32) as usize];
    Color::from_rgb_u8((c >> 16) as u8, (c >> 8) as u8, c as u8)
}

fn hex_color(h: &str) -> Option<Color> {
    let v = u32::from_str_radix(h.strip_prefix('#')?, 16).ok()?;
    Some(Color::from_rgb_u8((v >> 16) as u8, (v >> 8) as u8, v as u8))
}

fn md_rows(text: &str, max: usize) -> Vec<MdRow> {
    crate::notes::line_rows(text).into_iter().filter(|r| r.kind != "fence").take(max).map(|r| MdRow {
        kind: ss(r.kind),
        raw: ss(r.raw),
        md: slint::StyledText::from_markdown(&r.md).unwrap_or_else(|_| slint::StyledText::from_plain_text(&r.md)),
        plain: ss(r.plain),
    }).collect()
}

pub fn render(app: &App, u: &Ui, g: &S) {
    let Some(c) = u.cv.as_ref().filter(|c| c.path == u.note_path) else {
        NODES.with(|c| *c.borrow_mut() = None);
        EDGES.with(|c| *c.borrow_mut() = None);
        g.set_cv_nodes(model(vec![]));
        g.set_cv_edges(model(vec![]));
        return;
    };
    let d = &c.doc;
    let mv = d.movable(&c.sel);
    let main = if c.sel.len() == 1 { c.sel[0].clone() } else { String::new() };
    let nodes: Vec<CvNode> = d.nodes.iter().map(|n| {
        let (mut kind, mut title, mut tag, mut rows, mut img, mut missing) = (n.kind().to_string(), n.title(), String::new(), vec![], slint::Image::default(), false);
        let mut head = Color::from_rgb_u8(0x3D, 0x3E, 0x45);
        match n.kind() {
            "file" if is_image(n.file()) => {
                kind = "image".into();
                tag = "КАРТИНКА".into();
                img = image(app, n.file());
                title = n.file().rsplit('/').next().unwrap_or("").to_string();
            }
            "file" => {
                let f = n.file();
                let folder = f.rsplit_once('/').map(|p| p.0).unwrap_or("");
                tag = folder.rsplit('/').next().unwrap_or("").to_uppercase();
                head = folder_hue(folder);
                match app.notes.notes.iter().find(|x| x.path == f) {
                    Some(note) => {
                        let body = crate::notes::body_without_front(&note.body).trim_start();
                        // первая строка «# Заголовок» идёт в шапку ноды
                        let (h1, rest) = match body.split_once('\n') {
                            Some((first, rest)) if first.starts_with("# ") => (Some(first), rest),
                            None if body.starts_with("# ") => (Some(body), ""),
                            _ => (None, body),
                        };
                        if let Some(h) = h1 {
                            title = h.trim_start_matches('#').trim().to_string();
                        }
                        rows = md_rows(rest.trim_start(), 40);
                    }
                    None => missing = true,
                }
            }
            "text" => {
                tag = "ТЕКСТ".into();
                rows = md_rows(n.text(), 60);
            }
            "link" => tag = "ССЫЛКА".into(),
            _ => {}
        }
        let col = hex_color(&cv::color_hex(n.color()));
        if let Some(c) = col {
            head = c;
        }
        CvNode {
            id: ss(n.id()), kind: ss(kind), x: n.x() as f32, y: n.y() as f32, w: n.w() as f32, h: n.h() as f32,
            title: ss(title), tag: ss(tag), rows: model(rows), img, missing,
            head, colored: col.is_some(), text: ss(if n.is_group() { n.label() } else { n.text() }),
            sel: c.sel.iter().any(|s| s == n.id()), mv: mv.iter().any(|s| s == n.id()), main: main == n.id(),
            path: ss(n.file()),
        }
    }).collect();
    keep(&NODES, nodes, |m| g.set_cv_nodes(m));
    let edges: Vec<CvEdge> = d.edges.iter().filter_map(|e| {
        let (a, b) = (d.node(e.from())?, d.node(e.to())?);
        let k = cv::edge_curve(e, a, b);
        // провод — цветом источника (как в макете), свой цвет — главнее
        let col = hex_color(&cv::color_hex(e.color())).or_else(|| {
            let own = hex_color(&cv::color_hex(a.color()));
            let f = a.file();
            own.or_else(|| (a.kind() == "file" && !is_image(f)).then(|| folder_hue(f.rsplit_once('/').map(|p| p.0).unwrap_or(""))).map(|c| c.brighter(0.9)))
                .or_else(|| (a.kind() == "text").then(|| Color::from_rgb_u8(0xE8, 0xC6, 0x5A)))
        });
        Some(CvEdge {
            id: ss(e.id()), ax: k.a.0 as f32, ay: k.a.1 as f32, c1x: k.c1.0 as f32, c1y: k.c1.1 as f32,
            c2x: k.c2.0 as f32, c2y: k.c2.1 as f32, bx: k.b.0 as f32, by: k.b.1 as f32,
            amv: mv.iter().any(|s| s == e.from()), bmv: mv.iter().any(|s| s == e.to()),
            label: ss(e.label()), sel: c.edge == e.id(), arrow: e.arrow_to(),
            color: col.unwrap_or_default(), colored: col.is_some(),
        })
    }).collect();
    keep(&EDGES, edges, |m| g.set_cv_edges(m));
    let b = d.bounds_of(None).unwrap_or((-400.0, -300.0, 400.0, 300.0));
    g.set_cv_bounds(model(vec![b.0 as f32, b.1 as f32, b.2 as f32, b.3 as f32]));
    g.set_cv_ver(c.ver);
    g.set_cv_err(ss(c.err.clone()));
    g.set_cv_edit(ss(c.edit.clone()));
    g.set_cv_sel(c.sel.len() as i32 + if c.edge.is_empty() { 0 } else { 1 });
    g.set_cv_title(ss(c.path.rsplit('/').next().unwrap_or(&c.path).trim_end_matches(".canvas").to_string()));
    g.set_cv_crumb(ss(c.path.replace('/', " / ").to_uppercase()));
}

fn keep<T: Clone + PartialEq + 'static>(cell: &'static std::thread::LocalKey<std::cell::RefCell<Option<std::rc::Rc<slint::VecModel<T>>>>>, rows: Vec<T>, set: impl FnOnce(slint::ModelRc<T>)) {
    use slint::Model;
    cell.with(|c| {
        let mut c = c.borrow_mut();
        if let Some(m) = c.as_ref() {
            if m.row_count() == rows.len() {
                for (i, r) in rows.into_iter().enumerate() {
                    if m.row_data(i).as_ref() != Some(&r) {
                        m.set_row_data(i, r);
                    }
                }
                return;
            }
            // другое число строк: меняем по месту, лишние убираем, новые добавляем
            let n = m.row_count().min(rows.len());
            let mut it = rows.into_iter();
            for i in 0..n {
                let r = it.next().unwrap();
                if m.row_data(i).as_ref() != Some(&r) {
                    m.set_row_data(i, r);
                }
            }
            while m.row_count() > n {
                m.remove(m.row_count() - 1);
            }
            for r in it {
                m.push(r);
            }
            return;
        }
        let m = std::rc::Rc::new(slint::VecModel::from(rows));
        set(m.clone().into());
        *c = Some(m);
    });
}

fn side(s: i32) -> Side {
    match s {
        0 => Side::Top,
        1 => Side::Right,
        2 => Side::Bottom,
        _ => Side::Left,
    }
}

fn with_cv(f: impl FnOnce(&mut App, &mut Ui) + 'static) {
    act(|app, u| {
        ensure(app, u);
        f(app, u);
    });
}

pub fn wire(g: &S) {
    // выбор: id "" — снять; add — к выделению (Shift/Ctrl)
    g.on_cv_click(|id, add| with_cv(move |_, u| {
        let Some(c) = u.cv.as_mut() else { return };
        let id = id.to_string();
        c.edge.clear();
        if id.is_empty() {
            if !add { c.sel.clear(); }
        } else if add {
            if let Some(i) = c.sel.iter().position(|x| *x == id) { c.sel.remove(i); } else { c.sel.push(id); }
        } else if !c.sel.contains(&id) {
            c.sel = vec![id];
        }
        c.edit.clear();
    }));
    g.on_cv_box(|x0, y0, x1, y1, add| with_cv(move |_, u| {
        let Some(c) = u.cv.as_mut() else { return };
        let ids = c.doc.in_rect(x0 as f64, y0 as f64, x1 as f64, y1 as f64);
        if !add { c.sel.clear(); }
        for i in ids { if !c.sel.contains(&i) { c.sel.push(i); } }
        c.edge.clear();
    }));
    g.on_cv_move(|dx, dy, copy| with_cv(move |app, u| change(app, u, |c| {
        if copy {
            // Alt + тянуть — копия на новом месте, старое остаётся
            let ids = c.sel.clone();
            if let Some((x0, y0, x1, y1)) = c.doc.bounds_of(Some(&ids)) {
                let t = c.doc.copy_of(&ids);
                if let Some(made) = c.doc.paste(&t, (x0 + x1) / 2.0 + dx as f64, (y0 + y1) / 2.0 + dy as f64) { c.sel = made; }
            }
        } else {
            let mv = c.doc.movable(&c.sel);
            c.doc.shift(&mv, dx as f64, dy as f64);
        }
    })));
    g.on_cv_resize(|id, w, h| with_cv(move |app, u| change(app, u, |c| {
        if let Some(n) = c.doc.node_mut(&id) {
            let (x, y) = (n.x(), n.y());
            n.set_rect(x, y, cv::snap(w as f64), cv::snap(h as f64));
        }
    })));
    g.on_cv_add(|kind, x, y| with_cv(move |app, u| {
        let kind = kind.to_string();
        let mut made = String::new();
        change(app, u, |c| {
            let (w, h) = if kind == "group" { (500.0, 340.0) } else { (260.0, 120.0) };
            let label = if kind == "group" { "Группа" } else { "" };
            if kind == "group" && !c.sel.is_empty() {
                made = c.doc.group_around(&c.sel.clone(), label).unwrap_or_default();
            } else {
                made = c.doc.add(&kind, x as f64 - w / 2.0, y as f64 - h / 2.0, w, h, label);
            }
            c.sel = vec![made.clone()];
            c.edit = made.clone();
        });
    }));
    g.on_cv_text(|id, t| with_cv(move |app, u| {
        let (id, t) = (id.to_string(), t.to_string());
        change(app, u, |c| {
            if let Some(n) = c.doc.node_mut(&id) {
                let k = if n.is_group() { "label" } else { "text" };
                n.set_str(k, &t);
            } else if let Some(e) = c.doc.edge_mut(&id) {
                e.set_label(&t);
            }
            if c.edit == id { c.edit.clear(); }
        });
        // пустая новая карточка — не нужна
        let empty = u.cv.as_ref().is_some_and(|c| c.doc.node(&id).is_some_and(|n| n.kind() == "text" && n.text().trim().is_empty()));
        if empty {
            change(app, u, |c| c.doc.remove(std::slice::from_ref(&id)));
        }
    }));
    g.on_cv_edit_start(|id| with_cv(move |_, u| {
        if let Some(c) = u.cv.as_mut() { c.edit = id.to_string(); }
    }));
    g.on_cv_open(|id| with_cv(move |app, u| {
        let Some(c) = u.cv.as_ref() else { return };
        let Some(n) = c.doc.node(&id) else { return };
        match n.kind() {
            "file" if is_image(n.file()) => { if let Some(p) = file_of(app, n.file()) { let _ = open::that(p); } }
            "file" => {
                let p = n.file().to_string();
                if app.notes.notes.iter().any(|x| x.path == p) { super::wire::open_note_tab(app, u, &p); } else { app.say("Заметки нет в папке"); }
            }
            "link" => { let _ = open::that(n.url()); }
            _ => { let id = id.to_string(); if let Some(c) = u.cv.as_mut() { c.edit = id; } }
        }
    }));
    // провод от сокета `s` ноды `from`, отпущен в точке (x, y): над нодой — соединить, на пустом — новая карточка
    g.on_cv_wire(|from, s, x, y| with_cv(move |app, u| {
        let from = from.to_string();
        change(app, u, |c| {
            let (x, y) = (x as f64, y as f64);
            let target = c.doc.hit(x, y).filter(|n| n.id() != from).map(|n| (n.id().to_string(), cv::nearest_side(n, x, y)));
            match target {
                Some((to, ts)) => { if let Some(e) = c.doc.connect(&from, &to, Some(side(s)), Some(ts)) { c.edge = e; c.sel.clear(); } }
                None => {
                    let ts = match side(s) { Side::Top => Side::Bottom, Side::Bottom => Side::Top, Side::Left => Side::Right, Side::Right => Side::Left };
                    let (w, h) = (260.0, 120.0);
                    let (nx, ny) = match ts { Side::Left => (x, y - h / 2.0), Side::Right => (x - w, y - h / 2.0), Side::Top => (x - w / 2.0, y), Side::Bottom => (x - w / 2.0, y - h) };
                    let id = c.doc.add("text", nx, ny, w, h, "");
                    c.doc.connect(&from, &id, Some(side(s)), Some(ts));
                    c.sel = vec![id.clone()];
                    c.edit = id;
                }
            }
        });
    }));
    g.on_cv_edge_pick(|x, y, tol| {
        let mut hit = false;
        with_cv(move |_, u| {
            let Some(c) = u.cv.as_mut() else { return };
            if let Some(e) = c.doc.edge_at(x as f64, y as f64, tol as f64) {
                c.edge = e;
                c.sel.clear();
            }
        });
        UI.with(|u| hit = u.borrow().cv.as_ref().is_some_and(|c| !c.edge.is_empty()));
        hit
    });
    g.on_cv_note_find(|q| {
        let q = q.to_string();
        model(crate::state::peek(|app| {
            let found: Vec<&crate::notes::Note> = if q.trim().is_empty() { app.notes.notes.iter().collect() } else { app.notes.search(&q) };
            found.into_iter().take(8).map(|n| NoteRow { path: ss(n.path.clone()), title: ss(n.title.clone()), sub: ss(n.path.rsplit_once('/').map(|p| p.0).unwrap_or("").to_string()), cur: false }).collect()
        }).unwrap_or_default())
    });
    g.on_cv_add_file(|p, x, y| with_cv(move |app, u| {
        let p = p.to_string();
        change(app, u, |c| {
            let (w, h) = if is_image(&p) { (320.0, 240.0) } else { (300.0, 200.0) };
            let id = c.doc.add("file", x as f64 - w / 2.0, y as f64 - h / 2.0, w, h, &p);
            c.sel = vec![id];
        });
    }));
    g.on_cv_add_image(|x, y| with_cv(move |app, u| {
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
        change(app, u, |c| {
            let id = c.doc.add("file", x as f64 - 160.0, y as f64 - 120.0, 320.0, 240.0, &rel);
            c.sel = vec![id];
        });
    }));
    g.on_cv_new(|| act(|app, u| new_canvas(app, u, "")));
    g.on_cv_key(|k, x, y| with_cv(move |app, u| key(app, u, &k, x as f64, y as f64)));
}

/// Клавиши и кнопки панели. (x, y) — точка холста под мышью (для вставки).
fn key(app: &mut App, u: &mut Ui, k: &str, x: f64, y: f64) {
    let Some(c) = u.cv.as_mut() else { return };
    match k {
        "undo" | "redo" => {
            let now = c.doc.encode();
            let prev = if k == "undo" { c.hist.undo(now) } else { c.hist.redo(now) };
            if let Some(t) = prev {
                if let Ok(d) = Doc::parse(&t) {
                    c.doc = d;
                    c.sel.retain(|id| c.doc.node(id).is_some());
                    c.edge.clear();
                    save(app, c);
                }
            }
        }
        "all" => { c.sel = c.doc.nodes.iter().map(|n| n.id().to_string()).collect(); c.edge.clear(); }
        "esc" => { c.sel.clear(); c.edge.clear(); c.edit.clear(); }
        "copy" | "cut" => {
            if !c.sel.is_empty() {
                u.cv_clip = c.doc.copy_of(&c.sel);
                if k == "cut" { change(app, u, |c| { let s = std::mem::take(&mut c.sel); c.doc.remove(&s); }); }
            }
        }
        "paste" => {
            let clip = u.cv_clip.clone();
            if !clip.is_empty() { change(app, u, |c| { if let Some(m) = c.doc.paste(&clip, x, y) { c.sel = m; } }); }
        }
        "dup" => change(app, u, |c| { let s = c.sel.clone(); let m = c.doc.duplicate(&s); if !m.is_empty() { c.sel = m; } }),
        "group" => change(app, u, |c| { let s = c.sel.clone(); if let Some(g) = c.doc.group_around(&s, "Группа") { c.sel = vec![g.clone()]; c.edit = g; } }),
        "delete" => change(app, u, |c| {
            let mut s = std::mem::take(&mut c.sel);
            if !c.edge.is_empty() { s.push(std::mem::take(&mut c.edge)); }
            c.doc.remove(&s);
        }),
        "layout" => change(app, u, |c| { c.doc.auto_layout(); c.ver += 1; }),
        _ if k.starts_with("color:") => {
            let col = k.trim_start_matches("color:").to_string();
            change(app, u, |c| {
                let s = c.sel.clone();
                for id in &s { if let Some(n) = c.doc.node_mut(id) { n.set_str("color", &col); } }
                let e = c.edge.clone();
                if let Some(ed) = c.doc.edge_mut(&e) {
                    if col.is_empty() { ed.0.remove("color"); } else { ed.0.insert("color".into(), serde_json::json!(col)); }
                }
            });
        }
        _ => {}
    }
}
