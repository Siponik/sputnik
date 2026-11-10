//! Общие сферы — обмен с Google Календарём (порт app/lib/data/shared_store.dart; чистая логика — core::sharedcore).
//! У каждой сферы свой календарь «Спутник · сфера …», каждая запись — одно событие.
//! Shared — простые данные: сетевая работа идёт над копией в фоне по очереди (App::shared_job), копия потом
//! возвращается в App. Так окно не ждёт сети, а два обмена не перетирают друг друга.
use super::{now_ms, run, App};
use crate::data::api::enc;
use crate::data::google::{api, Fail};
use serde_json::{json, Map, Value};
use sputnik_core::j::*;
use sputnik_core::sharedcore as core;

const CAL: &str = "https://www.googleapis.com/calendar/v3";
type R<T> = Result<T, Fail>;

fn gone(e: &Fail) -> bool {
    matches!(e.status(), 404 | 410)
}
fn offline(e: &Fail) -> bool {
    matches!(e, Fail::Net(_))
}
fn rnd() -> f64 {
    rand::random::<f64>()
}

#[derive(Clone, Default)]
pub struct Shared {
    /// stores[cal] = { cal, title, role, sync, recs, base, pending, accepted, lost }
    pub stores: Map<String, Value>,
    pub me: String,
}

impl Shared {
    pub fn load() -> Shared {
        let j = crate::data::store::read("shared.json").unwrap_or(Value::Null);
        Shared { stores: o(&j["stores"]).clone(), me: s(&j["me"]).to_string() }
    }
    pub fn to_json(&self) -> Value {
        json!({"stores": self.stores, "me": self.me})
    }

    fn st(&mut self, cal: &str) -> &mut Value {
        self.stores.entry(cal.to_string()).or_insert_with(|| json!({"cal": cal, "sync": "", "recs": {}}))
    }
    fn recs(&mut self, cal: &str) -> &mut Map<String, Value> {
        let st = self.st(cal);
        if !st["recs"].is_object() {
            st["recs"] = json!({});
        }
        st["recs"].as_object_mut().unwrap()
    }
    fn pending(&mut self, cal: &str) -> &mut Map<String, Value> {
        let st = self.st(cal);
        if !st["pending"].is_object() {
            st["pending"] = json!({});
        }
        st["pending"].as_object_mut().unwrap()
    }
    fn rec(&self, cal: &str, k: &str) -> Value {
        self.stores.get(cal).map(|s0| s0["recs"][k].clone()).unwrap_or(Value::Null)
    }

    fn invite(&self, st: &Value) -> bool {
        core::is_invite(st, &self.me)
    }
    pub fn active_calendars(&self) -> Vec<String> {
        self.stores.values().filter(|x| !t(&x["lost"]) && !self.invite(x)).map(|x| text(&x["cal"])).collect()
    }
    pub fn invites(&self) -> Vec<Value> {
        let me = (!self.me.is_empty()).then_some(self.me.as_str());
        self.stores.values().filter(|x| !t(&x["lost"]) && self.invite(x)).map(|x| core::invite_info(x, me)).collect()
    }
    pub fn is_lost(&self, cal: &str) -> bool {
        self.stores.get(cal).is_some_and(|x| t(&x["lost"]))
    }
    pub fn is_owner(&self, cal: &str) -> bool {
        self.stores.get(cal).is_some_and(|x| x["role"] == "owner")
    }
    pub fn people(&self, cal: &str) -> Vec<Value> {
        core::members_of(self.stores.get(cal).map(|x| &x["recs"]).unwrap_or(&NULL))
    }
    pub fn sphere_rec(&self, cal: &str) -> Option<&Value> {
        self.stores.get(cal).map(|x| &x["recs"][core::SPHERE_KEY]).filter(|r| r.is_object())
    }
    pub fn cal_of_list(&self, lk: Option<&str>) -> Option<String> {
        let lk = lk?;
        self.stores.values().find(|x| x["recs"].get(lk).is_some()).map(|x| text(&x["cal"]))
    }

