//! «Входящие от Claude»: задачи, которые Apps Script (reminders/Inbox.gs) создал по запросам из чатов.
//! Решение хранится в слое: tasks[id].inbox = 'accepted' | 'rejected'. Порт tracker/src/lib/inbox.js.
use crate::habits::now;
use crate::j::*;
use crate::reminders::{local, parse_any};
use crate::rx;
use crate::spheres::{sphere_colors, spheres_from, ICONS};
use crate::stickers::topics_of;
use crate::templates::{templates_from, views};

/// taskId → { from, at } для задач, созданных из чатов.
pub fn claude_tasks(status: &Value) -> Json {
    let mut out = Json::new();
    for p in o(&status["processed"]).values() {
        if !p.is_object() || !t(&p["ok"]) {
            continue;
        }
        for c in a(&p["created"]) {
            if c.is_object() && c["op"] == "task.create" && t(&c["taskId"]) && !t(&c["existed"]) {
                let mut m = json!({"from": if t(&p["from"]) { p["from"].clone() } else { json!("") }});
                if !p["at"].is_null() {
                    m["at"] = p["at"].clone();
                }
                out.insert(text(&c["taskId"]), m);
            }
        }
    }
    out
}

/// Ещё не разобранные: задача есть, открыта и решения по ней нет. Свежие сверху.
pub fn pending(status: &Value, lists: &[Value], by_list: &Value, lay_tasks: &Value) -> Vec<Value> {
    let ids = claude_tasks(status);
    let mut items: Vec<Value> = vec![];
    for l in lists {
        for tk in a(&by_list[s(&l["id"])]) {
            let id = text(&tk["id"]);
            let Some(info) = ids.get(&id) else { continue };
            if tk["status"] == "completed" || t(&lay_tasks[id.as_str()]["inbox"]) {
                continue;
            }
            let mut m = json!({"task": tk, "listId": l["id"], "list": l["title"]});
            extend(m.as_object_mut().unwrap(), o(info));
            items.push(m);
        }
    }
    let at = |x: &Value| if t(&x["at"]) { text(&x["at"]) } else { String::new() };
    items.sort_by(|a0, b0| at(b0).cmp(&at(a0)));
    items
}

fn type_of(x: &str) -> Option<&'static str> {
    match x {
        "work" | "meeting" => Some("work"),
        "creative" => Some("creative"),
        "study" => Some("study"),
        "personal" => Some("personal"),
        _ => None,
    }
}

fn str_(v: &Value, max: usize) -> Option<String> {
    let x = v.as_str()?;
    if x.trim().is_empty() || x.chars().count() > max { None } else { Some(x.trim().to_string()) }
}

const MAX_LEAD: f64 = 60.0 * 24.0 * 62.0;
fn lead(m: &Value) -> Option<Value> {
    let x = n(m)?;
    if x.fract() == 0.0 && (0.0..=MAX_LEAD).contains(&x) { Some(json!({"kind": "lead", "min": x as i64})) } else { None }
}

fn plus_hour(hm: &str) -> String {
    let v = hm[..2].parse::<i64>().unwrap_or(0) * 60 + hm[3..].parse::<i64>().unwrap_or(0) + 60;
    let m = v.min(23 * 60 + 59);
    format!("{:02}:{:02}", m / 60, m % 60)
}

fn norm(x: &Value) -> String {
    let st = if x.is_null() { String::new() } else { text(x) };
    st.trim().to_lowercase().replace('ё', "е")
}

fn is_hm(v: &Value) -> bool {
    v.as_str().is_some_and(|x| rx::is(r"^([01]\d|2[0-3]):[0-5]\d$", x))
}

pub type TopicOf<'a> = dyn FnMut(&Value, &str) -> Option<String> + 'a;

