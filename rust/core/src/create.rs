//! Окно «Создать» v2 — чистые помощники: подписи дат, день рождения, свободное время, чек-лист этапа,
//! подсказка вида, разбор строки привычки, подарок ко дню рождения. Порт app/lib/core/create.dart.
use crate::calendar::local_dt;
use crate::dates::{add_days, js_date, parse_ymd, ymd};
use crate::j::*;
use crate::rx;
use crate::stickers::bucket;
use chrono::{Datelike, NaiveDate, Timelike};

fn pd(s: &str) -> NaiveDate {
    parse_ymd(s).unwrap_or(NaiveDate::from_ymd_opt(2000, 1, 1).unwrap())
}

pub fn plus(s: &str, n: i64) -> String {
    ymd(add_days(pd(s), n))
}

pub fn to_min(s: &str) -> i64 {
    crate::calendar::to_min(s)
}

pub fn from_min(m: i64) -> String {
    let x = m.min(1439);
    format!("{:02}:{:02}", x / 60, x % 60)
}

pub fn add_min(hhmm: &str, n: i64) -> String {
    from_min(to_min(hhmm) + n)
}

const WD: [&str; 7] = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"];
const WDF: [&str; 7] = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
use crate::habits::MONTH_GEN as MONG;
use crate::reminders::MON_SHORT as MON;

fn dday(d: NaiveDate) -> usize {
    d.weekday().num_days_from_sunday() as usize
}

pub fn short_day(s: &str) -> String {
    let d = pd(s);
    format!("{}, {} {}", WD[dday(d)], d.day(), MON[d.month0() as usize])
}

pub fn long_day(s: &str) -> String {
    let d = pd(s);
    format!("{}, {} {}", WDF[dday(d)], d.day(), MONG[d.month0() as usize])
}

pub fn event_day(s: &str, today: &str) -> String {
    let d = pd(s);
    let base = format!("{} {} {}", WD[dday(d)], d.day(), MONG[d.month0() as usize]);
    if s == today {
        format!("сегодня, {base}")
    } else if s == plus(today, 1) {
        format!("завтра, {base}")
    } else {
        base
    }
}

pub fn day_month(s: &str) -> String {
    let d = pd(s);
    format!("{} {}", d.day(), MONG[d.month0() as usize])
}

pub fn weekday(s: &str) -> &'static str {
    WD[dday(pd(s))]
}

pub fn due_short(due: &str, today: &str, slot: &Value) -> String {
    if due.is_empty() {
        return String::new();
    }
    let tt = if t(&slot["s"]) { format!(", {}", s(&slot["s"])) } else { String::new() };
    if due == today {
        return format!("сегодня{tt}");
    }
    if due == plus(today, 1) {
        return format!("завтра{tt}");
    }
    if due < today {
        return "просрочено".into();
    }
    if bucket(due, today) == "week" {
        return format!("{}{tt}", weekday(due));
    }
    let d = pd(due);
    format!("{} {}{tt}", d.day(), MON[d.month0() as usize])
}

pub fn when_chip(due: &str, today: &str) -> &'static str {
    if due.is_empty() {
        return "later";
    }
    let b = bucket(due, today);
    if b == "later" { "date" } else { b }
}

// ---------- день рождения ----------

pub fn dative(name: &str) -> String {
    let n = name.trim();
    if n.is_empty() || rx::is(r"\s", n) {
        return n.into();
    }
    let cut: String = {
        let c: Vec<char> = n.chars().collect();
        c[..c.len() - 1].iter().collect()
    };
    if rx::is(r"(?i)ия$", n) {
        format!("{cut}и")
    } else if rx::is(r"(?i)[ая]$", n) {
        format!("{cut}е")
    } else if rx::is(r"(?i)[йь]$", n) {
        format!("{cut}ю")
    } else if rx::is(r"(?i)[бвгджзклмнпрстфхцчшщ]$", n) {
        format!("{n}у")
    } else {
        n.into()
    }
}