    /// Сферы для колонки: поля записи сферы + id/порядок/метки.
    pub fn sphere_items(&self) -> Vec<Value> {
        let mut cals = self.active_calendars();
        cals.extend(self.stores.keys().filter(|c| self.is_lost(c)).cloned());
        let mut out = vec![];
        for cal in cals {
            if let Some(r) = self.sphere_rec(&cal) {
                let mut f = o(&r["f"]).clone();
                f.insert("id".into(), json!(core::sphere_id(&cal)));
                f.insert("order".into(), json!(1000));
                f.insert("shared".into(), json!(true));
                f.insert("lost".into(), json!(self.is_lost(&cal)));
                f.insert("owner".into(), json!(self.is_owner(&cal)));
                out.push(Value::Object(f));
            }
        }
        out
    }

    /// Списки общих сфер (как списки Google Tasks).
    pub fn lists(&self) -> Vec<Value> {
        let mut out = vec![];
        for st in self.stores.values() {
            if self.invite(st) {
                continue;
            }
            for mut l in core::lists_of(&st["recs"], &st["cal"]) {
                if t(&st["lost"]) {
                    l["lost"] = json!(true);
                }
                out.push(l);
            }
        }
        out
    }
    pub fn tasks(&self, id: &str) -> Vec<Value> {
        let lk = core::list_key(id);
        match self.cal_of_list(lk) {
            Some(cal) => core::tasks_of(&self.stores[&cal]["recs"], lk.unwrap()),
            None => vec![],
        }
    }

    // ---------- обмен (блокирующий, только в фоне) ----------

    /// Найти календари сфер и забрать изменения. Возвращает потерянные только что календари.
    pub fn pull_all(&mut self) -> R<Vec<String>> {
        let r = api("GET", &format!("{CAL}/users/me/calendarList?minAccessRole=reader&showHidden=true"), None)?;
        let items = a(&r["items"]).to_vec();
        for c in &items {
            if t(&c["primary"]) {
                self.me = text(&c["id"]);
            }
        }
        let found: Vec<Value> = items.into_iter().filter(core::is_sphere_cal).collect();
        let mut lost = vec![];
        let cals: Vec<String> = self.stores.keys().cloned().collect();
        for cal in cals {
            if !found.iter().any(|c| c["id"] == cal.as_str()) && !self.is_lost(&cal) {
                self.st(&cal)["lost"] = json!(true);
                lost.push(cal);
            }
        }
        for c in found {
            let id = text(&c["id"]);
            let st = self.st(&id);
            st["role"] = c["accessRole"].clone();
            st["title"] = c["summary"].clone();
            let res = self.flush(&id).and_then(|_| self.pull(&id));
            match res {
                Ok(got) => {
                    self.st(&id)["lost"] = json!(false);
                    let stv = self.stores[&id].clone();
                    if !self.invite(&stv) {
                        self.mark_joined(&id, &got)?;
                    }
                }
                Err(e) if matches!(e.status(), 403 | 404) => {
                    if !self.is_lost(&id) {
                        self.st(&id)["lost"] = json!(true);
                        lost.push(id);
                    }
                }
                Err(e) => return Err(e),
            }
        }
        Ok(lost)
    }

    fn pull(&mut self, cal: &str) -> R<Vec<Value>> {
        let mut out = vec![];
        let full = s(&self.st(cal)["sync"]).is_empty();
        let mut seen = std::collections::HashSet::new();
        let mut page = String::new();
        loop {
            let mut q = format!("maxResults=2500&showDeleted={}", if full { "false" } else { "true" });
            if !full {
                q += &format!("&syncToken={}", enc(s(&self.st(cal)["sync"])));
            }
            if !page.is_empty() {
                q += &format!("&pageToken={}", enc(&page));
            }
            let r = match api("GET", &format!("{CAL}/calendars/{}/events?{q}", enc(cal)), None) {
                Ok(r) => r,
                Err(e) if e.status() == 410 && !full => {
                    self.st(cal)["sync"] = json!("");
                    return self.pull(cal);
                }
                Err(e) => return Err(e),
            };
            for ev in a(&r["items"]) {
                let rec = core::from_event(ev);
                let k = if rec.is_object() { text(&rec["k"]) } else { text(&ev["id"]) };
                seen.insert(k.clone());
                let base = self.rec(cal, &k);
                if !rec.is_object() {
                    if base.is_object() && ev["status"] == "cancelled" {
                        self.recs(cal).shift_remove(&k);
                        out.push(Value::Null);
                    }
                    continue;
                }
                let m = core::merge_rec(&base, &rec);
                if base.is_object() && core::same(Some(&base), Some(&m)) {
                    continue;
                }
                self.recs(cal).insert(k, m.clone());
                out.push(m);
            }
            page = text(&r["nextPageToken"]);
            if page.is_empty() {
                self.st(cal)["sync"] = r.get("nextSyncToken").cloned().unwrap_or(json!(""));
                break;
            }
        }
        if full {
            let keys: Vec<String> = self.recs(cal).keys().cloned().collect();
            for k in keys {
                if !seen.contains(&k) && self.pending(cal).get(&k).is_none() {
                    self.recs(cal).shift_remove(&k);
                    out.push(Value::Null);
                }
            }
        }
        Ok(out)
    }

