//! Календарь: раскладка событий, задач и привычек по дням. Порт tracker/src/lib/calendar.js.
//! «Сейчас» — общий [habits::now].
use crate::dates::{add_days, js_date, parse_ymd, ymd};
use crate::habits::{dow, habit_span, is_done, now, scheduled_on, MONTH_GEN, MONTH_NAMES};
use crate::j::*;
use chrono::{Datelike, NaiveDate, NaiveDateTime, Timelike};

pub const GRID_START: f64 = 540.0;
pub const GRID_END: f64 = 1260.0;
pub const HOUR_PX: f64 = 40.0;
pub const HOUR_EMPTY: f64 = 12.0;
pub const BAND_MAX: f64 = 36.0;
pub const WD_SHORT: [&str; 7] = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"];
pub const WD_FULL: [&str; 7] = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"];

fn round2(x: f64) -> f64 {
    ((x * 100.0 + 0.5).floor()) / 100.0
}

#[derive(Clone, Debug, Default)]
pub struct HourLayout {
    pub ht: Vec<f64>,
    pub y: Vec<f64>,
    pub height: f64,
    pub labels: Vec<Value>,
    pub lines: Vec<f64>,
    pub bands: Vec<Value>,
    pub busy: Vec<bool>,
}

impl HourLayout {
    pub fn y_at(&self, min: f64) -> f64 {
        let m = min.clamp(0.0, 1440.0);
        let hh = ((m / 60.0).floor() as usize).min(23);
        self.y[hh] + ((m - hh as f64 * 60.0) / 60.0) * self.ht[hh]
    }
    pub fn to_json(&self) -> Value {
        let f = |v: &Vec<f64>| Value::Array(v.iter().map(|x| num(*x)).collect());
        json!({"HT": f(&self.ht), "Y": f(&self.y), "height": num(self.height), "labels": self.labels,
               "lines": f(&self.lines), "bands": self.bands, "busy": self.busy})
    }
}

/// Сетка суток: занятые часы — полная высота, пустые — сжатые полосы.
pub fn hour_layout(items: &[Value], hot: &[i64], fit: f64) -> HourLayout {
    let mut busy = vec![false; 24];
    for &h in hot {
        if (0..24).contains(&h) {
            busy[h as usize] = true;
        }
    }
    for it in items {
        let (s, e) = (n(&it["s"]).unwrap_or(0.0), n(&it["e"]).unwrap_or(0.0));
        let a = ((s / 60.0).floor()).max(0.0) as usize;
        let b = (((e.max(s + 30.0)) / 60.0).ceil() as usize).min(24);
        for q in a..b.max(a) {
            busy[q] = true;
        }
    }
    let mut runs: Vec<(usize, usize, f64)> = vec![];
    let mut h = 0;
    while h < 24 {
        if busy[h] {
            h += 1;
            continue;
        }
        let a = h;
        while h < 24 && !busy[h] {
            h += 1;
        }
        runs.push((a, h, ((h - a) as f64 * HOUR_EMPTY).min(BAND_MAX)));
    }
    let n_busy = busy.iter().filter(|x| **x).count();
    let mut full = HOUR_PX;
    if fit > 0.0 && n_busy > 0 {
        let v = ((fit - runs.iter().map(|r| r.2).sum::<f64>()) / n_busy as f64).floor();
        full = v.clamp(30.0, 72.0);
    }
    let mut ht = vec![0.0; 24];
    let mut y = vec![0.0; 25];
    for r in &runs {
        for q in r.0..r.1 {
            ht[q] = r.2 / (r.1 - r.0) as f64;
        }
    }
    for q in 0..24 {
        if busy[q] {
            ht[q] = full;
        }
        y[q + 1] = round2(y[q] + ht[q]);
    }
    let (mut labels, mut lines, mut bands) = (vec![], vec![], vec![]);
    for h in 0..24 {
        if !busy[h] {
            continue;
        }
        labels.push(json!({"key": format!("h{h}"), "text": format!("{h:02}:00"), "top": num(if h == 0 { 2.0 } else { y[h] - 7.0 }), "small": false}));
        if h > 0 && busy[h - 1] {
            lines.push(y[h]);
        }
    }
    for r in &runs {
        let text = format!("{:02}–{:02}", r.0, if r.1 == 24 { 0 } else { r.1 });
        bands.push(json!({"top": num(y[r.0]), "h": num(r.2), "a": r.0, "b": r.1, "text": text}));
        if r.2 >= BAND_MAX {
            labels.push(json!({"key": format!("b{}", r.0), "text": text, "top": num(y[r.0] + r.2 / 2.0 - 7.0), "small": true}));
        }
    }
    HourLayout { height: y[24], ht, y, labels, lines, bands, busy }
}