pub fn next_birthday(day: &str, today: &str) -> String {
    let (d, tt) = (pd(day), pd(today));
    let mut x = js_date(tt.year(), d.month0() as i32, d.day() as i32);
    if x < tt {
        x = js_date(tt.year() + 1, d.month0() as i32, d.day() as i32);
    }
    ymd(x)
}

pub fn age_at(year: &Value, day: &str, today: &str) -> Option<i64> {
    let y = match year {
        Value::Number(x) => x.as_f64().unwrap_or(0.0),
        Value::Null => 0.0,
        v => text(v).trim().parse::<f64>().unwrap_or(0.0),
    };
    if y == 0.0 || !(1900.0..=2100.0).contains(&y) {
        return None;
    }
    let a = next_birthday(day, today)[..4].parse::<f64>().unwrap() - y;
    if a > 0.0 && a < 130.0 { Some(a as i64) } else { None }
}

pub fn plural(n: i64, one: &str, few: &str, many: &str) -> String {
    let (a, b) = (n % 100, n % 10);
    let w = if a > 10 && a < 20 { many } else if b == 1 { one } else if b > 1 && b < 5 { few } else { many };
    format!("{n} {w}")
}

pub fn days_till(day: &str, today: &str) -> String {
    plural((pd(day) - pd(today)).num_days(), "день", "дня", "дней")
}

pub fn years(n: i64) -> String {
    plural(n, "год", "года", "лет")
}

// ---------- событие: свободно ли время ----------

struct Timed {
    a: i64,
    b: i64,
    title: Value,
}

fn timed_of(events: &[Value], day: &str) -> Vec<Timed> {
    let mut out = vec![];
    for x in events {
        let (st, en) = (s(&x["start"]["dateTime"]), s(&x["end"]["dateTime"]));
        if st.is_empty() || en.is_empty() || st.len() < 10 || en.len() < 10 {
            continue;
        }
        if &st[..10] > day || &en[..10] < day {
            continue;
        }
        let (Some(a0), Some(b0)) = (local_dt(st), local_dt(en)) else { continue };
        let am = if ymd(a0.date()).as_str() < day { 0 } else { (a0.hour() * 60 + a0.minute()) as i64 };
        let bm = if ymd(b0.date()).as_str() > day { 1440 } else { (b0.hour() * 60 + b0.minute()) as i64 };
        out.push(Timed { a: am, b: bm, title: if t(&x["summary"]) { x["summary"].clone() } else { json!("событие") } });
    }
    out
}

pub fn day_chunk(events: &[Value], day: &str, slot: &Value, title: &str, hours: i64) -> Value {
    let sm = if t(&slot["s"]) { Some(to_min(s(&slot["s"]))) } else { None };
    let start = match sm {
        None => 9,
        Some(x) => {
            let v = x / 60 - 1;
            let hi = 24 - hours;
            if v < hi { v.max(0) } else { hi.max(0) }
        }
    };
    let (from, to) = (start * 60, start * 60 + hours * 60);
    let piece = |a0: i64, b0: i64, tt: Value, mine: bool| -> Option<Value> {
        if b0 <= from || a0 >= to {
            return None;
        }
        let (lo, hi) = (a0.max(from), b0.min(to));
        let h = (hi - lo) as f64 / 60.0;
        Some(json!({"top": num((lo - from) as f64 / 60.0), "h": num(h.max(0.25)), "title": tt, "mine": mine}))
    };
    let mut items: Vec<Option<Value>> = timed_of(events, day).into_iter().map(|x| piece(x.a, x.b, x.title, false)).collect();
    if let Some(x) = sm {
        let e = if t(&slot["e"]) { to_min(s(&slot["e"])) } else { x + 60 };
        items.push(piece(x, e, json!(title), true));
    }
    json!({"hours": (0..hours).map(|i| start + i).collect::<Vec<_>>(), "items": items.into_iter().flatten().collect::<Vec<_>>()})
}

