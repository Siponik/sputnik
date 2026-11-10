//! Состояние приложения «сначала локально»: экран читает память; действие меняет память, пишет файл и кладёт
//! операцию в очередь исходящих; Google обновляется в фоне (sync.rs). Порт app/lib/state/app_state.dart.
pub mod bg;
pub mod demo;
pub mod update;
pub mod shared;
pub mod sync;

use serde_json::{json, Value};
use sputnik_core::dates::{add_days, parse_ymd, ymd, ymd_to_due};
use sputnik_core::j::*;
use sputnik_core::{habits as hb, inbox, layer as lay, reminders as rem, repeat as rep, route, spheres as sph, templates as tpl, today};

pub use bg::{peek, run, with};

pub fn now_ms() -> f64 {
    chrono::Utc::now().timestamp_millis() as f64
}
pub fn today_ymd() -> String {
    ymd(hb::now().date())
}
pub fn iso_now() -> String {
    chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string()
}

/// Плашка внизу окна: текст и необязательное действие («Отменить», «Открыть»).
pub struct Toast {
    pub text: String,
    pub label: String,
    pub act: Option<Box<dyn FnOnce(&mut App)>>,
    pub id: u64,
}

#[derive(Default, Clone)]
pub struct Flags {
    pub started: bool,
    pub syncing: bool,
    pub offline: bool,
    pub need_login: bool,
    pub logging_in: bool,
    pub error: Option<String>,
    pub synced_at: Option<f64>,
    pub cloud_at: Option<f64>,
    pub cloud_err: Option<String>,
    pub load_ms: u128,
    pub demo: bool,
}

pub struct App {
    pub lists: Vec<Value>,
    /// listId → [задача Google]
    pub tasks: Value,
    pub calendars: Vec<Value>,
    pub events: Vec<Value>,
    pub ev_from: String,
    pub ev_to: String,
    pub layer: Value,
    pub inbox_st: Value,
    pub flags: Flags,
    pub toast: Option<Toast>,
    pub outbox: sync::Outbox,
    pub shared: shared::Shared,
    pub bot_err: String,
    pub bot_at: Option<f64>,
    pub bot_last: String,
    pub layer_id: Option<String>,
    pub notes: crate::notes::Notes,
    writer: bg::Writer,
    seq: u64,
    layer_dirty: bool,
    shown: Vec<String>,
    pub timers: Timers,
    pub update: update::Update,
    shared_q: std::collections::VecDeque<shared::Job>,
    shared_busy: bool,
}

#[derive(Default)]
pub struct Timers {
    pub layer: Option<slint::Timer>,
    pub bot: Option<slint::Timer>,
    pub toast: Option<slint::Timer>,
    pub outbox: Option<slint::Timer>,
    pub repeat: Vec<slint::Timer>,
}

impl App {
    pub fn load() -> App {
        let t0 = std::time::Instant::now();
        let mut layer = lay::empty_layer();
        extend(layer.as_object_mut().unwrap(), o(&crate::data::store::read_layer()));
        let cache = crate::data::store::read("cache.json").unwrap_or(Value::Null);
        let ops = crate::data::store::read("outbox.json").and_then(|v| v.as_array().cloned()).unwrap_or_default();
        let mut app = App {
            lists: a(&cache["lists"]).to_vec(),
            tasks: if cache["tasks"].is_object() { cache["tasks"].clone() } else { json!({}) },
            calendars: a(&cache["calendars"]).to_vec(),
            events: a(&cache["events"]).to_vec(),
            ev_from: String::new(),
            ev_to: String::new(),
            layer,
            inbox_st: cache["inbox"].clone(),
            flags: Flags::default(),
            toast: None,
            outbox: sync::Outbox::new(ops),
            shared: shared::Shared::load(),
            bot_err: String::new(),
            bot_at: None,
            bot_last: String::new(),
            layer_id: None,
            notes: crate::notes::Notes::load(),
            writer: bg::Writer::new(),
            seq: 0,
            layer_dirty: false,
            shown: vec![],
            timers: Timers::default(),
            update: Default::default(),
            shared_q: Default::default(),
            shared_busy: false,
        };
        let hour = app.layer["settings"]["remindHour"]["v"].as_str().map(String::from);
        rem::set_default_time(hour.as_deref());
        app.flags.need_login = !crate::data::google::signed_in();
        if demo::on() {
            demo::fill(&mut app);
        }
        app.flags.started = true;
        app.flags.load_ms = t0.elapsed().as_millis();
        app
    }

    /// Запись файла фоном (в демо — никуда).
    fn put(&self, name: &str, v: Value) {
        if !self.flags.demo {
            self.writer.write(name, v);
        }
    }

    pub fn save_cache(&self) {
        self.put("cache.json", json!({"lists": self.lists, "tasks": self.tasks, "calendars": self.calendars,
            "events": self.events, "inbox": self.inbox_st}));
    }
    pub fn save_outbox(&self) {
        self.put("outbox.json", Value::Array(self.outbox.ops.clone()));
    }
    pub fn save_shared(&self) {
        self.put("shared.json", self.shared.to_json());
    }

    // ---------- плашка ----------

    pub fn say(&mut self, text: impl Into<String>) {
        self.say_act(text, "", None);
    }

    pub fn say_act(&mut self, text: impl Into<String>, label: &str, act: Option<Box<dyn FnOnce(&mut App)>>) {
        self.seq += 1;
        let id = self.seq;
        self.toast = Some(Toast { text: text.into(), label: label.into(), act, id });
        let t = slint::Timer::default();
        t.start(slint::TimerMode::SingleShot, std::time::Duration::from_secs(6), move || {
            with(|a| {
                if a.toast.as_ref().is_some_and(|x| x.id == id) {
                    a.toast = None;
                }
            });
        });
        self.timers.toast = Some(t);
    }

