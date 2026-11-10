//! Правки черновика доски { view, fields, cols } в редакторе. Порт app/lib/core/boardedit.dart.
use crate::j::*;

pub fn field_info_list() -> Value {
    json!([
        {"id": "due", "name": "Срок", "group": "card", "what": "чип «пт» / «сегодня»"},
        {"id": "prio", "name": "Приоритет", "group": "card", "what": "!!! слева от названия и полоска"},
        {"id": "type", "name": "Тип", "group": "card", "what": "цвет полоски и чип «#работа»"},
        {"id": "subtasks", "name": "Подзадачи", "group": "card", "what": "«☑ 2 из 4» на карточке"},
        {"id": "time", "name": "Учёт времени", "group": "card", "what": "«⏱ 1 ч 15 мин», кнопка таймера"},
        {"id": "stage", "name": "Дорожка этапов", "group": "card", "what": "полоска этапов под названием"},
        {"id": "progress", "name": "Прогресс", "group": "card", "what": "«3 из 10 уроков» — для учёбы"},
        {"id": "client", "name": "Клиент", "group": "drawer", "what": "поле в окне задачи + на карточке"},
        {"id": "money", "name": "Сумма", "group": "drawer", "what": "поле в окне задачи, итог колонки"},
    ])
}

pub fn field_info(id: &Value) -> Value {
    a(&field_info_list()).iter().find(|f| f["id"] == *id).cloned().unwrap_or(Value::Null)
}

fn or0(v: &Value) -> Value {
    if v.is_null() { json!(0) } else { v.clone() }
}

pub fn draft_of(b: &Value) -> Value {
    let cols: Vec<Value> = a(&b["cols"]).iter().map(|c| json!({"id": c["id"], "name": c["name"], "color": or0(&c["color"]), "limit": or0(&c["limit"])})).collect();
    json!({"view": b["view"], "fields": a(&b["fields"]), "cols": cols})
}

/// Переставить колонку: «Готово» (последняя) не двигается, после неё ничего не встаёт.
pub fn move_col(cols: &[Value], from: i64, to: i64) -> Vec<Value> {
    let end = cols.len() as i64 - 1;
    if from == end || from < 0 || from > end {
        return cols.to_vec();
    }
    let tt = to.clamp(0, (end - 1).max(0));
    if tt == from {
        return cols.to_vec();
    }
    let mut out = cols.to_vec();
    let c = out.remove(from as usize);
    out.insert(tt as usize, c);
    out
}

pub fn recolor(c: &Value) -> Value {
    let mut m = o(c).clone();
    m.insert("color".into(), json!((int(&c["color"]).unwrap_or(0) + 1) % 7));
    Value::Object(m)
}

pub fn relimit(c: &Value, d: i64) -> Value {
    let mut m = o(c).clone();
    m.insert("limit".into(), json!((int(&c["limit"]).unwrap_or(0) + d).clamp(0, 20)));
    Value::Object(m)
}

pub fn new_col(now: u64) -> Value {
    json!({"id": format!("c{}", radix36(now)), "name": "Новая колонка", "color": 0, "limit": 0})
}

/// Удалить колонку i (задачи — в соседнюю). Null — нельзя.
pub fn drop_col(cols: &[Value], i: i64, removed: &[Value], n: i64) -> Value {
    let end = cols.len() as i64 - 1;
    if cols.len() <= 2 || i == end || i < 0 {
        return Value::Null;
    }
    let c = &cols[i as usize];
    let to = &cols[if i > 0 { i - 1 } else { i + 1 } as usize];
    let left: Vec<Value> = cols.iter().enumerate().filter(|(k, _)| *k as i64 != i).map(|(_, x)| x.clone()).collect();
    let mut rem: Vec<Value> = removed
        .iter()
        .map(|r| if r["to"] == c["id"] { spread(&[r, &json!({"to": to["id"], "toName": to["name"]})]) } else { r.clone() })
        .collect();
    rem.push(json!({"id": c["id"], "name": c["name"], "to": to["id"], "toName": to["name"], "n": n}));
    json!({"cols": left, "removed": rem})
}

