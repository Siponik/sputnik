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
