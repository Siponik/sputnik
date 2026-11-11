//! Общая сфера — чистая логика без запросов. Порт tracker/src/lib/sharedcore.js.
//! Сфера живёт в своём Google Календаре; каждая запись (сфера, список, задача, участник) — служебное событие
//! с JSON { v, k, f: { поле: значение }, ft: { поле: время, мс } }. Слияние по полям: побеждает свежая правка.
//! «Нет поля» (undefined в JS) = ключа нет в объекте; null = поле очищено.
use crate::j::*;
use crate::rx;
use crate::search::ru_compare;
use chrono::{Datelike, Local, TimeZone, Timelike};

pub const MARK: &str = "sputnik-sphere";
pub const SUMMARY: &str = "Спутник · служебная запись";
pub const PREFIX: &str = "sh:";
pub const NOTES_MAX: usize = 6000;
pub const SPHERE_FIELDS: [&str; 3] = ["name", "color", "icon"];
pub const SPHERE_KEY: &str = "s0000000000000000";
pub const MEMBER_COLORS: [&str; 6] = ["var(--clay)", "var(--type-study)", "var(--type-work)", "var(--type-personal)", "var(--gold)", "var(--signal-done)"];
pub const NAME_MAX: usize = 24;
pub const PIC_MAX: usize = 6000;
pub const WHO_MODES: [&str; 3] = ["all", "mine", "none"];
const OWN_TASK: [&str; 9] = ["t", "gone", "timer", "spent", "remind", "inbox", "pulled", "cheer", "given"];
const OWN_LIST: [&str; 7] = ["t", "gone", "hidden", "sphere", "group", "sort", "cvGroup"];
const B32: &[u8] = b"0123456789abcdefghijklmnopqrstuv";

fn get<'a>(m: &'a Value, k: &str) -> Option<&'a Value> {
    m.as_object().and_then(|o| o.get(k))
}
fn ff(rec: &Value) -> &Json {
    o(&rec["f"])
}
fn ft(rec: &Value) -> &Json {
    o(&rec["ft"])
}
fn now_ms() -> f64 {
    chrono::Utc::now().timestamp_millis() as f64
}

/// Одинаковы ли значения (порядок ключей не важен; нет поля = null).
pub fn same(a0: Option<&Value>, b0: Option<&Value>) -> bool {
    let a0 = a0.unwrap_or(&NULL);
    let b0 = b0.unwrap_or(&NULL);
    match (a0, b0) {
        (Value::Number(x), Value::Number(y)) => x.as_f64() == y.as_f64(),
        (Value::Object(x), Value::Object(y)) => x.len() == y.len() && x.iter().all(|(k, v)| y.get(k).is_some_and(|w| same(Some(v), Some(w)))),
        (Value::Array(x), Value::Array(y)) => x.len() == y.len() && x.iter().zip(y).all(|(p, q)| same(Some(p), Some(q))),
        _ => a0 == b0,
    }
}

// ---------- ключи ----------

pub fn new_key(kind: &str, rnd: &mut dyn FnMut() -> f64) -> String {
    let mut s0 = kind.to_string();
    for _ in 0..16 {
        s0.push(B32[((rnd() * 32.0).floor() as usize).min(31)] as char);
    }
    s0
}

pub fn kind_of(k: &Value) -> Option<&'static str> {
    let k = k.as_str()?;
    if k == SPHERE_KEY {
        return Some("sphere");
    }
    match k.chars().next()? {
        'l' => Some("list"),
        't' => Some("task"),
        'm' => Some("member"),
        _ => None,
    }
}

/// Ключ записи участника — из почты (FNV, как в JS).
pub fn member_key(email: &str) -> String {
    let e = email.trim().to_lowercase();
    let (mut h1, mut h2): (u64, u64) = (0x811c9dc5, 0x01000193);
    for c in e.encode_utf16() {
        let c = c as u64;
        h1 = ((h1 ^ c).wrapping_mul(16777619)) & 0xFFFF_FFFF;
        h2 = ((h2 + c).wrapping_mul(2246822519)) & 0xFFFF_FFFF;
    }
    let mut s0 = String::from("m");
    for h in [h1, h2] {
        for i in 0..8 {
            s0.push(B32[((h >> (i * 4)) & 31) as usize] as char);
        }
    }
    s0
}

pub fn is_shared_id(id: &str) -> bool {
    id.starts_with(PREFIX)
}
pub fn list_id(lk: &str) -> String {
    format!("{PREFIX}{lk}")
}
pub fn list_key(id: &str) -> Option<&str> {
    id.strip_prefix(PREFIX)
}
pub fn sphere_id(cal: &str) -> String {
    format!("{PREFIX}{cal}")
}
pub fn cal_of_sphere(id: &str) -> Option<&str> {
    id.strip_prefix(PREFIX)
}

