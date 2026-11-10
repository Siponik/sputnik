//! Обмен с Google в фоне: очередь исходящих правок, полная синхронизация раз в 2 минуты, слой на Drive, бот.
//! Порт app/lib/data/outbox.dart и refresh/_syncLayer/botSync из app_state.dart.
//! Операции очереди: create { list, tmp, body, parent? } · patch { list, id, body } · delete { list, id }; у каждой uid «u».
use super::{now_ms, run, today_ymd, with, App};
use crate::data::{api, bot, google::Fail};
use serde_json::{json, Value};
use sputnik_core::j::*;
use sputnik_core::{layer as lay, reminders as rem, sharedbot as sbot};
use std::time::{Duration, Instant};

pub struct Outbox {
    pub ops: Vec<Value>,
    busy: Option<u64>,
    fails: usize,
    next: Instant,
    seq: u64,
}

impl Outbox {
    pub fn new(mut ops: Vec<Value>) -> Outbox {
        let mut seq = 0;
        for op in ops.iter_mut() {
            seq += 1;
            op["u"] = json!(seq);
        }
        Outbox { ops, busy: None, fails: 0, next: Instant::now(), seq }
    }

    pub fn pending_for(&self, id: &str) -> bool {
        self.ops.iter().any(|o0| o0["id"] == id || o0["tmp"] == id)
    }

    /// Две правки одной задачи подряд склеиваются (кроме уже отправляемой).
    pub fn add(&mut self, mut op: Value) {
        if op["op"] == "patch" {
            if let Some(last) = self.ops.last_mut() {
                let flying = self.busy.is_some_and(|u| last["u"] == u);
                let same_patch = last["op"] == "patch" && last["id"] == op["id"] && last["list"] == op["list"];
                let same_create = last["op"] == "create" && last["tmp"] == op["id"];
                if !flying && (same_patch || same_create) {
                    let b = o(&op["body"]).clone();
                    extend(last["body"].as_object_mut().unwrap(), &b);
                    return;
                }
            }
        }
        self.seq += 1;
        op["u"] = json!(self.seq);
        self.ops.push(op);
    }

    /// Задачу ещё не создали в Google, а её уже удалили — просто забыть её операции.
    pub fn drop_tmp(&mut self, tmp: &str) {
        let busy = self.busy;
        self.ops.retain(|o0| busy.is_some_and(|u| o0["u"] == u) || (o0["tmp"] != tmp && o0["id"] != tmp && o0["parent"] != tmp));
    }

    fn backoff(&mut self) {
        self.fails += 1;
        let s0 = [5u64, 15, 30, 60, 120, 300][(self.fails - 1).min(5)];
        self.next = Instant::now() + Duration::from_secs(s0);
    }
}

/// Отправить одну операцию (блокирующе, в фоне).
fn send(op: &Value, sh: Option<&mut super::shared::Shared>) -> Result<Value, Fail> {
    let list = s(&op["list"]);
    match s(&op["op"]) {
        "create" => {
            let parent = op["parent"].as_str();
            if parent.is_some_and(|p| p.starts_with("tmp-")) {
                return Err(Fail::Net("родитель ещё не создан".into()));
            }
            match sh {
                Some(sh) => sh.create_task(list, &op["body"], parent, &Json::new()),
                None => api::create_task(list, &op["body"], parent),
            }
        }
        "patch" => match sh {
            Some(sh) => sh.patch_task(list, s(&op["id"]), &op["body"]),
            None => api::patch_task(list, s(&op["id"]), &op["body"]),
        },
        _ => {
            let r = match sh {
                Some(sh) => sh.delete_task(list, s(&op["id"])),
                None => api::delete_task(list, s(&op["id"])),
            };
            match r {
                Err(e) if e.status() == 404 => Ok(Value::Null),
                r => r.map(|_| Value::Null),
            }
        }
    }
}

impl App {
    /// После любой новой операции: записать очередь и начать отправку.
    pub fn after_outbox(&mut self) {
        self.save_outbox();
        self.flush(false);
    }

