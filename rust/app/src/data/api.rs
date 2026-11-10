//! Тонкий клиент Google Tasks, Calendar и Drive (слой в appDataFolder). Всё блокирующее — только из фоновых потоков.
use super::google::{api, api_raw, Fail};
use serde_json::{json, Value};

const TASKS: &str = "https://tasks.googleapis.com/tasks/v1";
const CAL: &str = "https://www.googleapis.com/calendar/v3";
const DRIVE: &str = "https://www.googleapis.com/drive/v3";
const UPLOAD: &str = "https://www.googleapis.com/upload/drive/v3";
pub const LAYER_FILE: &str = "sputnik-layer.json";

pub type R<T> = Result<T, Fail>;

pub fn enc(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}

fn items(v: &Value) -> Vec<Value> {
    v.get("items").and_then(Value::as_array).cloned().unwrap_or_default()
}

pub fn lists() -> R<Vec<Value>> {
    Ok(items(&api("GET", &format!("{TASKS}/users/@me/lists?maxResults=100"), None)?))
}

fn pages(list: &str, filter: &str) -> R<Vec<Value>> {
    let mut out = vec![];
    let mut page: Option<String> = None;
    loop {
        let mut url = format!("{TASKS}/lists/{}/tasks?maxResults=100&{filter}", enc(list));
        if let Some(p) = &page {
            url += &format!("&pageToken={}", enc(p));
        }
        let v = api("GET", &url, None)?;
        out.extend(items(&v));
        match v.get("nextPageToken").and_then(Value::as_str) {
            Some(p) => page = Some(p.to_string()),
            None => return Ok(out),
        }
    }
}

/// Задачи списка: открытые и выполненные за последние done_days дней (для «Готово» и архива).
pub fn tasks(list: &str, done_days: i64) -> R<Vec<Value>> {
    let since = (chrono::Utc::now() - chrono::Duration::days(done_days)).format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string();
    let mut all = pages(list, "showCompleted=false")?;
    all.extend(pages(list, &format!("showCompleted=true&showHidden=true&completedMin={}", enc(&since)))?);
    let mut seen = std::collections::HashSet::new();
    all.retain(|t| seen.insert(t["id"].as_str().unwrap_or("").to_string()));
    Ok(all)
}

pub fn create_list(title: &str) -> R<Value> {
    api("POST", &format!("{TASKS}/users/@me/lists"), Some(&json!({ "title": title })))
}
pub fn rename_list(id: &str, title: &str) -> R<Value> {
    api("PATCH", &format!("{TASKS}/users/@me/lists/{}", enc(id)), Some(&json!({ "title": title })))
}
pub fn delete_list(id: &str) -> R<()> {
    api("DELETE", &format!("{TASKS}/users/@me/lists/{}", enc(id)), None).map(|_| ())
}
pub fn create_task(list: &str, body: &Value, parent: Option<&str>) -> R<Value> {
    let q = parent.map(|p| format!("?parent={}", enc(p))).unwrap_or_default();
    api("POST", &format!("{TASKS}/lists/{}/tasks{q}", enc(list)), Some(body))
}
pub fn patch_task(list: &str, id: &str, body: &Value) -> R<Value> {
    api("PATCH", &format!("{TASKS}/lists/{}/tasks/{}", enc(list), enc(id)), Some(body))
}
pub fn delete_task(list: &str, id: &str) -> R<()> {
    match api("DELETE", &format!("{TASKS}/lists/{}/tasks/{}", enc(list), enc(id)), None) {
        Err(Fail::Status(404, _)) | Err(Fail::Status(410, _)) => Ok(()),
        r => r.map(|_| ()),
    }
}

// ---------- Календарь ----------

pub fn calendars() -> R<Vec<Value>> {
    Ok(items(&api("GET", &format!("{CAL}/users/me/calendarList?maxResults=250"), None)?))
}

/// События календаря за [from, to) (ISO UTC), повторы развёрнуты.
pub fn events(cal: &str, from: &str, to: &str) -> R<Vec<Value>> {
    let mut out = vec![];
    let mut page: Option<String> = None;
    loop {
        let mut q = format!("singleEvents=true&orderBy=startTime&maxResults=250&timeMin={}&timeMax={}", enc(from), enc(to));
        if let Some(p) = &page {
            q += &format!("&pageToken={}", enc(p));
        }
        let v = api("GET", &format!("{CAL}/calendars/{}/events?{q}", enc(cal)), None)?;
        out.extend(items(&v));
        match v.get("nextPageToken").and_then(Value::as_str) {
            Some(p) => page = Some(p.to_string()),
            None => return Ok(out),
        }
    }
}

