//! «Когда» словами → день и время. Порт tracker/src/lib/when.js (через app/lib/core/when.dart).
//!   parse_when("завтра 15:00", today)   → day «2026-10-21», time «15:00», rest «»
//!   parse_when("скетч в пятницу 17.30") → day <ближайшая пятница>, time «17:30», rest «скетч»
use crate::dates::{add_days, dow_mon, js_date, ymd};
use chrono::{Datelike, NaiveDate};
use fancy_regex::{Captures, Regex};
use once_cell::sync::Lazy;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct When {
    /// «ГГГГ-ММ-ДД».
    pub day: Option<String>,
    /// «ЧЧ:ММ».
    pub time: Option<String>,
    pub all_day: bool,
    /// Нераспознанная часть текста.
    pub rest: String,
}

fn re(s: &str) -> Regex {
    Regex::new(s).expect("регулярка")
}

static WEEK: Lazy<Vec<Regex>> = Lazy::new(|| {
    [
        r"^(понедельник[ау]?|пн)$",
        r"^(вторник[ау]?|вт)$",
        r"^(сред[аеуы]|ср)$",
        r"^(четверг[ау]?|чт)$",
        r"^(пятниц[аеуы]|пт)$",
        r"^(суббот[аеуы]|сб)$",
        r"^(воскресень[еяю]|вс)$",
    ]
    .iter()
    .map(|s| re(s))
    .collect()
});
static WEEK_WORD: Lazy<Regex> = Lazy::new(|| {
    re(r"(?i)(?:^|\s)(?:(?:в|во|до|к|ко|на)\s+)?(понедельник[ау]?|вторник[ау]?|сред[аеуы]|четверг[ау]?|пятниц[аеуы]|суббот[аеуы]|воскресень[еяю]|пн|вт|ср|чт|пт|сб|вс)(?=\s|$|[,.!?])")
});
static ALL_DAY: Lazy<Regex> = Lazy::new(|| re(r"(?i)\s(весь день)(?=\s)"));
static TIME_COLON: Lazy<Regex> = Lazy::new(|| re(r"\s(?:(?:в|к|до)\s)?([01]?\d|2[0-3]):([0-5]\d)(?=\s|[,.!?]\s)"));
static TIME_DOT: Lazy<Regex> = Lazy::new(|| re(r"\s(?:в\s)?([6-9]|0[6-9]|1\d|2[0-3])\.([0-5][05])(?=\s|[,!?]\s)"));
static TIME_HOUR: Lazy<Regex> = Lazy::new(|| {
    re(r"(?i)\sв\s([01]?\d|2[0-3])(?:\s?(?:часов|часа|час|ч))?(?=\s)(?!\s*(?:янв|фев|мар|апр|ма|июн|июл|авг|сен|окт|ноя|дек))")
});
static AFTER2: Lazy<Regex> = Lazy::new(|| re(r"(?i)\s(?:(?:на|до|к)\s)?(послезавтра)(?=\s|[,.!?])"));
static TOMORROW: Lazy<Regex> = Lazy::new(|| re(r"(?i)\s(?:(?:на|до|к)\s)?(завтра)(?=\s|[,.!?])"));
static TODAY: Lazy<Regex> = Lazy::new(|| re(r"(?i)\s(?:(?:на|до|к)\s)?(сегодня)(?=\s|[,.!?])"));
static IN_N: Lazy<Regex> =
    Lazy::new(|| re(r"(?i)\sчерез\s(\d{1,3}|неделю|день)\s?(дн[еяй]+|день|недел[июь]+)?(?=\s|[,.!?])"));
static DAY_MONTH: Lazy<Regex> = Lazy::new(|| {
    re(r"(?i)\s(\d{1,2})\s(янв|фев|мар|апр|мая|май|июн|июл|авг|сен|окт|ноя|дек)[а-я]*\.?(?=\s|[,!?])")
});
static DAY_DOT: Lazy<Regex> = Lazy::new(|| re(r"\s(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?(?=\s|[,!?])"));
static SPACES: Lazy<Regex> = Lazy::new(|| re(r"\s+"));
static WEEK_UNIT: Lazy<Regex> = Lazy::new(|| re(r"(?i)недел"));
static MAY: Lazy<Regex> = Lazy::new(|| re(r"^ма[йя]"));

const MONTHS: [&str; 12] = ["янв", "фев", "мар", "апр", "ма", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
const MONTHS_GEN: [&str; 12] = [
    "января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря",
];
const WDS: [&str; 7] = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"];

fn hhmm(h: &str, m: &str) -> String {
    format!("{:0>2}:{m}", h)
}

fn g<'a>(c: &'a Captures, i: usize) -> &'a str {
    c.get(i).map(|m| m.as_str()).unwrap_or("")
}