// ---------- записи ----------

pub fn make(k: &str, fields: &Value, now: Option<f64>) -> Value {
    let now = now.unwrap_or_else(now_ms);
    let (mut f, mut t_) = (Json::new(), Json::new());
    for (key, v) in o(fields) {
        f.insert(key.clone(), v.clone());
        t_.insert(key.clone(), num(now));
    }
    json!({"v": 1, "k": k, "f": f, "ft": t_})
}

/// Правка: меняются только поля, значение которых действительно другое.
pub fn edit(rec: &Value, patch: &Value, now: Option<f64>) -> Value {
    let now = now.unwrap_or_else(now_ms);
    let (mut f, mut t_) = (ff(rec).clone(), ft(rec).clone());
    let mut changed = false;
    for (key, v) in o(patch) {
        if same(f.get(key), Some(v)) {
            continue;
        }
        f.insert(key.clone(), v.clone());
        let prev = n(t_.get(key).unwrap_or(&NULL)).unwrap_or(0.0) + 1.0;
        t_.insert(key.clone(), num(now.max(prev)));
        changed = true;
    }
    if !changed {
        return rec.clone();
    }
    let mut r = rec.clone();
    r["f"] = Value::Object(f);
    r["ft"] = Value::Object(t_);
    r
}

pub fn merge_rec(a0: &Value, b0: &Value) -> Value {
    if a0.is_null() {
        return b0.clone();
    }
    if b0.is_null() {
        return a0.clone();
    }
    let (af, bf, aft, bft) = (ff(a0), ff(b0), ft(a0), ft(b0));
    let mut names: Vec<&String> = af.keys().collect();
    for k in bf.keys() {
        if !names.contains(&k) {
            names.push(k);
        }
    }
    let (mut f, mut t_) = (Json::new(), Json::new());
    for nm in names {
        let ta = n(aft.get(nm).unwrap_or(&NULL)).unwrap_or(0.0);
        let tb = n(bft.get(nm).unwrap_or(&NULL)).unwrap_or(0.0);
        let enc = |m: &Json| serde_json::to_string(m.get(nm).unwrap_or(&NULL)).unwrap();
        let pick_b = if tb != ta { tb > ta } else { enc(bf) > enc(af) };
        let src = if pick_b { bf } else { af };
        if let Some(v) = src.get(nm) {
            f.insert(nm.clone(), v.clone());
        }
        t_.insert(nm.clone(), num(if pick_b { tb } else { ta }));
    }
    let k = if a0["k"].is_null() { b0["k"].clone() } else { a0["k"].clone() };
    json!({"v": 1, "k": k, "f": f, "ft": t_})
}

pub fn last_time(rec: &Value) -> f64 {
    ft(rec).values().filter_map(n).fold(0.0, f64::max)
}

// ---------- событие календаря ----------

pub fn to_event(rec: &Value) -> Value {
    let mut f = ff(rec).clone();
    if let Some(nt) = f.get("notes").and_then(|x| x.as_str()) {
        if nt.encode_utf16().count() > NOTES_MAX {
            let cut: String = nt.chars().take(NOTES_MAX).collect();
            f.insert("notes".into(), json!(cut));
        }
    }
    let desc = serde_json::to_string(&json!({"v": 1, "k": rec["k"], "f": f, "ft": rec["ft"]})).unwrap();
    json!({"id": rec["k"], "summary": SUMMARY, "description": desc, "start": {"date": "2000-01-01"}, "end": {"date": "2000-01-02"},
           "transparency": "transparent", "reminders": {"useDefault": false, "overrides": []},
           "extendedProperties": {"shared": {"sputnik": "rec"}}})
}

pub fn from_event(ev: &Value) -> Value {
    if ev.is_null() || ev["status"] == "cancelled" || ev["extendedProperties"]["shared"]["sputnik"] != "rec" {
        return Value::Null;
    }
    let Ok(j) = serde_json::from_str::<Value>(s(&ev["description"])) else { return Value::Null };
    if !j["f"].is_object() || !j["k"].is_string() || kind_of(&j["k"]).is_none() {
        return Value::Null;
    }
    json!({"v": 1, "k": j["k"], "f": j["f"], "ft": if j["ft"].is_object() { j["ft"].clone() } else { json!({}) }})
}

// ---------- как запись выглядит для трекера ----------

pub fn new_pos(now: Option<f64>) -> String {
    let v = (1e15 - now.unwrap_or_else(now_ms)).max(0.0).floor() as i64;
    format!("{v:020}")
}

fn iso(ms: f64) -> String {
    crate::reminders::iso(chrono::Utc.timestamp_millis_opt(ms as i64).unwrap())
}

