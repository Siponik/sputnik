//! Сферы (группы списков). Порт app/lib/core/spheres.dart. Цвета — имена переменных старого трекера,
//! в интерфейсе их переводит тема (`ui`): var(--clay) → акцент и т. д.
use crate::j::*;
use crate::search::ru_compare;

pub fn sphere_colors() -> Value {
    json!([
        {"id": "clay", "name": "Глина", "v": "var(--clay)"},
        {"id": "gold", "name": "Золото", "v": "var(--gold)"},
        {"id": "work", "name": "Синий", "v": "var(--type-work)"},
        {"id": "study", "name": "Фиолетовый", "v": "var(--type-study)"},
        {"id": "personal", "name": "Зелёный", "v": "var(--type-personal)"},
        {"id": "done", "name": "Бирюзовый", "v": "var(--signal-done)"},
    ])
}

pub const ICONS: [(&str, &str, &str); 8] = [
    ("cube", "Куб", "M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5"),
    ("case", "Портфель", "M4 8h16v11H4zM9 8V5h6v3M4 13h16"),
    ("book", "Книга", "M5 4h10a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3zM5 17a3 3 0 0 1 3-3h10"),
    ("home", "Дом", "M4 11l8-7 8 7M6 10v10h12V10M10 20v-6h4v6"),
    ("users", "Люди", "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14c2 .8 3 3 3 6"),
    ("heart", "Сердце", "M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"),
    ("brush", "Кисть", "M18 3l3 3-9.5 9.5-3-3zM8.5 12.5C6 12.5 4 14.5 4 17c0 1.5-1 2.5-2 3 4 1 8-1 8-4.5"),
    ("star", "Звезда", "M12 3l2.7 5.6 6.1.8-4.4 4.3 1 6.1L12 17l-5.4 2.8 1-6.1-4.4-4.3 6.1-.8z"),
];

pub fn sphere_color(sp: &Value) -> String {
    let c = &sp["color"];
    let cs = sphere_colors();
    let x = a(&cs).iter().find(|x| x["id"] == *c).unwrap_or(&cs[0]);
    s(&x["v"]).to_string()
}

pub fn icon_path(sp: &Value) -> String {
    let id = s(&sp["icon"]);
    ICONS.iter().find(|x| x.0 == id).unwrap_or(&ICONS[7]).2.to_string()
}

fn removed(sp: &Value) -> bool {
    sp.is_object() && !sp["removed"].is_null() && sp["removed"] != Value::Bool(false)
}

/// Сферы по порядку, без удалённых: [{id, …}].
pub fn spheres_from(lay: &Value) -> Vec<Value> {
    let mut out: Vec<Value> = o(&lay["spheres"])
        .iter()
        .filter(|(_, v)| v.is_object() && !removed(v))
        .map(|(k, v)| {
            let mut m = Json::new();
            m.insert("id".into(), Value::String(k.clone()));
            for (a, b) in o(v) {
                m.insert(a.clone(), b.clone());
            }
            Value::Object(m)
        })
        .collect();
    out.sort_by(|x, y| {
        let d = n(&x["order"]).unwrap_or(0.0) - n(&y["order"]).unwrap_or(0.0);
        d.partial_cmp(&0.0).unwrap().then_with(|| ru_compare(s(&x["name"]), s(&y["name"])))
    });
    out
}

pub fn sphere_of(list_id: &str, lay: &Value) -> Option<String> {
    let id = &lay["lists"][list_id]["sphere"];
    if !t(id) {
        return None;
    }
    let sp = &lay["spheres"][s(id)];
    (!sp.is_null() && !removed(sp)).then(|| s(id).to_string())
}

/// Списки для выпадающего списка с группами по сферам.
pub fn list_choices(lists: &[Value], lay: &Value) -> Value {
    let spheres = spheres_from(lay);
    let color = |id: &str| spheres.iter().find(|x| s(&x["id"]) == id).map(sphere_color).unwrap_or_default();
    let options: Vec<Value> = lists
        .iter()
        .map(|l| {
            let sp = sphere_of(s(&l["id"]), lay);
            json!({"id": l["id"], "label": l["title"], "group": sp.clone().unwrap_or_default(),
                   "color": sp.map(|x| color(&x)).unwrap_or_else(|| "var(--ink-faint)".into())})
        })
        .collect();
    let mut used: Vec<String> = vec![];
    for x in &options {
        let g = s(&x["group"]).to_string();
        if !used.contains(&g) {
            used.push(g);
        }
    }
    let mut groups: Vec<Value> = spheres
        .iter()
        .filter(|x| used.contains(&s(&x["id"]).to_string()))
        .map(|x| json!({"id": x["id"], "name": x["name"], "color": sphere_color(x)}))
        .collect();
    if used.contains(&String::new()) && used.len() > 1 {
        groups.push(json!({"id": "", "name": "Без сферы", "color": "var(--ink-faint)"}));
    }
    json!({"options": options, "groups": if groups.is_empty() { Value::Null } else { Value::Array(groups) }})
}