    fn write(&mut self, cal: &str, rec: Value) -> R<Value> {
        let mut r = rec;
        if !self.me.is_empty() && r["f"]["by"] != self.me.as_str() {
            r = core::edit(&r, &json!({"by": self.me}), None);
        }
        match self.put(cal, &r) {
            Ok(m) => Ok(m),
            Err(e) if offline(&e) && self.stores.contains_key(cal) => {
                let k = text(&r["k"]);
                self.recs(cal).insert(k.clone(), r.clone());
                self.pending(cal).insert(k, json!("w"));
                Ok(r)
            }
            Err(e) => Err(e),
        }
    }

    fn put(&mut self, cal: &str, rec: &Value) -> R<Value> {
        let k = text(&rec["k"]);
        let url = format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(&k));
        let cur = match api("GET", &url, None) {
            Ok(ev) => core::from_event(&ev),
            Err(e) if gone(&e) => Value::Null,
            Err(e) => return Err(e),
        };
        let m = core::merge_rec(&cur, rec);
        let body = core::to_event(&m);
        if cur.is_object() {
            api("PUT", &url, Some(&body))?;
        } else {
            match api("POST", &format!("{CAL}/calendars/{}/events", enc(cal)), Some(&body)) {
                Ok(_) => {}
                Err(e) if e.status() == 409 => {
                    let mut b = body.clone();
                    b["status"] = json!("confirmed");
                    api("PUT", &url, Some(&b))?;
                }
                Err(e) => return Err(e),
            }
        }
        if self.stores.contains_key(cal) {
            self.recs(cal).insert(k.clone(), m.clone());
            self.pending(cal).shift_remove(&k);
        }
        Ok(m)
    }

    fn drop_rec(&mut self, cal: &str, k: &str) -> R<()> {
        let r = api("DELETE", &format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(k)), None);
        let mut keep_d = false;
        match r {
            Ok(_) => {}
            Err(e) if offline(&e) && self.stores.contains_key(cal) => {
                self.pending(cal).insert(k.into(), json!("d"));
                keep_d = true;
            }
            Err(e) if gone(&e) => {}
            Err(e) => return Err(e),
        }
        if self.stores.contains_key(cal) {
            self.recs(cal).shift_remove(k);
            if !keep_d {
                self.pending(cal).shift_remove(k);
            }
        }
        Ok(())
    }

    fn flush(&mut self, cal: &str) -> R<()> {
        let p: Vec<(String, Value)> = self.pending(cal).iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        for (k, v) in p {
            if v == "d" {
                match api("DELETE", &format!("{CAL}/calendars/{}/events/{}", enc(cal), enc(&k)), None) {
                    Ok(_) => {}
                    Err(e) if gone(&e) => {}
                    Err(e) => return Err(e),
                }
                self.pending(cal).shift_remove(&k);
            } else {
                let r = self.rec(cal, &k);
                if r.is_object() {
                    self.put(cal, &r)?;
                } else {
                    self.pending(cal).shift_remove(&k);
                }
            }
        }
        Ok(())
    }

    fn mark_joined(&mut self, cal: &str, got: &[Value]) -> R<()> {
        if self.me.is_empty() || !self.rec(cal, core::SPHERE_KEY).is_object() {
            return Ok(());
        }
        let k = core::member_key(&self.me);
        let cur = self.rec(cal, &k);
        let cf = cur["f"].clone();
        let me = self.me.clone();
        let foreign = got.iter().any(|r| {
            r.is_object() && !r["f"]["by"].is_null() && r["f"]["by"] != me.as_str() && core::last_time(r) > n(&cf["seen"]).unwrap_or(0.0)
        });
        let stale = core::seen_due(&cf["seen"], foreign, None);
        if t(&cf["joined"]) && !t(&cf["removed"]) && !stale {
            return Ok(());
        }
        let now = now_ms();
        let next = if cur.is_object() {
            core::edit(&cur, &json!({"joined": true, "removed": false, "seen": now}), None)
        } else {
            let order = core::next_order(&self.stores[cal]["recs"]);
            core::make(&k, &json!({"email": me, "order": order, "joined": true, "seen": now}), None)
        };
        self.write(cal, next).map(|_| ())
    }

    pub fn patch_rec(&mut self, cal: &str, k: &str, patch: &Value) -> R<Value> {
        let cur = self.rec(cal, k);
        if !cur.is_object() {
            return Ok(Value::Null);
        }
        let next = core::edit(&cur, patch, None);
        if core::same(Some(&next), Some(&cur)) {
            return Ok(cur);
        }
        self.write(cal, next)
    }

    pub fn apply_profile(&mut self, profile: &Value) -> R<()> {
        if self.me.is_empty() {
            return Ok(());
        }
        for cal in self.active_calendars() {
            let cur = self.rec(&cal, &core::member_key(&self.me));
            if !cur.is_object() || t(&cur["f"]["removed"]) {
                continue;
            }
            let patch = core::profile_patch(&cur, profile);
            if !o(&patch).is_empty() {
                self.write(&cal, core::edit(&cur, &patch, None))?;
            }
        }
        Ok(())
    }

    // ---------- задачи и списки — как Google Tasks ----------

    fn need(&self, id: &str) -> R<(String, String)> {
        let lk = core::list_key(id);
        match (lk, self.cal_of_list(lk)) {
            (Some(lk), Some(cal)) => Ok((lk.to_string(), cal)),
            _ => Err(Fail::Status(404, "общий список не найден".into())),
        }
    }

    pub fn create_task(&mut self, id: &str, body: &Value, parent: Option<&str>, layer: &Json) -> R<Value> {
        let (lk, cal) = self.need(id)?;
        let mut b = json!({"title": "", "notes": "", "status": "needsAction"});
        extend(b.as_object_mut().unwrap(), o(body));
        let mut f = json!({"list": lk, "pos": core::new_pos(None)});
        let fm = f.as_object_mut().unwrap();
        extend(fm, o(&core::task_patch(&b, None)));
        if let Some(p) = parent {
            fm.insert("parent".into(), json!(p));
        }
        for (k, v) in layer {
            fm.insert(format!("${k}"), v.clone());
        }
        if fm.get("completed").is_some_and(Value::is_null) {
            fm.shift_remove("completed");
        }
        let key = core::new_key("t", &mut rnd);
        let r = self.write(&cal, core::make(&key, &f, None))?;
        Ok(core::task_view(&r))
    }

    pub fn patch_task(&mut self, id: &str, task: &str, body: &Value) -> R<Value> {
        let (_, cal) = self.need(id)?;
        let cur = self.rec(&cal, task);
        if !cur.is_object() {
            return Err(Fail::Status(404, "задача не найдена".into()));
        }
        let next = core::edit(&cur, &core::task_patch(body, None), None);
        if core::same(Some(&next), Some(&cur)) {
            return Ok(core::task_view(&cur));
        }
        Ok(core::task_view(&self.write(&cal, next)?))
    }

    pub fn delete_task(&mut self, id: &str, task: &str) -> R<()> {
        let (_, cal) = self.need(id)?;
        let ks = core::with_children(&self.stores[&cal]["recs"], task);
        for k in ks.iter().rev() {
            self.drop_rec(&cal, k)?;
        }
        Ok(())
    }

    pub fn create_list(&mut self, cal: &str, title: &str) -> R<Value> {
        let key = core::new_key("l", &mut rnd);
        let r = self.write(cal, core::make(&key, &json!({"title": title, "created": now_ms()}), None))?;
        Ok(core::list_view(&r, &json!(cal)))
    }

    pub fn rename_list(&mut self, id: &str, title: &str) -> R<()> {
        let (lk, cal) = self.need(id)?;
        self.patch_rec(&cal, &lk, &json!({"title": title})).map(|_| ())
    }

    pub fn delete_list(&mut self, id: &str) -> R<()> {
        let (lk, cal) = self.need(id)?;
        for sub_first in [true, false] {
            let ks: Vec<String> = self.stores[&cal]["recs"]
                .as_object()
                .map(|m| {
                    m.values()
                        .filter(|r| r["f"]["list"] == lk.as_str() && (!sub_first || !r["f"]["parent"].is_null()))
                        .map(|r| text(&r["k"]))
                        .collect()
                })
                .unwrap_or_default();
            for k in ks {
                self.drop_rec(&cal, &k)?;
            }
        }
        self.drop_rec(&cal, &lk)
    }

    // ---------- сфера ----------

    pub fn create_sphere(&mut self, name: &str, color: &str, icon: &str) -> R<String> {
        let c = api("POST", &format!("{CAL}/calendars"), Some(&json!({
            "summary": format!("Спутник · сфера {name}"),
            "description": format!("{} v1 — служебный календарь общей сферы Спутника. Не удаляй и не меняй его события вручную.", core::MARK),
            "timeZone": "Europe/Moscow",
        })))?;
        let id = text(&c["id"]);
        let _ = api("PATCH", &format!("{CAL}/users/me/calendarList/{}", enc(&id)), Some(&json!({"selected": false, "hidden": true})));
        self.stores.insert(id.clone(), json!({"cal": id, "title": c["summary"], "role": "owner", "sync": "", "recs": {}, "accepted": true}));
        let owner = if self.me.is_empty() { Value::Null } else { json!(self.me) };
        self.write(&id, core::make(core::SPHERE_KEY, &json!({"name": name, "color": color, "icon": icon, "owner": owner}), None))?;
        if !self.me.is_empty() {
            let me = self.me.clone();
            self.write(&id, core::make(&core::member_key(&me), &json!({"email": me, "order": 0, "joined": true}), None))?;
        }
        Ok(id)
    }

    pub fn remove_sphere(&mut self, cal: &str) -> R<()> {
        if self.is_lost(cal) {
            return self.forget(cal);
        }
        if self.is_owner(cal) {
            api("DELETE", &format!("{CAL}/calendars/{}", enc(cal)), None)?;
        } else {
            let k = core::member_key(&self.me);
            if !self.me.is_empty() && self.rec(cal, &k).is_object() {
                let _ = self.patch_rec(cal, &k, &json!({"removed": true}));
            }
            api("DELETE", &format!("{CAL}/users/me/calendarList/{}", enc(cal)), None)?;
        }
        self.stores.shift_remove(cal);
        Ok(())
    }

    pub fn join(&mut self, code: &str) -> R<String> {
        let id = code.trim().to_string();
        let c = api("POST", &format!("{CAL}/users/me/calendarList"), Some(&json!({"id": id, "selected": false, "hidden": true})))?;
        if !core::is_sphere_cal(&c) {
            let ev = api("GET", &format!("{CAL}/calendars/{}/events/{}", enc(&id), core::SPHERE_KEY), None).unwrap_or(Value::Null);
            if !core::from_event(&ev).is_object() {
                return Err(Fail::Status(400, "Это не общая сфера Спутника".into()));
            }
        }
        let role = if c["accessRole"].is_null() { json!("writer") } else { c["accessRole"].clone() };
        let st = self.stores.entry(id.clone()).or_insert_with(|| json!({"cal": id, "title": c["summary"], "role": role, "sync": "", "recs": {}}));
        st["accepted"] = json!(true);
        st["lost"] = json!(false);
        Ok(id)
    }

    pub fn accept(&mut self, cal: &str) -> R<()> {
        if !self.stores.contains_key(cal) {
            return Ok(());
        }
        self.st(cal)["accepted"] = json!(true);
        let _ = api("PATCH", &format!("{CAL}/users/me/calendarList/{}", enc(cal)), Some(&json!({"selected": false, "hidden": true})));
        self.mark_joined(cal, &[])
    }

    pub fn forget(&mut self, cal: &str) -> R<()> {
        let _ = api("DELETE", &format!("{CAL}/users/me/calendarList/{}", enc(cal)), None);
        self.stores.shift_remove(cal);
        Ok(())
    }

    pub fn invite_person(&mut self, cal: &str, email: &str) -> R<()> {
        let e = email.trim().to_lowercase();
        api("POST", &format!("{CAL}/calendars/{}/acl?sendNotifications=true", enc(cal)),
            Some(&json!({"role": "writer", "scope": {"type": "user", "value": e}})))?;
        let k = core::member_key(&e);
        let cur = self.rec(cal, &k);
        let next = if cur.is_object() {
            core::edit(&cur, &json!({"removed": false}), None)
        } else {
            let order = core::next_order(&self.stores[cal]["recs"]);
            core::make(&k, &json!({"email": e, "order": order, "joined": false}), None)
        };
        if !core::same(Some(&next), Some(&cur)) {
            self.write(cal, next)?;
        }
        Ok(())
    }

    pub fn remove_member(&mut self, cal: &str, email: &str) -> R<()> {
        let e = email.trim().to_lowercase();
        match api("DELETE", &format!("{CAL}/calendars/{}/acl/{}", enc(cal), enc(&format!("user:{e}"))), None) {
            Ok(_) => {}
            Err(x) if gone(&x) => {}
            Err(x) => return Err(x),
        }
        let k = core::member_key(&e);
        if self.rec(cal, &k).is_object() {
            self.patch_rec(cal, &k, &json!({"removed": true}))?;
        }
        Ok(())
    }

    pub fn invite_text(cal: &str, sphere: &str) -> String {
        let link = format!("https://calendar.google.com/calendar/r?cid={}", enc(cal));
        format!("Зову тебя в общую сферу «{sphere}» в Спутнике.\n1) Открой ссылку и добавь календарь: {link}\n2) Или в Спутнике: Доска → + сфера → «Войти в общую сферу…» и код: {cal}")
    }
}

