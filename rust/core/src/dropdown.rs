//! Логика выпадающего списка (поиск, клавиши, подпись, место меню). Порт tracker/src/lib/dropdown.js.
use crate::j::*;

fn norm(v: &Value) -> String {
    match v {
        Value::Null => String::new(),
        Value::String(x) => x.to_lowercase().replace('ё', "е"),
        x => x.to_string().to_lowercase(),
    }
}

pub fn filter_opts(opts: &[Value], q: &str) -> Vec<Value> {
    let qn = q.to_lowercase().replace('ё', "е");
    let words: Vec<&str> = qn.split_whitespace().collect();
    if words.is_empty() {
        return opts.to_vec();
    }
    opts.iter().filter(|o| { let tt = norm(&o["label"]); words.iter().all(|w| tt.contains(w)) }).cloned().collect()
}

/// Куски названия для подсветки первого вхождения: [{ t, hit }].
pub fn marks(label: &Value, q: &str) -> Value {
    let st = match label { Value::Null => String::new(), Value::String(x) => x.clone(), x => x.to_string() };
    let k: Vec<char> = q.to_lowercase().replace('ё', "е").trim().chars().collect();
    let sc: Vec<char> = st.chars().collect();
    let low: Vec<char> = st.to_lowercase().replace('ё', "е").chars().collect();
    let i = if k.is_empty() { None } else { (0..=low.len().saturating_sub(k.len())).find(|&i| low.len() >= k.len() && low[i..i + k.len()] == k[..]) };
    let Some(i) = i else { return json!([{"t": st, "hit": false}]) };
    let part = |a: usize, b: usize| sc[a.min(sc.len())..b.min(sc.len())].iter().collect::<String>();
    let parts = [(part(0, i), false), (part(i, i + k.len()), true), (part(i + k.len(), sc.len()), false)];
    Value::Array(parts.into_iter().filter(|(x, _)| !x.is_empty()).map(|(x, h)| json!({"t": x, "hit": h})).collect())
}

fn usable(o: &Value) -> bool {
    o.is_object() && (o["disabled"].is_null() || o["disabled"] == Value::Bool(false))
}

pub fn move_active(opts: &[Value], cur: i64, key: &str) -> i64 {
    let n = opts.len() as i64;
    if !opts.iter().any(usable) {
        return -1;
    }
    if key == "Home" {
        return opts.iter().position(usable).map_or(-1, |x| x as i64);
    }
    if key == "End" {
        return opts.iter().rposition(usable).map_or(-1, |x| x as i64);
    }
    let step = if key == "ArrowUp" { -1 } else { 1 };
    let mut i = if cur < 0 { if step > 0 { -1 } else { n } } else { cur };
    for _ in 0..n {
        i = (i + step + n).rem_euclid(n);
        if usable(&opts[i as usize]) {
            return i;
        }
    }
    cur
}

pub fn jump_to(opts: &[Value], cur: i64, ch: &str) -> i64 {
    let c = ch.to_lowercase().replace('ё', "е");
    if c.trim().is_empty() {
        return cur;
    }
    let n = opts.len() as i64;
    for k in 1..=n {
        let i = ((cur.max(-1)) + k + n).rem_euclid(n);
        if usable(&opts[i as usize]) && norm(&opts[i as usize]["label"]).starts_with(&c) {
            return i;
        }
    }
    cur
}

pub fn toggle_in(values: &[Value], id: &Value, opts: &[Value]) -> Vec<Value> {
    let mut set: Vec<Value> = vec![];
    for v in values {
        if !set.contains(v) {
            set.push(v.clone());
        }
    }
    if let Some(p) = set.iter().position(|x| x == id) { set.remove(p); } else { set.push(id.clone()); }
    let order: Vec<&Value> = opts.iter().map(|o| &o["id"]).collect();
    let pos = |x: &Value| order.iter().position(|y| *y == x).map_or(-1, |p| p as i64);
    set.sort_by_key(|x| pos(x));
    set
}

pub fn button_text(opts: &[Value], value: &Value, multi: bool) -> String {
    if !multi {
        return opts.iter().find(|o| o["id"] == *value).map(|o| s(&o["label"]).to_string()).unwrap_or_default();
    }
    let vs = a(value);
    let on: Vec<String> = opts
        .iter()
        .filter(|o| vs.contains(&o["id"]))
        .map(|o| if o["short"].is_null() { s(&o["label"]) } else { s(&o["short"]) }.to_string())
        .collect();
    if on.len() <= 2 { on.join(", ") } else { format!("{}, +{}", on[..2].join(", "), on.len() - 2) }
}

/// Место меню: под кнопкой или над ней. btn — {left, top, right, bottom, width}, view — {w, h}.
pub fn place_menu(btn: &Value, h: f64, w: f64, view: &Value, gap: f64, max: f64, pad: f64) -> Value {
    let f = |v: &Value| n(v).unwrap_or(0.0);
    let (bw, vw, vh) = (f(&btn["width"]), f(&view["w"]), f(&view["h"]));
    let width = w.max(bw).min(max.max(bw)).min(vw - pad * 2.0);
    let below = vh - pad - (f(&btn["bottom"]) + gap);
    let above = f(&btn["top"]) - gap - pad;
    let up = h > below && above > below;
    let left = pad.max(f(&btn["left"]).min(vw - pad - width));
    let room = 0f64.max(if up { above } else { below });
    if up {
        json!({"left": num(left), "top": null, "bottom": num(vh - (f(&btn["top"]) - gap)), "width": num(width), "up": up, "maxH": num(room)})
    } else {
        json!({"left": num(left), "top": num(f(&btn["bottom"]) + gap), "bottom": null, "width": num(width), "up": up, "maxH": num(room)})
    }
}
