//! Общий Telegram-бот Спутника — чистая часть (запросы к боту — в data). Порт tracker/src/lib/sharedbot.js.
use crate::dates::{add_days, ymd};
use crate::habits::now;
use crate::j::*;
use crate::route::{parse_line, route};
use crate::today::task_from;
use chrono::NaiveDate;

pub const BOT_URL: &str = "https://sputnik-bot.siponikdev.workers.dev";
pub const BOT_NAME: &str = "SputnikTasksBot";
pub const BOT_LINK: &str = "https://t.me/SputnikTasksBot";

/// Ключ привязки: 32 случайных байта в hex (байты даёт вызывающий — ГСЧ живёт в приложении).
pub fn key_hex(bytes: &[u8; 32]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Открытые задачи со сроком до +7 дней (и просроченные) — для /today и /week.
pub fn snapshot(lists: &[Value], by_list: &Value, lay_tasks: &Value, today: NaiveDate) -> Vec<Value> {
    let end = ymd(add_days(today, 7));
    let mut out = vec![];
    for l in lists {
        for tk in a(&by_list[s(&l["id"])]) {
            if tk["status"] == "completed" || t(&tk["deleted"]) || t(&tk["parent"]) || !t(&tk["due"]) {
                continue;
            }
            let due = day10(&tk["due"]);
            if due > end {
                continue;
            }
            let sl = &lay_tasks[s(&tk["id"])]["slot"]["s"];
            let mut m = json!({"title": if t(&tk["title"]) { tk["title"].clone() } else { json!("Без названия") }, "due": due});
            if t(sl) {
                m["time"] = sl.clone();
            }
            m["list"] = l["title"].clone();
            out.push(m);
        }
    }
    let tm = |x: &Value| if x["time"].is_string() { text(&x["time"]) } else { "99".into() };
    out.sort_by(|a0, b0| s(&a0["due"]).cmp(s(&b0["due"])).then(tm(a0).cmp(&tm(b0))));
    out.truncate(300);
    out
}

/// Для догадки в боте: списки, основной (первый) и выученные слова settings.route → { основа: listId }.
pub fn guess_ctx(lists: &[Value], layer: &Value) -> Value {
    let mut ws: Vec<(&String, &Value)> = o(&layer["settings"]["route"])
        .iter()
        .filter(|(_, v)| v.is_object() && lists.iter().any(|l| l["id"] == v["list"]))
        .collect();
    let nn = |v: &Value| n(&v["n"]).unwrap_or(1.0);
    ws.sort_by(|a0, b0| nn(b0.1).partial_cmp(&nn(a0.1)).unwrap());
    let mut words = Json::new();
    for (k, v) in ws.into_iter().take(300) {
        words.insert(k.clone(), v["list"].clone());
    }
    json!({
        "lists": lists.iter().take(100).map(|l| json!({"id": l["id"], "title": if t(&l["title"]) { l["title"].clone() } else { json!("Без названия") }})).collect::<Vec<_>>(),
        "def": lists.first().map(|l| l["id"].clone()).unwrap_or(Value::Null),
        "words": words,
    })
}

fn cut(x: &str, n_: usize) -> String {
    x.chars().take(n_).collect()
}

/// Сообщение боту → задача для quickCreate. Без даты — без срока.
pub fn from_text(text_: &str, lists: &[Value], layer: &Value, tasks: &Value, today: NaiveDate) -> Value {
    let mut parts = text_.split('\n');
    let first = parts.next().unwrap_or("");
    let rest: Vec<&str> = parts.collect();
    let p = parse_line(first, today, &json!({}));
    if !t(&p["title"]) || lists.is_empty() {
        return Value::Null;
    }
    let src = [
        if t(&p["at"]) { format!("@{}", text(&p["at"])) } else { String::new() },
        if t(&p["tag"]) { format!("#{}", text(&p["tag"])) } else { String::new() },
        text(&p["rest"]),
    ]
    .join(" ")
    .trim()
    .to_string();
    let ms = crate::reminders::local(now()).timestamp_millis() as f64;
    let ranked = route(&src, lists, layer, tasks, None, ms);
    let top = ranked.first().cloned().unwrap_or(json!({}));
    let dest = if top["listId"].is_null() { text(&lists[0]["id"]) } else { text(&top["listId"]) };
    let mut tk = task_from(&p, &ymd(today), &dest, &top);
    tk["due"] = p["day"].clone();
    tk["notes"] = json!(rest.join("\n").trim());
    tk
}

/// Карточка из бота (поля выбраны человеком) → задача для quickCreate.
/// rem: null — по умолчанию, 'off' — без напоминания, число — за N минут до начала.
pub fn from_draft(x: &Value, lists: &[Value], layer: &Value, tasks: &Value, today: NaiveDate) -> Value {
    let base = if t(&x["src"]) { from_text(&text(&x["src"]), lists, layer, tasks, today) } else { Value::Null };
    let list_id = if lists.iter().any(|l| l["id"] == x["listId"]) {
        x["listId"].clone()
    } else if !base["listId"].is_null() {
        base["listId"].clone()
    } else {
        let tt = if x["title"].is_null() { String::new() } else { text(&x["title"]) };
        from_text(&tt, lists, layer, tasks, today)["listId"].clone()
    };
    if !t(&list_id) || !t(&x["title"]) {
        return Value::Null;
    }
    let mut l2 = o(&base["layer"]).clone();
    l2.shift_remove("topic");
    l2.shift_remove("project");
    if n(&x["prio"]).is_some_and(|p| p == 1.0 || p == 2.0 || p == 3.0) {
        l2.insert("priority".into(), x["prio"].clone());
    } else {
        l2.shift_remove("priority");
    }
    let rem = &x["rem"];
    if rem == "off" {
        l2.insert("remind".into(), Value::Null);
    } else if let Some(m) = n(rem).filter(|m| m.fract() == 0.0 && *m >= 0.0) {
        l2.insert("remind".into(), json!({"kind": "lead", "min": m as i64}));
    }
    let due = x["due"].as_str().filter(|d| crate::rx::is(r"^\d{4}-\d{2}-\d{2}$", d)).map(String::from);
    let time = s(&x["time"]);
    let slot = match &due {
        Some(_) if crate::rx::is(r"^([01]\d|2[0-3]):[0-5]\d$", time) => {
            let v = (time[..2].parse::<i64>().unwrap() * 60 + time[3..].parse::<i64>().unwrap() + 60).min(1439);
            json!({"s": time, "e": format!("{:02}:{:02}", v / 60, v % 60)})
        }
        _ => Value::Null,
    };
    json!({"title": cut(&text(&x["title"]), 250), "listId": list_id, "due": due, "slot": slot, "layer": l2,
           "notes": cut(&if x["notes"].is_null() { String::new() } else { text(&x["notes"]) }, 4000)})
}