/// Задание над копией общих сфер: в фоне меняет Shared и возвращает, что сделать потом в окне.
pub type Job = Box<dyn FnOnce(&mut Shared) -> Box<dyn FnOnce(&mut App) + Send> + Send>;

impl App {
    /// Поставить задание в очередь общих сфер (по одному, чтобы обмены не перетирали друг друга).
    pub fn shared_job(&mut self, job: Job) {
        self.shared_q.push_back(job);
        self.shared_next();
    }

    fn shared_next(&mut self) {
        if self.shared_busy {
            return;
        }
        let Some(job) = self.shared_q.pop_front() else { return };
        self.shared_busy = true;
        let mut copy = self.shared.clone();
        run(move || {
            let then = job(&mut copy);
            (copy, then)
        }, |app, (copy, then)| {
            app.shared = copy;
            app.shared_busy = false;
            app.save_shared();
            then(app);
            app.shared_next();
        });
    }

    /// Простое действие со сферами: ошибка — плашкой, успех — обновить всё.
    pub fn shared_act(&mut self, fail: &'static str, f: impl FnOnce(&mut Shared) -> R<()> + Send + 'static) {
        self.shared_job(Box::new(move |sh| {
            let r = f(sh).map_err(|e| e.to_string());
            Box::new(move |app: &mut App| match r {
                Ok(()) => app.refresh(),
                Err(e) => app.say(format!("{fail}: {e}")),
            })
        }));
    }

