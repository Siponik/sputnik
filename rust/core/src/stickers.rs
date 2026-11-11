//! Вид «Стикеры»: раскладка по темам / срокам / людям, порядок, сроки, наклон. Порт tracker/src/lib/stickers.js.
use crate::dates::{add_days, parse_ymd, ymd};
use crate::j::*;
use crate::rx;
use chrono::{Datelike, NaiveDate};

pub fn default_topics() -> Value {
    json!([
        {"id": "docs", "name": "Документы", "color": "clay"},
        {"id": "buy", "name": "Покупки", "color": "gold"},
        {"id": "call", "name": "Звонки", "color": "work"},
        {"id": "health", "name": "Здоровье", "color": "study"},
        {"id": "home", "name": "Дом", "color": "personal"},
    ])
}

pub fn misc() -> Value {
    json!({"id": "", "name": "Разное", "c": "var(--ink-faint)"})
}

pub fn when_lanes() -> Value {
    json!([
        {"id": "today", "name": "Сегодня", "c": "var(--clay)"},
        {"id": "week", "name": "На неделе", "c": "var(--ink-faint)", "sub": "до воскресенья"},
        {"id": "later", "name": "Когда-нибудь", "c": "var(--ink-faint)", "sub": "без срока или позже"},
    ])
}

pub fn topics_of(l: &Value) -> Value {
    if l["topics"].is_array() { l["topics"].clone() } else { default_topics() }
}

pub fn topic_color(tp: &Value) -> String {
    if !t(tp) || !tp.is_object() {
        return "var(--ink-faint)".into();
    }
    let cs = crate::spheres::sphere_colors();
    let c = a(&cs).iter().find(|c| c["id"] == tp["color"]).unwrap_or(&cs[0]);
    s(&c["v"]).into()
}

fn d(x: &str) -> NaiveDate {
    parse_ymd(x).unwrap()
}

pub fn plus_days(x: &str, k: i64) -> String {
    ymd(add_days(d(x), k))
}

fn dow(x: &str) -> i64 {
    d(x).weekday().num_days_from_sunday() as i64
}

pub fn week_end(today: &str) -> String {
    if dow(today) == 0 { plus_days(today, 7) } else { plus_days(today, 7 - dow(today)) }
}

/// today | week | later.
pub fn bucket(due: &str, today: &str) -> &'static str {
    if due.is_empty() {
        return "later";
    }
    if due <= today {
        return "today";
    }
    if due <= week_end(today).as_str() { "week" } else { "later" }
}

pub fn when_due(target: &str, cur: &str, today: &str) -> Option<String> {
    match target {
        "today" => Some(today.into()),
        "later" => None,
        _ if !cur.is_empty() && bucket(cur, today) == "week" => Some(cur.into()),
        _ => Some(if dow(today) == 0 { week_end(today) } else { plus_days(today, 1) }),
    }
}

pub fn new_due(target: &str, today: &str) -> Option<String> {
    match target {
        "today" => Some(today.into()),
        "week" => Some(plus_days(today, 1)),
        _ => None,
    }
}

const WD: [&str; 7] = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"];
const MON: [&str; 12] = ["янв.", "февр.", "мар.", "апр.", "мая", "июн.", "июл.", "авг.", "сент.", "окт.", "нояб.", "дек."];
const MON_GEN: [&str; 12] = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];

fn short(x: &str) -> String {
    let dd = d(x);
    format!("{} {}", dd.day(), MON[dd.month0() as usize])
}

/// Подпись срока: { text, cls: late | soon | '' }.
pub fn due_label(due: &str, today: &str, slot: &Value, hide_today: bool) -> Value {
    if due.is_empty() {
        return json!({"text": "", "cls": ""});
    }
    let k = (d(due) - d(today)).num_days();
    if k < 0 {
        return json!({"text": format!("просрочено · {}", if k == -1 { "вчера".into() } else { short(due) }), "cls": "late"});
    }
    let at = if t(&slot["s"]) { format!(", {}", text(&slot["s"])) } else { String::new() };
    if k == 0 {
        return json!({"text": if hide_today && at.is_empty() { String::new() } else { format!("сегодня{at}") }, "cls": "soon"});
    }
    if k == 1 {
        return json!({"text": format!("завтра{at}"), "cls": ""});
    }
    if due <= week_end(today).as_str() {
        return json!({"text": format!("{}{at}", WD[dow(due) as usize]), "cls": ""});
    }
    json!({"text": format!("{}{at}", short(due)), "cls": ""})
}

pub fn today_sub(today: &str) -> String {
    let dd = d(today);
    format!("{}, {} {} · и просроченное", WD[dow(today) as usize], dd.day(), MON_GEN[dd.month0() as usize])
}

