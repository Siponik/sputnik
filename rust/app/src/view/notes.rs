//! Модели «Знаний».
use super::*;
use crate::NoteRow;

pub fn render(app: &App, u: &Ui, g: &S) {
    let n0 = &app.notes;
    let list: Vec<NoteRow> = if u.note_q.trim().is_empty() { n0.notes.iter().collect::<Vec<_>>() } else { n0.search(&u.note_q) }
        .iter()
        .map(|x| NoteRow { path: ss(x.path.clone()), title: ss(x.title.clone()), sub: ss(x.path.rsplit_once('/').map(|p| p.0.to_string()).unwrap_or_default()) })
        .collect();
    g.set_notes(model(list));
    g.set_note_path(ss(u.note_path.clone()));
    g.set_note_dirty(u.note_dirty);
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