    pub fn flush(&mut self, force: bool) {
        if self.outbox.busy.is_some() || self.outbox.ops.is_empty() || self.flags.need_login || self.flags.demo {
            if self.flags.demo {
                self.demo_ack();
            }
            return;
        }
        if !force && Instant::now() < self.outbox.next {
            return;
        }
        let op = self.outbox.ops[0].clone();
        let u = op["u"].as_u64().unwrap_or(0);
        self.outbox.busy = Some(u);
        if s(&op["list"]).starts_with("sh:") {
            self.shared_job(Box::new(move |sh| {
                let r = send(&op, Some(sh));
                Box::new(move |app: &mut App| app.sent(op, r))
            }));
        } else {
            run(move || {
                let r = send(&op, None);
                (op, r)
            }, |app, (op, r)| app.sent(op, r));
        }
    }

    /// Демо: «Google» сразу принимает операции (временный id → постоянный).
    fn demo_ack(&mut self) {
        let ops = std::mem::take(&mut self.outbox.ops);
        for op in ops {
            if op["op"] == "create" {
                let tmp = text(&op["tmp"]);
                let mut real = op["body"].clone();
                real["id"] = json!(format!("d{}", &tmp[4..]));
                real["status"] = json!(real["status"].as_str().unwrap_or("needsAction"));
                if !op["parent"].is_null() {
                    real["parent"] = op["parent"].clone();
                }
                self.created(&tmp, real);
            }
        }
    }

    fn sent(&mut self, op: Value, r: Result<Value, Fail>) {
        self.outbox.busy = None;
        let u = op["u"].clone();
        match r {
            Ok(res) => {
                self.outbox.ops.retain(|x| x["u"] != u);
                self.outbox.fails = 0;
                match s(&op["op"]) {
                    "create" => self.created(s(&op["tmp"]), res),
                    "patch" => self.saved(s(&op["list"]), res),
                    _ => {}
                }
                self.save_outbox();
                self.flush(true);
            }
            Err(e) if e.later() => {
                if e.need_login() {
                    self.flags.need_login = true;
                }
                self.flags.offline = matches!(e, Fail::Net(_));
                self.outbox.backoff();
                self.save_outbox();
            }
            Err(e) => {
                self.outbox.ops.retain(|x| x["u"] != u);
                self.save_outbox();
                self.say(format!("Не сохранилось в Google: {e}"));
                self.refresh();
            }
        }
    }

    /// Задача создана в Google: временный id → настоящий везде (задачи, слой, очередь).
    fn created(&mut self, tmp: &str, real: Value) {
        let rid = text(&real["id"]);
        if rid.is_empty() {
            return;
        }
        for o0 in self.outbox.ops.iter_mut() {
            if o0["id"] == tmp {
                o0["id"] = json!(rid);
            }
            if o0["parent"] == tmp {
                o0["parent"] = json!(rid);
            }
        }
        if let Some(m) = self.tasks.as_object_mut() {
            for (_, list) in m.iter_mut() {
                let Some(v) = list.as_array_mut() else { continue };
                for c in v.iter_mut() {
                    if c["parent"] == tmp {
                        c["parent"] = json!(rid);
                    }
                }
                if let Some(i) = v.iter().position(|x| x["id"] == tmp) {
                    let st = v[i]["status"].clone();
                    let mut r = real.clone();
                    if r["status"] != st {
                        r["status"] = st;
                    }
                    v[i] = r;
                }
            }
        }
        let mut moved = false;
        if let Some(lt) = self.layer["tasks"].as_object_mut() {
            for (_, r) in lt.iter_mut() {
                if r["repeatNext"] == tmp {
                    r["repeatNext"] = json!(rid);
                }
            }
            if let Some(l) = lt.get(tmp).cloned() {
                lt.insert(rid.clone(), l);
                lt.insert(tmp.to_string(), json!({"gone": true, "t": now_ms()}));
                moved = true;
            }
        }
        if moved {
            self.save_layer();
            self.push_shared("tasks", &rid);
        }
        self.save_cache();
    }

    fn saved(&mut self, list: &str, t: Value) {
        let id = text(&t["id"]);
        if id.is_empty() || self.outbox.pending_for(&id) {
            return;
        }
        if let Some(v) = self.tasks[list].as_array_mut() {
            if let Some(i) = v.iter().position(|x| x["id"] == id.as_str()) {
                v[i] = t;
            }
        }
    }

    // ---------- полная синхронизация ----------

