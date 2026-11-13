//! Шаблоны досок, доска списка (шаблон + своя копия), перенос задач между колонками, порядок в колонке, архив.
//! Порт tracker/src/lib/templates.js. Цвета — имена переменных старого трекера (переводит тема интерфейса).
use crate::j::*;
use crate::rx;
use std::collections::HashMap;

pub fn palette() -> Value {
    json!([
        {"v": "var(--ink-faint)", "name": "серый"}, {"v": "var(--type-work)", "name": "синий"},
        {"v": "var(--clay)", "name": "глина"}, {"v": "var(--gold)", "name": "золото"},
        {"v": "var(--type-study)", "name": "фиолетовый"}, {"v": "var(--type-personal)", "name": "зелёный"},
        {"v": "var(--signal-done)", "name": "бирюзовый"},
    ])
}

pub fn col_color(c: &Value) -> String {
    let p = palette();
    let i = if c.is_object() { if c["color"].is_null() { Some(0) } else { c["color"].as_i64() } } else { Some(0) };
    match i {
        Some(i) if i >= 0 && (i as usize) < a(&p).len() => s(&p[i as usize]["v"]).into(),
        _ => s(&p[0]["v"]).into(),
    }
}

pub fn views() -> Value {
    json!([
        {"id": "kanban", "name": "Канбан", "hint": "Колонки рядом, карточки перетаскиваются. Подходит, когда задач много и они быстро двигаются."},
        {"id": "pipe", "name": "Конвейер", "hint": "Строка = задача, колонки — этапы по порядку. Для долгих задач с этапами: ассеты, большие заказы."},
        {"id": "stickers", "name": "Стикеры", "hint": "Дела-стикеры по темам или по срокам, кружок — сделано. Для простых дел без этапов: покупки, звонки, дом."},
        {"id": "list", "name": "Список", "hint": "Простой список с этапом в виде метки. Для курсов и дел, где этапов мало."},
    ])
}

pub fn fields_list() -> Value {
    json!([
        {"id": "due", "name": "Срок"}, {"id": "prio", "name": "Приоритет"}, {"id": "type", "name": "Тип"},
        {"id": "stage", "name": "Дорожка этапов"}, {"id": "subtasks", "name": "Подзадачи"},
        {"id": "time", "name": "Учёт времени"}, {"id": "progress", "name": "Прогресс (3 из 10)"},
        {"id": "client", "name": "Клиент"}, {"id": "money", "name": "Сумма"},
    ])
}

fn col(id: &str, name: &str, color: i64, limit: i64) -> Value {
    json!({"id": id, "name": name, "color": color, "limit": limit})
}

pub fn builtin() -> Value {
    json!([
        {"id": "work", "name": "Работа", "title": "Работа", "hint": "Задачи: входящие → в работе → ревью → готово",
         "view": "kanban", "fields": ["due", "prio", "type"],
         "cols": [col("inbox", "Входящие", 0, 0), col("doing", "В работе", 2, 3), col("review", "На ревью", 3, 0), col("done", "Готово", 6, 0)]},
        {"id": "client", "name": "Заказы клиентов", "title": "Заказы", "hint": "Заявка → смета → работа → правки → сдано → оплачено",
         "view": "kanban", "fields": ["due", "prio", "client", "money"],
         "cols": [col("request", "Заявка", 0, 0), col("estimate", "Смета", 3, 0), col("doing", "В работе", 2, 2), col("revise", "Правки", 4, 0), col("delivered", "Сдано", 1, 0), col("done", "Оплачено", 6, 0)]},
        {"id": "asset3d", "name": "3D-ассеты", "title": "3D-проекты", "hint": "Каждая строка — модель, этапы пайплайна по порядку",
         "view": "pipe", "fields": ["due", "stage", "subtasks", "time"],
         "cols": [col("refs", "Референсы", 0, 0), col("blockout", "Блокаут", 1, 0), col("sculpt", "Скульпт", 4, 0), col("retopo", "Ретопология", 2, 0), col("uv", "UV", 3, 0), col("textures", "Текстуры", 5, 0), col("render", "Рендер", 3, 0), col("done", "Готово", 6, 0)]},
        {"id": "personal", "name": "Личное", "title": "Личное", "hint": "Простые дела стикерами: по темам или по срокам",
         "view": "stickers", "fields": ["due"],
         "cols": [col("inbox", "Надо сделать", 0, 0), col("doing", "Делаю", 2, 3), col("done", "Готово", 6, 0)]},
        {"id": "study", "name": "Учёба", "title": "Учёба", "hint": "Курсы и уроки: в планах → прохожу → пройдено",
         "view": "list", "fields": ["due", "progress"],
         "cols": [col("inbox", "В планах", 0, 0), col("doing", "Прохожу", 4, 2), col("done", "Пройдено", 6, 0)]},
    ])
}