    pub fn toast_act(&mut self) {
        if let Some(t) = self.toast.take() {
            if let Some(f) = t.act {
                f(self);
            }
        }
    }

    // ---------- слой ----------

    pub fn lt(&self, id: &str) -> &Value {
        &self.layer["tasks"][id]
    }
    pub fn ll(&self, id: &str) -> &Value {
        &self.layer["lists"][id]
    }
    pub fn settings(&self) -> &Value {
        &self.layer["settings"]
    }
    pub fn setting(&self, key: &str) -> &Value {
        &self.layer["settings"][key]["v"]
    }
    pub fn set_setting(&mut self, key: &str, v: Value) {
        self.touch("settings", key, json!({ "v": v }));
    }

    pub fn touch(&mut self, section: &str, key: &str, patch: Value) {
        lay::touch(&mut self.layer, section, key, &patch, now_ms());
        if section == "tasks" || section == "lists" {
            self.push_shared(section, key);
        }
        self.save_layer();
    }

    pub fn save_layer(&mut self) {
        self.layer_dirty = true;
        self.put("layer.json", self.layer.clone());
        let t = slint::Timer::default();
        t.start(slint::TimerMode::SingleShot, std::time::Duration::from_secs(4), || { with(|a| a.sync_layer_soon()); });
        self.timers.layer = Some(t);
        let b = slint::Timer::default();
        b.start(slint::TimerMode::SingleShot, std::time::Duration::from_secs(3), || { with(|a| a.bot_sync()); });
        self.timers.bot = Some(b);
    }

    fn writer_layer(&self) {
        self.put("layer.json", self.layer.clone());
    }
    fn layer_dirty_again(&mut self) {
        self.layer_dirty = true;
    }

    fn sync_layer_soon(&mut self) {
        if !self.layer_dirty || self.flags.need_login {
            return;
        }
        self.layer_dirty = false;
        self.sync_layer();
    }

    // ---------- что показывать ----------

    pub fn list(&self, id: &str) -> Option<&Value> {
        self.lists.iter().find(|l| l["id"] == id)
    }
    pub fn list_name(&self, id: &str) -> String {
        self.list(id).map(|l| text(&l["title"])).unwrap_or_default()
    }
    pub fn tasks_of(&self, list: &str) -> &[Value] {
        a(&self.tasks[list])
    }
    fn tasks_mut(&mut self, list: &str) -> &mut Vec<Value> {
        if !self.tasks.is_object() {
            self.tasks = json!({});
        }
        let m = self.tasks.as_object_mut().unwrap();
        let e = m.entry(list.to_string()).or_insert_with(|| json!([]));
        if !e.is_array() {
            *e = json!([]);
        }
        e.as_array_mut().unwrap()
    }
    pub fn task(&self, list: &str, id: &str) -> Option<&Value> {
        self.tasks_of(list).iter().find(|t| t["id"] == id)
    }
    /// Список задачи (по id).
    pub fn list_of_task(&self, id: &str) -> Option<String> {
        o(&self.tasks).iter().find(|(_, v)| a(v).iter().any(|t| t["id"] == id)).map(|(k, _)| k.clone())
    }
    pub fn is_done(t: &Value) -> bool {
        t["status"] == "completed"
    }
    pub fn top(t: &Value) -> bool {
        t["parent"].is_null() && !s(&t["title"]).trim().is_empty() && t["deleted"] != true
    }

    /// Списки для доски и «Сегодня»: не скрытые, не удалённые, не «Привычки».
    pub fn board_lists(&self) -> Vec<Value> {
        self.lists
            .iter()
            .filter(|l| {
                let ll = self.ll(s(&l["id"]));
                ll["hidden"] != true && ll["gone"] != true && !tpl::is_habit_list(l, &self.layer)
            })
            .cloned()
            .collect()
    }

    pub fn board(&self, list: &str) -> Value {
        tpl::board_of(list, &self.layer)
    }

    pub fn col_of(&self, t: &Value, cols: &[Value]) -> String {
        if Self::is_done(t) {
            return "done".into();
        }
        let st = &self.lt(s(&t["id"]))["status"];
        if t_(st) && st != "done" && cols.iter().any(|c| c["id"] == *st) {
            text(st)
        } else {
            cols.first().map(|c| text(&c["id"])).unwrap_or_else(|| "inbox".into())
        }
    }

    /// Задачи доски по колонкам; выполненные раньше срока архива — не на доске.
    pub fn columns(&self, list: &str) -> Vec<(Value, Vec<Value>)> {
        let b = self.board(list);
        let cols = a(&b["cols"]).to_vec();
        let days = tpl::archive_days(self.ll(list));
        let now = now_ms();
        let items: Vec<Value> = self.tasks_of(list).iter().filter(|t| Self::top(t) && !tpl::is_archived(t, days, now)).cloned().collect();
        let ordered = tpl::order_tasks(&items, &self.layer["tasks"], &tpl::sort_of(self.ll(list)));
        let mut out: Vec<(Value, Vec<Value>)> = cols.iter().map(|c| (c.clone(), vec![])).collect();
        for t in ordered {
            let c = self.col_of(&t, &cols);
            if let Some(x) = out.iter_mut().find(|x| x.0["id"] == c.as_str()) {
                x.1.push(t);
            }
        }
        out
    }

