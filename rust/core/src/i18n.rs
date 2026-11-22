//! Язык интерфейса. Исходный текст — русский; перевод — файл `rust/i18n/en/LC_MESSAGES/sputnik.po`
//! (один на Slint и Rust). В разметке строки оборачиваются в `@tr("…")` (Slint берёт перевод из того же .po,
//! без контекста), в Rust — в `t!("…")` / `t!("… {} …", x)`. Устройство и правила — docs/i18n.md.
//!
//! Переводятся только подписи на экране. Слова, которые программа разбирает (когда, @список, #тип),
//! id и названия, которые уходят в Google, — не трогать.
use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU8, Ordering};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Lang {
    Ru,
    En,
}

static LANG: AtomicU8 = AtomicU8::new(0);

pub fn set_lang(l: Lang) {
    LANG.store(if l == Lang::En { 1 } else { 0 }, Ordering::Relaxed);
}

pub fn lang() -> Lang {
    if LANG.load(Ordering::Relaxed) == 1 { Lang::En } else { Lang::Ru }
}

pub fn is_en() -> bool {
    lang() == Lang::En
}

/// Настройка `settings.lang.v` («ru» | «en» | «sys») + язык системы (как «en-US») → язык.
pub fn pick(setting: &str, system: Option<&str>) -> Lang {
    match setting {
        "en" => Lang::En,
        "ru" => Lang::Ru,
        _ => match system.map(|s| s.to_lowercase()) {
            // русский и близкие — по-русски, всё остальное — по-английски
            Some(s) if ["ru", "be", "uk", "kk"].iter().any(|p| s.starts_with(p)) => Lang::Ru,
            Some(_) => Lang::En,
            None => Lang::Ru,
        },
    }
}

/// Код для `slint::select_bundled_translation`: "" — исходный (русский).
pub fn slint_code(l: Lang) -> &'static str {
    if l == Lang::En { "en" } else { "" }
}

pub const PO: &str = include_str!("../../i18n/en/LC_MESSAGES/sputnik.po");

static EN: Lazy<HashMap<String, &'static str>> = Lazy::new(|| {
    let mut m = HashMap::new();
    for (id, s) in parse_po(PO) {
        if !s.is_empty() {
            m.insert(id, &*Box::leak(s.into_boxed_str()));
        }
    }
    m
});

/// Перевод строки на текущий язык; нет перевода — исходная строка.
pub fn tr(ru: &str) -> &str {
    if !is_en() {
        return ru;
    }
    EN.get(ru).copied().unwrap_or(ru)
}

/// Есть ли перевод (для тестов и проверки покрытия).
pub fn has(ru: &str) -> bool {
    EN.contains_key(ru)
}

/// Подставляет аргументы по порядку вместо `{}` (и `{0}`, `{1}` — по номеру).
pub fn fill(pat: &str, args: &[String]) -> String {
    let mut out = String::with_capacity(pat.len() + 16);
    let mut next = 0;
    let mut rest = pat;
    while let Some(i) = rest.find('{') {
        out.push_str(&rest[..i].replace("}}", "}"));
        let tail = &rest[i..];
        if tail.starts_with("{{") {
            out.push('{');
            rest = &tail[2..];
            continue;
        }
        let Some(j) = tail.find('}') else { out.push_str(tail); return out };
        let inner = &tail[1..j];
        let idx = if inner.is_empty() { next += 1; Some(next - 1) } else { inner.parse::<usize>().ok() };
        match idx.and_then(|k| args.get(k)) {
            Some(a) => out.push_str(a),
            None => out.push_str(&tail[..=j]),
        }
        rest = &tail[j + 1..];
    }
    out.push_str(&rest.replace("}}", "}"));
    out
}

/// `t!("Текст")` → перевод; `t!("Ошибка: {}", e)` → перевод с подстановкой (`{}` по порядку).
/// Переменные внутри скобок (`{e}`) не поддерживаются — только `{}` и `{0}`.
#[macro_export]
macro_rules! t {
    ($s:literal) => { $crate::i18n::tr($s) };
    ($s:literal, $($a:expr),+ $(,)?) => { $crate::i18n::fill($crate::i18n::tr($s), &[$(($a).to_string()),+]) };
}

/// Множественное число. Ключ перевода — три русские формы через «|» («задача|задачи|задач»),
/// перевод — две английские («task|tasks»).
pub fn plural<'a>(k: i64, forms: [&'a str; 3]) -> &'a str {
    if is_en() {
        let key = forms.join("|");
        if let Some(en) = EN.get(&key) {
            let mut it = en.split('|');
            let one = it.next().unwrap_or("");
            let many = it.next().unwrap_or(one);
            return if k.abs() == 1 { one } else { many };
        }
    }
    let (a, b) = (k.abs() % 10, k.abs() % 100);
    if a == 1 && b != 11 {
        forms[0]
    } else if (2..=4).contains(&a) && !(12..=14).contains(&b) {
        forms[1]
    } else {
        forms[2]
    }
}

// ---- даты ----

const RU_MONTHS: [&str; 12] = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
const RU_MONTHS_GEN: [&str; 12] = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
const RU_MONTHS_SHORT: [&str; 12] = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
const EN_MONTHS: [&str; 12] = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const EN_MONTHS_SHORT: [&str; 12] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
// дни недели с понедельника
const RU_WD: [&str; 7] = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
const RU_WD_FULL: [&str; 7] = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"];
const EN_WD: [&str; 7] = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
const EN_WD3: [&str; 7] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const EN_WD_FULL: [&str; 7] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

