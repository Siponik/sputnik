//! Канвас (холст) `.canvas` в открытом формате JSON Canvas 1.0 (jsoncanvas.org, MIT) — тот же файл открывает Obsidian.
//! Ноды text / file / link / group, провода между сторонами нод, с подписями. Неизвестные поля (свои у Obsidian
//! и плагинов) сохраняются как были — файл не портится. Образец — `app/lib/core/notes/canvas.dart`.
use serde_json::{json, Map, Value};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Side {
    Top,
    Right,
    Bottom,
    Left,
}

impl Side {
    pub fn parse(s: &str) -> Option<Side> {
        match s {
            "top" => Some(Side::Top),
            "right" => Some(Side::Right),
            "bottom" => Some(Side::Bottom),
            "left" => Some(Side::Left),
            _ => None,
        }
    }
    pub fn name(self) -> &'static str {
        match self {
            Side::Top => "top",
            Side::Right => "right",
            Side::Bottom => "bottom",
            Side::Left => "left",
        }
    }
    /// Куда смотрит сторона (единичный вектор).
    pub fn dir(self) -> (f64, f64) {
        match self {
            Side::Top => (0.0, -1.0),
            Side::Right => (1.0, 0.0),
            Side::Bottom => (0.0, 1.0),
            Side::Left => (-1.0, 0.0),
        }
    }
}

/// Нода: всё из файла как есть, плюс удобный доступ.
#[derive(Clone, Debug, PartialEq)]
pub struct Node(pub Map<String, Value>);

fn num(m: &Map<String, Value>, k: &str, d: f64) -> f64 {
    m.get(k).and_then(Value::as_f64).unwrap_or(d)
}
fn st<'a>(m: &'a Map<String, Value>, k: &str) -> &'a str {
    m.get(k).and_then(Value::as_str).unwrap_or("")
}