pub fn free_check(events: &[Value], day: &str, slot: &Value) -> Value {
    if !t(&slot["s"]) {
        return Value::Null;
    }
    let st = to_min(s(&slot["s"]));
    let en = to_min(if t(&slot["e"]) { s(&slot["e"]) } else { s(&slot["s"]) });
    let timed = timed_of(events, day);
    if let Some(x) = timed.iter().find(|x| x.a < en && x.b > st) {
        return json!({"clash": x.title});
    }
    let mut next: Option<&Timed> = None;
    for x in &timed {
        if x.a >= en && next.is_none_or(|nx| x.a < nx.a) {
            next = Some(x);
        }
    }
    match next {
        Some(nx) => json!({"until": from_min(nx.a)}),
        None => json!({"free": true}),
    }
}

// ---------- доски ----------

fn in_col<'a>(list_tasks: &'a [Value], lay: &'a Value, col: &'a Value, first: &'a Value) -> impl Iterator<Item = &'a Value> + 'a {
    list_tasks.iter().filter(move |tk| {
        let st = &lay[s(&tk["id"])]["status"];
        !t(&tk["parent"]) && tk["status"] != "completed" && (if st.is_null() { first } else { st }) == col
    })
}

pub fn col_count(list_tasks: &[Value], lay: &Value, col: &Value, first: &Value) -> usize {
    in_col(list_tasks, lay, col, first).count()
}

pub fn top_ord(list_tasks: &[Value], lay: &Value, col: &Value, first: &Value) -> f64 {
    let mut m = 0.0f64;
    for (i, tk) in in_col(list_tasks, lay, col, first).enumerate() {
        let o = n(&lay[s(&tk["id"])]["ord"]).unwrap_or(i as f64);
        if o < m {
            m = o;
        }
    }
    m - 1.0
}

pub fn stage_checklist(list_tasks: &[Value], lay: &Value) -> Vec<Value> {
    let mut tops: Vec<&Value> = list_tasks.iter().filter(|tk| !t(&tk["parent"])).collect();
    tops.sort_by(|a, b| s(&b["updated"]).cmp(s(&a["updated"])));
    for top in tops {
        let mut subs: Vec<&Value> = list_tasks.iter().filter(|tk| tk["parent"] == top["id"] && t(&lay[s(&tk["id"])]["stage"])).collect();
        subs.sort_by(|a, b| s(&a["position"]).cmp(s(&b["position"])));
        if !subs.is_empty() {
            return subs.iter().map(|x| json!({"title": x["title"], "stage": lay[s(&x["id"])]["stage"]})).collect();
        }
    }
    vec![]
}

pub fn initials(title: &str) -> String {
    let x = rx::all(r"(?i)[^a-zа-яё0-9]", title, "");
    let two: String = x.chars().take(2).collect();
    if two.is_empty() { "··".into() } else { two.to_uppercase() }
}

// ---------- подсказка вида ----------

fn w(re: &str) -> String {
    format!(r"(?i)(?:^|[^а-яёa-z0-9])(?:{re})(?=$|[^а-яёa-z0-9])")
}
const MEET: &str = r"созвон\S*|встреч[аиеуы]|встречу|врач\S*|к врачу|стоматолог\S*|собеседовани\S*|митинг\S*|свидани\S*|консультаци\S*";
const WITH: &str = r"(?:^|\s)(?:с|со)\s+(?:[А-ЯЁ][а-яё]+|(?:клиент|заказчик|команд|друз|друг|мам|пап|коллег|ребят)[а-яё]*)";
const HABIT: &str = r"каждый день|каждое утро|каждый вечер|ежедневно|по утрам|по вечерам|по будням|\d+\s+раза?\s+в\s+неделю";
const BDAY: &str = r"день рождени[яе]|дня рождения|днюх[аиу]|др";