pub fn task_view(rec: &Value) -> Value {
    let f = ff(rec);
    let g = |k: &str| f.get(k).cloned().unwrap_or(Value::Null);
    let done = g("status") == "completed";
    let mut m = Json::new();
    m.insert("id".into(), rec["k"].clone());
    m.insert("title".into(), if g("title").is_null() { json!("") } else { g("title") });
    m.insert("notes".into(), if g("notes").is_null() { json!("") } else { g("notes") });
    if t(&g("due")) {
        m.insert("due".into(), g("due"));
    }
    m.insert("status".into(), json!(if done { "completed" } else { "needsAction" }));
    if done && t(&g("completed")) {
        m.insert("completed".into(), g("completed"));
    }
    if t(&g("parent")) {
        m.insert("parent".into(), g("parent"));
    }
    m.insert("position".into(), if g("pos").is_null() { json!("") } else { g("pos") });
    m.insert("updated".into(), json!(iso(last_time(rec))));
    m.insert("shared".into(), json!(true));
    Value::Object(m)
}

pub fn list_view(rec: &Value, cal: &Value) -> Value {
    let title = ff(rec).get("title").cloned().filter(|x| !x.is_null()).unwrap_or(json!("Без названия"));
    json!({"id": list_id(s(&rec["k"])), "title": title, "updated": iso(last_time(rec)), "shared": cal})
}

/// Правка задачи в духе Google Tasks → поля записи.
pub fn task_patch(body: &Value, now: Option<f64>) -> Value {
    let b = o(body);
    let mut p = Json::new();
    let or = |k: &str, d: Value| b.get(k).cloned().filter(|x| !x.is_null()).unwrap_or(d);
    if b.contains_key("title") {
        p.insert("title".into(), or("title", json!("")));
    }
    if b.contains_key("notes") {
        p.insert("notes".into(), or("notes", json!("")));
    }
    if b.contains_key("due") {
        p.insert("due".into(), b["due"].clone());
    }
    if b.contains_key("status") {
        let done = b["status"] == "completed";
        p.insert("status".into(), json!(if done { "completed" } else { "needsAction" }));
        p.insert("completed".into(), if done { or("completed", json!(iso(now.unwrap_or_else(now_ms)))) } else { Value::Null });
    }
    Value::Object(p)
}

// ---------- поля слоя ----------

pub fn layer_of(rec: &Value) -> Value {
    let mut m = Json::new();
    for (k, v) in ff(rec) {
        if let Some(x) = k.strip_prefix('$') {
            m.insert(x.into(), v.clone());
        }
    }
    Value::Object(m)
}

pub fn shared_of(lay_rec: &Value, kind: &str) -> Json {
    let own: &[&str] = if kind == "list" { &OWN_LIST } else { &OWN_TASK };
    let mut m = Json::new();
    if !lay_rec.is_object() || t(&lay_rec["gone"]) {
        return m;
    }
    for (k, v) in o(lay_rec) {
        if !own.contains(&k.as_str()) {
            m.insert(format!("${k}"), v.clone());
        }
    }
    m
}

/// Трёхстороннее сведение полей слоя. toLayer — что вписать в слой, toRec — что дописать в календарь.
pub fn reconcile(l: &Value, base: &Value, rec: &Value, kind: &str) -> Value {
    let loc = shared_of(l, kind);
    let (b, r) = (ff(base), ff(rec));
    let mut names: Vec<String> = loc.keys().cloned().collect();
    for k in r.keys() {
        if k.starts_with('$') && !names.contains(k) {
            names.push(k.clone());
        }
    }
    let lt = n(&l["t"]).unwrap_or(0.0);
    let (mut to_layer, mut to_rec) = (Json::new(), Json::new());
    for nm in names {
        let (lv, bv, rv) = (loc.get(&nm), b.get(&nm), r.get(&nm));
        let local_changed = lv.is_some() && !same(lv, bv);
        let remote_changed = !same(rv, bv);
        if same(lv, rv) {
            continue;
        }
        let rvv = rv.cloned().unwrap_or(Value::Null);
        let rt = n(ft(rec).get(&nm).unwrap_or(&NULL)).unwrap_or(0.0);
        if remote_changed && (!local_changed || rt >= lt) {
            to_layer.insert(nm[1..].into(), rvv);
        } else if local_changed {
            to_rec.insert(nm.clone(), lv.unwrap().clone());
        } else if lv.is_none() {
            to_layer.insert(nm[1..].into(), rvv);
        }
    }
    json!({"toLayer": to_layer, "toRec": to_rec})
}