/// Порядок в колонке: закреплённые; при sort = due — просроченные и ближайшие; потом ord, потом position.
pub fn order(items: &[Value], lay_tasks: &Value, today: &str, sort: &str) -> Vec<Value> {
    let l = |x: &Value| &lay_tasks[s(&x["id"])];
    let due = |x: &Value| if t(&x["due"]) { day10(&x["due"]) } else { String::new() };
    let ord = |x: &Value| n(&l(x)["ord"]).unwrap_or(f64::INFINITY);
    let mut idx: Vec<usize> = (0..items.len()).collect();
    idx.sort_by(|&i, &j| {
        let (x, y) = (&items[i], &items[j]);
        let p = (t(&l(y)["pin"]) as i32) - (t(&l(x)["pin"]) as i32);
        if p != 0 {
            return p.cmp(&0);
        }
        if sort == "due" {
            let (dx, dy) = (due(x), due(y));
            let la = if !dx.is_empty() && dx.as_str() < today { 0 } else { 1 };
            let lb = if !dy.is_empty() && dy.as_str() < today { 0 } else { 1 };
            if la != lb {
                return la.cmp(&lb);
            }
            let da = if dx.is_empty() { "9999".to_string() } else { dx };
            let db = if dy.is_empty() { "9999".to_string() } else { dy };
            if da != db {
                return cmp16(&da, &db);
            }
        }
        let (oa, ob) = (ord(x), ord(y));
        if oa != ob {
            return oa.partial_cmp(&ob).unwrap();
        }
        cmp16(s(&x["position"]), s(&y["position"]))
    });
    idx.into_iter().map(|i| items[i].clone()).collect()
}

pub struct LaneOpts<'a> {
    pub group: &'a str,
    pub topics: &'a Value,
    pub lay_tasks: &'a Value,
    pub today: &'a str,
    pub sort: &'a str,
    pub people: &'a [Value],
    pub me: &'a str,
}

/// Колонки стены [{ id, name, c, sub, items }].
pub fn lanes(tasks: &[Value], o_: &LaneOpts) -> Vec<Value> {
    if o_.group == "people" {
        return people_lanes(tasks, o_);
    }
    if o_.group == "when" {
        return a(&when_lanes())
            .iter()
            .map(|w| {
                let mut m = o(w).clone();
                let sub = if s(&w["id"]) == "today" { json!(today_sub(o_.today)) } else { w["sub"].clone() };
                m.insert("sub".into(), sub);
                let its: Vec<Value> = tasks.iter().filter(|x| bucket(&if t(&x["due"]) { day10(&x["due"]) } else { String::new() }, o_.today) == s(&w["id"])).cloned().collect();
                m.insert("items".into(), json!(order(&its, o_.lay_tasks, o_.today, "due")));
                Value::Object(m)
            })
            .collect();
    }
    let tps = a(o_.topics);
    let topic_id = |x: &Value| {
        let tp = &o_.lay_tasks[s(&x["id"])]["topic"];
        if tps.iter().any(|k| k["id"] == *tp) { text(tp) } else { String::new() }
    };
    let mut out: Vec<Value> = tps
        .iter()
        .map(|tp| {
            let its: Vec<Value> = tasks.iter().filter(|x| topic_id(x) == text(&tp["id"])).cloned().collect();
            json!({"id": tp["id"], "name": tp["name"], "c": topic_color(tp), "sub": "", "items": order(&its, o_.lay_tasks, o_.today, o_.sort)})
        })
        .collect();
    let m: Vec<Value> = tasks.iter().filter(|x| topic_id(x).is_empty()).cloned().collect();
    if !m.is_empty() {
        let mut mm = o(&misc()).clone();
        mm.insert("sub".into(), json!(""));
        mm.insert("items".into(), json!(order(&m, o_.lay_tasks, o_.today, o_.sort)));
        out.push(Value::Object(mm));
    }
    out
}