pub fn suggest_kind(text_: &str, p: &Value) -> Value {
    if rx::is(&w(BDAY), text_) && t(&p["day"]) {
        return json!({"kind": "birthday", "what": "день рождения", "why": "раз в год"});
    }
    let h = rx::cap(&w(HABIT), text_);
    let every = &p["repeat"]["every"];
    if h.is_some() || every == "day" || every == "weekdays" {
        let phrase = match &h {
            Some(c) => c[0].clone().unwrap().trim().to_lowercase(),
            None => (if every == "day" { "каждый день" } else { "по будням" }).into(),
        };
        return json!({"kind": "habit", "what": "привычку", "why": format!("повторяется {phrase}")});
    }
    let (meet, with, time) = (rx::is(&w(MEET), text_), rx::is(WITH, text_), t(&p["time"]));
    if meet || (time && with) {
        let why = if time && with {
            "у неё есть время и с кем-то"
        } else if time {
            "у неё есть время"
        } else if with {
            "она с кем-то"
        } else {
            "её не отмечают сделанной"
        };
        return json!({"kind": "event", "what": "встречу", "why": why});
    }
    Value::Null
}

pub fn kind_hint(text_: &str, p: &Value, kind: &str) -> Value {
    let sg = suggest_kind(text_, p);
    if sg.is_null() || sg["kind"] == kind || kind == "birthday" || (kind == "event" && sg["kind"] == "habit") {
        return Value::Null;
    }
    sg
}

pub fn recurrence_of(rule: &Value) -> Value {
    let r = match s(&rule["every"]) {
        "day" => "FREQ=DAILY",
        "weekdays" => "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        "week" => "FREQ=WEEKLY",
        "month" => "FREQ=MONTHLY",
        "year" => "FREQ=YEARLY",
        _ => return Value::Null,
    };
    json!([format!("RRULE:{r}")])
}

// ---------- привычка: умная строка ----------

fn pp(re: &str) -> String {
    format!(r"(?i)(?:^|[^а-яёa-z0-9])({re})(?=$|[^а-яёa-z0-9])")
}
const GOAL: &str = r"(\d{1,5})\s+(стакан[а-яё]*|страниц[а-яё]*|минут[а-яё]*|мин|км|шаг[а-яё]*|раз|раза|отжиман[а-яё]*|приседан[а-яё]*|глав[а-яё]*|слов[а-яё]*)";

/// Совпадение: (from, to) в символах для группы 1, и группы.
fn find(p: &str, text_: &str) -> Option<(usize, usize, Vec<Option<String>>)> {
    let r = rx::rx(p);
    let c = r.captures(text_).ok()??;
    let g1 = c.get(1)?;
    let chars = |b: usize| text_[..b].chars().count();
    let groups = (0..c.len()).map(|i| c.get(i).map(|m| m.as_str().to_string())).collect();
    Some((chars(g1.start()), chars(g1.end()), groups))
}

