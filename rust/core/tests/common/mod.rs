// Общий запуск золотых тестов: каждый случай { fn, …, out } — ответ настоящего JS.
#![allow(dead_code)]
use serde_json::Value;

pub fn load(name: &str) -> Vec<Value> {
    let p = format!("{}/tests/golden/{name}", env!("CARGO_MANIFEST_DIR"));
    serde_json::from_str(&std::fs::read_to_string(&p).expect(&p)).unwrap()
}

/// Прогнать все случаи файла; f возвращает Some(ответ) или None, если функция не перенесена (это ошибка).
pub fn run(name: &str, mut f: impl FnMut(&str, &Value) -> Option<Value>) {
    run_with(name, |c| c["out"].clone(), |fname, c| f(fname, c), sputnik_core::j::same)
}

pub fn run_u(name: &str, mut f: impl FnMut(&str, &Value) -> Option<Value>) {
    run_with(name, |c| c["out"].clone(), |fname, c| f(fname, c), sputnik_core::j::same_u)
}

fn run_with(
    name: &str,
    want: impl Fn(&Value) -> Value,
    mut f: impl FnMut(&str, &Value) -> Option<Value>,
    eq: fn(&Value, &Value) -> bool,
) {
    let cases = load(name);
    let mut bad = vec![];
    for (i, c) in cases.iter().enumerate() {
        let fname = c["fn"].as_str().unwrap_or("");
        let w = want(c);
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| f(fname, c))) {
            Ok(Some(got)) if eq(&got, &w) => {}
            Ok(Some(got)) => bad.push(format!("#{i} {fname}: получил {got}\n   ждал {w}\n   вход {c}")),
            Ok(None) => bad.push(format!("#{i} {fname}: не перенесено")),
            Err(_) => bad.push(format!("#{i} {fname}: паника, вход {c}")),
        }
    }
    let shown: Vec<_> = bad.iter().take(12).cloned().collect();
    assert!(bad.is_empty(), "{name}: {} из {} не совпали\n{}", bad.len(), cases.len(), shown.join("\n"));
}