    /// «Сегодня»: открытые со сроком сегодня и раньше + сделанные сегодня.
    pub fn today_items(&self) -> Vec<(String, Value)> {
        let td = today_ymd();
        let mut out: Vec<(String, Value)> = vec![];
        for l in self.board_lists() {
            let id = text(&l["id"]);
            if self.ll(&id)["quiet"] == true {
                continue;
            }
            for x in self.tasks_of(&id) {
                if !Self::top(x) {
                    continue;
                }
                if id.starts_with("sh:") && !self.mine(x) {
                    continue;
                }
                let due = day10(&x["due"]);
                if Self::is_done(x) {
                    if day10(&x["completed"]) == td || (!due.is_empty() && due == td) {
                        out.push((id.clone(), x.clone()));
                    }
                } else if !due.is_empty() && due <= td {
                    out.push((id.clone(), x.clone()));
                }
            }
        }
        let prio = |x: &Value| n(&self.lt(s(&x["id"]))["priority"]).unwrap_or(2.0) as i64;
        let slot = |x: &Value| self.lt(s(&x["id"]))["slot"]["s"].as_str().unwrap_or("99").to_string();
        out.sort_by(|a0, b0| {
            (Self::is_done(&a0.1) as i32).cmp(&(Self::is_done(&b0.1) as i32))
                .then(slot(&a0.1).cmp(&slot(&b0.1)))
                .then(prio(&a0.1).cmp(&prio(&b0.1)))
                .then(day10(&a0.1["due"]).cmp(&day10(&b0.1["due"])))
        });
        out
    }

    /// Задачи со сроком в этот день (все списки).
    pub fn tasks_on(&self, day: &str) -> Vec<(String, Value)> {
        let mut out = vec![];
        for l in self.board_lists() {
            let id = text(&l["id"]);
            for x in self.tasks_of(&id) {
                if Self::top(x) && day10(&x["due"]) == day {
                    out.push((id.clone(), x.clone()));
                }
            }
        }
        out
    }

    /// События дня (местное время), весь день — первыми.
    pub fn events_on(&self, day: &str) -> Vec<Value> {
        let mut out: Vec<Value> = self
            .events
            .iter()
            .filter(|e| {
                let st = &e["start"];
                if st["date"].is_string() {
                    let end = if e["end"]["date"].is_string() { s(&e["end"]["date"]) } else { s(&st["date"]) };
                    return s(&st["date"]) <= day && day < end;
                }
                sputnik_core::calendar::local_dt(s(&st["dateTime"])).is_some_and(|d| ymd(d.date()) == day)
            })
            .cloned()
            .collect();
        out.sort_by(|a0, b0| s(&a0["start"]["dateTime"]).cmp(s(&b0["start"]["dateTime"])));
        out
    }

    pub fn is_birthday(e: &Value) -> bool {
        e["extendedProperties"]["private"]["sputnik"] == "birthday" || e["eventType"] == "birthday" || s(&e["calId"]).contains("#contacts@")
    }

    /// Показывать ли календарь: выбран в Google, не скрыт в слое, не служебный.
    pub fn cal_shown(&self, c: &Value) -> bool {
        if s(&c["summary"]).starts_with("Спутник · ") || s(&c["description"]).contains("sputnik-sphere") {
            return false;
        }
        let r = &self.layer["cals"][s(&c["id"])];
        if r.is_object() && !r["hidden"].is_null() {
            return r["hidden"] != true;
        }
        c["selected"] == true || c["primary"] == true
    }

    /// Календари, куда можно писать.
    pub fn writable_cals(&self) -> Vec<Value> {
        self.calendars
            .iter()
            .filter(|c| (["owner", "writer"].contains(&s(&c["accessRole"])) && self.cal_shown(c)) || c["primary"] == true)
            .cloned()
            .collect()
    }

    // ---------- привычки ----------

    pub fn habit_list(&self) -> Option<Value> {
        self.lists.iter().find(|l| tpl::is_habit_list(l, &self.layer)).cloned()
    }

    pub fn habits(&self) -> Vec<Value> {
        let Some(hl) = self.habit_list() else { return vec![] };
        let mut items: Vec<&Value> = self.tasks_of(s(&hl["id"])).iter().filter(|t| t["parent"].is_null() && !Self::is_done(t)).collect();
        items.sort_by(|a0, b0| s(&a0["position"]).cmp(s(&b0["position"])));
        let hs: Vec<Value> = items
            .iter()
            .map(|t| {
                let m = &self.layer["habits"][s(&t["id"])];
                let name = if s(&t["title"]).is_empty() { json!("Без названия") } else { t["title"].clone() };
                json!({"id": t["id"], "name": name, "days": if m["days"].is_null() { json!([]) } else { m["days"].clone() },
                    "win": m["win"], "time": m["time"], "end": m["end"], "createdAt": m["createdAt"], "part": m["part"],
                    "perWeek": m["perWeek"], "goal": m["goal"], "icon": m["icon"], "color": m["color"], "remind": m["remind"], "tipHide": m["tipHide"]})
            })
            .collect();
        hb::sort_habits(&hs)
    }

    pub fn habit_log(&self) -> &Value {
        &self.layer["log"]
    }

    pub fn habits_left(&self) -> usize {
        let td = today_ymd();
        self.habits().iter().filter(|h| !hb::is_done(self.habit_log(), &h["id"], &td)).count()
    }

    /// Отметка сегодня (у количества — «+1»).
    pub fn toggle_habit(&mut self, h: &Value) {
        let day = today_ymd();
        let mark = hb::next_mark(self.habit_log(), h, &day);
        self.touch("log", &hb::log_key(&h["id"], &day), mark);
        let streak = hb::stats(h, self.habit_log())["streak"].as_i64().unwrap_or(0);
        if hb::is_done(self.habit_log(), &h["id"], &day) && hb::MILESTONES.contains(&streak) {
            self.say(format!("Серия {streak}! {}", text(&h["name"])));
        }
    }

    /// Задним числом: state = done | skip | none.
    pub fn set_habit_day(&mut self, h: &Value, day: &str, state: &str) {
        self.touch("log", &hb::log_key(&h["id"], day), hb::day_mark(h, state));
    }

    pub fn save_habit(&mut self, id: &str, patch: Value) {
        self.touch("habits", id, patch);
    }