pub fn reconcile_sphere(sp: &Value, base: &Value, rec: &Value) -> Value {
    let st = n(&sp["t"]).unwrap_or(0.0);
    let (mut to_layer, mut to_rec) = (Json::new(), Json::new());
    for nm in SPHERE_FIELDS {
        let (lv, bv, rv) = (get(sp, nm), ff(base).get(nm), ff(rec).get(nm));
        if same(lv, rv) {
            continue;
        }
        let local_changed = lv.is_some() && !same(lv, bv);
        let remote_changed = !same(rv, bv);
        let rt = n(ft(rec).get(nm).unwrap_or(&NULL)).unwrap_or(0.0);
        if remote_changed && (!local_changed || rt >= st) {
            if let Some(v) = rv {
                to_layer.insert(nm.into(), v.clone());
            }
        } else if local_changed {
            to_rec.insert(nm.into(), lv.unwrap().clone());
        } else if lv.is_none() {
            if let Some(v) = rv {
                to_layer.insert(nm.into(), v.clone());
            }
        }
    }
    json!({"toLayer": to_layer, "toRec": to_rec})
}

// ---------- хранилище одной сферы ----------

fn recs(r: &Value) -> impl Iterator<Item = &Value> {
    o(r).values().filter(|v| v.is_object())
}

pub fn tasks_of(rs: &Value, lk: &str) -> Vec<Value> {
    recs(rs).filter(|r| kind_of(&r["k"]) == Some("task") && r["f"]["list"] == lk).map(task_view).collect()
}

pub fn lists_of(rs: &Value, cal: &Value) -> Vec<Value> {
    let mut xs: Vec<&Value> = recs(rs).filter(|r| kind_of(&r["k"]) == Some("list")).collect();
    xs.sort_by(|a0, b0| {
        n(&a0["f"]["created"]).unwrap_or(0.0).partial_cmp(&n(&b0["f"]["created"]).unwrap_or(0.0)).unwrap()
            .then(s(&a0["k"]).cmp(s(&b0["k"])))
    });
    xs.into_iter().map(|r| list_view(r, cal)).collect()
}

pub fn with_children(rs: &Value, k: &str) -> Vec<String> {
    let mut out = vec![k.to_string()];
    out.extend(recs(rs).filter(|r| kind_of(&r["k"]) == Some("task") && r["f"]["parent"] == k).map(|r| text(&r["k"])));
    out
}

pub fn is_sphere_cal(c: &Value) -> bool {
    c["description"].as_str().is_some_and(|d| d.contains(MARK))
}

// ---------- участники и исполнители ----------

fn ok_hue(c: &Value) -> Option<usize> {
    let x = n(c)?;
    (x.fract() == 0.0 && x >= 0.0 && (x as usize) < MEMBER_COLORS.len() && c.is_number()).then_some(x as usize)
}

pub fn ok_pic(p: &Value) -> Value {
    match p.as_str() {
        Some(x) if x.len() <= PIC_MAX && rx::is(r"^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/]+=*$", x) => p.clone(),
        _ => Value::Null,
    }
}

fn first_upper(x: &str) -> String {
    x.chars().next().map(|c| c.to_uppercase().collect()).unwrap_or_default()
}

pub fn members_of(rs: &Value) -> Vec<Value> {
    let owner = rs[SPHERE_KEY]["f"]["owner"].clone();
    let mut xs: Vec<(Value, Option<usize>)> = vec![];
    for r in recs(rs) {
        let f = &r["f"];
        if kind_of(&r["k"]) != Some("member") || !t(&f["email"]) || t(&f["removed"]) {
            continue;
        }
        let name = if t(&f["name"]) { f["name"].clone() } else { json!(name_of(&f["email"])) };
        xs.push((json!({"email": f["email"], "name": name, "order": if f["order"].is_null() { json!(0) } else { f["order"].clone() },
            "owner": f["email"] == owner, "joined": t(&f["joined"]) || f["email"] == owner, "seen": f["seen"],
            "invited": r["ft"]["email"], "pic": ok_pic(&f["pic"])}), ok_hue(&f["color"])));
    }
    xs.sort_by(|(a0, _), (b0, _)| {
        (b0["owner"] == true).cmp(&(a0["owner"] == true))
            .then(n(&a0["order"]).unwrap_or(0.0).partial_cmp(&n(&b0["order"]).unwrap_or(0.0)).unwrap())
            .then(ru_compare(s(&a0["email"]), s(&b0["email"])))
    });
    xs.into_iter()
        .enumerate()
        .map(|(i, (mut m, hue))| {
            let nm = if t(&m["name"]) { text(&m["name"]) } else { text(&m["email"]) };
            let nm = nm.trim();
            m["color"] = json!(MEMBER_COLORS[hue.unwrap_or(i % MEMBER_COLORS.len())]);
            m["letter"] = json!(if nm.is_empty() { "?".into() } else { first_upper(nm) });
            m
        })
        .collect()
}

