//! Окно «Создать» v2: умная строка и авто-определение списка (очки, без ИИ). Порт app/lib/core/route.dart.
//!   parse_line(строка, today, off) → { title, rest, day, time, priority, repeat, at, tag, marks }
//!   route(текст, lists, layer, tasks, current, now) → [{ listId, score, why, topic?, project? }]
//!   learn(route, title, listId, topic) → новые записи settings.route
use crate::j::*;
use crate::repeat::take_repeat;
use crate::rx;
use crate::stickers::topics_of;
use crate::templates::board_of;
use crate::when::parse_when;
use chrono::NaiveDate;

fn norm(s: &str) -> String {
    s.to_lowercase().replace('ё', "е")
}
const STOP: [&str; 24] = ["для", "над", "под", "про", "или", "это", "того", "чтобы", "надо", "нужно", "потом", "когда", "после", "перед",
    "через", "около", "возле", "всех", "всем", "свой", "свою", "своё", "мне", "тебе"];
const SPLIT: &str = r"[^a-zа-я0-9]+";

/// Значимые слова: без предлогов и коротких, строчными, ё = е.
pub fn words(text: &str) -> Vec<String> {
    rx::rx(SPLIT).split(&norm(text)).filter_map(|w| w.ok()).filter(|w| w.chars().count() >= 4 && !STOP.contains(w)).map(String::from).collect()
}

fn all_words(text: &str) -> Vec<String> {
    rx::rx(SPLIT).split(&norm(text)).filter_map(|w| w.ok()).filter(|w| w.chars().count() >= 2).map(String::from).collect()
}

/// Основа слова — первые 5 букв.
pub fn stem(w: &str) -> String {
    norm(w).chars().take(5).collect()
}

/// Одно слово в разных формах: общее начало не короче 4 букв.
pub fn same_word(a: &str, b: &str) -> bool {
    let (a, b): (Vec<char>, Vec<char>) = (a.chars().collect(), b.chars().collect());
    let n = a.len().min(b.len());
    let mut i = 0;
    while i < n && a[i] == b[i] {
        i += 1;
    }
    i >= 4 || (i == n && n >= 3)
}

// ---------- умная строка ----------

pub fn parse_line(raw: &str, today: NaiveDate, off: &Value) -> Value {
    let mut txt = format!(" {raw} ");
    let mut found: Vec<(String, &str)> = vec![];
    let mut cut = |txt: &mut String, p: &str, kind: &'static str| -> Option<String> {
        let c = rx::cap(p, txt)?;
        let m0 = c[0].clone().unwrap();
        let g = c.get(2).cloned().flatten().or(c[1].clone()).unwrap_or_default();
        found.push((g.clone(), kind));
        *txt = txt.replacen(&m0, if m0.starts_with(' ') { " " } else { "" }, 1);
        Some(g)
    };
    let (mut at, mut tag, mut priority, mut repeat) = (Value::Null, Value::Null, Value::Null, Value::Null);
    if !t(&off["at"]) {
        if let Some(g) = cut(&mut txt, r"(\s)(@[^\s@]+)", "at") {
            at = json!(g.chars().skip(1).collect::<String>());
        }
    }
    if !t(&off["prio"]) {
        if let Some(g) = cut(&mut txt, r"(\s)(!{1,3})(?=\s)", "prio") {
            priority = json!(4 - g.len() as i64);
        }
    }
    if !t(&off["tag"]) {
        if let Some(g) = cut(&mut txt, r"(\s)(#[^\s#]+)", "tag") {
            tag = json!(g.chars().skip(1).collect::<String>());
        }
    }
    if !t(&off["repeat"]) {
        let (rule, rest) = take_repeat(&txt);
        if !rule.is_null() {
            repeat = rule;
            for g in diff_words(&txt, &rest) {
                found.push((g, "when"));
            }
            txt = format!(" {rest} ");
        }
    }
    let (mut day, mut time) = (Value::Null, Value::Null);
    if !t(&off["when"]) {
        let w = parse_when(&txt, today);
        day = w.day.map(Value::from).unwrap_or(Value::Null);
        time = w.time.map(Value::from).unwrap_or(Value::Null);
        for g in diff_words(&txt, &w.rest) {
            found.push((g, "when"));
        }
        txt = w.rest;
    }
    let rest = rx::all(r"\s+", &txt, " ").trim().to_string();
    let mut ch = rest.chars();
    let title = match ch.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + ch.as_str(),
    };
    json!({"title": title, "rest": rest, "day": day, "time": time, "priority": priority, "repeat": repeat,
           "at": at, "tag": tag, "marks": locate(raw, &found)})
}

fn ws(s: &str) -> Vec<&str> {
    s.split_whitespace().collect()
}

