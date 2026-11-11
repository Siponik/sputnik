//! Модели «Знаний».
use super::*;
use crate::{GDot, GLine, MdRow, NoteRow};
use slint::{Model, VecModel};
use std::cell::RefCell;
use std::rc::Rc;
use sputnik_core::graph as gr;

pub fn render(app: &App, u: &Ui, g: &S) {
    let n0 = &app.notes;
    // список по папкам: строка папки — path пустой, title — папка, sub — число заметок
    let mut found: Vec<&crate::notes::Note> = if u.note_q.trim().is_empty() { n0.notes.iter().collect() } else { n0.search(&u.note_q) };
    found.sort_by(|a, b| (folder(&a.path), a.title.to_lowercase()).cmp(&(folder(&b.path), b.title.to_lowercase())));
    let mut list: Vec<NoteRow> = vec![];
    let mut last: Option<String> = None;
    for x in &found {
        let f = folder(&x.path);
        if last.as_deref() != Some(f.as_str()) {
            let cnt = found.iter().filter(|y| folder(&y.path) == f).count();
            list.push(NoteRow { path: ss(""), title: ss(if f.is_empty() { "КОРЕНЬ".to_string() } else { f.to_uppercase() }), sub: ss(cnt.to_string()), cur: false });
            last = Some(f.clone());
        }
        list.push(NoteRow { path: ss(x.path.clone()), title: ss(x.title.clone()), sub: ss(""), cur: false });
    }
    g.set_notes(model(list));
    g.set_notes_count(n0.notes.len() as i32);
    g.set_note_path(ss(u.note_path.clone()));
    g.set_note_dirty(u.note_dirty);
    g.set_note_graph(u.note_graph);
    // вкладки открытых заметок
    g.set_note_tabs(model(u.note_tabs.iter().map(|p| {
        let title = n0.notes.iter().find(|x| &x.path == p).map(|x| x.title.clone()).unwrap_or_else(|| p.clone());
        NoteRow { path: ss(p.clone()), title: ss(title), sub: ss(""), cur: *p == u.note_path }
    }).collect()));
    if u.note_graph {
        let (ns, es) = &n0.graph;
        let cur = ns.iter().position(|x| x.id == u.note_path);
        let near: Vec<usize> = cur.map(|c| gr::neighbors(es, c)).unwrap_or_default();
        g.set_graph_dots(model(ns.iter().enumerate().map(|(i, x)| GDot {
            x: x.x as f32, y: x.y as f32, r: gr::radius(x.degree) as f32, title: ss(x.label.clone()),
            path: ss(if x.missing { String::new() } else { x.id.clone() }), missing: x.missing,
            near: near.contains(&i), cur: Some(i) == cur,
        }).collect()));
        g.set_graph_lines(model(es.iter().map(|&(a, b)| GLine {
            x1: ns[a].x as f32, y1: ns[a].y as f32, x2: ns[b].x as f32, y2: ns[b].y as f32,
            near: cur.is_some_and(|c| a == c || b == c),
        }).collect()));
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
            let rows: Vec<MdRow> = crate::notes::line_blocks(&text).into_iter().map(|(k, raw, md)| MdRow {
                kind: ss(k),
                raw: ss(raw),
                md: slint::StyledText::from_markdown(&md).unwrap_or_else(|_| slint::StyledText::from_plain_text(&md)),
            }).collect();
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

fn folder(path: &str) -> String {
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
    let t: String = line.replace("[[", "").replace("]]", "").trim().trim_start_matches(['-', '*', ' ']).chars().take(140).collect();
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