pub fn profile_fields(profile: &Value) -> Value {
    let raw = if profile["name"].is_null() { String::new() } else { text(&profile["name"]) };
    let name: String = rx::all(r"\s+", &raw, " ").trim().chars().take(NAME_MAX).collect();
    json!({"name": if name.is_empty() { Value::Null } else { json!(name) }, "color": ok_hue(&profile["color"]), "pic": ok_pic(&profile["pic"])})
}

pub fn profile_patch(rec: &Value, profile: &Value) -> Value {
    let mut out = Json::new();
    for (k, v) in o(&profile_fields(profile)) {
        let cur = ff(rec).get(k).unwrap_or(&NULL);
        if !(cur == v || (cur.is_number() && v.is_number() && cur.as_f64() == v.as_f64())) {
            out.insert(k.clone(), v.clone());
        }
    }
    Value::Object(out)
}

pub fn name_of(email: &Value) -> String {
    let e = if email.is_null() { String::new() } else { text(email) };
    let local = e.split('@').next().unwrap_or("");
    let nm = rx::rx(r"[._+-]").split(local).next().and_then(|x| x.ok()).unwrap_or("").to_string();
    if nm.is_empty() {
        return "Участник".into();
    }
    let mut c = nm.chars();
    first_upper(&nm) + {
        c.next();
        c.as_str()
    }
}

pub fn next_order(rs: &Value) -> f64 {
    1.0 + recs(rs).filter(|r| kind_of(&r["k"]) == Some("member")).map(|r| n(&r["f"]["order"]).unwrap_or(0.0)).fold(0.0, f64::max)
}

pub fn who_of(l: &Value) -> Option<String> {
    l["who"].as_str().filter(|x| !x.is_empty()).map(String::from)
}

pub fn assigned_match(l: &Value, me: Option<&str>, mode: &str) -> bool {
    let w = who_of(l);
    let me_ok = me.is_some_and(|m| !m.is_empty());
    match mode {
        "mine" => me_ok && w.as_deref() == me,
        "none" => w.is_none(),
        "mineOrNone" => w.is_none() || (me_ok && w.as_deref() == me),
        _ => true,
    }
}

pub fn handoff(l: &Value, to_col: &str) -> Value {
    let next = &l["stageWho"][to_col];
    if t(next) && next.as_str().map(String::from) != who_of(l) { json!({"who": next}) } else { json!({}) }
}

pub fn set_stage_who(l: &Value, col: &str, who: &Value) -> Value {
    let mut cur = o(&l["stageWho"]).clone();
    if t(who) {
        cur.insert(col.into(), who.clone());
    } else {
        cur.shift_remove(col);
    }
    json!({"stageWho": cur})
}

pub fn is_together(people: &[Value]) -> bool {
    people.iter().any(|m| !t(&m["owner"]))
}

fn local_ms(ms: f64) -> chrono::NaiveDateTime {
    Local.timestamp_millis_opt(ms as i64).single().map(|d| d.naive_local()).unwrap_or_default()
}

/// «сегодня в 12:40» / «вчера в 9:05» / «20 окт.».
pub fn seen_text(ms: &Value, now: Option<f64>) -> String {
    if !t(ms) {
        return String::new();
    }
    let d = local_ms(n(ms).unwrap_or(0.0));
    let nn = local_ms(now.unwrap_or_else(now_ms));
    let hm = format!("{}:{:02}", d.hour(), d.minute());
    let diff = (nn.date() - d.date()).num_days();
    match diff {
        0 => format!("сегодня в {hm}"),
        1 => format!("вчера в {hm}"),
        _ => format!("{} {}", d.day(), crate::reminders::MON_SHORT[d.month0() as usize]),
    }
}

pub fn parse_emails(text_: &Value) -> Value {
    let src = if text_.is_null() { String::new() } else { text(text_) };
    let (mut ok, mut bad): (Vec<String>, Vec<String>) = (vec![], vec![]);
    for raw in rx::rx(r"[\s,;]+").split(&src).filter_map(|x| x.ok()) {
        let e = raw.trim().to_lowercase();
        if e.is_empty() {
            continue;
        }
        if rx::is(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", &e) {
            if !ok.contains(&e) {
                ok.push(e);
            }
        } else {
            bad.push(e);
        }
    }
    json!({"ok": ok, "bad": bad})
}

fn fold(x: &Value) -> String {
    (if x.is_null() { String::new() } else { text(x) }).to_lowercase().replace('ё', "е").trim().to_string()
}

pub fn member_of(people: &[Value], email: &Value) -> Value {
    if !t(email) {
        return Value::Null;
    }
    if let Some(p) = people.iter().find(|p| p["email"] == *email) {
        return p.clone();
    }
    let nm = name_of(email);
    json!({"email": email, "name": nm, "letter": nm.chars().next().map(String::from).unwrap_or_default(), "color": "var(--ink-faint)", "joined": true, "gone": true})
}