    pub fn add_habit(&mut self, name: String, fields: Value) {
        if let Some(hl) = self.habit_list() {
            let t = self.add_task(s(&hl["id"]), &name, None, json!({}), None, "");
            let mut f = fields;
            f["createdAt"] = json!(today_ymd());
            self.touch("habits", s(&t["id"]), f);
            return;
        }
        run(|| crate::data::api::create_list("Привычки"), move |app, r| match r {
            Ok(l) => {
                app.lists.push(l);
                app.add_habit(name, fields);
            }
            Err(e) => app.say(format!("Не получилось создать список «Привычки»: {e}")),
        });
    }

    pub fn rename_habit(&mut self, id: &str, name: &str) {
        if let Some(hl) = self.habit_list() {
            let lid = text(&hl["id"]);
            if let Some(t) = self.task(&lid, id).cloned() {
                self.rename(&lid, &t, name);
            }
        }
    }

    pub fn remove_habit(&mut self, id: &str) {
        if let Some(hl) = self.habit_list() {
            let lid = text(&hl["id"]);
            if let Some(t) = self.task(&lid, id).cloned() {
                self.remove(&lid, &t);
            }
        }
    }

    // ---------- доска ----------

    pub fn set_list_field(&mut self, list: &str, patch: Value) {
        self.touch("lists", list, patch);
    }

    /// Ручной выбор списка учит угадывание (settings.route).
    pub fn learn_route(&mut self, title: &str, list: &str, topic: &Value) {
        let cur = self.layer["settings"]["route"].clone();
        let learned = route::learn(&cur, title, list, topic);
        self.touch("settings", "route", learned);
    }

    pub fn set_task(&mut self, id: &str, patch: Value) {
        self.touch("tasks", id, patch);
    }

    /// Перенос в другой список: создать там, удалить здесь; поля слоя едут с задачей.
    pub fn move_to_list(&mut self, from: &str, t: &Value, to: &str) -> Option<String> {
        if from == to {
            return None;
        }
        let mut l = self.lt(s(&t["id"])).clone();
        if let Some(m) = l.as_object_mut() {
            m.shift_remove("t");
        }
        let x = self.add_task(to, s(&t["title"]), Some(&day10(&t["due"])), l, None, s(&t["notes"]));
        let id = text(&t["id"]);
        self.tasks_mut(from).retain(|y| y["id"] != id.as_str());
        if id.starts_with("tmp-") {
            self.outbox.drop_tmp(&id);
        } else {
            self.outbox.add(json!({"op": "delete", "list": from, "id": id}));
        }
        self.after_outbox();
        self.say(format!("Перенесено в «{}»", self.list_name(to)));
        Some(text(&x["id"]))
    }

    pub fn duplicate(&mut self, list: &str, t: &Value) {
        let mut l = self.lt(s(&t["id"])).clone();
        if let Some(m) = l.as_object_mut() {
            m.shift_remove("t");
        }
        self.add_task(list, &format!("{} (копия)", s(&t["title"])), Some(&day10(&t["due"])), l, None, s(&t["notes"]));
    }

    /// Архив списка: выполненные дольше срока архива.
    pub fn archived(&self, list: &str) -> Vec<Value> {
        let days = tpl::archive_days(self.ll(list));
        let now = now_ms();
        let mut v: Vec<Value> = self.tasks_of(list).iter().filter(|t| Self::top(t) && Self::is_done(t) && tpl::is_archived(t, days, now)).cloned().collect();
        v.sort_by(|a0, b0| s(&b0["completed"]).cmp(s(&a0["completed"])));
        v
    }

    /// Открытые задачи верхнего уровня (with_done — и выполненные до архива).
    pub fn top_tasks(&self, list: &str, with_done: bool) -> Vec<Value> {
        let days = tpl::archive_days(self.ll(list));
        let now = now_ms();
        self.tasks_of(list)
            .iter()
            .filter(|t| Self::top(t) && if with_done { !tpl::is_archived(t, days, now) } else { !Self::is_done(t) })
            .cloned()
            .collect()
    }

    pub fn subtasks(&self, list: &str, id: &str) -> Vec<Value> {
        let mut v: Vec<Value> = self.tasks_of(list).iter().filter(|t| t["parent"] == id && t["deleted"] != true).cloned().collect();
        v.sort_by(|a0, b0| s(&a0["position"]).cmp(s(&b0["position"])));
        v
    }

    pub fn add_subtask(&mut self, list: &str, parent: &str, title: &str) {
        let tmp = self.tmp_id();
        self.tasks_mut(list).push(json!({"id": tmp, "title": title, "status": "needsAction", "parent": parent}));
        self.outbox.add(json!({"op": "create", "list": list, "tmp": tmp, "body": {"title": title}, "parent": parent}));
        self.after_outbox();
    }

    // ---------- события и дни рождения (сразу в Google: событие без связи создать нельзя) ----------

    fn remind_props(mins: &[i64]) -> Value {
        if mins.is_empty() {
            return json!({});
        }
        let mut u: Vec<i64> = vec![];
        for m in mins {
            if !u.contains(m) {
                u.push(*m);
            }
        }
        json!({"sputnikR": "1", "sputnikRemind": u.iter().map(|m| m.to_string()).collect::<Vec<_>>().join(",")})
    }

    fn local_iso(day: &str, hhmm: &str) -> String {
        let d = parse_ymd(day).unwrap_or_else(|| hb::now().date());
        let (h, m) = hhmm.split_once(':').map(|(a0, b0)| (a0.parse().unwrap_or(0), b0.parse().unwrap_or(0))).unwrap_or((0, 0));
        let dt = d.and_hms_opt(0, 0, 0).unwrap() + chrono::Duration::minutes(h * 60 + m);
        rem::iso(rem::local(dt))
    }