    pub fn shared_patch(&mut self, cal: &str, k: &str, patch: &Value) {
        let (cal, k, patch) = (cal.to_string(), k.to_string(), patch.clone());
        self.shared_job(Box::new(move |sh| {
            let _ = sh.patch_rec(&cal, &k, &patch);
            Box::new(|_: &mut App| {})
        }));
    }

    pub fn accept_invite(&mut self, cal: &str) {
        let c = cal.to_string();
        self.shared_act("Не принялось", move |sh| sh.accept(&c));
    }
    pub fn decline_invite(&mut self, cal: &str) {
        let c = cal.to_string();
        self.shared_act("Не получилось", move |sh| sh.remove_sphere(&c));
    }
    pub fn join_sphere(&mut self, code: &str) {
        let c = code.to_string();
        self.shared_act("Не вошёл в сферу", move |sh| sh.join(&c).map(|_| ()));
    }
    pub fn forget_sphere(&mut self, cal: &str) {
        let c = cal.to_string();
        self.shared_act("Не убралось", move |sh| sh.forget(&c));
    }
    pub fn invite_person(&mut self, cal: &str, email: &str) {
        let (c, e) = (cal.to_string(), email.to_string());
        self.shared_act("Не позвал", move |sh| sh.invite_person(&c, &e));
    }
    pub fn remove_person(&mut self, cal: &str, email: &str) {
        let (c, e) = (cal.to_string(), email.to_string());
        self.shared_act("Не убрал", move |sh| sh.remove_member(&c, &e));
    }
    pub fn shared_remove_sphere(&mut self, cal: &str) {
        let c = cal.to_string();
        self.shared_act("Не удалилась сфера", move |sh| sh.remove_sphere(&c));
    }
    pub fn apply_profile(&mut self) {
        let p = self.layer["settings"]["profile"].clone();
        self.shared_job(Box::new(move |sh| {
            let _ = sh.apply_profile(&p);
            Box::new(|_: &mut App| {})
        }));
    }