pub fn start_of_week(d: NaiveDate) -> NaiveDate {
    add_days(d, -dow(d))
}

pub fn to_min(hhmm: &str) -> i64 {
    let mut p = hhmm.split(':').map(|x| x.trim().parse::<i64>().unwrap_or(0));
    p.next().unwrap_or(0) * 60 + p.next().unwrap_or(0)
}

pub fn from_min(m: i64) -> String {
    format!("{:02}:{:02}", m / 60, m % 60)
}

pub fn now_min() -> i64 {
    let d = now();
    (d.hour() * 60 + d.minute()) as i64
}

fn pd(s: &str) -> NaiveDate {
    parse_ymd(s).unwrap_or_else(|| now().date())
}

pub fn period_days(sel: &str, mode: &str) -> Vec<String> {
    let sel = pd(sel);
    let first = if mode == "week" { start_of_week(sel) } else { start_of_week(sel.with_day(1).unwrap()) };
    (0..if mode == "week" { 7 } else { 42 }).map(|i| ymd(add_days(first, i))).collect()
}

pub fn period_title(sel: &str, mode: &str) -> String {
    let sel = pd(sel);
    if mode == "month" {
        return format!("{} {}", MONTH_NAMES[sel.month0() as usize], sel.year());
    }
    let a = start_of_week(sel);
    let b = add_days(a, 6);
    if a.month() == b.month() {
        format!("{} – {} {}", a.day(), b.day(), MONTH_GEN[b.month0() as usize])
    } else {
        format!("{} {} – {} {}", a.day(), MONTH_GEN[a.month0() as usize], b.day(), MONTH_GEN[b.month0() as usize])
    }
}

pub fn shift_period(sel: &str, mode: &str, dir: i64) -> String {
    let sel = pd(sel);
    if mode == "week" {
        return ymd(add_days(sel, 7 * dir));
    }
    let (y, m0) = (sel.year(), sel.month0() as i32);
    let last = js_date(y, m0 + dir as i32 + 1, 0).day();
    ymd(js_date(y, m0 + dir as i32, sel.day().min(last) as i32))
}

pub fn type_of_template(tpl: &str) -> &'static str {
    match tpl {
        "asset3d" => "creative",
        "personal" => "personal",
        "study" => "study",
        _ => "work",
    }
}

pub fn type_color(t: &str) -> String {
    format!("var(--type-{t})")
}

/// Время из ISO → местное.
pub fn local_dt(iso: &str) -> Option<NaiveDateTime> {
    chrono::DateTime::parse_from_rfc3339(iso)
        .map(|d| d.with_timezone(&chrono::Local).naive_local())
        .ok()
        .or_else(|| NaiveDateTime::parse_from_str(iso, "%Y-%m-%dT%H:%M:%S").ok())
}

fn push_day(out: &mut Json, days: &[String], day: &str, item: Value) {
    if days.iter().any(|d| d == day) {
        out.entry(day.to_string()).or_insert_with(|| json!([])).as_array_mut().unwrap().push(item);
    }
}

pub fn events_by_day(events: &[Value], days: &[String]) -> Value {
    let mut out = Json::new();
    for e in events {
        let (start, end) = (&e["start"], &e["end"]);
        let title = if t(&e["summary"]) { e["summary"].clone() } else { json!("Без названия") };
        let kind = if e["kind"].is_null() { json!("event") } else { e["kind"].clone() };
        let base = |id: String, sm: Value, em: Value| {
            let mut m = json!({"kind": kind, "title": title, "cal": e["calendar"], "event": e, "id": id, "s": sm, "e": em});
            if e["calendar"].is_null() {
                m.as_object_mut().unwrap().shift_remove("cal");
            }
            m
        };
        let eid = text(&e["id"]);
        if t(&start["date"]) {
            let sd = s(&start["date"]);
            let ed = s(&end["date"]);
            let last = if !ed.is_empty() && ed > sd { ed.to_string() } else { ymd(add_days(pd(sd), 1)) };
            let mut d = pd(sd);
            while ymd(d) < last {
                let k = ymd(d);
                push_day(&mut out, days, &k, base(format!("{eid}|{k}"), Value::Null, Value::Null));
                d = add_days(d, 1);
            }
            continue;
        }
        if !t(&start["dateTime"]) {
            continue;
        }
        let Some(a) = local_dt(s(&start["dateTime"])) else { continue };
        let b = local_dt(if t(&end["dateTime"]) { s(&end["dateTime"]) } else { s(&start["dateTime"]) }).unwrap_or(a);
        let mut d = a.date().and_hms_opt(0, 0, 0).unwrap();
        loop {
            let day_end = d + chrono::Duration::days(1);
            let lo = a.max(d);
            let hi = b.min(day_end);
            let sm = ((lo - d).num_milliseconds() as f64 / 60e3 + 0.5).floor() as i64;
            let em = ((hi - d).num_milliseconds() as f64 / 60e3 + 0.5).floor() as i64;
            let whole = sm == 0 && em >= 1440;
            let k = ymd(d.date());
            let (sv, ev) = if whole { (Value::Null, Value::Null) } else { (json!(sm), json!(em.max(sm))) };
            push_day(&mut out, days, &k, base(format!("{eid}|{k}"), sv, ev));
            d = day_end;
            if d >= b {
                break;
            }
        }
    }
    Value::Object(out)
}