pub fn is_builtin(id: &Value) -> bool {
    a(&builtin()).iter().any(|x| x["id"] == *id)
}

pub fn blank_template(name: &str, now: u64) -> Value {
    json!({"name": name, "view": "kanban", "fields": ["due", "prio"],
           "cols": [col(&format!("c{}", radix36(now)), "Надо", 0, 0), col(&format!("c{}", radix36(now + 1)), "Делаю", 2, 0), col("done", "Готово", 6, 0)]})
}

fn pick(tt: &Value) -> Json {
    let mut m = Json::new();
    if !tt["name"].is_null() {
        m.insert("name".into(), tt["name"].clone());
    }
    m.insert("view".into(), tt["view"].clone());
    m.insert("fields".into(), json!(a(&tt["fields"])));
    m.insert("cols".into(), json!(a(&tt["cols"])));
    m
}

/// Все шаблоны с учётом слоя: встроенные (с правками) и свои.
pub fn templates_from(lay: &Value) -> Vec<Value> {
    let mut out = vec![];
    for b in a(&builtin()) {
        let e = &lay["templatesEdit"][s(&b["id"])];
        let mut m = o(b).clone();
        if e.is_object() && !t(&e["removed"]) {
            extend(&mut m, &pick(&spread(&[b, e])));
            m.insert("changed".into(), json!(true));
        } else {
            m.insert("changed".into(), json!(false));
        }
        out.push(Value::Object(m));
    }
    for (k, tt) in o(&lay["templates"]) {
        if !tt.is_object() || t(&tt["removed"]) || a(&tt["cols"]).is_empty() {
            continue;
        }
        let mut m = Json::new();
        m.insert("id".into(), json!(k));
        m.insert("title".into(), tt["name"].clone());
        m.insert("hint".into(), json!(a(&tt["cols"]).iter().map(|c| text(&c["name"])).collect::<Vec<_>>().join(" → ")));
        extend(&mut m, &pick(&spread(&[&json!({"view": "kanban", "fields": []}), tt])));
        m.insert("mine".into(), json!(true));
        out.push(Value::Object(m));
    }
    out
}

/// Шаблон по id; неизвестный — «Работа».
pub fn template_of(id: &Value, lay: &Value) -> Value {
    let all = templates_from(lay);
    all.iter().find(|x| x["id"] == *id).cloned().unwrap_or_else(|| all[0].clone())
}

pub fn short_name(tt: &Value) -> String {
    match s(&tt["id"]) { "work" => "работа", "client" => "заказы", "asset3d" => "3D", "personal" => "дела", "study" => "учёба", _ => "свой" }.into()
}

pub const HABITS_TEMPLATE: &str = "habits";

pub fn is_habit_list(list: &Value, lay: &Value) -> bool {
    s(&lay["lists"][s(&list["id"])]["template"]) == HABITS_TEMPLATE || rx::is(r"(?i)(^|\s)привычки$", s(&list["title"]))
}

fn ok_cols(c: &Value) -> bool {
    let v = a(c);
    v.len() >= 2 && v.last().is_some_and(|l| l.is_object() && s(&l["id"]) == "done")
}

/// Своё ли у списка (колонки или поля отвязаны от шаблона).
pub fn is_own(l: &Value) -> bool {
    l.is_object() && (ok_cols(&l["cols"]) || l["fields"].is_array())
}

/// Доска списка: шаблон с наложенной копией списка.
pub fn board_of(list_id: &str, lay: &Value) -> Value {
    let l = &lay["lists"][list_id];
    let base = template_of(&l["template"], lay);
    let cols = if ok_cols(&l["cols"]) { l["cols"].clone() } else { base["cols"].clone() };
    let fields = if l["fields"].is_array() { l["fields"].clone() } else { base["fields"].clone() };
    let view = if !l["view"].is_null() { l["view"].clone() } else if !base["view"].is_null() { base["view"].clone() } else { json!("kanban") };
    let mut m = o(&base).clone();
    m.insert("view".into(), view);
    m.insert("cols".into(), cols);
    m.insert("fields".into(), fields);
    m.insert("own".into(), json!(is_own(l)));
    m.insert("base".into(), base);
    Value::Object(m)
}