pub fn parse_habit(raw: &str, off: &Value) -> Value {
    let mut out = Json::new();
    let mut marks: Vec<(usize, usize, &str)> = vec![];
    let mut toks: Vec<Value> = vec![];
    let free = |marks: &Vec<(usize, usize, &str)>, a0: usize, b0: usize| marks.iter().all(|x| b0 <= x.0 || a0 >= x.1);
    if !t(&off["freq"]) {
        let freqs: [(String, u8); 4] = [(pp(r"(\d+)\s+раза?\s+в\s+неделю"), 0), (pp("по будням"), 1), (pp("по выходным"), 2), (pp("каждый день|ежедневно"), 3)];
        for (re, k) in freqs {
            if let Some((f, to, g)) = find(&re, raw) {
                if !free(&marks, f, to) {
                    continue;
                }
                marks.push((f, to, "freq"));
                let (val, label) = match k {
                    0 => {
                        let nn: i64 = g[2].as_ref().unwrap().parse().unwrap_or(1);
                        let word = if nn % 10 >= 2 && nn % 10 <= 4 { "раза" } else { "раз" };
                        (json!({"freq": "week", "perWeek": nn.clamp(1, 6)}), format!("{} {word} в неделю", g[2].as_ref().unwrap()))
                    }
                    1 => (json!({"freq": "days", "days": [0, 1, 2, 3, 4]}), "по будням".into()),
                    2 => (json!({"freq": "days", "days": [5, 6]}), "по выходным".into()),
                    _ => (json!({"freq": "daily"}), "каждый день".into()),
                };
                extend(&mut out, o(&val));
                toks.push(json!({"k": "freq", "l": label}));
                break;
            }
        }
    }
    if !t(&off["part"]) {
        let parts = [(pp("каждое утро|по утрам|утром"), "morning", "утро"), (pp("днём|днем|после обеда"), "day", "день"),
                     (pp("каждый вечер|по вечерам|вечером|перед сном"), "evening", "вечер")];
        for (re, part, label) in parts {
            if let Some((f, to, g)) = find(&re, raw) {
                if !free(&marks, f, to) {
                    continue;
                }
                marks.push((f, to, "part"));
                out.insert("part".into(), json!(part));
                toks.push(json!({"k": "part", "l": label}));
                if !t(out.get("freq").unwrap_or(&NULL)) && rx::is(r"(?i)^кажд", g[1].as_deref().unwrap_or("")) {
                    out.insert("freq".into(), json!("daily"));
                }
                break;
            }
        }
    }
    if !t(&off["goal"]) {
        if let Some((f, to, g)) = find(&pp(GOAL), raw) {
            let nn: i64 = g[2].as_ref().unwrap().parse().unwrap_or(0);
            if nn > 1 && free(&marks, f, to) {
                marks.push((f, to, "goal"));
                let word = g[3].as_ref().unwrap().to_lowercase();
                let units = [(r"^стакан", "стаканов"), (r"^страниц", "страниц"), (r"^мин", "минут"), (r"^км$", "км"), (r"^шаг", "шагов"), (r"^раз", "раз")];
                let unit = units.iter().find(|u| rx::is(u.0, &word)).map(|u| u.1.to_string()).unwrap_or(word);
                let gn = nn.min(999);
                out.insert("goal".into(), json!({"n": gn, "unit": unit}));
                toks.insert(0, json!({"k": "goal", "l": format!("цель {gn} {unit}")}));
            }
        }
    }
    let mut idx: Vec<usize> = (0..marks.len()).collect();
    idx.sort_by(|&a0, &b0| marks[a0].0.cmp(&marks[b0].0).then(a0.cmp(&b0)));
    let chars: Vec<char> = raw.chars().collect();
    let mut name = String::new();
    let mut i = 0;
    for k in &idx {
        let mk = marks[*k];
        name += &chars[i.min(mk.0)..mk.0].iter().collect::<String>();
        name.push(' ');
        i = mk.1;
    }
    name += &chars[i.min(chars.len())..].iter().collect::<String>();
    let name = rx::all(r"\s+", &name, " ").trim().to_string();
    let mut cs = name.chars();
    let name = match cs.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + cs.as_str(),
    };
    let mut res = Json::new();
    res.insert("marks".into(), Value::Array(idx.iter().map(|k| json!({"from": marks[*k].0, "to": marks[*k].1, "kind": marks[*k].2})).collect()));
    res.insert("toks".into(), Value::Array(toks));
    extend(&mut res, &out);
    res.insert("name".into(), json!(name));
    Value::Object(res)
}

/// Значки привычки в окне «Создать» (хранятся в поле `icon`; в списке значок — первая буква, §G_CreateHabit).
pub const HABIT_ICONS: [&str; 7] = ["🏃", "💧", "✏️", "📖", "🧘", "🍎", "🌙"];

/// Частота привычки из строки или кнопок: {"kind": "daily"|"weekdays"|"days"|"week", "days"?, "perWeek"?}.
/// `manual` — выбор кнопками в том же виде, что даёт разбор строки (`parse_habit`); Null — из строки.
pub fn habit_freq_of(h: &Value, manual: &Value) -> Value {
    let src = if manual.is_object() { manual } else { h };
    let per = n(&src["perWeek"]).unwrap_or(0.0) as i64;
    if s(&src["freq"]) == "week" || per > 0 {
        return json!({"kind": "week", "perWeek": per.clamp(1, 6)});
    }
    if s(&src["freq"]) == "days" || src["days"].is_array() {
        let mut d: Vec<i64> = a(&src["days"]).iter().filter_map(|x| x.as_i64()).filter(|x| (0..=6).contains(x)).collect();
        d.sort_unstable();
        d.dedup();
        if !d.is_empty() {
            return json!({"kind": if d == [0, 1, 2, 3, 4] { "weekdays" } else { "days" }, "days": d});
        }
    }
    json!({"kind": "daily"})
}