    #[allow(clippy::too_many_arguments)]
    pub fn create_event(&mut self, title: &str, day: &str, slot: Option<(String, String)>, notes: &str, remind: &[i64], cal: &str,
        location: &str, recurrence: Value) {
        let mut body = json!({"summary": title});
        match &slot {
            Some((st, en)) => {
                body["start"] = json!({"dateTime": Self::local_iso(day, st)});
                body["end"] = json!({"dateTime": Self::local_iso(day, en)});
            }
            None => {
                body["start"] = json!({"date": day});
                body["end"] = json!({"date": ymd(add_days(parse_ymd(day).unwrap_or_else(|| hb::now().date()), 1))});
            }
        }
        if !notes.is_empty() {
            body["description"] = json!(notes);
        }
        if !location.is_empty() {
            body["location"] = json!(location);
        }
        if !remind.is_empty() {
            body["extendedProperties"] = json!({"private": Self::remind_props(remind)});
        }
        if recurrence.is_array() {
            body["recurrence"] = recurrence;
            if slot.is_some() {
                body["start"]["timeZone"] = json!("Europe/Moscow");
                body["end"]["timeZone"] = json!("Europe/Moscow");
            }
        }
        let cal = cal.to_string();
        let c2 = cal.clone();
        run(move || crate::data::api::create_event(&c2, &body), move |app, r| match r {
            Ok(mut e) => {
                e["calId"] = json!(cal);
                app.events.push(e);
                app.say("Событие добавлено");
            }
            Err(e) => app.say(format!("Событие не создалось: {e}")),
        });
    }

    #[allow(clippy::too_many_arguments)]
    pub fn create_birthday(&mut self, name: &str, day: &str, year: Option<i64>, remind: &[i64], cal: &str, gift_days: i64, gift_list: Option<String>) {
        let mut pv = json!({"sputnik": "birthday"});
        if let Some(y) = year {
            pv["sputnikYear"] = json!(y.to_string());
        }
        if gift_days > 0 {
            pv["sputnikGift"] = json!(gift_days.to_string());
            if let Some(g) = &gift_list {
                pv["sputnikGiftList"] = json!(g);
            }
        }
        extend(pv.as_object_mut().unwrap(), o(&Self::remind_props(remind)));
        let next = ymd(add_days(parse_ymd(day).unwrap_or_else(|| hb::now().date()), 1));
        let body = json!({"summary": format!("🎂 {name}"), "start": {"date": day}, "end": {"date": next}, "recurrence": ["RRULE:FREQ=YEARLY"],
            "transparency": "transparent", "extendedProperties": {"private": pv}, "reminders": {"useDefault": false}});
        let cal = cal.to_string();
        let c2 = cal.clone();
        run(move || crate::data::api::create_event(&c2, &body), move |app, r| match r {
            Ok(mut e) => {
                e["calId"] = json!(cal);
                app.events.push(e);
                app.say("День рождения сохранён");
                app.gift_tasks();
            }
            Err(e) => app.say(format!("День рождения не сохранился: {e}")),
        });
    }

    /// Подарки ко дням рождения: задача заводится сама, когда подошёл день (settings.gifts — уже заведённые).
    pub fn gift_tasks(&mut self) {
        let due = sputnik_core::create::gifts_due(&self.events, &today_ymd());
        for g in due {
            let key = text(&g["key"]);
            if !self.layer["settings"]["gifts"][key.as_str()].is_null() {
                continue;
            }
            let ls = self.board_lists();
            let dest = g["listId"].as_str().filter(|id| ls.iter().any(|l| l["id"] == *id)).map(String::from)
                .or_else(|| ls.iter().find(|l| s(&self.board(s(&l["id"]))["view"]) == "stickers").map(|l| text(&l["id"])))
                .or_else(|| ls.first().map(|l| text(&l["id"])));
            let Some(dest) = dest else { return };
            self.add_task(&dest, s(&g["title"]), Some(s(&g["due"])), json!({}), None, "");
            let mut gifts = o(&self.layer["settings"]["gifts"]).clone();
            gifts.insert(key, json!(now_ms()));
            gifts.shift_remove("t");
            self.touch("settings", "gifts", Value::Object(gifts));
        }
    }

    // ---------- повторы ----------

    pub fn roll_repeats(&mut self, quiet: bool) {
        let ls: Vec<Value> = self.lists.iter().filter(|l| !tpl::is_habit_list(l, &self.layer)).cloned().collect();
        let todo = rep::due_repeats(&ls, &self.tasks, &self.layer["tasks"]);
        let td = today_ymd();
        for r in todo {
            let list = text(&r["listId"]);
            let t = r["task"].clone();
            let Some(day) = rep::next_due(&r["rule"], &day10(&t["due"]), &td) else { continue };
            let have = rep::existing_next(self.tasks_of(&list), &t, &day);
            if !have.is_null() {
                self.touch("tasks", s(&t["id"]), json!({"repeatNext": have["id"], "repeatAt": now_ms()}));
                continue;
            }
            let was = self.lt(s(&t["id"])).clone();
            let mut carry = Json::new();
            for k in rep::CARRY {
                if !was[k].is_null() {
                    carry.insert(k.into(), was[k].clone());
                }
            }
            let x = self.add_task(&list, s(&t["title"]), Some(&day), Value::Object(carry), None, s(&t["notes"]));
            self.touch("tasks", s(&t["id"]), json!({"repeatNext": x["id"], "repeatAt": now_ms()}));
            if !quiet {
                self.say(format!("Повтор: «{}» — снова {}", s(&t["title"]), if day == td { "сегодня".into() } else { day }));
            }
        }
    }

    /// «Отменить» выполнение в первые 10 минут убирает созданную копию.
    fn unroll(&mut self, list: &str, t: &Value) {
        let was = self.lt(s(&t["id"])).clone();
        let Some(next) = was["repeatNext"].as_str().map(String::from) else { return };
        if now_ms() - n(&was["repeatAt"]).unwrap_or(0.0) > 600_000.0 {
            return;
        }
        self.touch("tasks", s(&t["id"]), json!({"repeatNext": null, "repeatAt": null}));
        if let Some(x) = self.task(list, &next).cloned() {
            if !Self::is_done(&x) {
                self.remove_quiet(list, &x);
            }
        }
    }

