//! Модели «Знаний».
use super::*;
use crate::{MdRow, NoteRow, TreeRow};
use slint::{Model, VecModel};
use std::cell::RefCell;
use std::rc::Rc;

pub fn render(app: &App, u: &Ui, g: &S) {
    let n0 = &app.notes;
    // список по папкам: строка папки — path пустой, title — папка, sub — число заметок
    let mut found: Vec<&crate::notes::Note> = if u.note_q.trim().is_empty() { n0.notes.iter().collect() } else { n0.search(&u.note_q) };
    found.sort_by(|a, b| (folder(&a.path), a.title.to_lowercase()).cmp(&(folder(&b.path), b.title.to_lowercase())));
    // заметки и канвасы вместе, по папкам; у канваса sub = "canvas"
    let q = u.note_q.trim().to_lowercase().replace('ё', "е");
    // порядок внутри папки (G_Notes): «Изменено» — свежие сверху, «А–Я», «Связи» — больше связей сверху
    let deg = |p: &str| n0.graph.0.iter().find(|g| g.id == p).map(|g| g.degree).unwrap_or(0);
    let key = |x: &crate::notes::Note| match u.note_sort {
        1 => x.title.to_lowercase(),
        2 => format!("{:08}{}", 99_999_999 - deg(&x.path).min(99_999_999), x.title.to_lowercase()),
        _ => format!("{:020}{}", i64::MAX - x.mtime, x.title.to_lowercase()),
    };
    let pinned = pins();
    let pk = |p: &str, k: String| if pinned.iter().any(|x| x == p) { format!("!{k}") } else { format!("~{k}") };
    let mut items: Vec<(String, String, String, &str)> = found.iter().map(|x| (folder(&x.path), pk(&x.path, key(x)), x.path.clone(), "")).collect();
    for p in &n0.canvases {
        let t = p.rsplit('/').next().unwrap_or(p).trim_end_matches(".canvas").to_string();
        if q.is_empty() || t.to_lowercase().replace('ё', "е").contains(&q) {
            items.push((folder(p), pk(p, if u.note_sort == 1 { t.to_lowercase() } else { format!("~{}", t.to_lowercase()) }), p.clone(), "canvas"));
        }
    }
    items.sort();
    let title_of = |p: &str| n0.notes.iter().find(|x| x.path == p).map(|x| x.title.clone())
        .unwrap_or_else(|| p.rsplit('/').next().unwrap_or(p).trim_end_matches(".canvas").to_string());
    let mut list: Vec<NoteRow> = vec![];
    let mut last: Option<String> = None;
    for (f, _, p, kind) in &items {
        if last.as_deref() != Some(f.as_str()) {
            let cnt = items.iter().filter(|y| &y.0 == f).count();
            list.push(NoteRow { path: ss(""), title: ss(if f.is_empty() { "КОРЕНЬ".to_string() } else { f.to_uppercase() }), sub: ss(cnt.to_string()), cur: false });
            last = Some(f.clone());
        }
        list.push(NoteRow { path: ss(p.clone()), title: ss(title_of(p)), sub: ss(*kind), cur: false });
    }
    g.set_notes(model(list));
    // дерево папок (G_Notes): папки — сначала, потом заметки; открыты папки текущей заметки и те, что открыли руками
    let mut dirs: Vec<String> = vec![];
    for (f, ..) in &items {
        let mut cur = String::new();
        for part in f.split('/').filter(|x| !x.is_empty()) {
            cur = if cur.is_empty() { part.to_string() } else { format!("{cur}/{part}") };
            if !dirs.contains(&cur) {
                dirs.push(cur.clone());
            }
        }
    }
    dirs.sort_by_key(|d| d.to_lowercase());
    let hues = super::graph::groups(app);
    let searching = !q.is_empty();
    let open = |d: &str| searching || u.note_fold.iter().any(|x| x == d);
    let mut tree: Vec<TreeRow> = vec![];
    fn walk(dir: &str, depth: i32, dirs: &[String], items: &[(String, String, String, &str)], open: &dyn Fn(&str) -> bool,
            title_of: &dyn Fn(&str) -> String, hue: slint::Color, tree: &mut Vec<TreeRow>, pinned: &[String]) {
        for d in dirs.iter().filter(|d| folder(d) == dir && d.as_str() != dir) {
            let o = open(d);
            let n = items.iter().filter(|x| x.0 == *d || x.0.starts_with(&format!("{d}/"))).count();
            tree.push(TreeRow { path: ss(d.clone()), title: ss(d.rsplit('/').next().unwrap_or(d)), kind: ss("dir"), depth, open: o, n: ss(n.to_string()), hue });
            if o {
                walk(d, depth + 1, dirs, items, open, title_of, hue, tree, pinned);
            }
        }
        if depth == 0 && dir.is_empty() {
            return;
        }
        for (_, _, p, kind) in items.iter().filter(|x| x.0 == dir) {
            tree.push(TreeRow { path: ss(p.clone()), title: ss(title_of(p)), kind: ss(if kind.is_empty() { "note" } else { kind }), depth, open: pinned.iter().any(|x| x == p), n: ss(""), hue });
        }
    }
    for d in dirs.iter().filter(|d| !d.contains('/')) {
        let hue = hues.iter().find(|h| h.0 == *d).map(|h| h.1).unwrap_or(slint::Color::from_rgb_u8(0xA3, 0xA5, 0xAE));
        let o = open(d);
        let n = items.iter().filter(|x| x.0 == *d || x.0.starts_with(&format!("{d}/"))).count();
        tree.push(TreeRow { path: ss(d.clone()), title: ss(d.clone()), kind: ss("dir"), depth: 0, open: o, n: ss(n.to_string()), hue });
        if o {
            walk(d, 1, &dirs, &items, &open, &title_of, hue, &mut tree, &pinned);
        }
    }
    let grey = slint::Color::from_rgb_u8(0xA3, 0xA5, 0xAE);
    for (_, _, p, kind) in items.iter().filter(|x| x.0.is_empty()) {
        tree.push(TreeRow { path: ss(p.clone()), title: ss(title_of(p)), kind: ss(if kind.is_empty() { "note" } else { kind }), depth: 0, open: pinned.iter().any(|x| x == p), n: ss(""), hue: grey });
    }
    g.set_note_tree(model(tree));
    // «Недавние» — последние открытые вкладки, свежие сверху
    g.set_note_recent(model(u.note_tabs.iter().rev().take(3).map(|p| TreeRow {
        path: ss(p.clone()), title: ss(title_of(p)), kind: ss(if super::canvas::is_canvas(p) { "canvas" } else { "note" }), depth: 0, open: false, n: ss(""), hue: grey,
    }).collect()));
    g.set_notes_count(n0.notes.len() as i32);
    g.set_note_sort(u.note_sort);
    g.set_note_path(ss(u.note_path.clone()));
    g.set_note_dirty(u.note_dirty);
    g.set_note_graph(u.note_graph);
    // вкладки открытых заметок и канвасов
    g.set_note_tabs(model(u.note_tabs.iter().map(|p| {
        let title = n0.notes.iter().find(|x| &x.path == p).map(|x| x.title.clone())
            .unwrap_or_else(|| p.rsplit('/').next().unwrap_or(p).trim_end_matches(".canvas").trim_end_matches(".md").to_string());
        NoteRow { path: ss(p.clone()), title: ss(title), sub: ss(if super::canvas::is_canvas(p) { "canvas" } else { "" }), cur: *p == u.note_path }
    }).collect()));
    g.set_note_canvas(super::canvas::is_canvas(&u.note_path));
    super::canvas::render(app, u, g);
    if u.note_graph {
        super::graph::render(app, u, g);
    }
    match n0.notes.iter().find(|x| x.path == u.note_path) {
        Some(x) => {
            g.set_note_title(ss(x.title.clone()));
            g.set_note_file(ss(x.path.rsplit('/').next().unwrap_or(&x.path).to_string()));
            let f = folder(&x.path);
            g.set_note_crumb(ss(if f.is_empty() { x.title.clone() } else { format!("{} › {}", f.replace('/', " › "), x.title) }));
            let text = if u.note_dirty { u.note_draft.clone() } else { x.body.clone() };
            if !u.note_dirty {
                g.set_note_body(ss(x.body.clone()));
            }
            g.set_note_words(crate::notes::body_without_front(&text).split_whitespace().count() as i32);
            // плашки под заголовком: тип (первым), остальные свойства, затем #теги
            let mut pills: Vec<NoteRow> = vec![];
            let mut rest: Vec<&(String, String)> = x.props.iter().collect();
            if let Some(i) = rest.iter().position(|(k, _)| k == "type" || k == "тип") {
                let (k, v) = rest.remove(i);
                pills.push(NoteRow { path: ss("type"), title: ss(v.clone()), sub: ss(k.clone()), cur: true });
            }
            for (k, v) in rest {
                if k == "tags" { continue; }
                pills.push(NoteRow { path: ss("prop"), title: ss(format!("{k}: {v}")), sub: ss(""), cur: false });
            }
            for t in &x.tags {
                pills.push(NoteRow { path: ss("tag"), title: ss(format!("#{t}")), sub: ss(""), cur: false });
            }
            g.set_note_props(model(pills));
            // текст режима «Чтение»
            let rows: Vec<MdRow> = crate::notes::line_rows(&text).into_iter().map(|r| MdRow {
                kind: ss(r.kind),
                raw: ss(r.raw),
                md: slint::StyledText::from_markdown(&r.md).unwrap_or_else(|_| slint::StyledText::from_plain_text(&r.md)),
                plain: ss(r.plain),
            }).collect();
            g.set_note_line_links(model(crate::notes::line_rows(&text).iter().map(|r| r.raw.contains("[[") || r.raw.contains("](") || r.raw.contains("://")).collect()));
            sync_lines(g, &u.note_path, rows);
            // упомянуто без ссылки: название встречается в тексте другой заметки, но не как [[ссылка]]
            let low = x.title.to_lowercase();
            g.set_note_mentions(model(if low.chars().count() < 3 { vec![] } else {
                n0.notes.iter().filter(|o| o.path != x.path && !o.links.iter().any(|l| l.to_lowercase() == low)
                    && o.body.to_lowercase().contains(&low)).take(8)
                    .map(|o| NoteRow { path: ss(o.path.clone()), title: ss(o.title.clone()), sub: ss(around(&o.body, &x.title)), cur: false }).collect()
            }));
            g.set_note_links(model(x.links.iter().map(|l| {
                let f = n0.find(l);
                NoteRow { path: ss(f.map(|f| f.path.clone()).unwrap_or_default()), title: ss(l.clone()), sub: ss(""), cur: false }
            }).collect()));
            g.set_note_back(model(n0.backlinks(&x.title).iter().map(|b| NoteRow { path: ss(b.path.clone()), title: ss(b.title.clone()), sub: ss(snippet(&b.body, &x.title)), cur: false }).collect()));
        }
        None => {
            g.set_note_title("".into());
            g.set_note_links(model(vec![]));
            g.set_note_back(model(vec![]));
            g.set_note_props(model(vec![]));
            sync_lines(g, "", vec![]);
            g.set_note_mentions(model(vec![]));
        }
    }
}

