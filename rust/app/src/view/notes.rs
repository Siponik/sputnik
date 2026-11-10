//! Модели «Знаний».
use super::*;
use crate::{GDot, GLine, NoteRow};
use sputnik_core::graph as gr;

pub fn render(app: &App, u: &Ui, g: &S) {
    let n0 = &app.notes;
    let list: Vec<NoteRow> = if u.note_q.trim().is_empty() { n0.notes.iter().collect::<Vec<_>>() } else { n0.search(&u.note_q) }
        .iter()
        .map(|x| NoteRow { path: ss(x.path.clone()), title: ss(x.title.clone()), sub: ss(x.path.rsplit_once('/').map(|p| p.0.to_string()).unwrap_or_default()) })
        .collect();
    g.set_notes(model(list));
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
            if !u.note_dirty {
                g.set_note_body(ss(x.body.clone()));
            }
            g.set_note_links(model(x.links.iter().map(|l| {
                let f = n0.find(l);
                NoteRow { path: ss(f.map(|f| f.path.clone()).unwrap_or_default()), title: ss(l.clone()), sub: ss("") }
            }).collect()));
            g.set_note_back(model(n0.backlinks(&x.title).iter().map(|b| NoteRow { path: ss(b.path.clone()), title: ss(b.title.clone()), sub: ss("") }).collect()));
        }
        None => {
            g.set_note_title("".into());
            g.set_note_links(model(vec![]));
            g.set_note_back(model(vec![]));
        }
    }
}