    // ---------- входящие от Claude ----------

    pub fn pull_inbox_layer(&mut self) {
        let r = inbox::pull_patches(&self.inbox_st, &self.layer);
        let def = n(&self.layer["settings"]["remind"]["task"][0]).unwrap_or(60.0);
        for x in a(&r["spheres"]) {
            self.touch("spheres", s(&x[0]), x[1].clone());
        }
        for x in a(&r["lists"]) {
            self.touch("lists", s(&x[0]), x[1].clone());
        }
        for x in a(&r["tasks"]) {
            let mut p = x[1].clone();
            if self.lt(s(&x[0]))["remind"].is_null() && p["remind"].is_null() {
                p["remind"] = json!({"kind": "lead", "min": num(def)});
            }
            self.touch("tasks", s(&x[0]), p);
        }
    }

    pub fn inbox_items(&self) -> Vec<Value> {
        inbox::pending(&self.inbox_st, &self.board_lists(), &self.tasks, &self.layer["tasks"])
    }

    pub fn accept_inbox(&mut self, items: &[Value]) {
        for x in items {
            let t = &x["task"];
            self.touch("tasks", s(&t["id"]), json!({"inbox": "accepted"}));
            if let Some(dest) = x["dest"].as_str() {
                if dest != s(&x["listId"]) {
                    self.move_to_list(s(&x["listId"]), t, dest);
                }
            }
        }
        if items.len() > 1 {
            self.say(format!("Принято задач: {}", items.len()));
        } else if let Some(x) = items.first() {
            self.say(format!("«{}» — принято", s(&x["task"]["title"])));
        }
    }

    pub fn reject_inbox(&mut self, x: &Value) {
        let t = x["task"].clone();
        self.touch("tasks", s(&t["id"]), json!({"inbox": "rejected"}));
        self.remove_quiet(s(&x["listId"]), &t);
        self.say(format!("«{}» — отклонено и удалено", s(&t["title"])));
    }

    // ---------- списки и сферы ----------

    pub fn spheres(&self) -> Vec<Value> {
        let mut v = sph::spheres_from(&self.layer);
        v.extend(self.shared.sphere_items());
        v
    }

    pub fn sphere_of(&self, list: &str) -> Option<String> {
        sph::sphere_of(list, &self.layer)
    }

    pub fn create_list(&mut self, title: &str, template: &str, sphere: Option<String>, view: Option<String>, then: Option<Box<dyn FnOnce(&mut App, String) + Send>>) {
        let title = title.to_string();
        let template = template.to_string();
        let cal = sphere.as_deref().and_then(|x| sputnik_core::sharedcore::cal_of_sphere(x).map(String::from));
        if let Some(cal) = cal {
            self.shared_create_list(&cal, &title, template, sphere, view, then);
            return;
        }
        run(move || crate::data::api::create_list(&title), move |app, r| match r {
            Ok(l) => {
                let id = text(&l["id"]);
                app.lists.push(l);
                let mut p = json!({"template": template});
                if let Some(sp) = sphere {
                    p["sphere"] = json!(sp);
                }
                if let Some(v) = view {
                    p["view"] = json!(v);
                }
                app.touch("lists", &id, p);
                if let Some(f) = then {
                    f(app, id);
                }
            }
            Err(e) => app.say(format!("Список не создался: {e}")),
        });
    }

    pub fn rename_list(&mut self, id: &str, title: &str) {
        let Some(l) = self.lists.iter_mut().find(|x| x["id"] == id) else { return };
        let was = l["title"].clone();
        l["title"] = json!(title);
        if id.starts_with("sh:") {
            self.shared_rename_list(id, title);
            return;
        }
        let (id2, t2) = (id.to_string(), title.to_string());
        run(move || crate::data::api::rename_list(&id2, &t2), move |app, r| {
            if let Err(e) = r {
                if let Some(l) = app.lists.iter_mut().find(|x| x["id"] == was["id"].clone().as_str().unwrap_or("")) {
                    l["title"] = was;
                }
                app.say(format!("Не переименовался: {e}"));
            }
        });
    }

    pub fn delete_list(&mut self, id: &str) {
        let id = id.to_string();
        let i2 = id.clone();
        let done = move |app: &mut App, r: Result<(), String>| match r {
            Ok(()) => {
                let ids: Vec<String> = app.tasks_of(&id).iter().map(|t| text(&t["id"])).collect();
                lay::forget_list(&mut app.layer, &id, &ids, now_ms());
                app.lists.retain(|l| l["id"] != id.as_str());
                if let Some(m) = app.tasks.as_object_mut() {
                    m.shift_remove(&id);
                }
                app.save_layer();
                app.say("Список удалён");
            }
            Err(e) => app.say(format!("Не удалось удалить список: {e}")),
        };
        if i2.starts_with("sh:") {
            self.shared_job(Box::new(move |sh| {
                let r = sh.delete_list(&i2).map_err(|e| e.to_string());
                Box::new(move |app: &mut App| done(app, r))
            }));
        } else {
            run(move || crate::data::api::delete_list(&i2).map_err(|e| e.to_string()), done);
        }
    }

    pub fn switch_template(&mut self, list: &str, tpl_id: &str) {
        let plan = tpl::switch_plan(&self.layer, list, tpl_id, &self.tasks[list], &Value::Null);
        self.touch("lists", list, plan["patch"].clone());
        for m in a(&plan["moves"]).to_vec() {
            self.touch("tasks", s(&m["id"]), json!({"status": m["status"]}));
        }
    }