impl Node {
    pub fn id(&self) -> &str {
        st(&self.0, "id")
    }
    pub fn kind(&self) -> &str {
        self.0.get("type").and_then(Value::as_str).unwrap_or("text")
    }
    pub fn x(&self) -> f64 {
        num(&self.0, "x", 0.0)
    }
    pub fn y(&self) -> f64 {
        num(&self.0, "y", 0.0)
    }
    pub fn w(&self) -> f64 {
        num(&self.0, "width", 250.0)
    }
    pub fn h(&self) -> f64 {
        num(&self.0, "height", 60.0)
    }
    pub fn set(&mut self, k: &str, v: f64) {
        self.0.insert(k.into(), json!(v.round() as i64));
    }
    pub fn set_rect(&mut self, x: f64, y: f64, w: f64, h: f64) {
        self.set("x", x);
        self.set("y", y);
        self.set("width", w.max(40.0));
        self.set("height", h.max(30.0));
    }
    /// Текст карточки (type = text).
    pub fn text(&self) -> &str {
        st(&self.0, "text")
    }
    /// Путь файла от корня папки заметок (type = file).
    pub fn file(&self) -> &str {
        st(&self.0, "file")
    }
    pub fn url(&self) -> &str {
        st(&self.0, "url")
    }
    /// Подпись группы.
    pub fn label(&self) -> &str {
        st(&self.0, "label")
    }
    /// Цвет: `"1"`…`"6"` (красный, оранжевый, жёлтый, зелёный, голубой, фиолетовый) или `#RRGGBB`; "" — без цвета.
    pub fn color(&self) -> &str {
        st(&self.0, "color")
    }
    pub fn set_str(&mut self, k: &str, v: &str) {
        if v.is_empty() && (k == "color" || k == "label") {
            self.0.remove(k);
        } else {
            self.0.insert(k.into(), json!(v));
        }
    }
    pub fn is_group(&self) -> bool {
        self.kind() == "group"
    }
    pub fn contains(&self, px: f64, py: f64) -> bool {
        px >= self.x() && px <= self.x() + self.w() && py >= self.y() && py <= self.y() + self.h()
    }
    /// Точка на середине стороны.
    pub fn socket(&self, s: Side) -> (f64, f64) {
        let (cx, cy) = (self.x() + self.w() / 2.0, self.y() + self.h() / 2.0);
        match s {
            Side::Top => (cx, self.y()),
            Side::Right => (self.x() + self.w(), cy),
            Side::Bottom => (cx, self.y() + self.h()),
            Side::Left => (self.x(), cy),
        }
    }
    /// Название на экране: имя файла без папки и `.md`, адрес, подпись группы или первая строка текста.
    pub fn title(&self) -> String {
        match self.kind() {
            "file" => {
                let f = self.file();
                let name = f.rsplit('/').next().unwrap_or(f);
                name.strip_suffix(".md").unwrap_or(name).to_string()
            }
            "link" => self.url().to_string(),
            "group" => self.label().to_string(),
            _ => self.text().lines().find(|l| !l.trim().is_empty()).unwrap_or("").trim().trim_start_matches('#').trim().to_string(),
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Edge(pub Map<String, Value>);

impl Edge {
    pub fn id(&self) -> &str {
        st(&self.0, "id")
    }
    pub fn from(&self) -> &str {
        st(&self.0, "fromNode")
    }
    pub fn to(&self) -> &str {
        st(&self.0, "toNode")
    }
    pub fn from_side(&self) -> Option<Side> {
        Side::parse(st(&self.0, "fromSide"))
    }
    pub fn to_side(&self) -> Option<Side> {
        Side::parse(st(&self.0, "toSide"))
    }
    pub fn label(&self) -> &str {
        st(&self.0, "label")
    }
    pub fn set_label(&mut self, v: &str) {
        if v.trim().is_empty() {
            self.0.remove("label");
        } else {
            self.0.insert("label".into(), json!(v));
        }
    }
    pub fn color(&self) -> &str {
        st(&self.0, "color")
    }
    /// Стрелка на конце: по умолчанию у `to` есть, у `from` нет.
    pub fn arrow_to(&self) -> bool {
        self.0.get("toEnd").and_then(Value::as_str).unwrap_or("arrow") == "arrow"
    }
    pub fn arrow_from(&self) -> bool {
        self.0.get("fromEnd").and_then(Value::as_str).unwrap_or("none") == "arrow"
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Doc {
    pub nodes: Vec<Node>,
    pub edges: Vec<Edge>,
    /// Прочие поля верхнего уровня.
    pub extra: Map<String, Value>,
    seed: u64,
}

impl Doc {
    /// Разобрать файл. Пустой — пустой холст; не JSON-объект — ошибка (такой файл не перезаписываем).
    /// Битые записи (без id, провод без концов) пропускаются.
    pub fn parse(text: &str) -> Result<Doc, String> {
        if text.trim().is_empty() {
            return Ok(Doc::default());
        }
        let v: Value = serde_json::from_str(text).map_err(|e| format!("Холст не читается: {e}"))?;
        let Value::Object(mut m) = v else { return Err("Холст — не объект JSON".into()) };
        let nodes = match m.remove("nodes") {
            Some(Value::Array(a)) => a.into_iter().filter_map(|n| match n {
                Value::Object(o) if o.get("id").is_some_and(Value::is_string) => Some(Node(o)),
                _ => None,
            }).collect(),
            _ => vec![],
        };
        let edges = match m.remove("edges") {
            Some(Value::Array(a)) => a.into_iter().filter_map(|e| match e {
                Value::Object(o) if ["id", "fromNode", "toNode"].iter().all(|k| o.get(*k).is_some_and(Value::is_string)) => Some(Edge(o)),
                _ => None,
            }).collect(),
            _ => vec![],
        };
        Ok(Doc { nodes, edges, extra: m, seed: text.len() as u64 })
    }

    /// В файл — с отступами табуляцией, как пишет Obsidian.
    pub fn encode(&self) -> String {
        let mut m = Map::new();
        m.insert("nodes".into(), Value::Array(self.nodes.iter().map(|n| Value::Object(n.0.clone())).collect()));
        m.insert("edges".into(), Value::Array(self.edges.iter().map(|e| Value::Object(e.0.clone())).collect()));
        for (k, v) in &self.extra {
            m.insert(k.clone(), v.clone());
        }
        // отступы — табуляцией (в строках JSON переводов строк нет, они экранированы)
        let pretty = serde_json::to_string_pretty(&Value::Object(m)).unwrap_or_default();
        pretty.lines().map(|l| {
            let sp = l.len() - l.trim_start_matches(' ').len();
            format!("{}{}", "\t".repeat(sp / 2), &l[sp..])
        }).collect::<Vec<_>>().join("\n")
    }

    pub fn node(&self, id: &str) -> Option<&Node> {
        self.nodes.iter().find(|n| n.id() == id)
    }
    pub fn node_mut(&mut self, id: &str) -> Option<&mut Node> {
        self.nodes.iter_mut().find(|n| n.id() == id)
    }
    pub fn edge_mut(&mut self, id: &str) -> Option<&mut Edge> {
        self.edges.iter_mut().find(|e| e.id() == id)
    }

    /// Новый id: 16 шестнадцатеричных знаков, как у Obsidian, не занятый.
    pub fn new_id(&mut self) -> String {
        loop {
            // xorshift от времени и счётчика — без лишних библиотек
            if self.seed == 0 {
                self.seed = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_or(1, |d| d.as_nanos() as u64) | 1;
            }
            let mut x = self.seed;
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            self.seed = x;
            let id = format!("{x:016x}");
            if !self.nodes.iter().any(|n| n.id() == id) && !self.edges.iter().any(|e| e.id() == id) {
                return id;
            }
        }
    }

    /// Новая нода. `kind` — text / file / link / group; `val` — текст, путь файла, адрес или подпись группы.
    /// Группы — в начале списка (рисуются под остальными).
    pub fn add(&mut self, kind: &str, x: f64, y: f64, w: f64, h: f64, val: &str) -> String {
        let id = self.new_id();
        let mut m = Map::new();
        m.insert("id".into(), json!(id));
        m.insert("type".into(), json!(kind));
        let key = match kind {
            "file" => "file",
            "link" => "url",
            "group" => "label",
            _ => "text",
        };
        m.insert(key.into(), json!(val));
        let mut n = Node(m);
        n.set_rect(snap(x), snap(y), w, h);
        if kind == "group" {
            self.nodes.insert(0, n);
        } else {
            self.nodes.push(n);
        }
        id
    }

    /// Убрать ноды вместе с их проводами.
    pub fn remove(&mut self, ids: &[String]) {
        self.nodes.retain(|n| !ids.iter().any(|i| i == n.id()));
        self.edges.retain(|e| !ids.iter().any(|i| i == e.from() || i == e.to() || i == e.id()));
    }

    /// Провод `from` → `to`. Такой уже есть или это одна нода — None.
    pub fn connect(&mut self, from: &str, to: &str, fs: Option<Side>, ts: Option<Side>) -> Option<String> {
        if from == to || self.node(from).is_none() || self.node(to).is_none() {
            return None;
        }
        if self.edges.iter().any(|e| (e.from() == from && e.to() == to) || (e.from() == to && e.to() == from)) {
            return None;
        }
        let id = self.new_id();
        let mut m = Map::new();
        m.insert("id".into(), json!(id));
        m.insert("fromNode".into(), json!(from));
        if let Some(s) = fs {
            m.insert("fromSide".into(), json!(s.name()));
        }
        m.insert("toNode".into(), json!(to));
        if let Some(s) = ts {
            m.insert("toSide".into(), json!(s.name()));
        }
        self.edges.push(Edge(m));
        Some(id)
    }

    /// Ноды целиком внутри группы — двигаются вместе с ней.
    pub fn inside(&self, g: &Node) -> Vec<String> {
        self.nodes.iter().filter(|n| n.id() != g.id() && n.x() >= g.x() && n.y() >= g.y()
            && n.x() + n.w() <= g.x() + g.w() && n.y() + n.h() <= g.y() + g.h()).map(|n| n.id().to_string()).collect()
    }

    /// Что двигать вместе с выделенным: сами ноды и всё, что целиком внутри выделенных групп.
    pub fn movable(&self, ids: &[String]) -> Vec<String> {
        let mut out: Vec<String> = vec![];
        for id in ids {
            let Some(n) = self.node(id) else { continue };
            if !out.contains(id) {
                out.push(id.clone());
            }
            if n.is_group() {
                for k in self.inside(n) {
                    if !out.contains(&k) {
                        out.push(k);
                    }
                }
            }
        }
        out
    }

    /// Сдвинуть ноды (с шагом сетки 10 по итогу).
    pub fn shift(&mut self, ids: &[String], dx: f64, dy: f64) {
        for n in self.nodes.iter_mut().filter(|n| ids.iter().any(|i| i == n.id())) {
            let (x, y) = (n.x() + dx, n.y() + dy);
            n.set("x", snap(x));
            n.set("y", snap(y));
        }
    }

    /// Самая верхняя нода под точкой (группа — только если под точкой нет другой ноды).
    pub fn hit(&self, x: f64, y: f64) -> Option<&Node> {
        self.nodes.iter().rev().find(|n| !n.is_group() && n.contains(x, y))
            .or_else(|| self.nodes.iter().rev().find(|n| n.is_group() && n.contains(x, y)))
    }

    /// Границы нод (x0, y0, x1, y1); пусто — None.
    pub fn bounds_of(&self, ids: Option<&[String]>) -> Option<(f64, f64, f64, f64)> {
        let mut b: Option<(f64, f64, f64, f64)> = None;
        for n in self.nodes.iter().filter(|n| ids.is_none_or(|ids| ids.iter().any(|i| i == n.id()))) {
            let r = (n.x(), n.y(), n.x() + n.w(), n.y() + n.h());
            b = Some(match b {
                None => r,
                Some(o) => (o.0.min(r.0), o.1.min(r.1), o.2.max(r.2), o.3.max(r.3)),
            });
        }
        b
    }

    /// Выделение рамкой: ноды, которые задевает прямоугольник (группа — только целиком внутри).
    pub fn in_rect(&self, x0: f64, y0: f64, x1: f64, y1: f64) -> Vec<String> {
        let (ax, bx, ay, by) = (x0.min(x1), x0.max(x1), y0.min(y1), y0.max(y1));
        self.nodes.iter().filter(|n| if n.is_group() {
            n.x() >= ax && n.y() >= ay && n.x() + n.w() <= bx && n.y() + n.h() <= by
        } else {
            n.x() < bx && n.x() + n.w() > ax && n.y() < by && n.y() + n.h() > ay
        }).map(|n| n.id().to_string()).collect()
    }

    /// В буфер обмена: выделенные ноды и провода между ними, в формате JSON Canvas.
    pub fn copy_of(&self, ids: &[String]) -> String {
        let has = |i: &str| ids.iter().any(|x| x == i);
        let ns: Vec<Value> = self.nodes.iter().filter(|n| has(n.id())).map(|n| Value::Object(n.0.clone())).collect();
        let es: Vec<Value> = self.edges.iter().filter(|e| has(e.from()) && has(e.to())).map(|e| Value::Object(e.0.clone())).collect();
        json!({"nodes": ns, "edges": es}).to_string()
    }

    /// Вставить из буфера серединой в (cx, cy). Id новые, провода переподключаются. Не холст — None.
    pub fn paste(&mut self, text: &str, cx: f64, cy: f64) -> Option<Vec<String>> {
        let src = Doc::parse(text).ok()?;
        if src.nodes.is_empty() {
            return None;
        }
        let (x0, y0, x1, y1) = src.bounds_of(None)?;
        let (dx, dy) = (cx - (x0 + x1) / 2.0, cy - (y0 + y1) / 2.0);
        let mut ids: Vec<(String, String)> = vec![];
        let mut made = vec![];
        for mut n in src.nodes {
            let id = self.new_id();
            ids.push((n.id().to_string(), id.clone()));
            n.0.insert("id".into(), json!(id));
            let (x, y) = (n.x() + dx, n.y() + dy);
            n.set("x", snap(x));
            n.set("y", snap(y));
            if n.is_group() {
                self.nodes.insert(0, n);
            } else {
                self.nodes.push(n);
            }
            made.push(id);
        }
        let new_of = |old: &str| ids.iter().find(|p| p.0 == old).map(|p| p.1.clone());
        for mut e in src.edges {
            let (Some(a), Some(b)) = (new_of(e.from()), new_of(e.to())) else { continue };
            let id = self.new_id();
            e.0.insert("id".into(), json!(id));
            e.0.insert("fromNode".into(), json!(a));
            e.0.insert("toNode".into(), json!(b));
            self.edges.push(e);
        }
        Some(made)
    }

    /// Копия выделенного рядом (Ctrl+D).
    pub fn duplicate(&mut self, ids: &[String]) -> Vec<String> {
        let Some((x0, y0, x1, y1)) = self.bounds_of(Some(ids)) else { return vec![] };
        let t = self.copy_of(ids);
        self.paste(&t, (x0 + x1) / 2.0 + 30.0, (y0 + y1) / 2.0 + 30.0).unwrap_or_default()
    }

    /// Группа вокруг выделенного (Ctrl+G).
    pub fn group_around(&mut self, ids: &[String], label: &str) -> Option<String> {
        let (x0, y0, x1, y1) = self.bounds_of(Some(ids))?;
        let pad = 30.0;
        Some(self.add("group", x0 - pad, y0 - pad - 20.0, x1 - x0 + pad * 2.0, y1 - y0 + pad * 2.0 + 20.0, label))
    }

    /// Провод под точкой (допуск `tol` в единицах холста).
    pub fn edge_at(&self, x: f64, y: f64, tol: f64) -> Option<String> {
        let mut best = None;
        let mut bd = tol;
        for e in &self.edges {
            let (Some(a), Some(b)) = (self.node(e.from()), self.node(e.to())) else { continue };
            let c = edge_curve(e, a, b);
            for i in 0..=32 {
                let (px, py) = c.at(i as f64 / 32.0);
                let d = ((px - x).powi(2) + (py - y).powi(2)).sqrt();
                if d < bd {
                    bd = d;
                    best = Some(e.id().to_string());
                }
            }
        }
        best
    }

    /// Ноды-заметки, которые ссылаются на файл `path` (для подсветки на канвасе).
    pub fn files(&self) -> Vec<String> {
        self.nodes.iter().filter(|n| n.kind() == "file").map(|n| n.file().to_string()).collect()
    }

    /// Файл заметки переименован: обновить пути у нод. Сколько нод поменялось.
    pub fn rename_file(&mut self, old: &str, new: &str) -> usize {
        let mut k = 0;
        for n in self.nodes.iter_mut().filter(|n| n.kind() == "file" && n.file() == old) {
            n.set_str("file", new);
            k += 1;
        }
        k
    }
}

/// Шаг сетки 10, как у Obsidian.
pub fn snap(v: f64) -> f64 {
    (v / 10.0).round() * 10.0
}

/// Кривая провода: от сокета до сокета, ручки — наружу от сторон.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Curve {
    pub a: (f64, f64),
    pub c1: (f64, f64),
    pub c2: (f64, f64),
    pub b: (f64, f64),
}

impl Curve {
    pub fn at(&self, t: f64) -> (f64, f64) {
        let u = 1.0 - t;
        let f = |p0: f64, p1: f64, p2: f64, p3: f64| u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3;
        (f(self.a.0, self.c1.0, self.c2.0, self.b.0), f(self.a.1, self.c1.1, self.c2.1, self.b.1))
    }
}

/// Кривая от точки `a` стороны `sa` к точке `b` (у конца сторона `sb` или нет — провод, который тянут).
pub fn curve_between(a: (f64, f64), sa: Side, b: (f64, f64), sb: Option<Side>) -> Curve {
    let dist = ((b.0 - a.0).powi(2) + (b.1 - a.1).powi(2)).sqrt();
    let reach = (dist / 2.5).max(30.0);
    let da = sa.dir();
    let db = sb.map_or((0.0, 0.0), Side::dir);
    Curve { a, c1: (a.0 + da.0 * reach, a.1 + da.1 * reach), c2: (b.0 + db.0 * reach, b.1 + db.1 * reach), b }
}

pub fn edge_curve(e: &Edge, a: &Node, b: &Node) -> Curve {
    let (sa, sb) = edge_sides(e, a, b);
    curve_between(a.socket(sa), sa, b.socket(sb), Some(sb))
}

/// Стороны провода, если в файле не указаны: смотрят друг на друга по главной оси.
pub fn edge_sides(e: &Edge, a: &Node, b: &Node) -> (Side, Side) {
    let dx = (b.x() + b.w() / 2.0) - (a.x() + a.w() / 2.0);
    let dy = (b.y() + b.h() / 2.0) - (a.y() + a.h() / 2.0);
    let (fa, fb) = if dx.abs() >= dy.abs() {
        if dx >= 0.0 { (Side::Right, Side::Left) } else { (Side::Left, Side::Right) }
    } else if dy >= 0.0 {
        (Side::Bottom, Side::Top)
    } else {
        (Side::Top, Side::Bottom)
    };
    (e.from_side().unwrap_or(fa), e.to_side().unwrap_or(fb))
}

/// С какой стороны ноды ближе всего точка (провод отпустили над нодой).
pub fn nearest_side(n: &Node, px: f64, py: f64) -> Side {
    let d = [
        (Side::Top, (py - n.y()).abs()),
        (Side::Bottom, (py - n.y() - n.h()).abs()),
        (Side::Left, (px - n.x()).abs()),
        (Side::Right, (px - n.x() - n.w()).abs()),
    ];
    d.iter().min_by(|a, b| a.1.total_cmp(&b.1)).unwrap().0
}

/// Цвет ноды из файла → `#RRGGBB` (пусто — без цвета). Номера — как у Obsidian.
pub fn color_hex(c: &str) -> String {
    match c {
        "1" => "#E5484D".into(),
        "2" => "#F0A04B".into(),
        "3" => "#E8C547".into(),
        "4" => "#5BB98B".into(),
        "5" => "#4FB3D9".into(),
        "6" => "#A78BFA".into(),
        c if c.starts_with('#') && c.len() == 7 => c.to_uppercase(),
        _ => String::new(),
    }
}

/// История правок для Ctrl+Z / Ctrl+Shift+Z: снимки файла целиком, до 100 шагов.
#[derive(Default, Debug)]
pub struct History {
    undo: Vec<String>,
    redo: Vec<String>,
}

impl History {
    /// Запомнить состояние ДО правки.
    pub fn push(&mut self, before: String) {
        if self.undo.last() == Some(&before) {
            return;
        }
        self.undo.push(before);
        if self.undo.len() > 100 {
            self.undo.remove(0);
        }
        self.redo.clear();
    }
    pub fn undo(&mut self, now: String) -> Option<String> {
        let prev = self.undo.pop()?;
        self.redo.push(now);
        Some(prev)
    }
    pub fn redo(&mut self, now: String) -> Option<String> {
        let next = self.redo.pop()?;
        self.undo.push(now);
        Some(next)
    }
}