/// Поля слоя из pendingLayer, которые ещё не перенесены: [[taskId, patch], …].
pub fn layer_patches(status: &Value, lay_tasks: &Value, mut topic_of: Option<&mut TopicOf>) -> Vec<Value> {
    let mut out = vec![];
    for (id, f) in o(&status["pendingLayer"]) {
        if t(&lay_tasks[id.as_str()]["pulled"]) {
            continue;
        }
        let mut p = Json::new();
        p.insert("pulled".into(), json!(true));
        if let Some(ty) = f["type"].as_str().and_then(type_of) {
            p.insert("type".into(), json!(ty));
        }
        if f["project"].is_string() {
            p.insert("project".into(), f["project"].clone());
        }
        if f["tags"].is_array() {
            p.insert("tags".into(), json!(a(&f["tags"]).iter().filter(|x| x.is_string()).cloned().collect::<Vec<_>>()));
        }
        if n(&f["priority"]).is_some_and(|x| x == 1.0 || x == 2.0 || x == 3.0) {
            p.insert("priority".into(), f["priority"].clone());
        }
        if f["stage"].is_string() {
            p.insert("stage".into(), f["stage"].clone());
        }
        let every = s(&f["repeat"]["every"]);
        if ["day", "weekdays", "week", "month", "year"].contains(&every) && f["repeat"].is_object() {
            p.insert("repeat".into(), json!({"every": every}));
        }
        let slot = &f["slot"];
        if slot.is_object() && is_hm(&slot["s"]) && is_hm(&slot["e"]) && s(&slot["s"]) < s(&slot["e"]) {
            p.insert("slot".into(), json!({"s": slot["s"], "e": slot["e"]}));
        } else if slot.is_object() && is_hm(&slot["s"]) && slot["e"].is_null() {
            p.insert("slot".into(), json!({"s": slot["s"], "e": plus_hour(s(&slot["s"]))}));
        }
        if let Some(col) = str_(&f["status"], 40) {
            if rx::is(r"^[\w-]+$", &col) {
                let at = f["at"].as_str().and_then(parse_any).unwrap_or_else(|| local(now()));
                p.insert("stageAt".into(), json!({col.clone(): at.timestamp_millis()}));
                p.insert("status".into(), json!(col));
                // порядок ключей как в Dart: status раньше stageAt
                let st = p.shift_remove("stageAt").unwrap();
                p.insert("stageAt".into(), st);
            }
        }
        if let Some(topic) = str_(&f["topic"], 40) {
            let tid = match topic_of.as_deref_mut() {
                Some(fun) => fun(&f["listId"], &topic),
                None => Some(topic),
            };
            if let Some(x) = tid.filter(|x| !x.is_empty()) {
                p.insert("topic".into(), json!(x));
            }
        }
        if f["pin"] == true {
            p.insert("pin".into(), json!(true));
        }
        let client = str_(&f["client"], 100);
        let money = if let Some(x) = n(&f["money"]) { Some(text(&num(x))) } else { str_(&f["money"], 40) };
        if let Some(c) = client {
            p.insert("client".into(), json!(c));
        }
        if let Some(m) = money.filter(|m| !m.is_empty()) {
            p.insert("money".into(), json!(m));
        }
        let raw: Vec<Value> = if f["remind"].is_array() { a(&f["remind"]).to_vec() } else { vec![f["remind"].clone()] };
        let rems: Vec<Value> = raw.iter().filter_map(lead).collect();
        if !rems.is_empty() {
            p.insert("remind".into(), if rems.len() > 1 { Value::Array(rems) } else { rems[0].clone() });
        }
        if let Some(sp) = n(&f["spent"]) {
            if sp.is_finite() && sp > 0.0 && sp < 1e5 {
                p.insert("spent".into(), json!((sp + 0.5).floor() as i64));
            }
        }
        if f["accept"] == true {
            p.insert("inbox".into(), json!("accepted"));
        }
        out.push(json!([id, p]));
    }
    out
}

fn slug(name: &str, taken: &mut Vec<String>) -> String {
    let b = rx::all(r"[^a-zа-я0-9]+", &norm(&json!(name)), "-");
    let b = rx::all(r"^-|-$", &b, "");
    let mut base: String = b.chars().take(24).collect();
    if base.is_empty() {
        base = "x".into();
    }
    let (mut id, mut i) = (base.clone(), 2);
    while taken.contains(&id) {
        id = format!("{base}-{i}");
        i += 1;
    }
    taken.push(id.clone());
    id
}

