//! Сетка недели «Система G» (п. 47 `docs/design-g-fixes.md`, макеты `G_CalWeek`, `G_CalRules`).
//! Видны только часы от первого до последнего дела (по умолчанию 09–19), ничего не сжато; что за краем —
//! чипы «↑ раньше / ↓ позже». Дела в одно время — один блок «N дел» со строками внутри; часы такого
//! отрезка растут во всех днях (не больше чем вдвое). Длинная привычка («Работа 08–17») — фон, а не блок.

/// Дело в сетке: минуты от полуночи, вид (0 событие, 1 задача, 2 привычка), сделано ли.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WItem {
    pub s: f64,
    pub e: f64,
    pub kind: i32,
    pub done: bool,
}

pub const ROW_PX: f64 = 40.0;
/// Окно, внутри которого дела сами раздвигают видимые часы. Что раньше или позже — уходит в чипы.
pub const AUTO_LO: i64 = 8;
pub const AUTO_HI: i64 = 20;
pub const DEF_LO: i64 = 9;
pub const DEF_HI: i64 = 19;
/// Привычка от трёх часов — фон дня, а не блок.
pub const LONG_HABIT: f64 = 180.0;
/// Блок «N дел»: шапка (с отступом сверху) и строка; «+N ещё» — своя строка.
pub const STACK_HEAD: f64 = 20.0;
pub const STACK_MORE: f64 = 16.0;
pub const STACK_ROW: f64 = 28.0;
pub const MIN_H: f64 = 22.0;
/// Короче — одна строка.
pub const SHORT: f64 = 45.0;

pub fn is_background(it: &WItem) -> bool {
    it.kind == 2 && it.e - it.s >= LONG_HABIT
}

/// Время пишем, только если начало не ровно по часу (по часу его и так видно по сетке).
pub fn show_time(s: f64) -> bool {
    (s as i64) % 60 != 0
}

pub fn one_line(it: &WItem) -> bool {
    it.e - it.s < SHORT
}

/// Видимые часы [r0, r1). `up`/`down` — раскрыто пользователем (клик по чипу): час, до которого раскрыть.
pub fn week_range(days: &[Vec<WItem>], up: Option<i64>, down: Option<i64>) -> (i64, i64) {
    let (mut r0, mut r1) = (DEF_LO, DEF_HI);
    for it in days.iter().flatten().filter(|x| !is_background(x)) {
        let sh = (it.s / 60.0).floor() as i64;
        if sh >= AUTO_LO && sh < AUTO_HI {
            r0 = r0.min(sh);
            r1 = r1.max(((it.e.min(1440.0)) / 60.0).ceil() as i64);
        }
    }
    if let Some(u) = up {
        r0 = r0.min(u.clamp(0, 23));
    }
    if let Some(d) = down {
        r1 = r1.max(d.clamp(1, 24));
    }
    (r0, r1.clamp(r0 + 1, 24))
}

/// Дела дня, которые целиком за краем: (сколько раньше, начало первого раньше), (сколько позже, начало первого позже).
pub fn outside(items: &[WItem], r0: i64, r1: i64) -> ((usize, Option<f64>), (usize, Option<f64>)) {
    let (lo, hi) = (r0 as f64 * 60.0, r1 as f64 * 60.0);
    let fg: Vec<&WItem> = items.iter().filter(|x| !is_background(x)).collect();
    let before: Vec<f64> = fg.iter().filter(|x| x.e.max(x.s + 1.0) <= lo).map(|x| x.s).collect();
    let after: Vec<f64> = fg.iter().filter(|x| x.s >= hi).map(|x| x.s).collect();
    let mn = |v: &Vec<f64>| v.iter().cloned().fold(None, |m: Option<f64>, x| Some(m.map_or(x, |m| m.min(x))));
    ((before.len(), mn(&before)), (after.len(), mn(&after)))
}

/// Группы дел дня, которые пересекаются по времени (в пределах видимых часов). Номера — индексы в `items`,
/// внутри группы — по началу. Фоновые привычки и дела за краем не входят.
pub fn clusters(items: &[WItem], r0: i64, r1: i64) -> Vec<Vec<usize>> {
    let (lo, hi) = (r0 as f64 * 60.0, r1 as f64 * 60.0);
    let mut ix: Vec<usize> = (0..items.len()).filter(|&i| {
        let x = &items[i];
        !is_background(x) && x.e.max(x.s + 1.0) > lo && x.s < hi
    }).collect();
    ix.sort_by(|&a, &b| items[a].s.partial_cmp(&items[b].s).unwrap().then(items[b].e.partial_cmp(&items[a].e).unwrap()).then(a.cmp(&b)));
    let mut out: Vec<Vec<usize>> = vec![];
    let mut end = f64::MIN;
    for i in ix {
        let x = &items[i];
        // короткое дело на сетке занимает не меньше MIN_H — считаем его хотя бы получасовым
        let e = x.e.max(x.s + 30.0);
        if !out.is_empty() && x.s < end {
            out.last_mut().unwrap().push(i);
        } else {
            out.push(vec![i]);
        }
        end = if out.last().unwrap().len() == 1 { e } else { end.max(e) };
    }
    out
}