pub fn tasks_by_day(lists: &[Value], by_list: &Value, lay_tasks: &Value, type_of: &dyn Fn(&str, &str) -> String, days: &[String]) -> Value {
    let today = ymd(now().date());
    let mut out = Json::new();
    for l in lists {
        let lid = s(&l["id"]);
        for tk in a(&by_list[lid]) {
            if t(&tk["parent"]) || !t(&tk["due"]) {
                continue;
            }
            let day = day10(&tk["due"]);
            let slot = &lay_tasks[s(&tk["id"])]["slot"];
            let done = tk["status"] == "completed";
            let (sv, ev) = (&slot["s"], &slot["e"]);
            let sm = if t(sv) { json!(to_min(s(sv))) } else { Value::Null };
            let em = if t(ev) { json!(to_min(s(ev))) } else if t(sv) { json!(to_min(s(sv)) + 60) } else { Value::Null };
            push_day(&mut out, days, &day.clone(), json!({
                "kind": "task", "id": tk["id"],
                "title": if t(&tk["title"]) { tk["title"].clone() } else { json!("Без названия") },
                "task": tk, "listId": l["id"], "list": l["title"], "type": type_of(lid, s(&tk["id"])),
                "done": done, "overdue": !done && day < today, "s": sm, "e": em,
            }));
        }
    }
    Value::Object(out)
}

/// Блоки в сетке дня: место по высоте, колонки при пересечении.
pub fn layout_blocks(items: &[Value], y_at: &dyn Fn(f64) -> f64) -> Vec<Value> {
    let cl = |m: f64| m.clamp(0.0, 1440.0);
    let mut xs: Vec<(usize, Json)> = items
        .iter()
        .filter(|i| !i["s"].is_null())
        .enumerate()
        .map(|(k, i)| {
            let a0 = cl(n(&i["s"]).unwrap_or(0.0));
            let top = y_at(a0) + 1.0;
            let ce = cl(n(&i["e"]).unwrap_or(a0));
            let height = (y_at(ce.max(a0)) - y_at(a0) - 2.0).max(20.0);
            let mut m = o(i).clone();
            m.insert("a".into(), num(a0));
            m.insert("top".into(), num(top));
            m.insert("height".into(), num(height));
            m.insert("bot".into(), num(y_at(ce.max(a0 + 30.0)).max(top + height)));
            (k, m)
        })
        .collect();
    let g = |m: &Json, k: &str| m[k].as_f64().unwrap_or(0.0);
    xs.sort_by(|x, y| {
        g(&x.1, "top").partial_cmp(&g(&y.1, "top")).unwrap()
            .then(g(&y.1, "bot").partial_cmp(&g(&x.1, "bot")).unwrap())
            .then(x.0.cmp(&y.0))
    });
    let mut out = vec![];
    let mut cluster: Vec<Json> = vec![];
    let mut end = -1.0f64;
    let flush = |cluster: &mut Vec<Json>, out: &mut Vec<Value>| {
        let mut cols: Vec<f64> = vec![];
        for it in cluster.iter_mut() {
            let top = g(it, "top");
            let c = match cols.iter().position(|l| *l <= top) {
                Some(c) => c,
                None => {
                    cols.push(0.0);
                    cols.len() - 1
                }
            };
            cols[c] = g(it, "bot");
            it.insert("col".into(), json!(c));
        }
        for mut it in cluster.drain(..) {
            it.insert("cols".into(), json!(cols.len()));
            out.push(Value::Object(it));
        }
    };
    for (_, it) in xs {
        if !cluster.is_empty() && g(&it, "top") >= end {
            flush(&mut cluster, &mut out);
        }
        end = end.max(g(&it, "bot"));
        cluster.push(it);
    }
    if !cluster.is_empty() {
        flush(&mut cluster, &mut out);
    }
    out
}

fn is_done_item(i: &Value) -> bool {
    (i["kind"] == "task" || i["kind"] == "habit") && t(&i["done"])
}