pub fn follows(list_id: &str, lay: &Value, tid: &str) -> bool {
    s(&board_of(list_id, lay)["id"]) == tid && !is_own(&lay["lists"][list_id])
}

pub fn own_patch(d: &Value) -> Value {
    let cols: Vec<Value> = a(&d["cols"])
        .iter()
        .map(|c| {
            let nm = text(&c["name"]);
            let nm = nm.trim();
            json!({"id": c["id"], "name": if nm.is_empty() { "Без названия" } else { nm },
                   "color": if c["color"].is_null() { json!(0) } else { c["color"].clone() },
                   "limit": if c["limit"].is_null() { json!(0) } else { c["limit"].clone() }})
        })
        .collect();
    json!({"view": d["view"], "fields": a(&d["fields"]), "cols": cols})
}

pub fn same_shape(x: &Value, y: &Value) -> bool {
    let f = |v: &Value| {
        let mut l: Vec<String> = a(&v["fields"]).iter().map(text).collect();
        l.sort_by(|p, q| cmp16(p, q));
        l.join(",")
    };
    own_patch(x)["cols"].to_string() == own_patch(y)["cols"].to_string() && f(x) == f(y)
}

pub fn reset_patch() -> Value {
    json!({"cols": null, "fields": null, "view": null})
}

fn norm(v: &Value) -> String {
    text(v).trim().to_lowercase().replace('ё', "е")
}

/// Куда переедут задачи при смене колонок: по названию, тот же id, по порядку; «готово» — в последнюю.
pub fn match_cols(old: &[Value], new: &[Value]) -> Json {
    let last = new.len() as i64 - 1;
    let mut out = Json::new();
    let mut by_name: HashMap<String, String> = HashMap::new();
    for c in new {
        by_name.insert(norm(&c["name"]), text(&c["id"]));
    }
    for (i, c) in old.iter().enumerate() {
        let id = text(&c["id"]);
        if id == "done" {
            out.insert(id, new[last as usize]["id"].clone());
            continue;
        }
        match by_name.get(&norm(&c["name"])) {
            Some(nn) if nn != "done" => { out.insert(id, json!(nn)); }
            _ if new.iter().any(|x| text(&x["id"]) == id && id != "done") => { out.insert(id.clone(), json!(id)); }
            _ => {
                let cap = (last - 1).max(0);
                let k = (i as i64).min(cap);
                out.insert(id, new[k as usize]["id"].clone());
            }
        }
    }
    out
}

/// Правки [{ id, status }] для задач из пропавших колонок (цепочки разворачиваются).
pub fn relocate(task_list: &Value, lay_tasks: &Value, moves: &Json) -> Vec<Value> {
    let mut out = vec![];
    for tk in a(task_list) {
        let from = &lay_tasks[s(&tk["id"])]["status"];
        if !t(from) || !moves.contains_key(&text(from)) || moves[&text(from)] == *from {
            continue;
        }
        let mut st = from.clone();
        let mut guard = 0;
        while let Some(nx) = moves.get(&text(&st)) {
            if *nx == st || guard >= 20 {
                break;
            }
            guard += 1;
            st = nx.clone();
        }
        if st != *from {
            out.push(json!({"id": tk["id"], "status": st}));
        }
    }
    out
}

pub fn lost_moves(old: &[Value], new: &[Value]) -> Json {
    let m = match_cols(old, new);
    let mut out = Json::new();
    for c in old {
        if !new.iter().any(|x| x["id"] == c["id"]) {
            out.insert(text(&c["id"]), m[&text(&c["id"])].clone());
        }
    }
    out
}

pub fn save_list_plan(lay: &Value, list_id: &str, draft: &Value, task_list: &Value, removed: &[Value]) -> Value {
    let cur = board_of(list_id, lay);
    let mut moves = lost_moves(a(&cur["cols"]), a(&draft["cols"]));
    for r in removed {
        moves.insert(text(&r["id"]), r["to"].clone());
    }
    json!({"patch": own_patch(draft), "moves": relocate(task_list, &lay["tasks"], &moves)})
}

pub fn reset_list_plan(lay: &Value, list_id: &str, task_list: &Value) -> Value {
    let cur = board_of(list_id, lay);
    let mv = lost_moves(a(&cur["cols"]), a(&cur["base"]["cols"]));
    json!({"patch": reset_patch(), "moves": relocate(task_list, &lay["tasks"], &mv)})
}