    pub fn shared_create_list(&mut self, cal: &str, title: &str, template: String, sphere: Option<String>, view: Option<String>,
        then: Option<Box<dyn FnOnce(&mut App, String) + Send>>) {
        let (c, ti) = (cal.to_string(), title.to_string());
        self.shared_job(Box::new(move |sh| {
            let r = sh.create_list(&c, &ti).map_err(|e| e.to_string());
            Box::new(move |app: &mut App| match r {
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
            })
        }));
    }

    pub fn shared_rename_list(&mut self, id: &str, title: &str) {
        let (i, ti) = (id.to_string(), title.to_string());
        self.shared_job(Box::new(move |sh| {
            let r = sh.rename_list(&i, &ti).map_err(|e| e.to_string());
            Box::new(move |app: &mut App| {
                if let Err(e) = r {
                    app.say(format!("Не переименовался: {e}"));
                    app.refresh();
                }
            })
        }));
    }

    /// Сделать сферу общей: календарь сферы, списки переезжают туда вместе с задачами.
    pub fn share_sphere(&mut self, sphere_id: &str) {
        let Some(sp) = self.spheres().into_iter().find(|x| x["id"] == sphere_id) else { return };
        let lists: Vec<String> = self.lists.iter().map(|l| text(&l["id"])).filter(|l| self.sphere_of(l).as_deref() == Some(sphere_id)).collect();
        let mut plan = vec![];
        for l in &lists {
            let mut ll = o(self.ll(l)).clone();
            ll.shift_remove("t");
            let ts: Vec<(Value, Json)> = self.tasks_of(l).iter().map(|t0| {
                let mut lt = o(self.lt(s(&t0["id"]))).clone();
                lt.shift_remove("t");
                (t0.clone(), lt)
            }).collect();
            let title = text(&self.list(l).map(|x| x["title"].clone()).unwrap_or_default());
            plan.push((l.clone(), title, ll, ts));
        }
        let sid = sphere_id.to_string();
        let (name, color, icon) = (sp["name"].as_str().unwrap_or("Сфера").to_string(), sp["color"].as_str().unwrap_or("clay").to_string(), sp["icon"].as_str().unwrap_or("star").to_string());
        self.say("Делаю сферу общей…");
        self.shared_job(Box::new(move |sh| {
            let res = (|| -> R<(String, Vec<(String, Value)>)> {
                let cal = sh.create_sphere(&name, &color, &icon)?;
                let mut touches = vec![];
                for (old, title, ll, ts) in plan {
                    let nl = sh.create_list(&cal, &title)?;
                    let nid = text(&nl["id"]);
                    let mut lp = ll.clone();
                    lp.insert("sphere".into(), json!(core::sphere_id(&cal)));
                    touches.push((format!("lists|{nid}"), Value::Object(lp)));
                    let mut ids = std::collections::HashMap::new();
                    for (t0, lt) in ts.iter().filter(|x| x.0["parent"].is_null()) {
                        let r = sh.create_task(&nid, &body_of(t0), None, &core::shared_of(&Value::Object(lt.clone()), "task"))?;
                        ids.insert(text(&t0["id"]), text(&r["id"]));
                        if !lt.is_empty() {
                            touches.push((format!("tasks|{}", text(&r["id"])), Value::Object(lt.clone())));
                        }
                    }
                    for (t0, _) in ts.iter().filter(|x| !x.0["parent"].is_null()) {
                        if let Some(p) = ids.get(s(&t0["parent"])) {
                            sh.create_task(&nid, &body_of(t0), Some(p), &Json::new())?;
                        }
                    }
                    crate::data::api::delete_list(&old)?;
                }
                Ok((cal, touches))
            })();
            Box::new(move |app: &mut App| match res {
                Ok((_, touches)) => {
                    for (k, v) in touches {
                        let (sec, key) = k.split_once('|').unwrap();
                        app.touch(sec, key, v);
                    }
                    app.delete_sphere(&sid);
                    app.refresh();
                    app.say("Сфера стала общей — позови людей");
                }
                Err(e) => app.say(format!("Не получилось сделать общей: {e}")),
            })
        }));
    }