/// Поля привычки для слоя: разбор строки + выбор кнопками (частота, часть дня, своё окно, значок).
/// `freq` — Null, если кнопками не трогали; `part` — "" — как в строке; `win` — Null, своего окна нет (оно главнее части дня).
pub fn habit_fields(h: &Value, freq: &Value, part: &str, win: &Value, icon: &str) -> Value {
    let mut f = Json::new();
    let fr = habit_freq_of(h, freq);
    match s(&fr["kind"]) {
        "weekdays" | "days" => {
            f.insert("days".into(), fr["days"].clone());
        }
        "week" => {
            f.insert("days".into(), json!([0, 1, 2, 3, 4, 5, 6]));
            f.insert("perWeek".into(), fr["perWeek"].clone());
        }
        _ => {
            f.insert("days".into(), json!([0, 1, 2, 3, 4, 5, 6]));
        }
    }
    let w = crate::habits::clean_win(win);
    if !w.is_null() {
        extend(&mut f, o(&crate::habits::win_fields(&w)));
    } else {
        let p = if part.is_empty() { s(&h["part"]) } else { part.into() };
        if crate::habits::PART_IDS.iter().any(|x| *x == p) {
            f.insert("part".into(), json!(p));
        }
    }
    if h["goal"].is_object() {
        f.insert("goal".into(), h["goal"].clone());
    }
    if !icon.is_empty() {
        f.insert("icon".into(), json!(icon));
    }
    Value::Object(f)
}

/// Год рождения из строки окна: 1900…текущий; пусто или мусор — None.
pub fn bday_year(raw: &str) -> Option<i64> {
    let t = raw.trim();
    if t.is_empty() {
        return None;
    }
    let y: i64 = t.parse().ok()?;
    let cur = crate::habits::now().date().year() as i64;
    (1900..=cur).contains(&y).then_some(y)
}

// ---------- подарок ко дню рождения ----------

pub const GIFT_DAYS: [(i64, &str); 4] = [(3, "за 3 дня"), (7, "за неделю"), (14, "за 2 недели"), (30, "за месяц")];

pub fn gift_date(bday: &str, days: i64) -> String {
    plus(bday, -days)
}

pub fn bday_name(summary: &str) -> String {
    rx::first(r"^[^\p{L}]+", summary, "").trim().to_string()
}

pub fn gifts_due(events: &[Value], today: &str) -> Vec<Value> {
    let mut out = vec![];
    for e in events {
        let p = &e["extendedProperties"]["private"];
        let g = &p["sputnikGift"];
        let days = match g {
            Value::Number(x) => x.as_f64().unwrap_or(f64::NAN),
            Value::Null => f64::NAN,
            v => text(v).trim().parse::<f64>().unwrap_or(f64::NAN),
        };
        let bday = s(&e["start"]["date"]);
        if p["sputnik"] != "birthday" || !(days > 0.0) || bday.is_empty() {
            continue;
        }
        let from = gift_date(bday, days as i64);
        if today < from.as_str() || today > bday {
            continue;
        }
        let name = bday_name(&text(&e["summary"]));
        if name.is_empty() {
            continue;
        }
        let key = if t(&e["recurringEventId"]) { text(&e["recurringEventId"]) } else { text(&e["id"]) };
        out.push(json!({"key": format!("{key}|{}", &bday[..4]), "title": format!("Подарок {}", dative(&name)), "due": from,
            "bday": bday, "listId": if t(&p["sputnikGiftList"]) { p["sputnikGiftList"].clone() } else { Value::Null }}));
    }
    out
}