/// Отрезок часов группы: [a, b) в пределах видимых.
pub fn cluster_hours(items: &[WItem], c: &[usize], r0: i64, r1: i64) -> (i64, i64) {
    let s = c.iter().map(|&i| items[i].s).fold(f64::MAX, f64::min);
    let e = c.iter().map(|&i| items[i].e.max(items[i].s + 30.0)).fold(f64::MIN, f64::max);
    let a = ((s / 60.0).floor() as i64).clamp(r0, r1 - 1);
    let b = ((e / 60.0).ceil() as i64).clamp(a + 1, r1);
    (a, b)
}

/// Высоты видимых часов: 40 px, а где есть блок «N дел» — столько, чтобы строки влезли, но не больше чем вдвое.
/// Высота часа одна на все 7 дней.
pub fn row_heights(days: &[Vec<WItem>], r0: i64, r1: i64) -> Vec<f64> {
    let mut h = vec![ROW_PX; (r1 - r0).max(0) as usize];
    for items in days {
        for c in clusters(items, r0, r1).iter().filter(|c| c.len() > 1) {
            let (a, b) = cluster_hours(items, c, r0, r1);
            // блок занимает от начала первого до конца последнего дела (а не целые часы) и на 3 px меньше
            let s = c.iter().map(|&i| items[i].s).fold(f64::MAX, f64::min).max(r0 as f64 * 60.0);
            let e = c.iter().map(|&i| items[i].e.max(items[i].s + 30.0)).fold(f64::MIN, f64::max).min(r1 as f64 * 60.0);
            let need = STACK_HEAD + 3.0 + STACK_ROW * c.len() as f64;
            let per = (need / ((e - s) / 60.0).max(0.25)).ceil().clamp(ROW_PX, 2.0 * ROW_PX);
            for q in a..b {
                let k = (q - r0) as usize;
                h[k] = h[k].max(per);
            }
        }
    }
    h
}

/// Вертикаль видимых часов.
#[derive(Clone, Debug)]
pub struct WeekGrid {
    pub r0: i64,
    pub r1: i64,
    pub ht: Vec<f64>,
    pub y: Vec<f64>,
}

impl WeekGrid {
    pub fn new(days: &[Vec<WItem>], up: Option<i64>, down: Option<i64>) -> Self {
        let (r0, r1) = week_range(days, up, down);
        Self::build(days, r0, r1, 0.0)
    }
    fn build(days: &[Vec<WItem>], r0: i64, r1: i64, avail: f64) -> Self {
        let mut ht = row_heights(days, r0, r1);
        // все 24 часа влезли, а место ещё есть — растягиваем часы на остаток
        let sum: f64 = ht.iter().sum();
        if r0 == 0 && r1 == 24 && avail > sum {
            let k = avail / sum;
            for v in ht.iter_mut() {
                *v = (*v * k * 100.0).floor() / 100.0;
            }
        }
        let mut y = vec![0.0];
        for v in &ht {
            y.push(y.last().unwrap() + v);
        }
        WeekGrid { r0, r1, ht, y }
    }
    /// Сетка заполняет высоту `avail`: после часов с делами добавляем целые часы — сначала позже, потом раньше, —
    /// пока влезают; все 24 влезли — часы растягиваются на остаток. Пустого места под сеткой нет.
    pub fn fit(days: &[Vec<WItem>], up: Option<i64>, down: Option<i64>, avail: f64) -> Self {
        let (mut r0, mut r1) = week_range(days, up, down);
        if avail <= 0.0 {
            return Self::build(days, r0, r1, 0.0);
        }
        loop {
            let h: f64 = row_heights(days, r0, r1).iter().sum();
            if r1 < 24 && h + row_heights(days, r0, r1 + 1).last().copied().unwrap_or(ROW_PX) <= avail + 0.5 {
                r1 += 1;
            } else if r0 > 0 && h + ROW_PX <= avail + 0.5 {
                r0 -= 1;
            } else {
                break;
            }
        }
        Self::build(days, r0, r1, avail)
    }
    pub fn height(&self) -> f64 {
        *self.y.last().unwrap()
    }
    /// Минуты → y; за краем — прижато к краю.
    pub fn y_at(&self, min: f64) -> f64 {
        let m = min.clamp(self.r0 as f64 * 60.0, self.r1 as f64 * 60.0);
        let k = (((m / 60.0).floor() as i64 - self.r0).max(0) as usize).min(self.ht.len() - 1);
        self.y[k] + (m / 60.0 - (self.r0 + k as i64) as f64) * self.ht[k]
    }
    /// y → минуты с шагом `step`.
    pub fn min_at(&self, y: f64, step: f64) -> f64 {
        let y = y.clamp(0.0, self.height());
        let mut k = 0;
        while k + 1 < self.ht.len() && self.y[k + 1] <= y {
            k += 1;
        }
        let m = (self.r0 + k as i64) as f64 * 60.0 + ((y - self.y[k]) / self.ht[k]).clamp(0.0, 1.0) * 60.0;
        ((m / step).round() * step).clamp(self.r0 as f64 * 60.0, self.r1 as f64 * 60.0 - step)
    }
    /// Верх и высота блока с отступами (1 px сверху, 3 px между блоками), не ниже MIN_H.
    pub fn place(&self, s: f64, e: f64) -> (f64, f64) {
        let top = self.y_at(s) + 1.0;
        (top, (self.y_at(e.max(s)) - self.y_at(s) - 3.0).max(MIN_H))
    }
}