fn diff_words(a: &str, b: &str) -> Vec<String> {
    let (aw, bw) = (ws(a), ws(b));
    let mut out = vec![];
    let mut j = 0;
    let mut cur: Vec<&str> = vec![];
    for w in aw {
        if j < bw.len() && bw[j] == w {
            j += 1;
            if !cur.is_empty() {
                out.push(cur.join(" "));
                cur.clear();
            }
        } else {
            cur.push(w);
        }
    }
    if !cur.is_empty() {
        out.push(cur.join(" "));
    }
    out
}

fn index_of(hay: &[char], needle: &[char], from: usize) -> Option<usize> {
    if needle.is_empty() {
        return if from <= hay.len() { Some(from) } else { None };
    }
    (from..=hay.len().saturating_sub(needle.len())).find(|&i| i + needle.len() <= hay.len() && hay[i..i + needle.len()] == *needle)
}

fn lower_chars(s: &str) -> Vec<char> {
    s.chars().map(|c| c.to_lowercase().next().unwrap_or(c)).collect()
}

fn locate(raw: &str, found: &[(String, &str)]) -> Vec<Value> {
    let lower = lower_chars(raw);
    let rawc: Vec<char> = raw.chars().collect();
    let mut marks: Vec<(usize, usize, String)> = vec![];
    for (text, kind) in found {
        let needle = lower_chars(&rx::all(r"\s+", text, " "));
        let mut pos = 0;
        let from = loop {
            let f = if pos <= lower.len() { index_of(&lower, &needle, pos) } else { None };
            match f {
                Some(f) if marks.iter().any(|m| f < m.1 && f + needle.len() > m.0) => pos = f + 1,
                _ => break f,
            }
        };
        let Some(from) = from else { continue };
        marks.push((from, from + needle.len(), kind.to_string()));
    }
    let mut idx: Vec<usize> = (0..marks.len()).collect();
    idx.sort_by(|&a, &b| marks[a].0.cmp(&marks[b].0).then(a.cmp(&b)));
    let mut out: Vec<(usize, usize, String)> = vec![];
    for k in idx {
        let m = &marks[k];
        if let Some(last) = out.last_mut() {
            let between: String = if m.0 <= last.1 { String::new() } else { rawc[last.1..m.0].iter().collect() };
            if last.2 == m.2 && between.trim().is_empty() {
                last.1 = m.1;
                continue;
            }
        }
        out.push(m.clone());
    }
    out.into_iter().map(|(f, to, k)| json!({"from": f, "to": to, "kind": k})).collect()
}

// ---------- словари ----------

const WORK: &[&str] = &["клиент", "смет", "макет", "правк", "ревью", "созвон", "бриф", "счет", "заказ"];
pub fn dict(tpl: &str) -> &'static [&'static str] {
    match tpl {
        "asset3d" => &["lowpoly", "highpoly", "ретоп", "скульпт", "uv", "развертк", "текстур", "запек", "рендер", "модел", "ассет", "пропс", "блокаут"],
        "work" | "client" => WORK,
        "study" => &["урок", "курс", "лекци", "глав", "конспект"],
        "personal" => &["купить", "забрать", "оплатить", "позвонить", "записаться", "продлить", "убрать", "почистить", "починить", "подарок"],
        _ => &[],
    }
}

pub fn topic_words(name: &str) -> &'static [&'static str] {
    match name {
        "покупки" => &["купи", "куплю", "заказа", "забра", "посылк"],
        "звонки" => &["позвон", "набра", "напис"],
        "здоровье" => &["врач", "стоматолог", "анализ", "=зал"],
        "документы" => &["продл", "полис", "паспорт", "налог", "оплат"],
        "дом" => &["убра", "почист", "почин", "постира"],
        _ => &[],
    }
}

fn hit(w: &str, e: &str) -> bool {
    match e.strip_prefix('=') {
        Some(x) => w == x,
        None => w.starts_with(e),
    }
}

pub fn tag_tpl(tag: &str) -> &'static [&'static str] {
    match tag {
        "asset" | "ассет" => &["asset3d"],
        "work" | "работа" => &["work", "client"],
        "client" | "клиент" => &["client", "work"],
        "study" | "учеба" => &["study"],
        "personal" | "личное" => &["personal"],
        _ => &[],
    }
}

const W_AT: f64 = 1000.0;
const W_TAG: f64 = 8.0;
const W_LEARN: f64 = 6.0;
const W_WORD: f64 = 4.0;
const W_TOPIC: f64 = 3.0;
const W_SIM: f64 = 3.0;
const W_SIM_MAX: f64 = 4.0;
const W_PROJECT: f64 = 4.0;
const W_CURRENT: f64 = 2.0;
const MIN_SCORE: f64 = 4.0;
const MONTH: f64 = 30.0 * 864e5;

