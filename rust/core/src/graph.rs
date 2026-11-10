//! Граф знаний: точки — заметки (и ещё не созданные по ссылкам), связи — [[ссылки]].
//! Раскладка — силовая (отталкивание + пружины), без случайности: при каждом открытии одна и та же.

#[derive(Clone, Debug, PartialEq)]
pub struct GNode {
    pub id: String,
    pub label: String,
    pub missing: bool,
    pub degree: usize,
    pub x: f64,
    pub y: f64,
}

/// Собрать граф: `notes` — (id, название, ссылки по названиям). Ссылка без заметки — бледная точка, если `missing`.
pub fn build(notes: &[(String, String, Vec<String>)], missing: bool) -> (Vec<GNode>, Vec<(usize, usize)>) {
    let mut nodes: Vec<GNode> = notes.iter().map(|(id, l, _)| GNode { id: id.clone(), label: l.clone(), missing: false, degree: 0, x: 0.0, y: 0.0 }).collect();
    let by_title = |nodes: &Vec<GNode>, t: &str| nodes.iter().position(|n| n.label.to_lowercase() == t.to_lowercase());
    let mut edges: Vec<(usize, usize)> = vec![];
    for (i, (_, _, links)) in notes.iter().enumerate() {
        for l in links {
            let j = match by_title(&nodes, l) {
                Some(j) => j,
                None if missing => {
                    nodes.push(GNode { id: format!("?{l}"), label: l.clone(), missing: true, degree: 0, x: 0.0, y: 0.0 });
                    nodes.len() - 1
                }
                None => continue,
            };
            let e = (i.min(j), i.max(j));
            if i != j && !edges.contains(&e) {
                edges.push(e);
            }
        }
    }
    for &(a, b) in &edges {
        nodes[a].degree += 1;
        nodes[b].degree += 1;
    }
    layout(&mut nodes, &edges);
    (nodes, edges)
}

/// Радиус точки: растёт с числом связей.
pub fn radius(degree: usize) -> f64 {
    3.0 + (degree as f64).sqrt() * 1.6
}

/// Соседи точки (локальный граф глубины 1).
pub fn neighbors(edges: &[(usize, usize)], i: usize) -> Vec<usize> {
    edges.iter().filter_map(|&(a, b)| if a == i { Some(b) } else if b == i { Some(a) } else { None }).collect()
}

/// Силовая раскладка в квадрате 0…1000 (центр 500,500).
pub fn layout(nodes: &mut [GNode], edges: &[(usize, usize)]) {
    let n = nodes.len();
    if n == 0 {
        return;
    }
    // старт — золотая спираль
    for (i, p) in nodes.iter_mut().enumerate() {
        let a = i as f64 * 2.399_963;
        let r = 30.0 * (i as f64 + 0.5).sqrt();
        p.x = a.cos() * r;
        p.y = a.sin() * r;
    }
    let k = 60.0;
    let mut t = 40.0;
    for _ in 0..300 {
        let mut d = vec![(0.0f64, 0.0f64); n];
        for i in 0..n {
            for j in i + 1..n {
                let (dx, dy) = (nodes[i].x - nodes[j].x, nodes[i].y - nodes[j].y);
                let dist2 = (dx * dx + dy * dy).max(1.0);
                let f = k * k / dist2;
                d[i].0 += dx * f;
                d[i].1 += dy * f;
                d[j].0 -= dx * f;
                d[j].1 -= dy * f;
            }
        }
        for &(a, b) in edges {
            let (dx, dy) = (nodes[a].x - nodes[b].x, nodes[a].y - nodes[b].y);
            let dist = (dx * dx + dy * dy).sqrt().max(0.01);
            let f = dist / k;
            d[a].0 -= dx * f;
            d[a].1 -= dy * f;
            d[b].0 += dx * f;
            d[b].1 += dy * f;
        }
        for (i, p) in nodes.iter_mut().enumerate() {
            // тяга к центру, чтобы одиночки не улетали
            d[i].0 -= p.x * 0.15;
            d[i].1 -= p.y * 0.15;
            let len = (d[i].0 * d[i].0 + d[i].1 * d[i].1).sqrt().max(0.01);
            let s = len.min(t) / len;
            p.x += d[i].0 * s;
            p.y += d[i].1 * s;
        }
        t = (t * 0.985).max(1.0);
    }
    // вписать в 0…1000
    let (mut x0, mut x1, mut y0, mut y1) = (f64::MAX, f64::MIN, f64::MAX, f64::MIN);
    for p in nodes.iter() {
        x0 = x0.min(p.x);
        x1 = x1.max(p.x);
        y0 = y0.min(p.y);
        y1 = y1.max(p.y);
    }
    let span = (x1 - x0).max(y1 - y0).max(1.0);
    let s = if n == 1 { 0.0 } else { 900.0 / span };
    let (cx, cy) = ((x0 + x1) / 2.0, (y0 + y1) / 2.0);
    for p in nodes.iter_mut() {
        p.x = 500.0 + (p.x - cx) * s;
        p.y = 500.0 + (p.y - cy) * s;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn n(id: &str, links: &[&str]) -> (String, String, Vec<String>) {
        (format!("{id}.md"), id.into(), links.iter().map(|x| x.to_string()).collect())
    }
    #[test]
    fn builds_and_lays_out() {
        let notes = vec![n("А", &["Б", "Нет"]), n("Б", &["а"]), n("В", &[])];
        let (ns, es) = build(&notes, false);
        assert_eq!(ns.len(), 3);
        assert_eq!(es, vec![(0, 1)]);
        assert_eq!(ns[0].degree, 1);
        let (ns2, es2) = build(&notes, true);
        assert_eq!(ns2.len(), 4);
        assert!(ns2[3].missing);
        assert_eq!(es2.len(), 2);
        // устойчиво и в пределах
        assert_eq!(build(&notes, false).0, ns);
        for p in &ns {
            assert!((0.0..=1000.0).contains(&p.x) && (0.0..=1000.0).contains(&p.y));
        }
        // связанные ближе, чем одиночка
        let d = |a: &GNode, b: &GNode| ((a.x - b.x).powi(2) + (a.y - b.y).powi(2)).sqrt();
        assert!(d(&ns[0], &ns[1]) < d(&ns[0], &ns[2]));
        assert_eq!(neighbors(&es, 1), vec![0]);
    }
}
