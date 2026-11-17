//! Граф знаний (G_NotesGraph): нода «Фильтры» слева, граф в середине, панель «Читаю» справа.
use super::*;
use crate::{GDot, GLine, Opt};
use sputnik_core::graph as gr;

/// Цвета групп-папок: «Входящие» — серые, остальные по кругу (тона сфер).
const HUES: [u32; 7] = [0xF0A04B, 0xB48CF0, 0x6FA2F2, 0x7FD18C, 0xE8C65A, 0xF0785F, 0x5FB3C4];

/// Группа точки — первая папка пути; у тегов, вложений и несозданных — своя.
fn group(path: &str) -> String {
    match path.split_once('/') {
        Some((f, _)) => f.to_string(),
        None => "Без папки".into(),
    }
}

/// Папки по алфавиту с цветом и числом заметок.
pub fn groups(app: &App) -> Vec<(String, Color, usize)> {
    let mut fs: Vec<String> = app.notes.notes.iter().map(|n| group(&n.path)).collect();
    fs.sort();
    fs.dedup();
    let mut k = 0;
    fs.into_iter().map(|f| {
        let n = app.notes.notes.iter().filter(|x| group(&x.path) == f).count();
        let low = f.to_lowercase();
        let c = if low.contains("входящ") || f == "Без папки" { hex(0xA3A5AE) } else { k += 1; hex(HUES[(k - 1) % HUES.len()]) };
        (f, c, n)
    }).collect()
}

fn when(ms: i64) -> String {
    use chrono::TimeZone;
    if ms <= 0 {
        return String::new();
    }
    let Some(d) = chrono::Local.timestamp_millis_opt(ms).single() else { return String::new() };
    let today = chrono::Local::now().date_naive();
    if d.date_naive() == today { format!("изменено {}", d.format("%H:%M")) } else { format!("изменено {}", d.format("%d.%m")) }
}