pub fn create_event(cal: &str, body: &Value) -> R<Value> {
    api("POST", &format!("{CAL}/calendars/{}/events", enc(cal)), Some(body))
}
pub fn patch_event(cal: &str, id: &str, body: &Value) -> R<Value> {
    api("PATCH", &format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(id)), Some(body))
}
pub fn put_event(cal: &str, id: &str, body: &Value) -> R<Value> {
    api("PUT", &format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(id)), Some(body))
}
pub fn delete_event(cal: &str, id: &str) -> R<()> {
    match api("DELETE", &format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(id)), None) {
        Err(Fail::Status(404, _)) | Err(Fail::Status(410, _)) => Ok(()),
        r => r.map(|_| ()),
    }
}
pub fn get_event(cal: &str, id: &str) -> R<Value> {
    api("GET", &format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(id)), None)
}
/// Все служебные записи календаря общей сферы (не развёрнутые, с удалёнными — для слияния).
pub fn all_events(cal: &str, updated_min: Option<&str>) -> R<Vec<Value>> {
    let mut out = vec![];
    let mut page: Option<String> = None;
    loop {
        let mut q = String::from("maxResults=2500&showDeleted=true&privateExtendedProperty=&sharedExtendedProperty=sputnik%3Drec");
        q = q.replace("privateExtendedProperty=&", "");
        if let Some(u) = updated_min {
            q += &format!("&updatedMin={}", enc(u));
        }
        if let Some(p) = &page {
            q += &format!("&pageToken={}", enc(p));
        }
        let v = api("GET", &format!("{CAL}/calendars/{}/events?{q}", enc(cal)), None)?;
        out.extend(items(&v));
        match v.get("nextPageToken").and_then(Value::as_str) {
            Some(p) => page = Some(p.to_string()),
            None => return Ok(out),
        }
    }
}
pub fn create_calendar(summary: &str, description: &str) -> R<Value> {
    api("POST", &format!("{CAL}/calendars"), Some(&json!({ "summary": summary, "description": description, "timeZone": "Europe/Moscow" })))
}
pub fn delete_calendar(cal: &str) -> R<()> {
    api("DELETE", &format!("{CAL}/calendars/{}", enc(cal)), None).map(|_| ())
}
pub fn share_calendar(cal: &str, email: &str, role: &str) -> R<Value> {
    api("POST", &format!("{CAL}/calendars/{}/acl?sendNotifications=true", enc(cal)),
        Some(&json!({ "role": role, "scope": { "type": "user", "value": email } })))
}
pub fn unshare_calendar(cal: &str, email: &str) -> R<()> {
    match api("DELETE", &format!("{CAL}/calendars/{}/acl/{}", enc(cal), enc(&format!("user:{email}"))), None) {
        Err(Fail::Status(404, _)) => Ok(()),
        r => r.map(|_| ()),
    }
}
pub fn add_calendar(cal: &str) -> R<Value> {
    api("POST", &format!("{CAL}/users/me/calendarList"), Some(&json!({ "id": cal, "hidden": true, "selected": false })))
}
pub fn remove_calendar(cal: &str) -> R<()> {
    api("DELETE", &format!("{CAL}/users/me/calendarList/{}", enc(cal)), None).map(|_| ())
}
/// Почта вошедшего: основной календарь называется почтой.
pub fn my_email() -> R<String> {
    let v = api("GET", &format!("{CAL}/calendars/primary"), None)?;
    Ok(v["id"].as_str().unwrap_or("").to_lowercase())
}

// ---------- Слой на Drive (appDataFolder) ----------

pub fn find_layer() -> R<Option<String>> {
    let q = enc(&format!("name='{LAYER_FILE}' and trashed=false"));
    let v = api("GET", &format!("{DRIVE}/files?spaces=appDataFolder&q={q}&fields=files(id,modifiedTime)&orderBy=modifiedTime%20desc&pageSize=10"), None)?;
    Ok(v["files"].as_array().and_then(|f| f.first()).and_then(|f| f["id"].as_str()).map(String::from))
}

pub fn pull_layer(id: &str) -> R<Value> {
    api("GET", &format!("{DRIVE}/files/{}?alt=media", enc(id)), None)
}

/// Записать слой; возвращает id файла (создаёт, если его ещё нет).
pub fn push_layer(id: Option<&str>, data: &Value) -> R<String> {
    let id = match id {
        Some(i) => i.to_string(),
        None => {
            let f = api("POST", &format!("{DRIVE}/files?fields=id"),
                Some(&json!({ "name": LAYER_FILE, "parents": ["appDataFolder"], "mimeType": "application/json" })))?;
            f["id"].as_str().unwrap_or("").to_string()
        }
    };
    api_raw("PATCH", &format!("{UPLOAD}/files/{}?uploadType=media", enc(&id)), Some((data.to_string().into_bytes(), "application/json")))?;
    Ok(id)
}