    pub fn save_sphere(&mut self, id: Option<&str>, fields: Value) {
        if let Some(cal) = id.and_then(sputnik_core::sharedcore::cal_of_sphere) {
            let cal = cal.to_string();
            self.shared_patch(&cal, sputnik_core::sharedcore::SPHERE_KEY, &fields);
            return;
        }
        let sid = id.map(String::from).unwrap_or_else(|| format!("sp-{}", now_ms() as i64));
        let mut f = fields;
        if id.is_none() {
            let order = self.spheres().iter().filter_map(|x| n(&x["order"])).filter(|x| *x < 1000.0).fold(0.0, f64::max) + 1.0;
            f["order"] = num(order);
        }
        self.touch("spheres", &sid, f);
    }

    pub fn delete_sphere(&mut self, id: &str) {
        if let Some(cal) = sputnik_core::sharedcore::cal_of_sphere(id) {
            let cal = cal.to_string();
            self.shared_remove_sphere(&cal);
            return;
        }
        self.touch("spheres", id, json!({"removed": true}));
        let ids: Vec<String> = self.lists.iter().map(|l| text(&l["id"])).filter(|l| self.ll(l)["sphere"] == id).collect();
        for l in ids {
            self.touch("lists", &l, json!({"sphere": null}));
        }
    }

    // ---------- задачи ----------

    fn tmp_id(&mut self) -> String {
        self.seq += 1;
        format!("tmp-{}-{}", now_ms() as i64, self.seq)
    }

    fn patch_local(&mut self, list: &str, id: &str, body: &Value) {
        if let Some(t) = self.tasks_mut(list).iter_mut().find(|t| t["id"] == id) {
            for (k, v) in o(body) {
                if v.is_null() {
                    t.as_object_mut().unwrap().shift_remove(k);
                } else {
                    t[k.as_str()] = v.clone();
                }
            }
        }
    }

    fn send(&mut self, list: &str, id: &str, body: Value) {
        self.patch_local(list, id, &body);
        self.outbox.add(json!({"op": "patch", "list": list, "id": id, "body": body}));
        self.after_outbox();
    }

    pub fn toggle_done(&mut self, list: &str, t: &Value) {
        let done = !Self::is_done(t);
        if !done {
            self.unroll(list, t);
        }
        let body = if done { json!({"status": "completed", "completed": iso_now()}) } else { json!({"status": "needsAction", "completed": null}) };
        self.send(list, s(&t["id"]), body);
        if done {
            if let Some(tm) = self.lt(s(&t["id"]))["timer"].as_object() {
                let _ = tm;
                let p = sputnik_core::small::stop_patch(self.lt(s(&t["id"])), now_ms());
                self.touch("tasks", s(&t["id"]), p);
            }
            if !self.lt(s(&t["id"]))["repeat"].is_null() {
                self.roll_repeats(false);
            }
        }
    }

    /// Выполнить с «Отменить» на плашке.
    pub fn done_undo(&mut self, list: &str, t: &Value) {
        let was = Self::is_done(t);
        self.toggle_done(list, t);
        if !was {
            let (l, id) = (list.to_string(), text(&t["id"]));
            self.say_act(format!("Готово · «{}»", s(&t["title"])), "Отменить", Some(Box::new(move |a: &mut App| {
                if let Some(x) = a.task(&l, &id).cloned() {
                    a.toggle_done(&l, &x);
                }
            })));
        }
    }

    /// Перенос по колонкам: «готово» — выполнить, из «готово» — вернуть.
    pub fn set_stage(&mut self, list: &str, t: &Value, col: &str) {
        let id = text(&t["id"]);
        if col == "done" {
            if !Self::is_done(t) {
                self.toggle_done(list, t);
            }
            return;
        }
        if Self::is_done(t) {
            self.toggle_done(list, t);
        }
        let mut stage_at = o(&self.lt(&id)["stageAt"]).clone();
        stage_at.insert(col.into(), num(now_ms()));
        stage_at.shift_remove("t");
        let mut patch = json!({"status": col, "stageAt": stage_at});
        if id.starts_with("tmp-") || list.starts_with("sh:") {
            let from = self.col_of(t, a(&self.board(list)["cols"]));
            if list.starts_with("sh:") && from != col {
                let me = self.shared.me.clone();
                let sp = sputnik_core::sharedcore::stage_pass(self.lt(&id), &from, col, &me, Some(now_ms()));
                extend(patch.as_object_mut().unwrap(), o(&sp));
            }
        }
        self.touch("tasks", &id, patch);
    }

    pub fn set_due(&mut self, list: &str, t: &Value, day: Option<&str>) {
        let due = day.filter(|d| !d.is_empty()).and_then(ymd_to_due);
        self.send(list, s(&t["id"]), json!({ "due": due }));
    }

    /// Задача → новый день и время (перетаскивание в календаре). slot None — «весь день».
    pub fn schedule(&mut self, list: &str, t: &Value, day: &str, slot: Value) {
        if day10(&t["due"]) != day {
            self.set_due(list, t, Some(day));
        }
        self.set_task(s(&t["id"]), json!({ "slot": slot }));
    }

    pub fn rename(&mut self, list: &str, t: &Value, title: &str) {
        self.send(list, s(&t["id"]), json!({ "title": title }));
    }
    pub fn set_notes(&mut self, list: &str, t: &Value, notes: &str) {
        self.send(list, s(&t["id"]), json!({ "notes": notes }));
    }
    pub fn set_priority(&mut self, id: &str, p: Option<i64>) {
        self.touch("tasks", id, json!({ "priority": p }));
    }

    fn remove_quiet(&mut self, list: &str, t: &Value) {
        let id = text(&t["id"]);
        self.tasks_mut(list).retain(|x| x["id"] != id.as_str());
        self.touch("tasks", &id, json!({"gone": true}));
        if id.starts_with("tmp-") {
            self.outbox.drop_tmp(&id);
        } else {
            self.outbox.add(json!({"op": "delete", "list": list, "id": id}));
        }
        self.after_outbox();
    }

