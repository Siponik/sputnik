//! Маленькие модули: fresh (ответ Google не затирает свежие правки), dupes (дубли задач),
//! timer (учёт времени), meta (тип и приоритет). Порт tracker/src/lib/{fresh,dupes,timer,meta}.js.
use crate::j::*;
use std::collections::{HashMap, HashSet};

// ---------- fresh ----------

/// fetched — ответ; local — задачи сейчас; before — id на момент запроса; touched — id → когда меняли (мс); t0 — запрос.
pub fn keep_local(fetched: &[Value], local: &[Value], before: &HashSet<String>, touched: &HashMap<String, f64>, t0: f64) -> Vec<Value> {
    let now: HashMap<&str, &Value> = local.iter().map(|t| (s(&t["id"]), t)).collect();
    let got: HashSet<&str> = fetched.iter().map(|t| s(&t["id"])).collect();
    let mut out = vec![];
    for t in fetched {
        let id = s(&t["id"]);
        if before.contains(id) && !now.contains_key(id) {
            continue;
        }
        let fresh = touched.get(id).copied().unwrap_or(0.0) > t0;
        out.push(if fresh && now.contains_key(id) { now[id].clone() } else { t.clone() });
    }
    for t in local {
        let id = s(&t["id"]);
        if !got.contains(id) && !before.contains(id) {
            out.push(t.clone());
        }
    }
    out
}

// ---------- dupes ----------

/// Группы дублей: [{ listId, listName, title, due, keep, extra }]. Оставляем копию с бо́льшим числом полей слоя.
pub fn find_dupes(tasks: &Value, lists: &[Value], lay_tasks: &Value) -> Vec<Value> {
    let weight = |t: &Value| -> i64 { o(&lay_tasks[s(&t["id"])]).keys().filter(|k| *k != "t").count() as i64 };
    let mut out = vec![];
    for l in lists {
        let mut order: Vec<String> = vec![];
        let mut groups: HashMap<String, Vec<Value>> = HashMap::new();
        for t in a(&tasks[s(&l["id"])]) {
            if crate::j::t(&t["parent"]) || crate::j::t(&t["deleted"]) || s(&t["status"]) == "completed" || s(&t["title"]).trim().is_empty() {
                continue;
            }
            let k = format!("{}|{}", s(&t["title"]).trim().to_lowercase(), day10(&t["due"]));
            if !groups.contains_key(&k) {
                order.push(k.clone());
            }
            groups.entry(k).or_default().push(t.clone());
        }
        for k in order {
            let g = &groups[&k];
            if g.len() < 2 {
                continue;
            }
            let mut sorted = g.clone();
            sorted.sort_by(|x, y| weight(y).cmp(&weight(x)).then_with(|| cmp16(s(&x["id"]), s(&y["id"]))));
            out.push(json!({
                "listId": l["id"], "listName": l["title"], "title": sorted[0]["title"],
                "due": day10(&sorted[0]["due"]), "keep": sorted[0], "extra": sorted[1..],
            }));
        }
    }
    out
}

// ---------- timer ----------

const MAX_RUN_MS: f64 = 12.0 * 3600e3;

fn start_of(l: &Value) -> Option<f64> {
    n(&l["timer"]["start"]).filter(|x| *x != 0.0)
}

/// Минут набрано вместе с идущим таймером.
pub fn spent_min(l: &Value, now: f64) -> f64 {
    let run = start_of(l).map(|st| (now - st).clamp(0.0, MAX_RUN_MS)).unwrap_or(0.0);
    n(&l["spent"]).unwrap_or(0.0) + run / 60e3
}

/// Id задачи с идущим таймером (самый поздний запуск).
pub fn running_id(lay_tasks: &Value) -> Option<String> {
    let mut best: Option<(String, f64)> = None;
    for (k, v) in o(lay_tasks) {
        if let Some(st) = start_of(v) {
            if best.as_ref().map_or(true, |b| st > b.1) {
                best = Some((k.clone(), st));
            }
        }
    }
    best.map(|b| b.0)
}

pub fn stop_patch(l: &Value, now: f64) -> Value {
    json!({ "spent": num((spent_min(l, now) * 10.0).round() / 10.0), "timer": null })
}

