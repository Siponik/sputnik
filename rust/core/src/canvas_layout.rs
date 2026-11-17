//! Авто-раскладка холста: слоями слева направо по проводам, группы — блоком.

use crate::canvas::{snap, Doc};

impl Doc {
    /// «Авто-раскладка»: ноды слоями слева направо по направлению проводов; внутри каждой верхней группы —
    /// так же, рамка растягивается под свои ноды, потом группа ставится как одна нода. Стороны проводов — заново.
    pub fn auto_layout(&mut self) {
        let groups: Vec<usize> = (0..self.nodes.len()).filter(|&i| self.nodes[i].is_group()).collect();
        // верхние группы — не лежат в другой группе
        let top: Vec<usize> = groups.iter().copied().filter(|&g| {
            !groups.iter().any(|&o| o != g && self.inside(&self.nodes[o]).iter().any(|id| id == self.nodes[g].id()))
        }).collect();
        let mut owner: Vec<Option<usize>> = vec![None; self.nodes.len()];
        for &g in &top {
            for id in self.inside(&self.nodes[g]) {
                if let Some(i) = self.nodes.iter().position(|n| n.id() == id) {
                    if owner[i].is_none() {
                        owner[i] = Some(g);
                    }
                }
            }
        }
        let idx = |d: &Doc, id: &str| d.nodes.iter().position(|n| n.id() == id);
        let links: Vec<(usize, usize)> = self.edges.iter().filter_map(|e| Some((idx(self, e.from())?, idx(self, e.to())?))).collect();
        // 1) внутри каждой группы — свои ноды слоями
        for &g in &top {
            let mem: Vec<usize> = (0..self.nodes.len()).filter(|&i| owner[i] == Some(g) && !self.nodes[i].is_group()).collect();
            if mem.is_empty() {
                continue;
            }
            let le: Vec<(usize, usize)> = links.iter().filter_map(|&(a, b)| Some((mem.iter().position(|&m| m == a)?, mem.iter().position(|&m| m == b)?))).collect();
            let boxes: Vec<(f64, f64, f64)> = mem.iter().map(|&i| (self.nodes[i].w(), self.nodes[i].h(), self.nodes[i].y())).collect();
            let at = layered(&boxes, &le);
            let (gx, gy) = (self.nodes[g].x(), self.nodes[g].y());
            let (mut r, mut btm) = (gx, gy);
            for (k, &i) in mem.iter().enumerate() {
                let (x, y) = (snap(gx + 40.0 + at[k].0), snap(gy + 60.0 + at[k].1));
                self.nodes[i].set("x", x);
                self.nodes[i].set("y", y);
                r = r.max(x + self.nodes[i].w());
                btm = btm.max(y + self.nodes[i].h());
            }
            // вложенные группы и прочее внутри — оставляем, но рамку растягиваем на ноды
            let (w, h) = (r + 40.0 - gx, btm + 40.0 - gy);
            self.nodes[g].set("width", w);
            self.nodes[g].set("height", h);
        }
        // 2) верхний уровень: группы целиком и свободные ноды
        let items: Vec<usize> = (0..self.nodes.len()).filter(|&i| {
            if self.nodes[i].is_group() { top.contains(&i) } else { owner[i].is_none() }
        }).collect();
        if items.len() < 2 && top.is_empty() {
            return;
        }
        let item_of = |i: usize| -> Option<usize> { items.iter().position(|&t| t == owner[i].unwrap_or(i)) };
        let mut le: Vec<(usize, usize)> = vec![];
        for &(a, b) in &links {
            if let (Some(x), Some(y)) = (item_of(a), item_of(b)) {
                if x != y && !le.contains(&(x, y)) {
                    le.push((x, y));
                }
            }
        }
        let boxes: Vec<(f64, f64, f64)> = items.iter().map(|&i| (self.nodes[i].w(), self.nodes[i].h(), self.nodes[i].y())).collect();
        let at = layered(&boxes, &le);
        let (ox, oy) = items.iter().fold((f64::MAX, f64::MAX), |m, &i| (m.0.min(self.nodes[i].x()), m.1.min(self.nodes[i].y())));
        for (k, &i) in items.iter().enumerate() {
            let (dx, dy) = (snap(ox + at[k].0) - self.nodes[i].x(), snap(oy + at[k].1) - self.nodes[i].y());
            let mut ids = vec![self.nodes[i].id().to_string()];
            if self.nodes[i].is_group() {
                ids.extend(self.inside(&self.nodes[i]));
            }
            self.shift(&ids, dx, dy);
        }
        // стороны проводов — заново по месту
        for e in &mut self.edges {
            e.0.remove("fromSide");
            e.0.remove("toSide");
        }
    }
}

/// Раскладка слоями слева направо: (ширина, высота, старый y) → (x, y) от нуля.
fn layered(b: &[(f64, f64, f64)], e: &[(usize, usize)]) -> Vec<(f64, f64)> {
    let n = b.len();
    let mut layer = vec![0usize; n];
    for _ in 0..n {
        let mut ch = false;
        for &(a, c) in e {
            if a != c && layer[c] < layer[a] + 1 && layer[a] + 1 < n {
                layer[c] = layer[a] + 1;
                ch = true;
            }
        }
        if !ch {
            break;
        }
    }
    let cols = layer.iter().max().map_or(0, |m| m + 1);
    let mut col: Vec<Vec<usize>> = vec![vec![]; cols];
    let mut ord: Vec<usize> = (0..n).collect();
    ord.sort_by(|&x, &y| b[x].2.total_cmp(&b[y].2));
    for i in ord {
        col[layer[i]].push(i);
    }
    // порядок в столбце — по середине соседей слева
    let mut rank = vec![0.0; n];
    for c in &col {
        for (k, &i) in c.iter().enumerate() {
            rank[i] = k as f64;
        }
    }
    for c in col.iter_mut().skip(1) {
        let key: Vec<(usize, f64)> = c.iter().map(|&i| {
            let p: Vec<f64> = e.iter().filter(|x| x.1 == i && layer[x.0] < layer[i]).map(|x| rank[x.0]).collect();
            (i, if p.is_empty() { rank[i] } else { p.iter().sum::<f64>() / p.len() as f64 })
        }).collect();
        c.sort_by(|x, y| key.iter().find(|k| k.0 == *x).unwrap().1.total_cmp(&key.iter().find(|k| k.0 == *y).unwrap().1));
        for (k, &i) in c.iter().enumerate() {
            rank[i] = k as f64;
        }
    }
    let gap = 40.0;
    let hcol: Vec<f64> = col.iter().map(|c| c.iter().map(|&i| b[i].1).sum::<f64>() + gap * c.len().saturating_sub(1) as f64).collect();
    let tall = hcol.iter().cloned().fold(0.0, f64::max);
    let mut out = vec![(0.0, 0.0); n];
    let mut x = 0.0;
    for (ci, c) in col.iter().enumerate() {
        let wmax = c.iter().map(|&i| b[i].0).fold(0.0, f64::max);
        let mut y = (tall - hcol[ci]) / 2.0;
        for &i in c {
            out[i] = (x, y);
            y += b[i].1 + gap;
        }
        x += wmax + 120.0;
    }
    out
}