pub fn who_options(people: &[Value], me: Option<&str>, q: &str, counts: &Value) -> Vec<Value> {
    let f = fold(&json!(q));
    let me_v = me.map(|m| json!(m)).unwrap_or(Value::Null);
    let hit = |p: &Value| f.is_empty() || fold(&p["name"]).contains(&f) || fold(&p["email"]).contains(&f) || (p["email"] == me_v && "я".starts_with(&f));
    let ppl: Vec<&Value> = people.iter().filter(|p| p["email"] == me_v).chain(people.iter().filter(|p| p["email"] != me_v)).filter(|p| hit(p)).collect();
    let cnt = |k: &str| if counts[k].is_null() { json!(0) } else { counts[k].clone() };
    let mut rows: Vec<Value> = ppl.iter().enumerate().map(|(i, p)| json!({
        "email": p["email"], "m": p, "label": if p["email"] == me_v { json!("Я") } else { p["name"].clone() },
        "note": if t(&p["joined"]) { "" } else { "ещё не принял" }, "n": cnt(s(&p["email"])),
        "key": if i < 9 { format!("{}", i + 1) } else { String::new() }})).collect();
    if f.is_empty() || "без исполнителя".contains(&f) || "никто".contains(&f) {
        rows.push(json!({"email": null, "m": null, "label": "Без исполнителя", "note": "", "n": cnt(""), "key": "0"}));
    }
    rows
}

/// Цифра → почта исполнителя: Some(Null) — без исполнителя, None — такой строки нет.
pub fn who_by_digit(people: &[Value], me: Option<&str>, d: &str) -> Option<Value> {
    if d == "0" {
        return Some(Value::Null);
    }
    who_options(people, me, "", &json!({})).into_iter().find(|r| r["key"] == d && t(&r["email"])).map(|r| r["email"].clone())
}

pub fn member_by_word(people: &[Value], word: &str) -> Value {
    let w = rx::first(r"^@", &fold(&json!(word)), "");
    if w.is_empty() {
        return Value::Null;
    }
    if let Some(p) = people.iter().find(|p| fold(&p["name"]) == w) {
        return p.clone();
    }
    people.iter().find(|p| fold(&p["name"]).starts_with(&w) || fold(&json!(s(&p["email"]).split('@').next().unwrap_or(""))).starts_with(&w)).cloned().unwrap_or(Value::Null)
}

pub fn edit_of(rec: &Value) -> Value {
    let by = &rec["f"]["by"];
    if !t(by) {
        return Value::Null;
    }
    let ts: Vec<(&String, f64)> = ft(rec).iter().filter(|(k, _)| *k != "by").map(|(k, v)| (k, n(v).unwrap_or(0.0))).collect();
    let at = ts.iter().map(|x| x.1).fold(0.0, f64::max);
    if at == 0.0 {
        return Value::Null;
    }
    json!({"by": by, "at": num(at), "fields": ts.iter().filter(|x| at - x.1 < 3000.0).map(|x| x.0.clone()).collect::<Vec<_>>(),
           "col": rec["f"]["$status"], "who": rec["f"]["$who"]})
}

pub fn change_text(ed: &Value, people: &[Value], me: Option<&str>, col_name: &dyn Fn(&Value) -> String, now: Option<f64>) -> String {
    if ed.is_null() || me.is_some_and(|m| ed["by"] == m) {
        return String::new();
    }
    let mo = member_of(people, &ed["by"]);
    let who = if mo["name"].is_null() { name_of(&ed["by"]) } else { text(&mo["name"]) };
    let f: Vec<&str> = a(&ed["fields"]).iter().map(|x| s(x)).collect();
    let what = if f.contains(&"status") {
        "отметка «сделано»".to_string()
    } else if f.contains(&"$status") {
        format!("перенос{}", if t(&ed["col"]) { format!(" в «{}»", col_name(&ed["col"])) } else { String::new() })
    } else if f.contains(&"$who") {
        if t(&ed["who"]) {
            format!("отдано: {}", if me.is_some_and(|m| ed["who"] == m) { "тебе".into() } else { text(&member_of(people, &ed["who"])["name"]) })
        } else {
            "снят исполнитель".into()
        }
    } else if f.contains(&"title") {
        "новое название".into()
    } else if f.contains(&"due") {
        "новый срок".into()
    } else if f.contains(&"notes") {
        "заметка".into()
    } else {
        "правка".into()
    };
    let when = rx::first(r"^сегодня в ", &seen_text(&ed["at"], now), "");
    format!("{who} · {what} · {when}")
}