/// «По людям»: «Я» первым, потом остальные, «Ничьи» последней.
pub fn people_lanes(tasks: &[Value], o_: &LaneOpts) -> Vec<Value> {
    let who = |x: &Value| { let w = &o_.lay_tasks[s(&x["id"])]["who"]; if t(w) { text(w) } else { String::new() } };
    let mut ppl: Vec<&Value> = o_.people.iter().filter(|p| s(&p["email"]) == o_.me).collect();
    ppl.extend(o_.people.iter().filter(|p| s(&p["email"]) != o_.me));
    let mut out = vec![];
    for p in ppl {
        let its: Vec<Value> = tasks.iter().filter(|x| who(x) == s(&p["email"])).cloned().collect();
        if !t(&p["joined"]) && its.is_empty() {
            continue;
        }
        let name = if s(&p["email"]) == o_.me { json!("Я") } else { p["name"].clone() };
        out.push(json!({"id": p["email"], "name": name, "c": p["color"], "m": p, "sub": "", "items": order(&its, o_.lay_tasks, o_.today, o_.sort)}));
    }
    let known: Vec<String> = out.iter().map(|l| text(&l["id"])).collect();
    let none: Vec<Value> = tasks.iter().filter(|x| { let w = who(x); w.is_empty() || !known.contains(&w) }).cloned().collect();
    out.push(json!({"id": "", "name": "Ничьи", "c": "var(--ink-faint)", "m": null, "sub": "", "items": order(&none, o_.lay_tasks, o_.today, o_.sort)}));
    out
}

pub fn next_group(cur: &str, to: &Value, shared: bool) -> String {
    let all: &[&str] = if shared { &["topic", "when", "people"] } else { &["topic", "when"] };
    if let Some(x) = to.as_str().filter(|x| all.contains(x)) {
        return x.into();
    }
    let i = all.iter().position(|x| *x == cur).map_or(-1, |p| p as i64);
    all[((i + 1) as usize) % all.len()].into()
}

/// Какие колонки показать: (shown, hidden).
pub fn visible_lanes(all: &[Value], group: &str, keep: &Value) -> (Vec<Value>, Vec<Value>) {
    let empty = |l: &Value| a(&l["items"]).is_empty();
    if group == "when" || group == "people" || all.iter().all(empty) {
        return (all.to_vec(), vec![]);
    }
    let vis = |l: &Value| !empty(l) || (!keep.is_null() && l["id"] == *keep);
    (all.iter().filter(|l| vis(l)).cloned().collect(), all.iter().filter(|l| !vis(l)).cloned().collect())
}

pub fn topic_of_task(task: &Value, lay_tasks: &Value, topics: &Value) -> Value {
    let tp = &lay_tasks[s(&task["id"])]["topic"];
    a(topics).iter().find(|x| x["id"] == *tp).cloned().unwrap_or(Value::Null)
}

/// Наклон −1,5°…+1,5°, постоянный для задачи (FNV-1a по id).
pub fn tilt(id: &Value) -> f64 {
    let st = if id.is_null() { "null".to_string() } else { text(id) };
    let mut h: u64 = 2166136261;
    for cp in st.chars() {
        h = (h ^ cp as u64) & 0xFFFF_FFFF;
        h = (h.wrapping_mul(16777619)) & 0xFFFF_FFFF;
    }
    ((h % 31) as f64 - 15.0) / 10.0
}

/// Сделано за 7 дней — число в «баночке».
pub fn jar_count(tasks: &[Value], now: f64) -> usize {
    tasks
        .iter()
        .filter(|x| !t(&x["parent"]) && s(&x["status"]) == "completed" && t(&x["completed"]) && parse_ms(s(&x["completed"])).is_some_and(|c| now - c <= 7.0 * 864e5))
        .count()
}

/// «купить батарейки #покуп в пятницу 17:00 !!!» → { title, topic, day, time, priority, repeat }.
pub fn parse_sticker(raw: &str, topics: &Value, today: NaiveDate) -> Value {
    let mut txt = format!(" {raw} ");
    let mut priority = Value::Null;
    if let Some(c) = rx::cap(r"\s(!{1,3})(?=\s)", &txt) {
        priority = json!(4 - c[1].as_ref().unwrap().chars().count() as i64);
        txt = txt.replacen(c[0].as_ref().unwrap(), " ", 1);
    }
    let mut topic = Value::Null;
    if let Some(c) = rx::cap(r"(^|\s)#([^\s#]+)", &txt) {
        let k = c[2].as_ref().unwrap().to_lowercase().replace('ё', "е");
        if let Some(tp) = a(topics).iter().find(|x| s(&x["name"]).to_lowercase().replace('ё', "е").starts_with(&k)) {
            topic = tp["id"].clone();
            txt = txt.replacen(c[0].as_ref().unwrap(), " ", 1);
        }
    }
    let (rule, rest) = crate::repeat::take_repeat(&txt);
    let w = crate::when::parse_when(&rest, today);
    let tt = w.rest.trim();
    let mut ch = tt.chars();
    let title = match ch.next() { Some(f) => f.to_uppercase().collect::<String>() + ch.as_str(), None => String::new() };
    json!({"title": title, "topic": topic, "day": w.day, "time": w.time, "priority": priority, "repeat": rule})
}