/// Сколько строк блока «N дел» показать при высоте `h`; остаток — строка «+N ещё».
pub fn stack_fit(h: f64, n: usize) -> (usize, usize) {
    let rows = |room: f64| ((room / STACK_ROW).floor().max(0.0)) as usize;
    if rows(h - STACK_HEAD) >= n {
        (n, 0)
    } else {
        let shown = rows(h - STACK_HEAD - STACK_MORE).max(1).min(n);
        (shown, n - shown)
    }
}

/// «2 ДЕЛА · 11–13».
pub fn stack_head(n: usize, a: f64, b: f64) -> String {
    let word = crate::habits::plural(n as i64, ["ДЕЛО", "ДЕЛА", "ДЕЛ"]);
    format!("{n} {word} · {:02}–{:02}", (a / 60.0).floor() as i64, ((b / 60.0).ceil() as i64).min(24))
}

/// «↑ 07:00 · ещё 1 раньше» / «↓ 19:00 · ещё 2 позже».
pub fn chip_text(up: bool, n: usize, first: f64) -> String {
    let m = first as i64;
    format!("{} {:02}:{:02} · ЕЩЁ {} {}", if up { "↑" } else { "↓" }, m / 60, m % 60, n, if up { "РАНЬШЕ" } else { "ПОЗЖЕ" })
}

/// «2 Ч», «45 МИН», «1 Ч 30 МИН».
pub fn dur_text(min: f64) -> String {
    let m = min.max(0.0).round() as i64;
    match (m / 60, m % 60) {
        (0, r) => format!("{r} МИН"),
        (h, 0) => format!("{h} Ч"),
        (h, r) => format!("{h} Ч {r} МИН"),
    }
}

/// Порядок дел в клетке месяца и в строке «весь день» (G_CalRules, п. 2): день рождения, весь день,
/// по времени начала, сделанное — в конце. Дело: (вид — 3 день рождения, начало в минутах или None, сделано).
pub fn day_order(items: &[(i32, Option<f64>, bool)]) -> Vec<usize> {
    let mut ix: Vec<usize> = (0..items.len()).collect();
    let key = |i: usize| {
        let (kind, s, done) = items[i];
        let group = if kind == 3 { 0 } else if s.is_none() { 1 } else { 2 };
        (done as i32, group, s.unwrap_or(-1.0))
    };
    ix.sort_by(|&a, &b| {
        let (ka, kb) = (key(a), key(b));
        ka.0.cmp(&kb.0).then(ka.1.cmp(&kb.1)).then(ka.2.partial_cmp(&kb.2).unwrap()).then(a.cmp(&b))
    });
    ix
}

/// Сколько строк показать, если влезает `cap`: всё — или `cap − 1` и строка «+N ещё».
pub fn fit_rows(n: usize, cap: usize) -> (usize, usize) {
    if n <= cap { (n, 0) } else { let k = cap.saturating_sub(1); (k, n - k) }
}
