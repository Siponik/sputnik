//! Помощники для JSON-данных (слой, задачи Google): переносят JS-привычки в Rust.
//! `v["ключ"]` у serde_json уже даёт Null для отсутствующего ключа, поэтому здесь — только «истина» и чтение.
pub use serde_json::{json, Map, Value};

pub type Json = Map<String, Value>;
pub static NULL: Value = Value::Null;

/// «Истина» как в JS: null, false, 0, "" и NaN — ложь, остальное (в т.ч. [] и {}) — истина.
pub fn t(v: &Value) -> bool {
    match v {
        Value::Null => false,
        Value::Bool(b) => *b,
        Value::Number(n) => n.as_f64().is_some_and(|x| x != 0.0 && !x.is_nan()),
        Value::String(s) => !s.is_empty(),
        _ => true,
    }
}

/// Строка или "".
pub fn s(v: &Value) -> &str {
    v.as_str().unwrap_or("")
}

/// Число (f64), если это число.
pub fn n(v: &Value) -> Option<f64> {
    v.as_f64()
}

/// Массив или пустой срез.
pub fn a(v: &Value) -> &[Value] {
    v.as_array().map(Vec::as_slice).unwrap_or(&[])
}

/// Объект или пустой.
pub fn o(v: &Value) -> &Json {
    static EMPTY: std::sync::OnceLock<Json> = std::sync::OnceLock::new();
    v.as_object().unwrap_or_else(|| EMPTY.get_or_init(Json::new))
}

/// Первые 10 символов (срок Google → «ГГГГ-ММ-ДД»).
pub fn day10(v: &Value) -> String {
    let x = s(v);
    x.chars().take(10).collect()
}

/// Число в JSON: целые без «.0», как в JS.
pub fn num(x: f64) -> Value {
    if x.fract() == 0.0 && x.abs() < 9e15 {
        Value::from(x as i64)
    } else {
        serde_json::Number::from_f64(x).map(Value::Number).unwrap_or(Value::Null)
    }
}

/// Равенство как у JSON.stringify: числа сравниваются по значению (1 == 1.0).
pub fn same(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Number(x), Value::Number(y)) => close(x.as_f64(), y.as_f64()),
        (Value::Array(x), Value::Array(y)) => x.len() == y.len() && x.iter().zip(y).all(|(p, q)| same(p, q)),
        (Value::Object(x), Value::Object(y)) => {
            x.len() == y.len() && x.iter().zip(y.iter()).all(|((k1, v1), (k2, v2))| k1 == k2 && same(v1, v2))
        }
        _ => a == b,
    }
}

/// Равенство без учёта порядка ключей (для проверок, где порядок не важен).
pub fn same_u(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Number(x), Value::Number(y)) => close(x.as_f64(), y.as_f64()),
        (Value::Array(x), Value::Array(y)) => x.len() == y.len() && x.iter().zip(y).all(|(p, q)| same_u(p, q)),
        (Value::Object(x), Value::Object(y)) => x.len() == y.len() && x.iter().all(|(k, v)| y.get(k).is_some_and(|w| same_u(v, w))),
        _ => a == b,
    }
}

/// Сравнение строк как в JS (по кодам UTF-16).
pub fn cmp16(a: &str, b: &str) -> std::cmp::Ordering {
    a.encode_utf16().cmp(b.encode_utf16())
}

/// Числа равны до последних знаков (pow в разных языках расходится в последнем бите).
fn close(a: Option<f64>, b: Option<f64>) -> bool {
    match (a, b) {
        (Some(x), Some(y)) => x == y || (x - y).abs() <= 1e-12 * x.abs().max(y.abs()),
        _ => a == b,
    }
}

/// Наложить поля b на a (как `{...a, ...b}` в JS: существующие ключи остаются на своих местах).
pub fn extend(a: &mut Json, b: &Json) {
    for (k, v) in b {
        a.insert(k.clone(), v.clone());
    }
}

/// `{...a, ...b}` для значений-объектов.
pub fn spread(parts: &[&Value]) -> Value {
    let mut m = Json::new();
    for p in parts {
        extend(&mut m, o(p));
    }
    Value::Object(m)
}

/// Число как i64, если целое.
pub fn int(v: &Value) -> Option<i64> {
    v.as_i64().or_else(|| v.as_f64().filter(|x| x.fract() == 0.0).map(|x| x as i64))
}

/// Текст значения, как `String(v)` в JS (null → "").
pub fn text(v: &Value) -> String {
    match v {
        Value::Null => String::new(),
        Value::String(x) => x.clone(),
        Value::Number(x) => {
            let f = x.as_f64().unwrap_or(0.0);
            if f.fract() == 0.0 && f.abs() < 1e15 { format!("{}", f as i64) } else { format!("{f}") }
        }
        x => x.to_string(),
    }
}

/// Миллисекунды с эпохи из ISO-строки (как Date.parse).
pub fn parse_ms(iso: &str) -> Option<f64> {
    chrono::DateTime::parse_from_rfc3339(iso).ok().map(|d| d.timestamp_millis() as f64)
}

/// Число → строка в системе 36 (как toString(36) в JS для целых).
pub fn radix36(mut x: u64) -> String {
    if x == 0 {
        return "0".into();
    }
    let d = b"0123456789abcdefghijklmnopqrstuvwxyz";
    let mut out = vec![];
    while x > 0 {
        out.push(d[(x % 36) as usize]);
        x /= 36;
    }
    out.reverse();
    String::from_utf8(out).unwrap()
}