/// Найти, обработать и вырезать первое совпадение (как `t.replace(m[0], ' ')` в JS — первое вхождение строки).
fn take(t: &mut String, r: &Regex, mut f: impl FnMut(&Captures)) -> bool {
    let Ok(Some(c)) = r.captures(t) else { return false };
    let whole = c.get(0).unwrap().as_str().to_string();
    f(&c);
    *t = t.replacen(&whole, " ", 1);
    true
}

/// «25 окт» без года — ближайшее такое число: в этом году или, если уже прошло, в следующем.
fn nearest(base: NaiveDate, month0: i32, date: i32) -> NaiveDate {
    let d = js_date(base.year(), month0, date);
    if d < base { js_date(base.year() + 1, month0, date) } else { d }
}

pub fn parse_when(text: &str, today: NaiveDate) -> When {
    let mut t = format!(" {} ", SPACES.replace_all(text, " "));
    let base = today;
    let mut day: Option<NaiveDate> = None;
    let mut time: Option<String> = None;
    let mut all_day = false;

    take(&mut t, &ALL_DAY, |_| all_day = true);
    let _ = take(&mut t, &TIME_COLON, |c| time = Some(hhmm(g(c, 1), g(c, 2))))
        || take(&mut t, &TIME_DOT, |c| time = Some(hhmm(g(c, 1), g(c, 2))))
        || take(&mut t, &TIME_HOUR, |c| time = Some(hhmm(g(c, 1), "00")));

    let _ = take(&mut t, &AFTER2, |_| day = Some(add_days(base, 2)))
        || take(&mut t, &TOMORROW, |_| day = Some(add_days(base, 1)))
        || take(&mut t, &TODAY, |_| day = Some(base))
        || take(&mut t, &IN_N, |c| {
            let unit = g(c, 2);
            let n = match g(c, 1) {
                "неделю" => 7,
                "день" => 1,
                v => v.parse::<i64>().unwrap_or(0) * if WEEK_UNIT.is_match(unit).unwrap_or(false) { 7 } else { 1 },
            };
            day = Some(add_days(base, n));
        })
        || take(&mut t, &DAY_MONTH, |c| {
            let k = g(c, 2).to_lowercase();
            let mi = if MAY.is_match(&k).unwrap_or(false) {
                4
            } else {
                let p: String = k.chars().take(3).collect();
                MONTHS.iter().position(|m| *m == p).map(|i| i as i32).unwrap_or(-1)
            };
            day = Some(nearest(base, mi, g(c, 1).parse().unwrap_or(1)));
        })
        || take(&mut t, &DAY_DOT, |c| {
            let d: i32 = g(c, 1).parse().unwrap_or(1);
            let m: i32 = g(c, 2).parse().unwrap_or(1);
            day = Some(match c.get(3).map(|x| x.as_str()) {
                Some(y) => {
                    let y: i32 = if y.len() == 2 { format!("20{y}").parse().unwrap() } else { y.parse().unwrap() };
                    js_date(y, m - 1, d)
                }
                None => nearest(base, m - 1, d),
            });
        })
        || take(&mut t, &WEEK_WORD, |c| {
            let w = g(c, 1).to_lowercase();
            let i = WEEK.iter().position(|r| r.is_match(&w).unwrap_or(false)).map(|i| i as i64).unwrap_or(-1);
            let diff = (i - dow_mon(base) + 7).rem_euclid(7);
            day = Some(add_days(base, if diff == 0 { 7 } else { diff }));
        });

    if all_day {
        time = None;
    }
    When { day: day.map(ymd), time, all_day, rest: SPACES.replace_all(&t, " ").trim().to_string() }
}

/// Подпись поля «Срок»: («Завтра, 21 октября», «15:00–16:00» | «весь день» | «»).
pub fn when_text(day: &str, slot: Option<(&str, &str)>, today: NaiveDate) -> (String, String) {
    let Some(x) = crate::dates::parse_ymd(day) else { return ("Без срока".into(), String::new()) };
    let diff = (x - today).num_days();
    let wd = WDS[dow_mon(x) as usize];
    let rel = match diff {
        0 => "Сегодня".to_string(),
        1 => "Завтра".to_string(),
        2 => "Послезавтра".to_string(),
        -1 => "Вчера".to_string(),
        _ => {
            let mut c = wd.chars();
            let f = c.next().unwrap().to_uppercase().collect::<String>();
            f + c.as_str()
        }
    };
    let year = if x.year() != today.year() { format!(" {}", x.year()) } else { String::new() };
    let time = match slot {
        Some((s, e)) if !s.is_empty() => format!("{s}–{e}"),
        _ => "весь день".to_string(),
    };
    (format!("{rel}, {} {}{year}", x.day(), MONTHS_GEN[x.month0() as usize]), time)
}