    /// Забрать всё из Google: списки, задачи, календари, события, «Входящие», слой, общие сферы.
    /// Идёт в очереди общих сфер — так их копия не перетирается.
    pub fn refresh(&mut self) {
        if self.flags.syncing || self.flags.need_login || self.flags.demo {
            if self.flags.demo {
                self.flags.synced_at = Some(now_ms());
            }
            return;
        }
        self.flags.syncing = true;
        self.flush(true);
        let cals_layer = self.layer["cals"].clone();
        let layer_id = self.layer_id.clone();
        self.shared_job(Box::new(move |sh| {
            let got = fetch_all(&cals_layer, layer_id);
            let shared = sh.pull_all().map_err(|e| e.to_string());
            Box::new(move |app: &mut App| app.apply_refresh(got, shared))
        }));
    }

    fn apply_refresh(&mut self, got: Result<Fetched, Fail>, shared: Result<Vec<String>, String>) {
        self.flags.syncing = false;
        let f = match got {
            Ok(f) => f,
            Err(e) => {
                if e.need_login() {
                    self.flags.need_login = true;
                }
                self.flags.offline = matches!(e, Fail::Net(_));
                self.flags.error = Some(if self.flags.offline { "Нет связи с Google".into() } else { e.to_string() });
                crate::data::store::log("refresh", &e.to_string());
                return;
            }
        };
        match shared {
            Ok(gone) if !gone.is_empty() => self.say("Пропал доступ к общей сфере"),
            Err(e) => crate::data::store::log("общие сферы", &e),
            _ => {}
        }
        let mut fresh = serde_json::Map::new();
        let mut all_lists = f.lists.clone();
        let shl = self.shared.lists();
        let mut pairs: Vec<(String, Vec<Value>)> = f.tasks.into_iter().collect();
        for l in &shl {
            let id = text(&l["id"]);
            pairs.push((id.clone(), self.shared.tasks(&id)));
        }
        all_lists.extend(shl);
        for (id, list) in pairs {
            let old = a(&self.tasks[&id]).to_vec();
            let mut v: Vec<Value> = list.into_iter().map(|t0| {
                let tid = s(&t0["id"]);
                if self.outbox.pending_for(tid) {
                    if let Some(o0) = old.iter().find(|x| x["id"] == tid) {
                        return o0.clone();
                    }
                }
                t0
            }).collect();
            v.extend(old.into_iter().filter(|t0| s(&t0["id"]).starts_with("tmp-") && self.outbox.pending_for(s(&t0["id"]))));
            fresh.insert(id, Value::Array(v));
        }
        self.lists = all_lists;
        self.tasks = Value::Object(fresh);
        self.calendars = f.calendars;
        self.events = f.events;
        self.ev_from = f.from;
        self.ev_to = f.to;
        if !f.inbox.is_null() {
            self.inbox_st = f.inbox;
            self.pull_inbox_layer();
        }
        self.flags.offline = false;
        self.flags.error = None;
        // слой с Drive — до повторов, чтобы второй компьютер не создал копию ещё раз
        if let Some((id, remote)) = f.layer {
            self.layer_id = id;
            self.merge_layer(remote);
        }
        self.reconcile_shared();
        self.flags.synced_at = Some(now_ms());
        self.roll_repeats(true);
        self.gift_tasks();
        self.bot_sync();
        self.save_cache();
    }

    fn merge_layer(&mut self, remote: Value) {
        let r = lay::merge(&self.layer, &remote);
        if r.local_changed {
            self.layer = r.merged.clone();
            self.writer_layer();
        }
        if r.remote_changed {
            let id = self.layer_id.clone();
            let data = r.merged;
            run(move || api::push_layer(id.as_deref(), &data), |app, res| match res {
                Ok(id) => {
                    app.layer_id = Some(id);
                    app.flags.cloud_at = Some(now_ms());
                    app.flags.cloud_err = None;
                }
                Err(e) => {
                    app.flags.cloud_err = Some(e.to_string());
                    app.layer_dirty_again();
                }
            });
        } else {
            self.flags.cloud_at = Some(now_ms());
        }
    }