/// Всё, что прислали чаты, одним набором правок слоя: { spheres, lists, tasks } — каждое [[id, patch], …].
pub fn pull_patches(status: &Value, lay: &Value) -> Value {
    let mut spheres = Json::new();
    let mut lists = Json::new();
    let known = spheres_from(lay);
    let tpls = templates_from(lay);
    let colors = sphere_colors();
    let color_ids: Vec<String> = a(&colors).iter().map(|c| text(&c["id"])).collect();
    let mut sphere_ids: Vec<String> = o(&lay["spheres"]).keys().cloned().collect();
    let mut order = 0.0f64;
    for sp in &known {
        order = order.max(n(&sp["order"]).unwrap_or(0.0));
    }
    let views = views();

    let topic_list = |raw: &[Value]| -> Vec<Value> {
        let mut taken: Vec<String> = vec![];
        let mut out: Vec<Value> = vec![];
        for (i, x) in raw.iter().enumerate() {
            let nv = if x.is_string() { x.clone() } else if x.is_object() { x["name"].clone() } else { Value::Null };
            let Some(name) = str_(&nv, 40) else { continue };
            if out.iter().any(|tp| norm(&tp["name"]) == norm(&json!(name))) {
                continue;
            }
            let defs = topics_of(&Value::Null);
            let def = a(&defs).iter().find(|tp| norm(&tp["name"]) == norm(&json!(name))).cloned();
            let xc = &x["color"];
            let color = if xc.is_string() && color_ids.contains(&text(xc)) {
                xc.clone()
            } else if let Some(d) = def.as_ref().filter(|d| !d["color"].is_null()) {
                d["color"].clone()
            } else {
                json!(color_ids[i % color_ids.len()])
            };
            let tid = match &def {
                Some(d) if !taken.contains(&text(&d["id"])) => {
                    taken.push(text(&d["id"]));
                    text(&d["id"])
                }
                _ => slug(&name, &mut taken),
            };
            out.push(json!({"id": tid, "name": name, "color": color}));
        }
        out.truncate(12);
        out
    };

    for (id, f) in o(&status["pendingLists"]) {
        if !f.is_object() {
            continue;
        }
        if t(&f["at"]) && lay["lists"][id.as_str()]["pulled"] == f["at"] {
            continue;
        }
        let mut p = Json::new();
        p.insert("pulled".into(), if t(&f["at"]) { f["at"].clone() } else { json!(true) });
        if str_(&f["template"], 60).is_some() {
            if let Some(tp) = tpls.iter().find(|tp| tp["id"] == f["template"] || norm(&tp["name"]) == norm(&f["template"])) {
                p.insert("template".into(), tp["id"].clone());
            }
        }
        if a(&views).iter().any(|v| v["id"] == f["view"]) {
            p.insert("view".into(), f["view"].clone());
        }
        if let Some(sp) = str_(&f["sphere"], 40) {
            let found = known.iter().find(|k| norm(&k["name"]) == norm(&json!(sp))).map(|k| text(&k["id"]))
                .or_else(|| spheres.iter().find(|(_, v)| norm(&v["name"]) == norm(&json!(sp))).map(|(k, _)| k.clone()));
            let sid = match found {
                Some(x) => x,
                None => {
                    let nid = format!("sp-{}", slug(&sp, &mut sphere_ids));
                    let c = &f["sphereColor"];
                    let color = if c.is_string() && color_ids.contains(&text(c)) { c.clone() } else { json!(color_ids[(known.len() + spheres.len()) % color_ids.len()]) };
                    let ic = s(&f["sphereIcon"]);
                    order += 1.0;
                    spheres.insert(nid.clone(), json!({"name": sp.trim(), "color": color,
                        "icon": if ICONS.iter().any(|x| x.0 == ic) { ic } else { "star" }, "order": num(order), "removed": false}));
                    nid
                }
            };
            p.insert("sphere".into(), json!(sid));
        }
        if f["topics"].is_array() {
            let tl = topic_list(a(&f["topics"]));
            if !tl.is_empty() {
                p.insert("topics".into(), Value::Array(tl));
            }
        }
        if f["group"] == "topic" || f["group"] == "when" {
            p.insert("group".into(), f["group"].clone());
        }
        lists.insert(id.clone(), Value::Object(p));
    }

    let tasks = {
        let mut topic_of = |list_id: &Value, name: &str| -> Option<String> {
            if !t(list_id) {
                return None;
            }
            let lid = text(list_id);
            let cur: Vec<Value> = match lists.get(&lid).and_then(|l| l["topics"].as_array()) {
                Some(x) => x.clone(),
                None => a(&topics_of(&lay["lists"][lid.as_str()])).to_vec(),
            };
            if let Some(tp) = cur.iter().find(|tp| tp["id"] == name || norm(&tp["name"]) == norm(&json!(name))) {
                return Some(text(&tp["id"]));
            }
            let mut taken: Vec<String> = cur.iter().map(|tp| text(&tp["id"])).collect();
            let nt = json!({"id": slug(name, &mut taken), "name": name, "color": color_ids[cur.len() % color_ids.len()]});
            let nid = text(&nt["id"]);
            let mut all = cur;
            all.push(nt);
            let e = lists.entry(lid).or_insert_with(|| json!({}));
            e["topics"] = Value::Array(all);
            Some(nid)
        };
        layer_patches(status, &lay["tasks"], Some(&mut topic_of))
    };
    json!({
        "spheres": spheres.into_iter().map(|(k, v)| json!([k, v])).collect::<Vec<_>>(),
        "lists": lists.into_iter().map(|(k, v)| json!([k, v])).collect::<Vec<_>>(),
        "tasks": tasks,
    })
}