/// Месяц (0–11) как в заголовке: «Ноябрь» / «November».
pub fn month(m0: usize) -> &'static str {
    let m0 = m0 % 12;
    if is_en() { EN_MONTHS[m0] } else { RU_MONTHS[m0] }
}

/// Месяц после числа: «ноября» / «November».
pub fn month_gen(m0: usize) -> &'static str {
    let m0 = m0 % 12;
    if is_en() { EN_MONTHS[m0] } else { RU_MONTHS_GEN[m0] }
}

/// Короткий месяц после числа: «ноя» / «Nov».
pub fn month_short(m0: usize) -> &'static str {
    let m0 = m0 % 12;
    if is_en() { EN_MONTHS_SHORT[m0] } else { RU_MONTHS_SHORT[m0] }
}

/// День недели коротко (0 — понедельник): «Пн» / «Mo».
pub fn wd(d0: usize) -> &'static str {
    let d0 = d0 % 7;
    if is_en() { EN_WD[d0] } else { RU_WD[d0] }
}

/// То же, но 0 — воскресенье (как `weekday().num_days_from_sunday()`).
pub fn wd_sun(d0: usize) -> &'static str {
    wd((d0 + 6) % 7)
}

/// Короткий месяц: в английском «Nov», в русском — свой вариант из `ru` (бывает «нояб.» или «ноя»).
pub fn month_abbr(m0: usize, ru: &[&'static str; 12]) -> &'static str {
    if is_en() { EN_MONTHS_SHORT[m0 % 12] } else { ru[m0 % 12] }
}

/// День недели тремя буквами в английском («Mon»), в русском — как `wd` («Пн»).
pub fn wd3(d0: usize) -> &'static str {
    let d0 = d0 % 7;
    if is_en() { EN_WD3[d0] } else { RU_WD[d0] }
}

/// День недели полностью: «понедельник» / «Monday».
pub fn wd_full(d0: usize) -> &'static str {
    let d0 = d0 % 7;
    if is_en() { EN_WD_FULL[d0] } else { RU_WD_FULL[d0] }
}

/// Число и месяц: «12 ноября» / «Nov 12».
pub fn day_month(day: u32, m0: usize) -> String {
    if is_en() { format!("{} {}", EN_MONTHS_SHORT[m0 % 12], day) } else { format!("{} {}", day, RU_MONTHS_GEN[m0 % 12]) }
}

/// Месяц и год: «Ноябрь 2026» / «November 2026».
pub fn month_year(m0: usize, year: i32) -> String {
    format!("{} {}", month(m0), year)
}

/// Промежуток дней: «16 – 22 ноября», «30 ноября – 6 декабря» / «Nov 16 – 22», «Nov 30 – Dec 6».
pub fn day_range(d1: u32, m1: usize, d2: u32, m2: usize) -> String {
    if m1 % 12 == m2 % 12 {
        if is_en() { format!("{} {} – {}", EN_MONTHS_SHORT[m1 % 12], d1, d2) } else { format!("{} – {} {}", d1, d2, RU_MONTHS_GEN[m2 % 12]) }
    } else {
        format!("{} – {}", day_month(d1, m1), day_month(d2, m2))
    }
}

// ---- .po ----

/// Разбор gettext .po: пары (msgid, msgstr). Множественные формы (`msgid_plural`) Slint'а — по `msgstr[0]`.
/// Записи с `msgctxt` тоже берутся (контекст для Rust не важен).
pub fn parse_po(src: &str) -> Vec<(String, String)> {
    #[derive(PartialEq)]
    enum F { None, Id, Str, Other }
    let mut out = Vec::new();
    let (mut id, mut st, mut f) = (String::new(), String::new(), F::None);
    let mut have = false;
    let flush = |id: &mut String, st: &mut String, have: &mut bool, out: &mut Vec<(String, String)>| {
        if *have && !id.is_empty() {
            out.push((std::mem::take(id), std::mem::take(st)));
        }
        id.clear();
        st.clear();
        *have = false;
    };
    for line in src.lines() {
        let l = line.trim();
        if l.is_empty() || l.starts_with('#') {
            continue;
        }
        if let Some(r) = l.strip_prefix("msgctxt ") {
            flush(&mut id, &mut st, &mut have, &mut out);
            let _ = r;
            f = F::Other;
        } else if let Some(r) = l.strip_prefix("msgid ") {
            if f != F::Other {
                flush(&mut id, &mut st, &mut have, &mut out);
            }
            id = unq(r);
            have = true;
            f = F::Id;
        } else if l.starts_with("msgid_plural ") {
            f = F::Other;
        } else if let Some(r) = l.strip_prefix("msgstr[0] ").or_else(|| l.strip_prefix("msgstr ")) {
            st = unq(r);
            f = F::Str;
        } else if l.starts_with("msgstr[") {
            f = F::Other;
        } else if l.starts_with('"') {
            match f {
                F::Id => id.push_str(&unq(l)),
                F::Str => st.push_str(&unq(l)),
                _ => {}
            }
        }
    }
    flush(&mut id, &mut st, &mut have, &mut out);
    out
}

fn unq(s: &str) -> String {
    let s = s.trim();
    let s = s.strip_prefix('"').unwrap_or(s);
    let s = s.strip_suffix('"').unwrap_or(s);
    let mut o = String::with_capacity(s.len());
    let mut it = s.chars();
    while let Some(c) = it.next() {
        if c == '\\' {
            match it.next() {
                Some('n') => o.push('\n'),
                Some('t') => o.push('\t'),
                Some(x) => o.push(x),
                None => {}
            }
        } else {
            o.push(c);
        }
    }
    o
}
