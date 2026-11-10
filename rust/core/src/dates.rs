//! Даты, как их хранит Спутник (порт помощников из tracker/src/lib/api.js).
//! День задачи — строка «ГГГГ-ММ-ДД» (местная дата); Google Tasks хранит срок как «ГГГГ-ММ-ДДT00:00:00.000Z».
use chrono::{Datelike, Duration, NaiveDate};

/// «ГГГГ-ММ-ДД».
pub fn ymd(d: NaiveDate) -> String {
    format!("{:04}-{:02}-{:02}", d.year(), d.month(), d.day())
}

/// Срок задачи из Google → «ГГГГ-ММ-ДД» (или пусто без срока).
pub fn due_to_ymd(due: Option<&str>) -> String {
    match due {
        Some(s) if s.len() >= 10 => s[..10].to_string(),
        _ => String::new(),
    }
}

/// «ГГГГ-ММ-ДД» → срок для Google.
pub fn ymd_to_due(s: &str) -> Option<String> {
    if s.is_empty() { None } else { Some(format!("{s}T00:00:00.000Z")) }
}

pub fn parse_ymd(s: &str) -> Option<NaiveDate> {
    NaiveDate::parse_from_str(s, "%Y-%m-%d").ok()
}

pub fn add_days(d: NaiveDate, n: i64) -> NaiveDate {
    d + Duration::days(n)
}

/// Дата как в JS `new Date(y, m0, d)`: выход за границы месяца переносится дальше (31 февраля → 3 марта).
pub fn js_date(y: i32, m0: i32, d: i32) -> NaiveDate {
    let y = y + m0.div_euclid(12);
    let m = m0.rem_euclid(12) as u32 + 1;
    let first = NaiveDate::from_ymd_opt(y, m, 1).expect("дата");
    first + Duration::days(d as i64 - 1)
}

/// День недели: пн = 0 … вс = 6.
pub fn dow_mon(d: NaiveDate) -> i64 {
    d.weekday().num_days_from_monday() as i64
}