thread_local! {
    static PINS: RefCell<Option<Vec<String>>> = const { RefCell::new(None) };
}

/// Закреплённые заметки и холсты (пути) — встают наверх своей папки. Хранятся в папке настроек.
pub fn pins() -> Vec<String> {
    PINS.with(|p| p.borrow_mut().get_or_insert_with(|| {
        crate::data::store::read("note-pins.json").and_then(|v| serde_json::from_value(v).ok()).unwrap_or_default()
    }).clone())
}

pub fn pin_toggle(path: &str) {
    let mut v = pins();
    if let Some(i) = v.iter().position(|x| x == path) { v.remove(i); } else { v.push(path.to_string()); }
    let _ = crate::data::store::write_json("note-pins.json", &serde_json::json!(v));
    PINS.with(|p| *p.borrow_mut() = Some(v));
}

pub fn folder(path: &str) -> String {
    path.rsplit_once('/').map(|p| p.0.to_string()).unwrap_or_default()
}

/// Кусок текста вокруг ссылки на заметку — для карточки «Ссылаются сюда».
pub fn snippet(body: &str, title: &str) -> String {
    let low = body.to_lowercase();
    let key = format!("[[{}", title.to_lowercase());
    let line = match low.find(&key) {
        Some(i) => body[..].lines().find(|l| l.to_lowercase().contains(&key)).unwrap_or(&body[i..]).to_string(),
        None => body.lines().find(|l| !l.trim().is_empty() && !l.starts_with('#')).unwrap_or("").to_string(),
    };
    // как видно в заметке: [[Имя|подпись]] → подпись, без звёздочек
    let line = line.trim().trim_start_matches(['-', '*', ' ']);
    let t: String = sputnik_core::mdline::plain(line).text.chars().take(140).collect();
    t
}