/// «Колонки из другого шаблона»: список переходит на шаблон и снова идёт за ним.
pub fn switch_plan(lay: &Value, list_id: &str, tpl: &str, task_list: &Value, mapping: &Value) -> Value {
    let cur = board_of(list_id, lay);
    let next = template_of(&json!(tpl), lay);
    let (cc, nc) = (a(&cur["cols"]), a(&next["cols"]));
    let mut map = match_cols(cc, nc);
    extend(&mut map, o(mapping));
    let ids: Vec<&Value> = nc.iter().map(|c| &c["id"]).collect();
    let last = &nc[nc.len() - 1]["id"];
    let mut moves = vec![];
    for tk in a(task_list) {
        if t(&tk["parent"]) || s(&tk["status"]) == "completed" {
            continue;
        }
        let st = &lay["tasks"][s(&tk["id"])]["status"];
        let from = if t(st) && s(st) != "done" && cc.iter().any(|c| c["id"] == *st) { st.clone() } else { cc[0]["id"].clone() };
        let mut to = map.get(&text(&from)).cloned().filter(|v| !v.is_null()).unwrap_or_else(|| nc[0]["id"].clone());
        if to == *last || !ids.contains(&&to) {
            to = nc[0]["id"].clone();
        }
        let now = if t(st) && s(st) != "done" && ids.contains(&st) { st.clone() } else { nc[0]["id"].clone() };
        if to != now {
            moves.push(json!({"id": tk["id"], "status": to}));
        }
    }
    let cf = a(&cur["fields"]);
    let fresh: Vec<Value> = a(&next["fields"]).iter().filter(|f| !cf.contains(f)).cloned().collect();
    let mut patch = Json::new();
    patch.insert("template".into(), next["id"].clone());
    extend(&mut patch, o(&reset_patch()));
    json!({"patch": patch, "moves": moves, "map": map, "fresh": fresh})
}

pub fn sorts() -> Value {
    json!([{"id": "own", "name": "Свой"}, {"id": "due", "name": "Срок"}, {"id": "prio", "name": "Приоритет"}])
}

pub fn sort_of(l: &Value) -> String {
    match s(&l["sort"]) { "due" => "due", "prio" => "prio", _ => "own" }.into()
}

fn due_key(tk: &Value) -> String {
    if t(&tk["due"]) { day10(&tk["due"]) } else { "9999".into() }
}

/// Задачи колонки в порядке списка: own — свой (tasks[id].ord, без него — приоритет), due, prio.
pub fn order_tasks(items: &[Value], lay_tasks: &Value, sort: &str) -> Vec<Value> {
    let pr = |x: &Value| crate::small::priority_rank(&lay_tasks[s(&x["id"])]["priority"]);
    let pos = |x: &Value, y: &Value| cmp16(s(&x["position"]), s(&y["position"]));
    let mut v = items.to_vec();
    match sort {
        "due" => v.sort_by(|x, y| cmp16(&due_key(x), &due_key(y)).then(pr(x).cmp(&pr(y))).then(pos(x, y))),
        "prio" => v.sort_by(|x, y| pr(x).cmp(&pr(y)).then(cmp16(&due_key(x), &due_key(y))).then(pos(x, y))),
        _ => {
            v.sort_by(|x, y| pr(x).cmp(&pr(y)).then(pos(x, y)));
            let key: Vec<f64> = v.iter().enumerate().map(|(i, x)| n(&lay_tasks[s(&x["id"])]["ord"]).unwrap_or(i as f64 - 0.5)).collect();
            let mut idx: Vec<usize> = (0..v.len()).collect();
            idx.sort_by(|&i, &j| key[i].partial_cmp(&key[j]).unwrap_or(std::cmp::Ordering::Equal));
            v = idx.into_iter().map(|i| v[i].clone()).collect();
        }
    }
    v
}

pub const ARCHIVE_AFTER: i64 = 3;

pub fn archive_days(l: &Value) -> i64 {
    match l["archive"].as_i64() { Some(x) if [0, 3, 7].contains(&x) => x, _ => ARCHIVE_AFTER }
}

pub fn is_archived(task: &Value, days: i64, now: f64) -> bool {
    if s(&task["status"]) != "completed" || !t(&task["completed"]) {
        return false;
    }
    parse_ms(s(&task["completed"])).is_some_and(|c| now - c > days as f64 * 864e5)
}