pub fn assigned_to_me(base: &Value, rec: &Value, me: Option<&str>) -> bool {
    let Some(me) = me.filter(|m| !m.is_empty()) else { return false };
    if rec.is_null() || kind_of(&rec["k"]) != Some("task") {
        return false;
    }
    let f = &rec["f"];
    f["$who"] == me && base["f"]["$who"] != me && t(&f["by"]) && f["by"] != me && f["status"] != "completed"
}

pub fn who_counts(tasks: &[Value], lay_tasks: &Value) -> Value {
    let mut out = Json::new();
    for tk in tasks {
        if t(&tk["parent"]) || tk["status"] == "completed" {
            continue;
        }
        let w = who_of(&lay_tasks[s(&tk["id"])]).unwrap_or_default();
        let c = out.get(&w).and_then(|v| v.as_i64()).unwrap_or(0) + 1;
        out.insert(w, json!(c));
    }
    Value::Object(out)
}

pub fn who_tally(tasks: &[Value], lay_tasks: &Value, me: Option<&str>) -> Value {
    let (mut all, mut mine, mut none) = (0, 0, 0);
    for tk in tasks {
        if t(&tk["parent"]) || tk["status"] == "completed" {
            continue;
        }
        all += 1;
        match who_of(&lay_tasks[s(&tk["id"])]) {
            None => none += 1,
            Some(w) if me.is_some_and(|m| !m.is_empty() && m == w) => mine += 1,
            _ => {}
        }
    }
    json!({"all": all, "mine": mine, "none": none})
}

/// Задачи для «Сегодня» и календаря: из общих сфер — только мои и ничьи; подзадачи идут за родителем.
pub fn for_me(by_list: &Value, lay_tasks: &Value, me: Option<&str>, together: &dyn Fn(&str) -> bool) -> Value {
    let mut out = Json::new();
    for (k, v) in o(by_list) {
        let ts = a(v);
        if !together(k) {
            out.insert(k.clone(), v.clone());
            continue;
        }
        let keep: Vec<&Value> = ts.iter().filter(|tk| !t(&tk["parent"]) && assigned_match(&lay_tasks[s(&tk["id"])], me, "mineOrNone")).map(|tk| &tk["id"]).collect();
        out.insert(k.clone(), Value::Array(ts.iter().filter(|tk| if t(&tk["parent"]) { keep.contains(&&tk["parent"]) } else { keep.contains(&&tk["id"]) }).cloned().collect()));
    }
    Value::Object(out)
}

// ---------- Конвейер: исполнители этапов и передача ----------

fn who2(people: &[Value], email: &Value, me: Option<&str>, dat: bool) -> String {
    if me.map(|m| *email == m).unwrap_or(email.is_null()) {
        return (if dat { "тебе" } else { "ты" }).into();
    }
    let m = member_of(people, email);
    if m["name"].is_null() { "никто".into() } else { text(&m["name"]) }
}

pub fn stage_pass(l: &Value, from: &str, to: &str, by: &str, now: Option<f64>) -> Value {
    let h = handoff(l, to);
    let who = if h["who"].is_null() { who_of(l).map(Value::from).unwrap_or(Value::Null) } else { h["who"].clone() };
    let mut passes: Vec<Value> = a(&l["passes"]).to_vec();
    passes.push(json!({"from": from, "to": to, "by": by, "who": who, "at": num(now.unwrap_or_else(now_ms))}));
    let last8 = passes.split_off(passes.len().saturating_sub(8));
    let mut out = o(&h).clone();
    if let Some(w) = who_of(l) {
        if !t(&l["stageWho"][from]) {
            let mut sw = o(&l["stageWho"]).clone();
            sw.insert(from.into(), json!(w));
            out.insert("stageWho".into(), Value::Object(sw));
        }
    }
    out.insert("passes".into(), Value::Array(last8));
    Value::Object(out)
}

pub fn pass_text(p: &Value, people: &[Value], me: Option<&str>, col_name: &dyn Fn(&Value) -> String) -> String {
    let by = who2(people, &p["by"], me, false);
    let head = format!("{}{} · «{}» готов{}", first_upper(&by), by.chars().skip(1).collect::<String>(), col_name(&p["from"]), if t(&p["from"]) { "о" } else { "" });
    if !t(&p["who"]) {
        return format!("{head} → на этапе никого");
    }
    if p["who"] != p["by"] {
        return format!("{head} → {}", who2(people, &p["who"], me, true));
    }
    let tail = if me.is_some_and(|m| p["who"] == m) { "остаётся у тебя".into() } else { format!("снова у: {}", text(&member_of(people, &p["who"])["name"])) };
    format!("{head} → «{}» {tail}", col_name(&p["to"]))
}