    /// Поля слоя задач и списков общих сфер ↔ записи календаря (трёхстороннее сведение).
    pub fn reconcile_shared(&mut self) {
        let mut changed = false;
        let mut to_rec = vec![];
        for cal in self.shared.active_calendars() {
            let recs: Vec<Value> = self.shared.stores[&cal]["recs"].as_object().map(|m| m.values().cloned().collect()).unwrap_or_default();
            for r in recs {
                let k = text(&r["k"]);
                let Some(kind) = core::kind_of(&r["k"]) else { continue };
                if kind != "task" && kind != "list" {
                    continue;
                }
                let lk = if kind == "list" { core::list_id(&k) } else { k.clone() };
                let sec = if kind == "list" { "lists" } else { "tasks" };
                let cur = self.layer[sec][&lk].clone();
                let base = self.shared.stores[&cal]["base"][&k].clone();
                let res = core::reconcile(&cur, &base, &r, kind);
                let mut to_layer = o(&res["toLayer"]).clone();
                if kind == "list" && cur["sphere"] != core::sphere_id(&cal).as_str() {
                    to_layer.insert("sphere".into(), json!(core::sphere_id(&cal)));
                }
                if !to_layer.is_empty() {
                    if !self.layer[sec].is_object() {
                        self.layer[sec] = json!({});
                    }
                    let mut m = o(&cur).clone();
                    extend(&mut m, &to_layer);
                    m.insert("t".into(), if cur["t"].is_null() { json!(now_ms()) } else { cur["t"].clone() });
                    self.layer[sec][&lk] = Value::Object(m);
                    changed = true;
                }
                if !o(&res["toRec"]).is_empty() {
                    to_rec.push((cal.clone(), k.clone(), res["toRec"].clone()));
                }
                let st = self.shared.st(&cal);
                if !st["base"].is_object() {
                    st["base"] = json!({});
                }
                st["base"][&k] = r;
            }
        }
        for (cal, k, p) in to_rec {
            self.shared_patch(&cal, &k, &p);
        }
        if changed {
            self.save_layer();
        }
    }