pub fn toggle_field(fields: &[Value], f: &Value) -> Vec<Value> {
    if fields.contains(f) { fields.iter().filter(|x| *x != f).cloned().collect() } else { let mut v = fields.to_vec(); v.push(f.clone()); v }
}

/// «1 задача», «3 задачи», «5 задач».
pub fn word(n: i64, one: &str, few: &str, many: &str) -> String {
    let (a, b) = (n % 10, n % 100);
    let w = if a == 1 && b != 11 { one } else if (2..=4).contains(&a) && !(12..=14).contains(&b) { few } else { many };
    format!("{n} {w}")
}

pub fn tasks_word(n: i64) -> String { word(n, "задача", "задачи", "задач") }
pub fn lists_word(n: i64) -> String { word(n, "список", "списка", "списков") }

pub fn col_is_own(c: &Value, base: &[Value]) -> bool {
    match base.iter().find(|b| b["id"] == c["id"]) {
        Some(b) => text(&b["name"]).trim() != text(&c["name"]).trim(),
        None => true,
    }
}

/// Что поменялось в черновике — короткими словами.
pub fn changes(from: &Value, draft: &Value) -> Vec<String> {
    let mut out = vec![];
    let (fc, dc) = (a(&from["cols"]), a(&draft["cols"]));
    let has = |id: &Value| fc.iter().any(|c| c["id"] == *id);
    let old = |id: &Value| fc.iter().find(|c| c["id"] == *id);
    for c in dc.iter().filter(|c| !has(&c["id"])) {
        out.push(format!("колонка «{}»", text(&c["name"])));
    }
    for c in fc.iter().filter(|c| !dc.iter().any(|x| x["id"] == c["id"])) {
        out.push(format!("убрана «{}»", text(&c["name"])));
    }
    for c in dc.iter().filter(|c| has(&c["id"]) && old(&c["id"]).unwrap()["name"] != c["name"]) {
        out.push(format!("«{}»", text(&c["name"])));
    }
    let kept: Vec<String> = dc.iter().filter(|c| has(&c["id"])).map(|c| text(&c["id"])).collect();
    let was: Vec<String> = fc.iter().filter(|c| kept.contains(&text(&c["id"]))).map(|c| text(&c["id"])).collect();
    if kept.join(",") != was.join(",") {
        out.push("порядок колонок".into());
    }
    if dc.iter().any(|c| old(&c["id"]).is_some_and(|o| !same(&or0(&o["color"]), &or0(&c["color"])) || !same(&or0(&o["limit"]), &or0(&c["limit"])))) {
        out.push("цвет или лимит".into());
    }
    let f = |x: &Value| {
        let mut l: Vec<String> = a(&x["fields"]).iter().map(text).collect();
        l.sort_by(|p, q| cmp16(p, q));
        l.join(",")
    };
    if f(from) != f(draft) {
        out.push("поля".into());
    }
    if from["view"] != draft["view"] {
        out.push("вид".into());
    }
    out
}

/// Задача для превью карточки: открытая, с бо́льшим числом видимых полей.
pub fn sample_task(tasks: &[Value], lay_tasks: &Value, subs_of: impl Fn(&Value) -> usize) -> Value {
    let score = |tk: &Value| {
        let l = &lay_tasks[s(&tk["id"])];
        (if t(&tk["due"]) { 2 } else { 0 }) + (if t(&l["priority"]) { 2 } else { 0 }) + (if t(&l["type"]) { 1 } else { 0 })
            + (if subs_of(&tk["id"]) > 0 { 2 } else { 0 }) + (if t(&l["spent"]) { 1 } else { 0 }) + (if t(&l["client"]) { 1 } else { 0 })
    };
    let mut best: Option<&Value> = None;
    for tk in tasks {
        if t(&tk["parent"]) || s(&tk["status"]) == "completed" {
            continue;
        }
        if best.map_or(true, |b| score(tk) > score(b)) {
            best = Some(tk);
        }
    }
    best.cloned().unwrap_or(Value::Null)
}

pub fn preview_count(n: Option<i64>, i: i64, total: i64) -> i64 {
    n.unwrap_or(if i == 0 { 3 } else if i == total - 1 { 2 } else { 1 }).min(3)
}
