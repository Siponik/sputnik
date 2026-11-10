//! Золотые тесты: ответы взяты у настоящего JS (tools/golden/gen.mjs пишет rust/core/tests/golden/*.json).
use chrono::NaiveDate;
use serde_json::Value;
use sputnik_core::when::{parse_when, when_text};

fn load(name: &str) -> Vec<Value> {
    let p = format!("{}/tests/golden/{name}", env!("CARGO_MANIFEST_DIR"));
    serde_json::from_str(&std::fs::read_to_string(&p).expect(&p)).unwrap()
}

fn day(v: &Value) -> NaiveDate {
    let a = v.as_array().unwrap();
    NaiveDate::from_ymd_opt(a[0].as_i64().unwrap() as i32, a[1].as_u64().unwrap() as u32, a[2].as_u64().unwrap() as u32).unwrap()
}

fn s(v: &Value) -> Option<String> {
    v.as_str().map(str::to_string)
}

#[test]
fn when_parse() {
    let mut bad = vec![];
    let cases = load("when_parse.json");
    for c in &cases {
        let got = parse_when(c["text"].as_str().unwrap(), day(&c["today"]));
        let w = &c["out"];
        let ok = got.day == s(&w["day"]) && got.time == s(&w["time"]) && got.all_day == w["allDay"].as_bool().unwrap()
            && got.rest == w["rest"].as_str().unwrap();
        if !ok {
            bad.push(format!("«{}»: {:?} ≠ {}", c["text"], got, w));
        }
    }
    assert!(bad.is_empty(), "{} из {}:\n{}", bad.len(), cases.len(), bad.join("\n"));
}

#[test]
fn when_label() {
    for c in load("when_text.json") {
        let slot = c["slot"].as_object().map(|o| (o["s"].as_str().unwrap(), o["e"].as_str().unwrap()));
        let (d, t) = when_text(c["day"].as_str().unwrap_or(""), slot, day(&c["today"]));
        assert_eq!(d, c["out"]["date"].as_str().unwrap(), "{c}");
        assert_eq!(t, c["out"]["time"].as_str().unwrap(), "{c}");
    }
}
