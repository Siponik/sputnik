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
