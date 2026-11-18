//! Граф знаний: точки — заметки (и ещё не созданные по ссылкам), связи — [[ссылки]].
//! Раскладка — силовая (отталкивание + пружины), без случайности: при каждом открытии одна и та же.

#[derive(Clone, Debug, PartialEq)]
pub struct GNode {
    pub id: String,
    pub label: String,
    pub missing: bool,
    /// Точка-тег (`#тег`): связана со всеми заметками, где он стоит.
    pub tag: bool,
    /// Вложение (картинка, PDF…) по ссылке `![[файл.png]]`.
    pub file: bool,
    pub degree: usize,
    pub x: f64,
    pub y: f64,
}

/// Собрать граф: `notes` — (id, название, ссылки по названиям). Ссылка без заметки — бледная точка, если `missing`.
/// Ссылка вида `#тег` становится точкой-тегом, ссылка на файл с расширением (`.png`, `.pdf`…) — вложением.
pub fn build(notes: &[(String, String, Vec<String>)], missing: bool) -> (Vec<GNode>, Vec<(usize, usize)>) {
    build_with(notes, missing, Forces::default())
}

/// Силы раскладки — ползунки «Отталкивание», «Длина связей», «Притяжение к центру», каждый 0…1.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Forces {
    pub repel: f64,
    pub dist: f64,
    pub grav: f64,
}

impl Default for Forces {
    fn default() -> Self {
        Forces { repel: 0.25, dist: 0.25, grav: 0.25 }
    }
}

impl Forces {
    /// (длина связи, заряд, тяга к центру) в единицах раскладки; 0,25 у всех — прежние 40, −60, 0,06.
    fn units(&self) -> (f64, f64, f64) {
        let c = |v: f64| v.clamp(0.0, 1.0);
        (15.0 + 100.0 * c(self.dist), -(20.0 + 160.0 * c(self.repel)), 0.02 + 0.16 * c(self.grav))
    }
}

fn is_file(name: &str) -> bool {
    let low = name.to_lowercase();
    match low.rsplit_once('.') {
        Some((a, e)) => !a.is_empty() && !e.is_empty() && e.len() <= 4 && e != "md" && e.chars().all(|c| c.is_ascii_alphanumeric()),
        None => false,
    }
}