pub fn next_hint(l: &Value, next: Option<&str>, me: Option<&str>, people: &[Value]) -> String {
    let Some(next) = next.filter(|x| !x.is_empty()) else { return String::new() };
    let cur = who_of(l);
    let to = l["stageWho"][next].as_str().map(String::from);
    let Some(target) = to.or(cur.clone()).filter(|x| !x.is_empty()) else { return "этап без исполнителя".into() };
    let nm = || text(&member_of(people, &json!(target))["name"]);
    let mine = me == Some(target.as_str());
    if Some(&target) == cur.as_ref() {
        if mine { "этап твой — останется у тебя".into() } else { format!("останется: {}", nm()) }
    } else if mine {
        "уйдёт к тебе".into()
    } else {
        format!("уйдёт: {}", nm())
    }
}

pub fn stage_crew(l: &Value, cols: &[Value], cur: &Value) -> Vec<Value> {
    cols.iter()
        .map(|c| {
            let sw = &l["stageWho"][s(&c["id"])];
            let who = if !sw.is_null() { sw.clone() } else if c["id"] == *cur { who_of(l).map(Value::from).unwrap_or(Value::Null) } else { Value::Null };
            json!({"col": c, "who": who})
        })
        .collect()
}

// ---------- состояния ----------

pub fn is_invite(store: &Value, me: &str) -> bool {
    if store.is_null() || store["role"] == "owner" || t(&store["accepted"]) {
        return false;
    }
    let r = &store["recs"][member_key(me).as_str()];
    !(t(&r["f"]["joined"]) && !t(&r["f"]["removed"]))
}

pub fn invite_info(store: &Value, me: Option<&str>) -> Value {
    let rs = &store["recs"];
    let people = members_of(rs);
    let owner = people.iter().find(|p| p["owner"] == true).cloned().unwrap_or(Value::Null);
    let name = rs[SPHERE_KEY]["f"]["name"].clone();
    let mut out = json!({"cal": store["cal"], "name": if name.is_null() { json!("Общая сфера") } else { name }, "owner": owner,
           "lists": recs(rs).filter(|r| kind_of(&r["k"]) == Some("list")).count(),
           "tasks": recs(rs).filter(|r| kind_of(&r["k"]) == Some("task") && !t(&r["f"]["parent"]) && r["f"]["status"] != "completed").count(),
           "people": people.iter().filter(|p| p["joined"] == true && me.map(|m| p["email"] != m).unwrap_or(!p["email"].is_null())).cloned().collect::<Vec<_>>()});
    if store["cal"].is_null() {
        out.as_object_mut().unwrap().shift_remove("cal");
    }
    out
}

pub fn waiting_for(rec: &Value, people: &[Value], me: Option<&str>) -> Value {
    let w = &rec["f"]["$who"];
    let me_v = me.map(|m| json!(m)).unwrap_or(Value::Null);
    if !t(w) || *w == me_v || rec["f"]["by"] != me_v {
        return Value::Null;
    }
    let Some(m) = people.iter().find(|p| p["email"] == *w) else { return Value::Null };
    if !t(&m["joined"]) || !t(&m["seen"]) {
        return Value::Null;
    }
    if n(&rec["ft"]["$who"]).unwrap_or(0.0) > n(&m["seen"]).unwrap_or(0.0) { m.clone() } else { Value::Null }
}

pub fn unseen_by(rs: &Value, people: &[Value], me: Option<&str>) -> Vec<Value> {
    let me_v = me.map(|m| json!(m)).unwrap_or(Value::Null);
    let mine: Vec<&Value> = recs(rs).filter(|r| matches!(kind_of(&r["k"]), Some("task") | Some("list")) && r["f"]["by"] == me_v).collect();
    let mut xs: Vec<Value> = people.iter()
        .filter(|p| p["email"] != me_v && t(&p["joined"]) && t(&p["seen"]))
        .map(|p| json!({"m": p, "n": mine.iter().filter(|r| last_time(r) > n(&p["seen"]).unwrap_or(0.0)).count()}))
        .filter(|x| x["n"].as_u64().unwrap_or(0) > 0)
        .collect();
    xs.sort_by(|a0, b0| b0["n"].as_u64().cmp(&a0["n"].as_u64()));
    xs
}

pub fn seen_due(seen: &Value, foreign_newer: bool, now: Option<f64>) -> bool {
    if !t(seen) {
        return true;
    }
    let nn = now.unwrap_or_else(now_ms);
    let sv = n(seen).unwrap_or(0.0);
    nn - sv > 36e5 || (foreign_newer && nn - sv > 120e3)
}

pub fn ask_access_text(sphere: &str, owner: Option<&str>) -> String {
    let to = owner.filter(|x| !x.is_empty()).map(|x| format!("Кому: {x}\n")).unwrap_or_default();
    format!("{to}Тема: Доступ к сфере «{sphere}» в Спутнике\n\nПривет! У меня пропал доступ к общей сфере «{sphere}». Позови меня снова, пожалуйста: «Участники» → почта.")
}