    /// Слой ↔ Drive (через 4 с после правки).
    pub fn sync_layer(&mut self) {
        if self.flags.demo {
            return;
        }
        let id = self.layer_id.clone();
        run(move || -> Result<(Option<String>, Value), Fail> {
            let id = match id {
                Some(i) => Some(i),
                None => api::find_layer()?,
            };
            let remote = match &id {
                Some(i) => api::pull_layer(i)?,
                None => Value::Null,
            };
            Ok((id, remote))
        }, |app, r| match r {
            Ok((id, remote)) => {
                app.layer_id = id;
                app.merge_layer(remote);
            }
            Err(e) => {
                app.flags.cloud_err = Some(e.to_string());
                app.layer_dirty_again();
            }
        });
    }

    // ---------- вход ----------

    pub fn login(&mut self) {
        self.flags.logging_in = true;
        self.flags.error = None;
        run(crate::data::google::login, |app, r| {
            app.flags.logging_in = false;
            match r {
                Ok(()) => {
                    app.flags.need_login = false;
                    app.refresh();
                }
                Err(e) => app.flags.error = Some(e),
            }
        });
    }

    pub fn sign_out(&mut self) {
        crate::data::google::sign_out();
        self.flags.need_login = true;
        self.layer_id = None;
        self.shared = super::shared::Shared::default();
        self.save_shared();
    }

    /// Календарь листают за пределы загруженного — догрузить события.
    pub fn ensure_events(&mut self, from: &str, to: &str) {
        if self.flags.need_login || (!self.ev_from.is_empty() && from >= self.ev_from.as_str() && to <= self.ev_to.as_str()) {
            return;
        }
        let (Some(fd), Some(td)) = (sputnik_core::dates::parse_ymd(from), sputnik_core::dates::parse_ymd(to)) else { return };
        let a0 = month_start(fd, -1);
        let b0 = month_start(td, 2);
        let cals: Vec<Value> = self.calendars.iter().filter(|c| self.cal_shown(c)).cloned().collect();
        // окно сразу помечаем, чтобы листание не слало одинаковые запросы
        let (af, bt) = (a0.clone(), b0.clone());
        if self.ev_from.is_empty() || af < self.ev_from {
            self.ev_from = af.clone();
        }
        if bt > self.ev_to {
            self.ev_to = bt.clone();
        }
        run(move || events_in(&cals, &af, &bt), |app, got| {
            let have: std::collections::HashSet<String> = app.events.iter().map(|e| format!("{}|{}", s(&e["calId"]), s(&e["id"]))).collect();
            app.events.extend(got.into_iter().filter(|e| !have.contains(&format!("{}|{}", s(&e["calId"]), s(&e["id"])))));
        });
    }

    // ---------- бот ----------

    pub fn bot_sync(&mut self) {
        let key = self.bot_key();
        if key.is_empty() || self.flags.demo {
            return;
        }
        let live: Vec<Value> = self.board_lists().into_iter().filter(|l| !t(&self.ll(s(&l["id"]))["quiet"])).collect();
        let today = sputnik_core::habits::now().date();
        let mut body = json!({"items": self.remind_items(), "today": sbot::snapshot(&live, &self.tasks, &self.layer["tasks"], today), "tz": "Europe/Moscow"});
        extend(body.as_object_mut().unwrap(), o(&sbot::guess_ctx(&self.board_lists(), &self.layer)));
        let txt = body.to_string();
        let changed = txt != self.bot_last;
        run(move || -> Result<(bool, Value), String> {
            if changed {
                bot::push(&key, &body)?;
            }
            Ok((changed, bot::inbox(&key)?))
        }, move |app, r| match r {
            Ok((changed, inbox)) => {
                if changed {
                    app.bot_last = txt;
                }
                app.bot_items(inbox);
                app.bot_err.clear();
                app.bot_at = Some(now_ms());
            }
            Err(e) => app.bot_err = e,
        });
    }