pub fn build_with(notes: &[(String, String, Vec<String>)], missing: bool, forces: Forces) -> (Vec<GNode>, Vec<(usize, usize)>) {
    let mut nodes: Vec<GNode> = notes.iter().map(|(id, l, _)| GNode { id: id.clone(), label: l.clone(), missing: false, tag: false, file: false, degree: 0, x: 0.0, y: 0.0 }).collect();
    let mut at: std::collections::HashMap<String, usize> = nodes.iter().enumerate().map(|(i, n)| (n.label.to_lowercase(), i)).collect();
    let mut edges: Vec<(usize, usize)> = vec![];
    let mut seen = std::collections::HashSet::new();
    for (i, (_, _, links)) in notes.iter().enumerate() {
        for l in links {
            let j = match at.get(&l.to_lowercase()) {
                Some(&j) => j,
                None if l.starts_with('#') => {
                    nodes.push(GNode { id: l.to_lowercase(), label: l.clone(), missing: false, tag: true, file: false, degree: 0, x: 0.0, y: 0.0 });
                    at.insert(l.to_lowercase(), nodes.len() - 1);
                    nodes.len() - 1
                }
                None if is_file(l) => {
                    nodes.push(GNode { id: format!("?{l}"), label: l.clone(), missing: false, tag: false, file: true, degree: 0, x: 0.0, y: 0.0 });
                    at.insert(l.to_lowercase(), nodes.len() - 1);
                    nodes.len() - 1
                }
                None if missing => {
                    nodes.push(GNode { id: format!("?{l}"), label: l.clone(), missing: true, tag: false, file: false, degree: 0, x: 0.0, y: 0.0 });
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
    layout_with(&mut nodes, &edges, forces);
    (nodes, edges)
}

/// Радиус точки: растёт с числом связей.
pub fn radius(degree: usize) -> f64 {
    2.6 + (degree as f64).sqrt() * 2.2
}

/// Соседи точки (локальный граф глубины 1).
pub fn neighbors(edges: &[(usize, usize)], i: usize) -> Vec<usize> {
    edges.iter().filter_map(|&(a, b)| if a == i { Some(b) } else if b == i { Some(a) } else { None }).collect()
}

/// Силовая раскладка по алгоритму d3-force (ISC, github.com/d3/d3-force): скоростной Верле с затуханием,
/// связи (сила 1/меньшая степень, смещение по степеням), отталкивание Барнса–Хата (θ = 0,9), тяга к центру
/// по x/y (чтобы одиночки не улетали) и центрирование. Старт — филлотаксис, как у d3. Итог вписан в 0…1000.
pub fn layout(nodes: &mut [GNode], edges: &[(usize, usize)]) {
    layout_with(nodes, edges, Forces::default())
}

/// Точки не дальше `depth` связей от `i` (сама `i` — первой): локальный граф.
pub fn local(n: usize, edges: &[(usize, usize)], i: usize, depth: usize) -> Vec<usize> {
    if i >= n {
        return vec![];
    }
    let mut seen = vec![false; n];
    seen[i] = true;
    let mut out = vec![i];
    let mut front = vec![i];
    for _ in 0..depth {
        let mut next = vec![];
        for &f in &front {
            for j in neighbors(edges, f) {
                if !seen[j] {
                    seen[j] = true;
                    out.push(j);
                    next.push(j);
                }
            }
        }
        front = next;
    }
    out
}

pub fn layout_with(nodes: &mut [GNode], edges: &[(usize, usize)], forces: Forces) {
    if nodes.is_empty() {
        return;
    }
    let mut sim = Sim::new(nodes.len(), edges, forces, &[]);
    while sim.tick() {}
    for (i, p) in nodes.iter_mut().enumerate() {
        p.x = sim.x[i];
        p.y = sim.y[i];
    }
    fit(nodes);
}

/// Живая раскладка графа (как в Obsidian): шаг за шагом, точки разлетаются по местам на глазах;
/// точку можно тянуть — соседи идут следом. Координаты — свои, на лист 0…1000 их переводит `place`.
pub struct Sim {
    pub x: Vec<f64>,
    pub y: Vec<f64>,
    vx: Vec<f64>,
    vy: Vec<f64>,
    lk: Vec<(usize, usize, f64, f64)>,
    dist: f64,
    charge: f64,
    grav: f64,
    /// «Температура»: 1 — всё летит, к 0,001 — замерло.
    pub alpha: f64,
    /// Тянут мышью: точка и куда (в своих координатах).
    pub held: Option<(usize, f64, f64)>,
    /// Перевод в лист 0…1000: центр и масштаб (обновляется, пока точку не тянут).
    pub map: (f64, f64, f64),
    /// За сколько шагов остывает: 300 — для разовой раскладки, живой граф — быстрее.
    pub steps: f64,
    /// Точки без связей: к центру тянутся слабо — ложатся кольцом по краю (как в Obsidian).
    lone: Vec<bool>,
}

impl Sim {
    /// `start` — где точки уже стоят (свои координаты); остальные — по спирали от центра.
    pub fn new(n: usize, edges: &[(usize, usize)], forces: Forces, start: &[Option<(f64, f64)>]) -> Sim {
        let (mut x, mut y) = (vec![0.0f64; n], vec![0.0f64; n]);
        let ang = std::f64::consts::PI * (3.0 - 5f64.sqrt());
        for i in 0..n {
            match start.get(i).copied().flatten() {
                Some((a, b)) => { x[i] = a; y[i] = b; }
                None => {
                    let r = 10.0 * (0.5 + i as f64).sqrt();
                    x[i] = r * (i as f64 * ang).cos();
                    y[i] = r * (i as f64 * ang).sin();
                }
            }
        }
        let mut deg = vec![0usize; n];
        for &(a, b) in edges {
            deg[a] += 1;
            deg[b] += 1;
        }
        let lk = edges.iter().map(|&(a, b)| {
            let st = 1.0 / deg[a].min(deg[b]).max(1) as f64;
            let bias = deg[a] as f64 / (deg[a] + deg[b]) as f64;
            (a, b, st, bias)
        }).collect();
        let (dist, charge, grav) = forces.units();
        let mut s = Sim { x, y, vx: vec![0.0; n], vy: vec![0.0; n], lk, dist, charge, grav, alpha: 1.0, held: None, map: (0.0, 0.0, 1.0), steps: 300.0, lone: deg.iter().map(|&d| d == 0).collect() };
        s.refit();
        s
    }

    /// Один шаг. false — уже замерло (и никто не тянет).
    pub fn tick(&mut self) -> bool {
        let n = self.x.len();
        if n == 0 || (self.alpha <= 0.001 && self.held.is_none()) {
            return false;
        }
        let adecay = 1.0 - 0.001f64.powf(1.0 / self.steps);
        // пока тянут — не остывает ниже 0,3
        let target = if self.held.is_some() { 0.3 } else { 0.0 };
        self.alpha += (target - self.alpha) * adecay;
        let (x, y, vx, vy) = (&mut self.x, &mut self.y, &mut self.vx, &mut self.vy);
        let alpha = self.alpha;
        for &(a, b, st, bias) in &self.lk {
            let mut dx = x[b] + vx[b] - x[a] - vx[a];
            let mut dy = y[b] + vy[b] - y[a] - vy[a];
            if dx == 0.0 && dy == 0.0 {
                dx = 1e-6;
                dy = 1e-6;
            }
            let l = (dx * dx + dy * dy).sqrt();
            let f = (l - self.dist) / l * alpha * st;
            let (fx, fy) = (dx * f, dy * f);
            vx[b] -= fx * bias;
            vy[b] -= fy * bias;
            vx[a] += fx * (1.0 - bias);
            vy[a] += fy * (1.0 - bias);
        }
        let q = Quad::build(x, y);
        for i in 0..n {
            let (fx, fy) = q.force(x[i], y[i], i, self.charge * alpha);
            vx[i] += fx;
            vy[i] += fy;
        }
        for i in 0..n {
            let g = if self.lone[i] { self.grav * 0.35 } else { self.grav };
            vx[i] -= x[i] * g * alpha;
            vy[i] -= y[i] * g * alpha;
            vx[i] *= 0.6;
            vy[i] *= 0.6;
            x[i] += vx[i];
            y[i] += vy[i];
        }
        if let Some((i, hx, hy)) = self.held {
            x[i] = hx;
            y[i] = hy;
            vx[i] = 0.0;
            vy[i] = 0.0;
        } else {
            let (mx, my) = (x.iter().sum::<f64>() / n as f64, y.iter().sum::<f64>() / n as f64);
            for i in 0..n {
                x[i] -= mx;
                y[i] -= my;
            }
        }
        true
    }

    /// Пересчитать перевод на лист так, чтобы всё влезло (как `fit`).
    pub fn refit(&mut self) {
        let n = self.x.len();
        if n == 0 {
            return;
        }
        let (mut x0, mut x1, mut y0, mut y1) = (f64::MAX, f64::MIN, f64::MAX, f64::MIN);
        for i in 0..n {
            x0 = x0.min(self.x[i]);
            x1 = x1.max(self.x[i]);
            y0 = y0.min(self.y[i]);
            y1 = y1.max(self.y[i]);
        }
        let span = (x1 - x0).max(y1 - y0);
        let s = if span < 1.0 { 0.0 } else { (900.0 / span).min(4.0) };
        self.map = ((x0 + x1) / 2.0, (y0 + y1) / 2.0, s);
    }

    /// Поставить точки на лист 0…1000.
    pub fn place(&self, nodes: &mut [GNode]) {
        let (cx, cy, s) = self.map;
        for (i, p) in nodes.iter_mut().enumerate().take(self.x.len()) {
            p.x = 500.0 + (self.x[i] - cx) * s;
            p.y = 500.0 + (self.y[i] - cy) * s;
        }
    }

    /// Место на листе → свои координаты.
    pub fn from_sheet(&self, px: f64, py: f64) -> (f64, f64) {
        let (cx, cy, s) = self.map;
        if s == 0.0 { (cx, cy) } else { (cx + (px - 500.0) / s, cy + (py - 500.0) / s) }
    }

    /// Встряхнуть (после правки связей, при перетаскивании).
    pub fn reheat(&mut self, a: f64) {
        self.alpha = self.alpha.max(a);
    }
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