    /// Правка слоя задачи/списка общей сферы — сразу в календарь (поля с «$»).
    pub fn push_shared(&mut self, section: &str, key: &str) {
        if section != "tasks" && section != "lists" {
            return;
        }
        let rk = if section == "lists" { core::list_key(key).map(String::from) } else { Some(key.to_string()) };
        let lk = if section == "lists" { rk.clone() } else { self.list_key_of_task(key) };
        let (Some(rk), Some(cal)) = (rk, self.shared.cal_of_list(lk.as_deref())) else { return };
        let mut patch = core::shared_of(&self.layer[section][key], if section == "lists" { "list" } else { "task" });
        if section == "lists" {
            patch.shift_remove("$sphere");
        }
        if !patch.is_empty() {
            self.shared_patch(&cal, &rk, &Value::Object(patch));
        }
    }

    fn list_key_of_task(&self, id: &str) -> Option<String> {
        for (k, v) in o(&self.tasks) {
            if k.starts_with("sh:") && a(v).iter().any(|t0| t0["id"] == id) {
                return core::list_key(k).map(String::from);
            }
        }
        None
    }
}

pub fn body_of(t0: &Value) -> Value {
    let mut b = json!({"title": text(&t0["title"]), "notes": text(&t0["notes"]),
        "status": t0["status"].as_str().unwrap_or("needsAction")});
    if !t0["due"].is_null() {
        b["due"] = t0["due"].clone();
    }
    if !t0["completed"].is_null() {
        b["completed"] = t0["completed"].clone();
    }
    b
}