pub fn render(app: &App, u: &Ui, g: &S) {
    let (ns, es) = &app.notes.graph;
    let gs = groups(app);
    let hue_of = |path: &str| gs.iter().find(|x| x.0 == group(path)).map(|x| x.1).unwrap_or(hex(0x8A8C96));
    let o = app.notes.graph_opts;
    g.set_graph_groups(model(gs.iter().map(|(f, c, n)| Opt { id: ss(f.clone()), label: ss(f.clone()), hint: ss(n.to_string()), hue: *c, on: !u.graph_hide.contains(f) }).collect()));
    g.set_graph_show(model(vec![o.tags, o.files, !u.graph_no_lonely, o.missing]));
    g.set_graph_forces(model(vec![o.forces.repel as f32, o.forces.dist as f32, o.forces.grav as f32]));
    g.set_graph_local(u.graph_local);
    g.set_graph_q(ss(u.graph_q.clone()));

    // выбранная точка: явно выбранная на графе, иначе открытая заметка
    let sel_id = if u.graph_sel.is_empty() { u.note_path.clone() } else { u.graph_sel.clone() };
    let cur = ns.iter().position(|x| x.id == sel_id);
    let near: Vec<usize> = cur.map(|c| gr::neighbors(es, c)).unwrap_or_default();
    // что видно: группы, «без связей», локальный граф
    let mut vis: Vec<bool> = ns.iter().map(|x| {
        let note = !x.missing && !x.tag && !x.file;
        !(note && u.graph_hide.contains(&group(&x.id))) && !(u.graph_no_lonely && x.degree == 0)
    }).collect();
    if u.graph_local {
        if let Some(c) = cur {
            let keep = gr::local(ns.len(), es, c, 2);
            for (i, v) in vis.iter_mut().enumerate() {
                *v = *v && keep.contains(&i);
            }
        }
    }
    // видимое вписываем в лист 1000×1000 заново (локальный граф — крупно)
    let (mut x0, mut x1, mut y0, mut y1) = (f64::MAX, f64::MIN, f64::MAX, f64::MIN);
    for (i, p) in ns.iter().enumerate().filter(|(i, _)| vis[*i]) {
        let _ = i;
        x0 = x0.min(p.x);
        x1 = x1.max(p.x);
        y0 = y0.min(p.y);
        y1 = y1.max(p.y);
    }
    let span = (x1 - x0).max(y1 - y0);
    let (sc, cx, cy) = if u.graph_local && span > 1.0 { (800.0 / span, (x0 + x1) / 2.0, (y0 + y1) / 2.0) } else { (1.0, 500.0, 500.0) };
    let px = |p: &gr::GNode| (500.0 + (p.x - cx) * sc, 500.0 + (p.y - cy) * sc);
    let q = u.graph_q.trim().to_lowercase().replace('ё', "е");
    let hit = |i: usize| q.is_empty() || ns[i].label.to_lowercase().replace('ё', "е").contains(&q);
    // подписи: самые связанные, выбранная и соседи
    let mut by_deg: Vec<usize> = (0..ns.len()).filter(|&i| vis[i] && !ns[i].tag && !ns[i].file).collect();
    by_deg.sort_by(|a, b| ns[*b].degree.cmp(&ns[*a].degree));
    let named: Vec<usize> = by_deg.into_iter().take(7).filter(|&i| ns[i].degree >= 3).collect();
    let mut dots = vec![];
    let mut nd = 0;
    for (i, p) in ns.iter().enumerate() {
        if !vis[i] {
            continue;
        }
        if !p.missing && !p.tag && !p.file {
            nd += 1;
        }
        let (x, y) = px(p);
        let on = Some(i) == cur || near.contains(&i);
        let hue = if p.tag || p.file { hex(0x8A8C96) } else if p.missing { hex(0x62646E) } else { hue_of(&p.id) };
        dots.push(GDot {
            x: x as f32, y: y as f32, r: (gr::radius(p.degree) * if u.graph_local { 1.3 } else { 1.0 }) as f32, title: ss(p.label.clone()),
            path: ss(if p.missing || p.tag || p.file { String::new() } else { p.id.clone() }), missing: p.missing,
            near: near.contains(&i), cur: Some(i) == cur, hue,
            dim: (cur.is_some() && !on) || !hit(i), label: named.contains(&i) || on || (!q.is_empty() && hit(i)) || u.graph_local, id: ss(p.id.clone()),
        });
    }
    let mut lines = vec![];
    for &(a, b) in es.iter() {
        if !vis[a] || !vis[b] {
            continue;
        }
        let ((xa, ya), (xb, yb)) = (px(&ns[a]), px(&ns[b]));
        lines.push(GLine { x1: xa as f32, y1: ya as f32, x2: xb as f32, y2: yb as f32, near: cur.is_some_and(|c| a == c || b == c) });
    }
    g.set_graph_info(ss(format!("{} · {}", super::spheres::plural(nd, "ЗАМЕТКА", "ЗАМЕТКИ", "ЗАМЕТОК"), super::spheres::plural(lines.len(), "СВЯЗЬ", "СВЯЗИ", "СВЯЗЕЙ"))));
    g.set_graph_dots(model(dots));
    g.set_graph_lines(model(lines));


    // панель «Читаю»
    let note = cur.and_then(|c| app.notes.notes.iter().find(|n| n.path == ns[c].id));
    g.set_graph_sel(ss(note.map(|n| n.path.clone()).unwrap_or_default()));
    let Some(n) = note else {
        g.set_graph_sel_title(ss(cur.map(|c| ns[c].label.clone()).unwrap_or_default()));
        g.set_graph_sel_lines(model(vec![]));
        g.set_graph_sel_near(model(vec![]));
        return;
    };
    let c = cur.unwrap();
    g.set_graph_sel_title(ss(n.title.clone()));
    g.set_graph_sel_head(ss(n.title.to_uppercase()));
    g.set_graph_sel_hue(hue_of(&n.path));
    let f = super::notes::folder(&n.path);
    let crumb = if f.is_empty() { String::new() } else { f.replace('/', " › ") };
    g.set_graph_sel_crumb(ss([crumb, when(n.mtime)].into_iter().filter(|x| !x.is_empty()).collect::<Vec<_>>().join(" · ")));
    g.set_graph_sel_tags(model(n.tags.iter().take(4).map(|t| ss(format!("#{t}"))).collect()));
    let body = crate::notes::body_without_front(&n.body);
    let rows: Vec<&str> = body.lines().map(|l| l.trim()).filter(|l| !l.is_empty() && l.trim_start_matches('#').trim() != n.title).collect();
    let mut shown: Vec<slint::SharedString> = vec![];
    let mut used = 0;
    for l in rows.iter() {
        if shown.len() >= 5 {
            break;
        }
        used += 1;
        let t = sputnik_core::mdline::plain(l.trim_start_matches('#').trim()).text;
        if !t.trim().is_empty() {
            shown.push(ss(t.chars().take(160).collect::<String>()));
        }
    }
    let heads = rows[used.min(rows.len())..].iter().filter(|l| l.starts_with('#')).count();
    let rest = rows.len().saturating_sub(used);
    g.set_graph_sel_more(ss(if heads > 0 { format!("…ещё {}", super::spheres::plural(heads, "раздел", "раздела", "разделов")) } else if rest > 0 { format!("…ещё {}", super::spheres::plural(rest, "строка", "строки", "строк")) } else { String::new() }));
    g.set_graph_sel_lines(model(shown));
    let all: Vec<usize> = near.iter().copied().filter(|&j| !ns[j].tag && !ns[j].file).collect();
    g.set_graph_sel_n(gr::neighbors(es, c).len() as i32);
    g.set_graph_sel_near(model(all.iter().take(5).map(|&j| Opt { id: ss(ns[j].id.clone()), label: ss(ns[j].label.clone()), hint: ss(""), hue: if ns[j].missing { hex(0x62646E) } else { hue_of(&ns[j].id) }, on: !ns[j].missing }).collect()));
    g.set_graph_sel_rest(all.len().saturating_sub(5) as i32);
}