pub fn view_of(list_id: &str, layer: &Value) -> String {
    s(&board_of(list_id, layer)["view"]).to_string()
}

/// Проекты списка (Конвейер) по частоте.
pub fn projects_of(list_tasks: &Value, lay_tasks: &Value) -> Vec<String> {
    let mut n: Vec<(String, i64)> = vec![];
    for tk in a(list_tasks) {
        if t(&tk["parent"]) {
            continue;
        }
        let p = &lay_tasks[s(&tk["id"])]["project"];
        if t(p) {
            let p = text(p);
            match n.iter_mut().find(|x| x.0 == p) {
                Some(x) => x.1 += 1,
                None => n.push((p, 1)),
            }
        }
    }
    let mut idx: Vec<usize> = (0..n.len()).collect();
    idx.sort_by(|&a, &b| n[b].1.cmp(&n[a].1).then(a.cmp(&b)));
    idx.into_iter().map(|i| n[i].0.clone()).collect()
}

/// «@раб» → список: точное совпадение, начало названия, часть названия.
pub fn find_list<'a>(lists: &'a [Value], word: &str) -> Option<&'a Value> {
    let k = |s: &str| rx::all(r"[\s\-_·.]+", &norm(s), "");
    let w = k(word);
    if w.is_empty() {
        return None;
    }
    let tests: [&dyn Fn(&str) -> bool; 3] = [&|x| x == w, &|x| x.starts_with(&w), &|x| x.contains(&w)];
    for test in tests {
        if let Some(l) = lists.iter().find(|l| test(&k(s(&l["title"])))) {
            return Some(l);
        }
    }
    None
}

#[derive(Default)]
struct R {
    list_id: Value,
    score: f64,
    i: usize,
    parts: Vec<(&'static str, f64)>,
    learn_word: Option<String>,
    topic: Value,
    topic_word: String,
    topic_learn: bool,
    word: Option<String>,
    sim_n: usize,
    title_hit: bool,
    project: Option<String>,
    project_word: String,
}
impl R {
    fn add(&mut self, k: &'static str, pts: f64) {
        self.score += pts;
        match self.parts.iter_mut().find(|p| p.0 == k) {
            Some(p) => p.1 += pts,
            None => self.parts.push((k, pts)),
        }
    }
    fn part(&self, k: &str) -> f64 {
        self.parts.iter().find(|p| p.0 == k).map(|p| p.1).unwrap_or(0.0)
    }
}

pub fn route(text_: &str, lists: &[Value], layer: &Value, tasks: &Value, current: Option<&str>, now: f64) -> Vec<Value> {
    if lists.is_empty() {
        return vec![];
    }
    let at = rx::cap(r"(?:^|\s)@([^\s@]+)", text_).and_then(|c| c[1].clone());
    let at_list = at.as_deref().and_then(|w| find_list(lists, w));
    let tag_m = rx::cap(r"(?:^|\s)#([^\s#]+)", text_).and_then(|c| c[1].clone());
    let tag_t: &[&str] = tag_m.as_deref().map(|x| tag_tpl(&norm(x))).unwrap_or(&[]);
    let stripped = rx::all(r"(?:^|\s)[@#]\S+", text_, " ");
    let ws = words(&stripped);
    let allw = all_words(&stripped);
    let learned = &layer["settings"]["route"];
    let lay_tasks = &layer["tasks"];
    let cur = current.unwrap_or("\u{0}");

    let mut out: Vec<R> = vec![];
    for (i, l) in lists.iter().enumerate() {
        let lid = s(&l["id"]);
        let mut r = R { list_id: l["id"].clone(), i, ..Default::default() };
        let board = board_of(lid, layer);
        let tpl = s(&board["id"]).to_string();
        let view = s(&board["view"]).to_string();
        if at_list.is_some_and(|x| x["id"] == l["id"]) {
            r.add("at", W_AT);
        }
        if tag_t.contains(&tpl.as_str()) {
            r.add("tag", if tag_t[0] == tpl { W_TAG } else { W_TAG / 2.0 });
        }
        for w in &ws {
            let e = &learned[stem(w).as_str()];
            if e.is_object() && e["list"] == l["id"] {
                let nn = n(&e["n"]).unwrap_or(1.0);
                r.add("learn", W_LEARN + 2.0 * nn.min(5.0));
                if r.learn_word.is_none() {
                    r.learn_word = Some(w.clone());
                }
                if t(&e["topic"]) && !t(&r.topic) {
                    r.topic = e["topic"].clone();
                    r.topic_word = w.clone();
                    r.topic_learn = true;
                }
            }
        }
        for w in &allw {
            if dict(&tpl).iter().any(|e| hit(w, e)) {
                r.add("word", W_WORD);
                if r.word.is_none() {
                    r.word = Some(w.clone());
                }
            }
        }
        if view == "stickers" {
            let topics = topics_of(&layer["lists"][lid]);
            'outer: for w in &allw {
                for tp in a(&topics) {
                    let nm = norm(s(&tp["name"]));
                    if same_word(w, &nm) || topic_words(&nm).iter().any(|e| hit(w, e)) {
                        r.add("word", W_TOPIC);
                        if r.word.is_none() {
                            r.word = Some(w.clone());
                        }
                        if !t(&r.topic) {
                            r.topic = tp["id"].clone();
                            r.topic_word = w.clone();
                        }
                        break 'outer;
                    }
                }
            }
        }
        let title_words = words(s(&l["title"]));
        let mut known = title_words.clone();
        for tk in a(&tasks[lid]) {
            if t(&tk["parent"]) {
                continue;
            }
            if tk["status"] == "completed" {
                let d = if !tk["completed"].is_null() { &tk["completed"] } else { &tk["updated"] };
                if !parse_ms(s(d)).is_some_and(|ms| ms > now - MONTH) {
                    continue;
                }
            }
            known.extend(words(s(&tk["title"])));
        }
        let sim: Vec<&String> = ws.iter().filter(|w| known.iter().any(|k| same_word(w, k))).collect();
        r.sim_n = sim.len();
        r.title_hit = sim.iter().any(|w| title_words.iter().any(|k| same_word(w, k)));
        if !sim.is_empty() {
            r.add("sim", W_SIM * (sim.len() as f64).min(W_SIM_MAX));
        }
        if view == "pipe" {
            for p in projects_of(&tasks[lid], lay_tasks) {
                let pw = words(&p);
                if let Some(h) = ws.iter().find(|w| pw.iter().any(|k| same_word(w, k))) {
                    r.add("project", W_PROJECT);
                    r.project_word = h.clone();
                    r.project = Some(p);
                    break;
                }
            }
        }
        if lid == cur {
            r.add("current", W_CURRENT);
        }
        out.push(r);
    }
    let is_cur = |r: &R| (s(&r.list_id) == cur) as i32;
    out.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap().then(is_cur(b).cmp(&is_cur(a))).then(a.i.cmp(&b.i)));
    let own = |r: &R| r.score - r.part("current");
    if own(&out[0]) < MIN_SCORE {
        if let Some(k) = out.iter().position(|r| s(&r.list_id) == cur) {
            let x = out.remove(k);
            out.insert(0, x);
        }
    }
    out.iter()
        .enumerate()
        .map(|(i, r)| {
            let mut m = json!({"listId": r.list_id, "score": num(r.score),
                "why": why_of(r, i == 0 && own(r) < MIN_SCORE, at.as_deref(), tag_m.as_deref())});
            let mm = m.as_object_mut().unwrap();
            if t(&r.topic) {
                mm.insert("topic".into(), r.topic.clone());
                let w = if r.topic_learn { format!("запомнил «{}»", r.topic_word) } else { format!("по слову «{}»", r.topic_word) };
                mm.insert("topicWhy".into(), json!(w));
            }
            if let Some(p) = &r.project {
                mm.insert("project".into(), json!(p));
                mm.insert("projectWord".into(), json!(r.project_word));
            }
            m
        })
        .collect()
}