thread_local! {
    /// Строки открытой заметки: одна модель на всё время, меняются только изменённые строки —
    /// иначе строка, которую сейчас правят, пересоздаётся и теряет курсор.
    static LINES: RefCell<(String, Option<Rc<VecModel<MdRow>>>)> = const { RefCell::new((String::new(), None)) };
}

fn sync_lines(g: &S, path: &str, rows: Vec<MdRow>) {
    LINES.with(|c| {
        let mut c = c.borrow_mut();
        let same = |a: &MdRow, b: &MdRow| a.kind == b.kind && a.raw == b.raw;
        match &c.1 {
            Some(m) if c.0 == path => {
                let old: Vec<MdRow> = m.iter().collect();
                let pre = old.iter().zip(&rows).take_while(|(a, b)| same(a, b)).count();
                let max_suf = old.len().min(rows.len()) - pre;
                let suf = old.iter().rev().zip(rows.iter().rev()).take(max_suf).take_while(|(a, b)| same(a, b)).count();
                let (o_end, n_end) = (old.len() - suf, rows.len() - suf);
                let common = (o_end - pre).min(n_end - pre);
                for k in 0..common {
                    m.set_row_data(pre + k, rows[pre + k].clone());
                }
                for _ in pre + common..o_end {
                    m.remove(pre + common);
                }
                for k in pre + common..n_end {
                    m.insert(k, rows[k].clone());
                }
            }
            _ => {
                let m = Rc::new(VecModel::from(rows));
                g.set_note_lines(m.clone().into());
                *c = (path.to_string(), Some(m));
            }
        }
    });
}

fn around(body: &str, word: &str) -> String {
    let lw = word.to_lowercase();
    body.lines().find(|l| l.to_lowercase().contains(&lw)).unwrap_or("").replace("[[", "").replace("]]", "").trim().chars().take(120).collect()
}
