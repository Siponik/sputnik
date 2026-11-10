//! Модели «Знаний».
use super::*;
use crate::{GDot, GLine, NoteRow};
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
            list.push(NoteRow { path: ss(""), title: ss(if f.is_empty() { "КОРЕНЬ".to_string() } else { f.to_uppercase() }), sub: ss(cnt.to_string()) });
            last = Some(f.clone());
        }
        list.push(NoteRow { path: ss(x.path.clone()), title: ss(x.title.clone()), sub: ss("") });
    }
    g.set_notes(model(list));
    g.set_notes_count(n0.notes.len() as i32);
    g.set_note_path(ss(u.note_path.clone()));
    g.set_note_dirty(u.note_dirty);
    g.set_note_graph(u.note_graph);
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
            g.set_note_words(x.body.split_whitespace().count() as i32);
            if !u.note_dirty {
                g.set_note_body(ss(x.body.clone()));
            }
            g.set_note_links(model(x.links.iter().map(|l| {
                let f = n0.find(l);
                NoteRow { path: ss(f.map(|f| f.path.clone()).unwrap_or_default()), title: ss(l.clone()), sub: ss("") }
            }).collect()));
            g.set_note_back(model(n0.backlinks(&x.title).iter().map(|b| NoteRow { path: ss(b.path.clone()), title: ss(b.title.clone()), sub: ss(snippet(&b.body, &x.title)) }).collect()));
        }
        None => {
            g.set_note_title("".into());
            g.set_note_links(model(vec![]));
            g.set_note_back(model(vec![]));
        }
    }
}

fn folder(path: &str) -> String {
    path.rsplit_once('/').map(|p| p.0.to_string()).unwrap_or_default()
}

/// Кусок текста вокруг ссылки на заметку — для карточки «Ссылаются сюда».
fn snippet(body: &str, title: &str) -> String {
    let low = body.to_lowercase();
    let key = format!("[[{}", title.to_lowercase());
    let line = match low.find(&key) {
        Some(i) => body[..].lines().find(|l| l.to_lowercase().contains(&key)).unwrap_or(&body[i..]).to_string(),
        None => body.lines().find(|l| !l.trim().is_empty() && !l.starts_with('#')).unwrap_or("").to_string(),
    };
    let t: String = line.replace("[[", "").replace("]]", "").trim().trim_start_matches(['-', '*', ' ']).chars().take(140).collect();
    t
}