    fn bot_items(&mut self, r: Value) {
        let today = sputnik_core::habits::now().date();
        let mut ok = vec![];
        let mut added = 0;
        for x in a(&r["items"]).to_vec() {
            match s(&x["type"]) {
                "add" => {
                    let ctx = self.board_lists();
                    let tk = if x["draft"].is_object() {
                        sbot::from_draft(&x["draft"], &ctx, &self.layer, &self.tasks, today)
                    } else {
                        sbot::from_text(s(&x["text"]), &ctx, &self.layer, &self.tasks, today)
                    };
                    if tk.is_object() {
                        let mut patch = if tk["layer"].is_object() { tk["layer"].clone() } else { json!({}) };
                        if !tk["slot"].is_null() {
                            patch["slot"] = tk["slot"].clone();
                        }
                        if patch.get("remind").is_none() {
                            patch["remind"] = rem::default_rule(&self.layer["settings"]);
                        }
                        if patch["remind"].is_null() {
                            patch.as_object_mut().unwrap().shift_remove("remind");
                        }
                        self.add_task(s(&tk["listId"]), s(&tk["title"]), tk["due"].as_str(), patch, None, s(&tk["notes"]));
                        added += 1;
                    }
                }
                ty @ ("move" | "done") => {
                    let list = text(&x["listId"]);
                    if let Some(tk) = self.task(&list, s(&x["taskId"])).cloned() {
                        if !Self::is_done(&tk) {
                            if ty == "done" {
                                self.toggle_done(&list, &tk);
                            } else {
                                self.set_due(&list, &tk, x["due"].as_str().map(|d| &d[..d.len().min(10)]));
                            }
                        }
                    }
                }
                _ => {}
            }
            ok.push(x["id"].clone());
        }
        if added > 0 {
            self.say(if added == 1 { "Из Telegram — новая задача".to_string() } else { format!("Из Telegram — новых задач: {added}") });
        }
        if !ok.is_empty() {
            let key = self.bot_key();
            run(move || bot::ack(&key, &ok), |_, _| {});
        }
    }

    pub fn bot_link(&mut self, code: &str) {
        let key = if self.bot_key().is_empty() {
            let b: [u8; 32] = rand::random();
            sbot::key_hex(&b)
        } else {
            self.bot_key()
        };
        let c = code.to_string();
        run(move || bot::link(&c, &key).map(|r| (r, key)), |app, r| match r {
            Ok((r, key)) => {
                app.bot_last.clear();
                app.touch("settings", "tgbot", json!({"key": key, "name": r["name"].as_str().unwrap_or(""), "at": now_ms()}));
                app.say("Telegram подключён ✓ — напоминания придут туда");
                app.bot_sync();
            }
            Err(e) => app.say(format!("Не привязался: {e}")),
        });
    }
    pub fn bot_test(&mut self) {
        let key = self.bot_key();
        run(move || bot::test(&key), |app, r| match r {
            Ok(()) => app.say("Отправил проверку — загляни в Telegram"),
            Err(e) => app.say(format!("Бот не ответил: {e}")),
        });
    }
    pub fn bot_unlink(&mut self) {
        let key = self.bot_key();
        run(move || bot::unlink(&key), |app, _| {
            app.touch("settings", "tgbot", json!({"key": null, "name": "", "at": null}));
            app.say("Telegram отключён");
        });
    }

    /// Запуск: опрос раз в 2 мин, повтор очереди раз в 30 с, уведомления раз в минуту.
    pub fn start_timers(&mut self) {
        let mk = |secs: u64, f: fn(&mut App)| {
            let t0 = slint::Timer::default();
            t0.start(slint::TimerMode::Repeated, Duration::from_secs(secs), move || {
                with(f);
            });
            t0
        };
        self.timers.repeat = vec![
            mk(120, |a| a.refresh()),
            mk(30, |a| a.flush(false)),
            mk(60, |a| a.tick_notify()),
            mk(3600, |a| a.gift_tasks()),
        ];
        if !self.flags.demo {
            self.notes.watch();
        }
        let u = self.update_timers();
        self.timers.repeat.extend(u);
        if !self.flags.need_login {
            self.refresh();
        }
        let _ = today_ymd;
    }
}

pub struct Fetched {
    lists: Vec<Value>,
    tasks: Vec<(String, Vec<Value>)>,
    calendars: Vec<Value>,
    events: Vec<Value>,
    from: String,
    to: String,
    inbox: Value,
    layer: Option<(Option<String>, Value)>,
}

fn month_start(d: chrono::NaiveDate, add: i32) -> String {
    use chrono::Datelike;
    let m0 = d.year() * 12 + d.month0() as i32 + add;
    format!("{:04}-{:02}-01", m0.div_euclid(12), m0.rem_euclid(12) + 1)
}

fn iso_of(ymd: &str) -> String {
    sputnik_core::dates::parse_ymd(ymd).and_then(|d| chrono::TimeZone::from_local_datetime(&chrono::Local, &d.and_hms_opt(0, 0, 0)?).earliest())
        .map(|d| d.with_timezone(&chrono::Utc).format("%Y-%m-%dT%H:%M:%SZ").to_string())
        .unwrap_or_else(|| format!("{ymd}T00:00:00Z"))
}

