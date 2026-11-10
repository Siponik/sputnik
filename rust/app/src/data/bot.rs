//! Общий Telegram-бот Спутника (bot/, Cloudflare Workers) — сеть. Ключ привязки — в слое settings.tgbot.key.
use serde_json::{json, Value};
use sputnik_core::sharedbot::BOT_URL;
use std::time::Duration;

fn call(path: &str, method: &str, key: &str, body: Option<&Value>) -> Result<Value, String> {
    let agent = ureq::AgentBuilder::new().timeout(Duration::from_secs(15)).build();
    let mut req = agent.request(method, &format!("{BOT_URL}{path}"));
    if !key.is_empty() {
        req = req.set("Authorization", &format!("Bearer {key}"));
    }
    let res = match body {
        Some(b) => req.send_json(b.clone()),
        None => req.call(),
    };
    match res {
        Ok(r) => Ok(r.into_json().unwrap_or(Value::Null)),
        Err(ureq::Error::Status(c, r)) => {
            let v: Value = r.into_json().unwrap_or(Value::Null);
            Err(v["error"].as_str().map(String::from).unwrap_or_else(|| format!("Бот ответил {c}")))
        }
        Err(_) => Err("Бот не отвечает — проверь интернет".into()),
    }
}

pub fn link(code: &str, key: &str) -> Result<Value, String> {
    let digits: String = code.chars().filter(|c| c.is_ascii_digit()).collect();
    call("/link", "POST", "", Some(&json!({ "code": digits, "key": key, "tz": "Europe/Moscow" })))
}
pub fn test(key: &str) -> Result<(), String> {
    call("/test", "POST", key, None).map(|_| ())
}
pub fn unlink(key: &str) -> Result<(), String> {
    call("/unlink", "POST", key, None).map(|_| ())
}
pub fn inbox(key: &str) -> Result<Value, String> {
    call("/inbox", "GET", key, None)
}
pub fn ack(key: &str, ids: &[Value]) -> Result<(), String> {
    call("/ack", "POST", key, Some(&json!({ "ids": ids }))).map(|_| ())
}
/// Напоминания и задачи на неделю (тело уже собрано: { items, today, tz, lists, def, words }).
pub fn push(key: &str, body: &Value) -> Result<(), String> {
    call("/state", "PUT", key, Some(body)).map(|_| ())
}