pub fn busy(items: &[Value], lo: f64, hi: f64) -> Vec<[f64; 2]> {
    let mut xs: Vec<(usize, [f64; 2])> = items
        .iter()
        .enumerate()
        .filter(|(_, i)| !i["s"].is_null() && !is_done_item(i))
        .map(|(k, i)| (k, [n(&i["s"]).unwrap_or(0.0).max(lo), n(&i["e"]).unwrap_or(0.0).min(hi)]))
        .filter(|x| x.1[1] > x.1[0])
        .collect();
    xs.sort_by(|x, y| x.1[0].partial_cmp(&y.1[0]).unwrap().then(x.0.cmp(&y.0)));
    let mut out: Vec<[f64; 2]> = vec![];
    for (_, ab) in xs {
        match out.last_mut() {
            Some(l) if ab[0] <= l[1] => l[1] = l[1].max(ab[1]),
            _ => out.push(ab),
        }
    }
    out
}

pub fn busy_minutes(items: &[Value]) -> f64 {
    busy(items, GRID_START, GRID_END).iter().map(|x| x[1] - x[0]).sum()
}

pub fn best_window(day_items: &Value, days: &[String]) -> Value {
    let work: Vec<String> = days.iter().filter(|d| dow(pd(d)) < 5).cloned().collect();
    let rest: Vec<String> = days.iter().filter(|d| !work.contains(d)).cloned().collect();
    let w = longest_gap(day_items, &work);
    if w.is_null() { longest_gap(day_items, &rest) } else { w }
}

fn longest_gap(day_items: &Value, days: &[String]) -> Value {
    let today = ymd(now().date());
    let mut best: Option<(String, f64, f64, f64)> = None;
    for day in days {
        if *day < today {
            continue;
        }
        let nm = ((now_min() as f64) / 30.0).ceil() * 30.0;
        let lo = if *day == today { GRID_START.max(nm) } else { GRID_START };
        if lo > GRID_END - 60.0 {
            continue;
        }
        let mut from = lo;
        let mut gaps = vec![];
        for ab in busy(a(&day_items[day.as_str()]), lo, GRID_END) {
            if ab[0] > from {
                gaps.push([from, ab[0]]);
            }
            from = from.max(ab[1]);
        }
        if GRID_END > from {
            gaps.push([from, GRID_END]);
        }
        for gp in gaps {
            let len = gp[1] - gp[0];
            if len >= 60.0 && best.as_ref().is_none_or(|b| len > b.3) {
                best = Some((day.clone(), gp[0], gp[0] + len.min(180.0), len));
            }
        }
    }
    match best {
        None => Value::Null,
        Some((d, s0, e0, l)) => json!({"day": d, "s": num(s0), "e": num(e0), "len": num(l)}),
    }
}

pub fn habit_day(h: &Value, log: &Value, day: &str, today: &str) -> Value {
    let done = is_done(log, &h["id"], day);
    let c = s(&h["createdAt"]);
    let before = !c.is_empty() && day < &c[..c.len().min(10)];
    json!({"sched": scheduled_on(h, log, day) && (!before || done), "done": done, "isToday": day == today, "future": day > today})
}

pub fn habit_blocks(habits: &[Value], log: &Value, day: &str, today: &str) -> Vec<Value> {
    let mut out = vec![];
    for h in habits {
        let sp = habit_span(h);
        if sp.is_null() {
            continue;
        }
        let x = habit_day(h, log, day, today);
        if x["sched"] != true {
            continue;
        }
        let mut m = json!({"kind": "habit", "id": format!("hab:{}|{day}", text(&h["id"])), "title": h["name"], "h": h,
                           "s": sp["s"], "e": sp["e"], "end": sp["end"]});
        extend(m.as_object_mut().unwrap(), o(&x));
        out.push(m);
    }
    out
}

pub fn day_label(day: &str) -> Value {
    let d = pd(day);
    json!({"weekday": WD_FULL[dow(d) as usize], "short": WD_SHORT[dow(d) as usize],
           "title": format!("{} {}", d.day(), MONTH_GEN[d.month0() as usize]), "n": d.day(), "month": d.month0()})
}

pub fn when_label(day: &str) -> String {
    let nd = now().date();
    if day == ymd(nd) {
        "сегодня".into()
    } else if day == ymd(add_days(nd, 1)) {
        "завтра".into()
    } else if day == ymd(add_days(nd, -1)) {
        "вчера".into()
    } else {
        WD_SHORT[dow(pd(day)) as usize].into()
    }
}

pub fn hours_label(min: f64) -> String {
    if min == 0.0 || min.is_nan() {
        return "—".into();
    }
    let v = ((min / 6.0 + 0.5).floor()) / 10.0;
    let s = if v.fract() == 0.0 { format!("{}", v as i64) } else { format!("{v}") };
    format!("{} ч", s.replace('.', ","))
}
