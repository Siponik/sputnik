//! Google Tasks: списки и открытые задачи, отметка «сделано», новая задача.
use crate::google::api;
use serde_json::{json, Value};
use sputnik_core::dates::due_to_ymd;
use sputnik_core::today::TodayTask;

const BASE: &str = "https://tasks.googleapis.com/tasks/v1";

#[derive(Clone, Debug)]
pub struct List {
    pub id: String,
    pub title: String,
}

fn enc(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}

fn items(v: &Value) -> Vec<Value> {
    v.get("items").and_then(Value::as_array).cloned().unwrap_or_default()
}

/// Все списки и их открытые задачи (без подзадач — в «Сегодня» их нет). Страницы Google — по 100.
pub fn fetch_all() -> Result<(Vec<List>, Vec<TodayTask>), String> {
    let lists: Vec<List> = items(&api("GET", &format!("{BASE}/users/@me/lists?maxResults=100"), None)?)
        .iter()
        .map(|l| List { id: s(l, "id"), title: s(l, "title") })
        .collect();
    let mut tasks = vec![];
    for l in &lists {
        let mut page = String::new();
        loop {
            let mut url = format!("{BASE}/lists/{}/tasks?maxResults=100&showCompleted=false", enc(&l.id));
            if !page.is_empty() {
                url += &format!("&pageToken={}", enc(&page));
            }
            let v = api("GET", &url, None)?;
            for t in items(&v) {
                if t.get("parent").is_some() || s(&t, "title").trim().is_empty() {
                    continue;
                }
                tasks.push(TodayTask {
                    id: s(&t, "id"),
                    list_id: l.id.clone(),
                    title: s(&t, "title"),
                    day: due_to_ymd(t.get("due").and_then(Value::as_str)),
                    done: false,
                });
            }
            match v.get("nextPageToken").and_then(Value::as_str) {
                Some(p) => page = p.to_string(),
                None => break,
            }
        }
    }
    Ok((lists, tasks))
}

fn s(v: &Value, k: &str) -> String {
    v.get(k).and_then(Value::as_str).unwrap_or("").to_string()
}

pub fn set_done(list: &str, id: &str, done: bool) -> Result<(), String> {
    let body = if done {
        json!({ "status": "completed" })
    } else {
        json!({ "status": "needsAction", "completed": null })
    };
    api("PATCH", &format!("{BASE}/lists/{}/tasks/{}", enc(list), enc(id)), Some(&body)).map(|_| ())
}

/// Новая задача в списке; возвращает её id.
pub fn create(list: &str, title: &str, day: &str) -> Result<String, String> {
    let mut body = json!({ "title": title });
    if let Some(d) = sputnik_core::dates::ymd_to_due(day) {
        body["due"] = json!(d);
    }
    let v = api("POST", &format!("{BASE}/lists/{}/tasks", enc(list)), Some(&body))?;
    Ok(s(&v, "id"))
}

// Кэш: те же поля, что и в памяти.
pub fn to_cache(lists: &[List], tasks: &[TodayTask]) -> Value {
    json!({
        "lists": lists.iter().map(|l| json!({"id": l.id, "title": l.title})).collect::<Vec<_>>(),
        "tasks": tasks.iter().map(|t| json!({"id": t.id, "list": t.list_id, "title": t.title, "day": t.day})).collect::<Vec<_>>(),
    })
}

pub fn from_cache(v: &Value) -> (Vec<List>, Vec<TodayTask>) {
    let arr = |k: &str| v.get(k).and_then(Value::as_array).cloned().unwrap_or_default();
    (
        arr("lists").iter().map(|l| List { id: s(l, "id"), title: s(l, "title") }).collect(),
        arr("tasks")
            .iter()
            .map(|t| TodayTask { id: s(t, "id"), list_id: s(t, "list"), title: s(t, "title"), day: s(t, "day"), done: false })
            .collect(),
    )
}
