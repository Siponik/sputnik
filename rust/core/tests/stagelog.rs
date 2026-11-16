use chrono::{Local, TimeZone};
use serde_json::json;
use sputnik_core::stagelog as sl;

fn ms(y: i32, m: u32, d: u32) -> f64 {
    Local.with_ymd_and_hms(y, m, d, 12, 0, 0).unwrap().timestamp_millis() as f64
}

#[test]
fn log_and_spans() {
    let mut log = json!([]);
    log = sl::push(&log, "sketch", ms(2026, 11, 10));
    log = sl::push(&log, "sketch", ms(2026, 11, 11));
    assert_eq!(log.as_array().unwrap().len(), 1, "тот же этап подряд не пишется");
    log = sl::push(&log, "block", ms(2026, 11, 12));
    let sp = sl::spans(&log, ms(2026, 11, 15));
    assert_eq!(sp.len(), 2);
    assert_eq!(sp[0]["days"], 2);
    assert_eq!(sp[0]["from"], "2026-11-10");
    assert_eq!(sp[0]["to"], "2026-11-12");
    assert_eq!(sp[1]["days"], 3);
    assert_eq!(sp[1]["cur"], true);
    assert_eq!(sl::total_days(&log, ms(2026, 11, 15)), 5);
    // назад и снова вперёд — дни этапа складываются
    log = sl::push(&log, "sketch", ms(2026, 11, 15));
    log = sl::push(&log, "block", ms(2026, 11, 16));
    assert_eq!(sl::days_in(&log, "sketch", ms(2026, 11, 17)), 3);
    assert_eq!(sl::total_days(&json!([]), ms(2026, 11, 17)), 0);
}
