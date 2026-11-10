//! Какие задачи показывать в «Сегодня» (порт app/lib/core/today_tasks.dart):
//! открытые со сроком сегодня или раньше (просроченные выше), потом по приоритету слоя (1 высокий … 3 низкий, нет — 2).
use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct TodayTask {
    pub id: String,
    pub list_id: String,
    pub title: String,
    /// «ГГГГ-ММ-ДД» или пусто.
    pub day: String,
    pub done: bool,
}

pub fn priority(layer: &Value, id: &str) -> i64 {
    layer.pointer(&format!("/tasks/{}/priority", id.replace('~', "~0").replace('/', "~1")))
        .and_then(Value::as_f64)
        .map(|p| p as i64)
        .unwrap_or(2)
}

/// Задачи на сегодня: срок ≤ today; порядок — день, приоритет, исходный порядок (сортировка устойчивая).
pub fn today_tasks(all: &[TodayTask], layer: &Value, today: &str) -> Vec<TodayTask> {
    let mut list: Vec<TodayTask> =
        all.iter().filter(|x| !x.day.is_empty() && x.day.as_str() <= today).cloned().collect();
    list.sort_by(|a, b| a.day.cmp(&b.day).then(priority(layer, &a.id).cmp(&priority(layer, &b.id))));
    list
}

/// Показывать ли список в «Сегодня»: не «Привычки», не скрытый, не «тихий», не удалённый.
pub fn show_list(id: &str, title: &str, layer: &Value) -> bool {
    if title.trim() == "Привычки" {
        return false;
    }
    match layer.get("lists").and_then(|l| l.get(id)) {
        Some(Value::Object(r)) => ![ "hidden", "quiet", "gone"].iter().any(|k| r.get(*k) == Some(&Value::Bool(true))),
        _ => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn t(id: &str, day: &str) -> TodayTask {
        TodayTask { id: id.into(), list_id: "l".into(), title: id.into(), day: day.into(), done: false }
    }

    #[test]
    fn order_and_filter() {
        let layer = json!({"tasks": {"b": {"priority": 1}}});
        let got = today_tasks(&[t("a", "2026-11-10"), t("b", "2026-11-10"), t("c", "2026-11-09"), t("d", ""), t("e", "2026-11-11")], &layer, "2026-11-10");
        let ids: Vec<_> = got.iter().map(|x| x.id.as_str()).collect();
        assert_eq!(ids, ["c", "b", "a"]);
    }

    #[test]
    fn lists() {
        let layer = json!({"lists": {"q": {"quiet": true}, "h": {"hidden": false}}});
        assert!(!show_list("x", " Привычки ", &layer));
        assert!(!show_list("q", "Работа", &layer));
        assert!(show_list("h", "Дом", &layer));
        assert!(show_list("n", "Дом", &layer));
    }
}

// ---------- строка быстрого добавления (порт app/lib/core/today.dart) ----------
use crate::j::{self, json};

/// #тег → тип задачи (старые русские теги тоже).
pub fn type_tag(tag: &str) -> Option<&'static str> {
    Some(match tag {
        "asset" | "ассет" => "creative",
        "work" | "client" | "работа" | "клиент" => "work",
        "study" | "учеба" | "учёба" => "study",
        "personal" | "личное" => "personal",
        _ => return None,
    })
}

fn type_of(p: &Value) -> Option<&'static str> {
    if j::t(&p["tag"]) { type_tag(&j::s(&p["tag"]).to_lowercase()) } else { None }
}

fn to_min(x: &str) -> i64 {
    let mut it = x.split(':').map(|v| v.parse::<i64>().unwrap_or(0));
    it.next().unwrap_or(0) * 60 + it.next().unwrap_or(0)
}

pub fn hhmm(m: i64) -> String {
    format!("{:02}:{:02}", m / 60, m % 60)
}

/// Чипы «Понял:» [{ kind, text }].
pub fn understood(p: &Value, today: &str) -> Vec<Value> {
    if !p.is_object() || !j::t(&p["title"]) {
        return vec![];
    }
    let day = if p["day"].is_null() { today.to_string() } else { j::s(&p["day"]).to_string() };
    let date = if day == today {
        "сегодня".to_string()
    } else {
        crate::when::when_text(&day, None, crate::dates::parse_ymd(today).unwrap()).0.to_lowercase()
    };
    let when = if j::t(&p["time"]) { format!("{date} · {}", j::s(&p["time"])) } else { date };
    let mut out = vec![json!({"kind": "when", "text": when})];
    let pr = crate::small::priority_of(&p["priority"]);
    if !pr.is_null() {
        out.push(json!({"kind": "prio", "text": format!("{} {}", j::s(&pr["mark"]), j::s(&pr["label"]).to_lowercase())}));
    }
    if j::t(&p["repeat"]) {
        out.push(json!({"kind": "repeat", "text": format!("↻ {}", crate::repeat::repeat_label(&p["repeat"]))}));
    }
    if let Some(ty) = type_of(p) {
        out.push(json!({"kind": "type", "text": format!("#{}", crate::small::type_label(&json!(ty)))}));
    }
    out
}

/// Задача из строки: { title, listId, due, slot, layer }.
pub fn task_from(p: &Value, today: &str, dest: &str, r: &Value) -> Value {
    let mut layer = j::Json::new();
    if let Some(ty) = type_of(p) {
        layer.insert("type".into(), json!(ty));
    }
    let tag = j::s(&p["tag"]).to_lowercase();
    if tag == "client" || tag == "клиент" {
        layer.insert("tags".into(), json!(["client"]));
    }
    if j::t(&p["priority"]) {
        layer.insert("priority".into(), p["priority"].clone());
    }
    if j::t(&p["repeat"]) {
        layer.insert("repeat".into(), p["repeat"].clone());
    }
    if j::s(&r["listId"]) == dest && j::t(&r["topic"]) {
        layer.insert("topic".into(), r["topic"].clone());
    }
    if j::s(&r["listId"]) == dest && j::t(&r["project"]) {
        layer.insert("project".into(), r["project"].clone());
    }
    let slot = if j::t(&p["time"]) {
        let m = to_min(j::s(&p["time"]));
        json!({"s": p["time"], "e": hhmm(if m + 60 < 1439 { m + 60 } else { 1439 })})
    } else {
        Value::Null
    };
    let due = if p["day"].is_null() { json!(today) } else { p["day"].clone() };
    let mut out = j::Json::new();
    if !p["title"].is_null() {
        out.insert("title".into(), p["title"].clone());
    }
    for (k, v) in [("listId", json!(dest)), ("due", due), ("slot", slot), ("layer", Value::Object(layer))] {
        out.insert(k.into(), v);
    }
    Value::Object(out)
}