    /// Удалить с «Отменить» (6 с): отмена создаёт задачу заново с теми же полями.
    pub fn remove(&mut self, list: &str, t: &Value) {
        let mut keep = self.lt(s(&t["id"])).clone();
        if let Some(m) = keep.as_object_mut() {
            m.shift_remove("t");
        }
        self.remove_quiet(list, t);
        let (l, x) = (list.to_string(), t.clone());
        self.say_act("Задача удалена", "Отменить", Some(Box::new(move |a: &mut App| {
            a.add_task(&l, s(&x["title"]), Some(&day10(&x["due"])), keep, None, s(&x["notes"]));
        })));
    }

    /// Новая задача: сразу в памяти с временным id, в Google — из очереди.
    pub fn add_task(&mut self, list: &str, title: &str, due: Option<&str>, layer_patch: Value, col: Option<&str>, notes: &str) -> Value {
        let tmp = self.tmp_id();
        let mut body = json!({ "title": title });
        if let Some(d) = due.filter(|d| !d.is_empty()) {
            body["due"] = json!(ymd_to_due(d));
        }
        if !notes.is_empty() {
            body["notes"] = json!(notes);
        }
        let mut t = json!({ "id": tmp, "status": "needsAction" });
        extend(t.as_object_mut().unwrap(), o(&body));
        self.tasks_mut(list).insert(0, t.clone());
        let mut patch = layer_patch;
        if !patch.is_object() {
            patch = json!({});
        }
        if let Some(c) = col.filter(|c| *c != "done") {
            patch["status"] = json!(c);
        }
        if list.starts_with("sh:") && patch["who"].is_null() && !self.shared.me.is_empty() {
            patch["who"] = json!(self.shared.me);
        }
        if !o(&patch).is_empty() {
            self.touch("tasks", &tmp, patch);
        }
        self.outbox.add(json!({"op": "create", "list": list, "tmp": tmp, "body": body}));
        self.after_outbox();
        t
    }

    /// Умная строка: «купить молоко завтра 17:00 @дом !!» → задача в угаданный (или данный) список.
    pub fn add_line(&mut self, text_: &str, list: Option<&str>, no_date_today: bool) -> Option<(String, String)> {
        let td = hb::now().date();
        let p = route::parse_line(text_, td, &json!({}));
        let title = text(&p["title"]);
        if title.trim().is_empty() {
            return None;
        }
        let ls = self.board_lists();
        let dest = match list {
            Some(l) => Some(l.to_string()),
            None => route::route(text_, &ls, &self.layer, &self.tasks, None, now_ms()).first().map(|r| text(&r["listId"]))
                .or_else(|| ls.first().map(|l| text(&l["id"]))),
        }?;
        let x = today::task_from(&p, &ymd(td), &dest, &json!({}));
        let mut patch = if x["layer"].is_object() { x["layer"].clone() } else { json!({}) };
        if !x["slot"].is_null() {
            patch["slot"] = x["slot"].clone();
        }
        if patch["remind"].is_null() && (!p["day"].is_null() || no_date_today) {
            let r = rem::default_rule(self.settings());
            if !r.is_null() {
                patch["remind"] = r;
            }
        }
        let due = if no_date_today { x["due"].as_str().map(String::from) } else { p["day"].as_str().map(String::from) };
        self.add_task(&dest, &title, due.as_deref(), patch, None, "");
        Some((dest, title))
    }

    // ---------- Telegram ----------

    pub fn bot_key(&self) -> String {
        s(&self.layer["settings"]["tgbot"]["key"]).to_string()
    }

    /// Пункты напоминаний — для бота и уведомлений.
    pub fn remind_items(&self) -> Vec<Value> {
        let hour = self.layer["settings"]["remindHour"]["v"].as_str().map(String::from);
        rem::set_default_time(hour.as_deref());
        let evs: Vec<Value> = self.events.iter().filter(|e| e["extendedProperties"]["private"]["sputnikR"] == "1").cloned().collect();
        let ls = self.board_lists();
        let hl = self.habit_list().unwrap_or(Value::Null);
        let mut items = rem::collect(&ls, &self.tasks, &self.layer["tasks"], &hl, &[], &evs);
        items.extend(rem::habit_items(&self.habits(), self.habit_log(), None));
        items.extend(rem::assigned_items(&ls, &self.tasks, &self.layer["tasks"], None));
        items
    }

    /// Уведомления, пока приложение открыто: окно привычки; задачи — если бот не привязан.
    pub fn tick_notify(&mut self) {
        if self.layer["settings"]["notify"]["v"] == false {
            return;
        }
        let td = today_ymd();
        let sent: Vec<Value> = self.shown.iter().map(|x| json!(x)).collect();
        let hs = self.habits();
        let due: Vec<Value> = rem::habit_win_due(&hs, self.habit_log(), &sent, None).into_iter().cloned().collect();
        for h in due {
            self.shown.push(format!("{}|{td}", text(&h["id"])));
            crate::notify::show(&format!("Привычка · {}", text(&h["name"])), "Ещё не отмечено сегодня");
        }
        if !self.bot_key().is_empty() {
            return;
        }
        let now = now_ms();
        for it in self.remind_items() {
            let key = text(&it["key"]);
            let Some(at) = rem::parse_any(s(&it["fireAt"])).map(|d| d.timestamp_millis() as f64) else { continue };
            if self.shown.contains(&key) || at > now || now - at > 300_000.0 {
                continue;
            }
            self.shown.push(key);
            crate::notify::show("Спутник · напоминание", &format!("{}{}", s(&it["title"]), it["list"].as_str().map(|l| format!(" · {l}")).unwrap_or_default()));
        }
    }

    /// Задача общей сферы — моя или ничья.
    pub fn mine(&self, t: &Value) -> bool {
        let w = &self.lt(s(&t["id"]))["who"];
        !t_(w) || *w == self.shared.me.as_str()
    }
}

fn t_(v: &Value) -> bool {
    sputnik_core::j::t(v)
}
