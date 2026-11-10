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
    let mut at: std::collections::HashMap<String, usize> = nodes.iter().enumerate().map(|(i, n)| (n.label.to_lowercase(), i)).collect();
    let mut edges: Vec<(usize, usize)> = vec![];
    let mut seen = std::collections::HashSet::new();
    for (i, (_, _, links)) in notes.iter().enumerate() {
        for l in links {
            let j = match at.get(&l.to_lowercase()) {
                Some(&j) => j,
                None if missing => {
                    nodes.push(GNode { id: format!("?{l}"), label: l.clone(), missing: true, degree: 0, x: 0.0, y: 0.0 });
                    at.insert(l.to_lowercase(), nodes.len() - 1);
                    nodes.len() - 1
                }
                None => continue,
            };
            let e = (i.min(j), i.max(j));
            if i != j && seen.insert(e) {
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

/// Силовая раскладка по алгоритму d3-force (ISC, github.com/d3/d3-force): скоростной Верле с затуханием,
/// связи (сила 1/меньшая степень, смещение по степеням), отталкивание Барнса–Хата (θ = 0,9), тяга к центру
/// по x/y (чтобы одиночки не улетали) и центрирование. Старт — филлотаксис, как у d3. Итог вписан в 0…1000.
pub fn layout(nodes: &mut [GNode], edges: &[(usize, usize)]) {
    let n = nodes.len();
    if n == 0 {
        return;
    }
    let (mut x, mut y) = (vec![0.0f64; n], vec![0.0f64; n]);
    let (mut vx, mut vy) = (vec![0.0f64; n], vec![0.0f64; n]);
    let ang = std::f64::consts::PI * (3.0 - 5f64.sqrt());
    for i in 0..n {
        let r = 10.0 * (0.5 + i as f64).sqrt();
        x[i] = r * (i as f64 * ang).cos();
        y[i] = r * (i as f64 * ang).sin();
    }
    let mut deg = vec![0usize; n];
    for &(a, b) in edges {
        deg[a] += 1;
        deg[b] += 1;
    }
    let lk: Vec<(usize, usize, f64, f64)> = edges.iter().map(|&(a, b)| {
        let st = 1.0 / deg[a].min(deg[b]).max(1) as f64;
        let bias = deg[a] as f64 / (deg[a] + deg[b]) as f64;
        (a, b, st, bias)
    }).collect();
    let (dist, charge, grav, vdecay) = (40.0, -60.0, 0.06, 0.6);
    let mut alpha = 1.0f64;
    let adecay = 1.0 - 0.001f64.powf(1.0 / 300.0);
    while alpha > 0.001 {
        alpha += (0.0 - alpha) * adecay;
        // связи
        for &(a, b, st, bias) in &lk {
            let mut dx = x[b] + vx[b] - x[a] - vx[a];
            let mut dy = y[b] + vy[b] - y[a] - vy[a];
            if dx == 0.0 && dy == 0.0 {
                dx = 1e-6;
                dy = 1e-6;
            }
            let l = (dx * dx + dy * dy).sqrt();
            let f = (l - dist) / l * alpha * st;
            let (fx, fy) = (dx * f, dy * f);
            vx[b] -= fx * bias;
            vy[b] -= fy * bias;
            vx[a] += fx * (1.0 - bias);
            vy[a] += fy * (1.0 - bias);
        }
        // отталкивание (Барнс–Хат)
        let q = Quad::build(&x, &y);
        for i in 0..n {
            let (fx, fy) = q.force(x[i], y[i], i, charge * alpha);
            vx[i] += fx;
            vy[i] += fy;
        }
        for i in 0..n {
            vx[i] -= x[i] * grav * alpha;
            vy[i] -= y[i] * grav * alpha;
            vx[i] *= vdecay;
            vy[i] *= vdecay;
            x[i] += vx[i];
            y[i] += vy[i];
        }
        let (mx, my) = (x.iter().sum::<f64>() / n as f64, y.iter().sum::<f64>() / n as f64);
        for i in 0..n {
            x[i] -= mx;
            y[i] -= my;
        }
    }
    for (i, p) in nodes.iter_mut().enumerate() {
        p.x = x[i];
        p.y = y[i];
    }
    fit(nodes);
}

fn fit(nodes: &mut [GNode]) {
    let (mut x0, mut x1, mut y0, mut y1) = (f64::MAX, f64::MIN, f64::MAX, f64::MIN);
    for p in nodes.iter() {
        x0 = x0.min(p.x);
        x1 = x1.max(p.x);
        y0 = y0.min(p.y);
        y1 = y1.max(p.y);
    }
    let span = (x1 - x0).max(y1 - y0);
    // мало точек — не растягиваем на весь лист
    let s = if span < 1.0 { 0.0 } else { (900.0 / span).min(4.0) };
    let (cx, cy) = ((x0 + x1) / 2.0, (y0 + y1) / 2.0);
    for p in nodes.iter_mut() {
        p.x = 500.0 + (p.x - cx) * s;
        p.y = 500.0 + (p.y - cy) * s;
    }
}

/// Дерево квадрантов для отталкивания: дальние группы точек считаются одной точкой в их центре масс.
struct Quad {
    cells: Vec<Cell>,
}
struct Cell {
    x0: f64,
    y0: f64,
    size: f64,
    mass: f64,
    cx: f64,
    cy: f64,
    kids: [usize; 4],
    point: Option<usize>,
    px: f64,
    py: f64,
}

impl Quad {
    fn build(x: &[f64], y: &[f64]) -> Quad {
        let (mut x0, mut x1, mut y0, mut y1) = (f64::MAX, f64::MIN, f64::MAX, f64::MIN);
        for i in 0..x.len() {
            x0 = x0.min(x[i]);
            x1 = x1.max(x[i]);
            y0 = y0.min(y[i]);
            y1 = y1.max(y[i]);
        }
        let size = (x1 - x0).max(y1 - y0).max(1.0) + 1.0;
        let mut q = Quad { cells: vec![Cell::new(x0, y0, size)] };
        for i in 0..x.len() {
            q.insert(0, i, x[i], y[i], 0);
        }
        q
    }
    fn insert(&mut self, c: usize, i: usize, px: f64, py: f64, depth: usize) {
        {
            let cl = &mut self.cells[c];
            cl.cx = (cl.cx * cl.mass + px) / (cl.mass + 1.0);
            cl.cy = (cl.cy * cl.mass + py) / (cl.mass + 1.0);
            cl.mass += 1.0;
            if cl.mass == 1.0 {
                cl.point = Some(i);
                cl.px = px;
                cl.py = py;
                return;
            }
        }
        if depth > 40 {
            return; // совпадающие точки: дальше не делим
        }
        if let Some(j) = self.cells[c].point.take() {
            let (jx, jy) = (self.cells[c].px, self.cells[c].py);
            self.push_down(c, j, jx, jy, depth);
        }
        self.push_down(c, i, px, py, depth);
    }
    fn push_down(&mut self, c: usize, i: usize, px: f64, py: f64, depth: usize) {
        let (x0, y0, h) = (self.cells[c].x0, self.cells[c].y0, self.cells[c].size / 2.0);
        let k = (px >= x0 + h) as usize + 2 * (py >= y0 + h) as usize;
        if self.cells[c].kids[k] == 0 {
            self.cells.push(Cell::new(x0 + h * (k & 1) as f64, y0 + h * (k >> 1) as f64, h));
            let id = self.cells.len() - 1;
            self.cells[c].kids[k] = id;
        }
        let kid = self.cells[c].kids[k];
        self.insert(kid, i, px, py, depth + 1);
    }
    fn force(&self, px: f64, py: f64, me: usize, k: f64) -> (f64, f64) {
        let (mut fx, mut fy) = (0.0, 0.0);
        let mut stack = vec![0usize];
        while let Some(c) = stack.pop() {
            let cl = &self.cells[c];
            if cl.mass == 0.0 || cl.point == Some(me) && cl.mass == 1.0 {
                continue;
            }
            let (dx, dy) = (cl.cx - px, cl.cy - py);
            let l2 = (dx * dx + dy * dy).max(1.0);
            let leaf = cl.kids.iter().all(|&x| x == 0);
            if leaf || cl.size * cl.size / l2 < 0.81 {
                let w = if leaf && cl.point.is_none() { cl.mass - 1.0 } else { cl.mass };
                fx += dx * k * w / l2;
                fy += dy * k * w / l2;
            } else {
                stack.extend(cl.kids.iter().filter(|&&x| x != 0));
            }
        }
        (fx, fy)
    }
}

impl Cell {
    fn new(x0: f64, y0: f64, size: f64) -> Cell {
        Cell { x0, y0, size, mass: 0.0, cx: 0.0, cy: 0.0, kids: [0; 4], point: None, px: 0.0, py: 0.0 }
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

    #[test]
    fn big_graph_is_fast() {
        let notes: Vec<_> = (0..2000).map(|i| (format!("{i}.md"), format!("n{i}"), vec![format!("n{}", i / 3), format!("n{}", (i * 7) % 2000)])).collect();
        let t = std::time::Instant::now();
        let (ns, _) = build(&notes, false);
        assert!(t.elapsed().as_millis() < 10_000, "{:?}", t.elapsed()); // в отладке; в выпуске ~0,5 с
        assert!(ns.iter().all(|p| p.x.is_finite() && (0.0..=1000.0).contains(&p.x)));
    }
}