fn why_of(r: &R, weak: bool, at: Option<&str>, tag: Option<&str>) -> String {
    let has = |k: &str| r.part(k) != 0.0;
    if has("at") {
        return format!("указано @{}", at.unwrap_or(""));
    }
    if has("tag") {
        return format!("указано #{}", tag.unwrap_or(""));
    }
    let def = || if has("current") { "текущая доска" } else { "по умолчанию" }.to_string();
    if weak {
        return def();
    }
    if has("learn") {
        return format!("запомнил «{}»", r.learn_word.as_deref().unwrap_or(""));
    }
    if (r.sim_n >= 3 && r.title_hit) || (has("sim") && !has("word")) {
        return "похоже на задачи этой доски".into();
    }
    if has("word") {
        return format!("по слову «{}»", r.word.as_deref().unwrap_or(""));
    }
    if has("project") {
        return format!("проект «{}»", r.project.as_deref().unwrap_or(""));
    }
    def()
}

/// Обучение: 1–2 значимых слова названия → записи settings.route.
pub fn learn(current: &Value, title: &str, list_id: &str, topic: &Value) -> Value {
    let mut out = Json::new();
    for w in words(title).into_iter().take(2) {
        let k = stem(&w);
        let e = &current[k.as_str()];
        let same = e.is_object() && e["list"] == list_id;
        let mut m = json!({"list": list_id});
        if t(topic) {
            m["topic"] = topic.clone();
        }
        m["n"] = if same { num(n(&e["n"]).unwrap_or(1.0) + 1.0) } else { json!(1) };
        out.insert(k, m);
    }
    Value::Object(out)
}