fn shown(c: &Value, cals_layer: &Value) -> bool {
    let name = s(&c["summary"]);
    if name.starts_with("Спутник · ") || s(&c["description"]).contains("sputnik-sphere") {
        return false;
    }
    let r = &cals_layer[s(&c["id"])];
    if r.is_object() && !r["hidden"].is_null() {
        return r["hidden"] != true;
    }
    t(&c["selected"]) || t(&c["primary"])
}

fn events_in(cals: &[Value], from: &str, to: &str) -> Vec<Value> {
    let (f, tt) = (iso_of(from), iso_of(to));
    std::thread::scope(|sc| {
        let hs: Vec<_> = cals.iter().map(|c| {
            let (f, tt) = (&f, &tt);
            sc.spawn(move || {
                let id = text(&c["id"]);
                api::events(&id, f, tt).unwrap_or_default().into_iter().map(|mut e| {
                    e["calId"] = json!(id);
                    e
                }).collect::<Vec<_>>()
            })
        }).collect();
        hs.into_iter().flat_map(|h| h.join().unwrap_or_default()).filter(|e| e["status"] != "cancelled").collect()
    })
}

/// Всё из Google параллельно (каждый список — свой поток).
fn fetch_all(cals_layer: &Value, layer_id: Option<String>) -> Result<Fetched, Fail> {
    std::thread::scope(|sc| {
        let layer_h = sc.spawn(move || -> Result<(Option<String>, Value), Fail> {
            let id = match layer_id {
                Some(i) => Some(i),
                None => api::find_layer()?,
            };
            let v = match &id {
                Some(i) => api::pull_layer(i)?,
                None => Value::Null,
            };
            Ok((id, v))
        });
        let cal_h = sc.spawn(move || -> Result<(Vec<Value>, Vec<Value>, String, String, Value), Fail> {
            let cals = api::calendars()?;
            let today = sputnik_core::habits::now().date();
            let (from, to) = (month_start(today, -1), month_start(today, 3));
            let show: Vec<Value> = cals.iter().filter(|c| shown(c, cals_layer)).cloned().collect();
            let evs = events_in(&show, &from, &to);
            let inbox = cals.iter().find(|c| s(&c["summary"]).starts_with("Спутник · входящие"))
                .and_then(|q| api::events(s(&q["id"]), "2029-12-31T00:00:00Z", "2030-01-03T00:00:00Z").ok())
                .and_then(|evs| evs.into_iter().find(|e| e["summary"] == "Спутник · статус"))
                .map(|e| inbox_json(s(&e["description"])))
                .unwrap_or(Value::Null);
            Ok((cals, evs, from, to, inbox))
        });
        let ls = api::lists()?;
        let hs: Vec<_> = ls.iter().map(|l| {
            let id = text(&l["id"]);
            sc.spawn(move || api::tasks(&id, 14).map(|v| (id, v)))
        }).collect();
        let mut tasks = vec![];
        for h in hs {
            tasks.push(h.join().map_err(|_| Fail::Net("поток упал".into()))??);
        }
        let (calendars, events, from, to, inbox) = cal_h.join().map_err(|_| Fail::Net("поток упал".into()))??;
        let layer = match layer_h.join() {
            Ok(Ok(x)) => Some(x),
            Ok(Err(e)) => {
                crate::data::store::log("слой", &e.to_string());
                None
            }
            Err(_) => None,
        };
        Ok(Fetched { lists: ls, tasks, calendars, events, from, to, inbox, layer })
    })
}

/// Статус «Входящих от Claude»: JSON в описании события (Google мог обернуть его в HTML).
fn inbox_json(desc: &str) -> Value {
    let re = sputnik_core::rx::rx(r"<[^>]+>");
    let txt = re.replace_all(desc, "").replace("&quot;", "\"").replace("&amp;", "&");
    let (Some(a0), Some(b0)) = (txt.find('{'), txt.rfind('}')) else { return Value::Null };
    if b0 < a0 {
        return Value::Null;
    }
    serde_json::from_str(&txt[a0..=b0]).unwrap_or(Value::Null)
}