/// Патчи [[id, patch]]: остановить всё, что идёт; если у id не шёл — запустить.
pub fn timer_toggle(lay_tasks: &Value, id: &str, now: f64) -> Vec<(String, Value)> {
    let was = start_of(&lay_tasks[id]).is_some();
    let mut out: Vec<(String, Value)> =
        o(lay_tasks).iter().filter(|(_, v)| start_of(v).is_some()).map(|(k, v)| (k.clone(), stop_patch(v, now))).collect();
    if !was {
        out.push((id.to_string(), json!({ "timer": { "start": num(now) } })));
    }
    out
}

pub fn fmt_min(min: f64) -> String {
    let m = min.floor() as i64;
    if m < 1 {
        return "меньше минуты".into();
    }
    let h = m / 60;
    if h > 0 { format!("{h} ч {:02} мин", m % 60) } else { format!("{m} мин") }
}

pub fn clock(ms: f64) -> String {
    let sec = if ms < 0.0 { 0 } else { (ms / 1000.0) as i64 };
    format!("{}:{:02}:{:02}", sec / 3600, sec / 60 % 60, sec % 60)
}

// ---------- meta ----------

pub const TYPES: [(&str, &str); 4] = [("work", "work"), ("creative", "asset"), ("study", "study"), ("personal", "personal")];

pub fn types_json() -> Value {
    Value::Array(TYPES.iter().map(|(id, l)| json!({"id": id, "label": l})).collect())
}

pub fn type_label(id: &Value) -> String {
    TYPES.iter().find(|(i, _)| Some(*i) == id.as_str()).map(|x| x.1.to_string()).unwrap_or_default()
}

pub fn priorities() -> Value {
    json!([
        {"id": 1, "label": "Высокий", "mark": "!!!", "cls": "p1"},
        {"id": 2, "label": "Средний", "mark": "!!", "cls": "p2"},
        {"id": 3, "label": "Низкий", "mark": "!", "cls": "p3"},
    ])
}

pub fn priority_of(p: &Value) -> Value {
    a(&priorities()).iter().find(|x| n(&x["id"]).is_some() && n(&x["id"]) == n(p)).cloned().unwrap_or(Value::Null)
}

/// Высокий выше, без приоритета — после среднего, перед низким.
pub fn priority_rank(p: &Value) -> i64 {
    match n(p) {
        Some(x) if x == 1.0 => 0,
        Some(x) if x == 2.0 => 1,
        Some(x) if x == 3.0 => 3,
        _ => 2,
    }
}

fn due_or(t: &Value) -> String {
    let d = s(&t["due"]);
    if d.is_empty() { "9999".into() } else { d.chars().take(10).collect() }
}

/// С чего начать: просроченное, приоритет, срок, порядок в списке. items — [{task, …}].
pub fn pick_next(items: &[Value], lay_tasks: &Value, today: &str) -> Value {
    let late = |t: &Value| if !s(&t["due"]).is_empty() && due_or(t).as_str() < today { 0 } else { 1 };
    let prio = |t: &Value| priority_rank(&lay_tasks[s(&t["id"])]["priority"]);
    let mut list: Vec<&Value> = items.iter().collect();
    list.sort_by(|x, y| {
        let (ta, tb) = (&x["task"], &y["task"]);
        late(ta).cmp(&late(tb)).then(prio(ta).cmp(&prio(tb))).then(cmp16(&due_or(ta), &due_or(tb))).then(cmp16(s(&ta["position"]), s(&tb["position"])))
    });
    list.first().map(|x| (*x).clone()).unwrap_or(Value::Null)
}

/// Почему енот советует именно её.
pub fn next_reason(task: &Value, lay_tasks: &Value, today: &str, human_due: impl Fn(&str) -> String) -> String {
    let due = s(&task["due"]);
    let has = !due.is_empty();
    if has && due.chars().take(10).collect::<String>().as_str() < today {
        let h = human_due(due);
        let h = match h.find(", ") { Some(i) if !h[..i].contains(char::is_whitespace) => h[i + 2..].to_string(), _ => h };
        return format!("просрочено с {h}");
    }
    let p = priority_of(&lay_tasks[s(&task["id"])]["priority"]);
    if !p.is_null() && n(&p["id"]).unwrap_or(9.0) < 3.0 {
        let tail = if has { format!(", срок {}", human_due(due)) } else { String::new() };
        return format!("{} приоритет{tail}", s(&p["label"]).to_lowercase());
    }
    if has { format!("срок {}", human_due(due)) } else { String::new() }
}
