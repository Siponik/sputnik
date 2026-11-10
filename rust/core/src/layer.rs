//! Слой Спутника и его слияние между компьютерами. Порт app/lib/core/layer.dart (← tracker/src/lib/layer.js).
//! Каждая запись несёт t — время изменения; при слиянии по каждой записи побеждают поля более свежей.
//! Удалённая запись — «надгробие» { gone: true, t }, чтобы другой компьютер не вернул её.
use crate::j::*;

pub const SECTIONS: [&str; 9] = ["tasks", "lists", "habits", "log", "cals", "settings", "templates", "templatesEdit", "spheres"];

pub fn empty_layer() -> Value {
    let mut m = Json::new();
    m.insert("version".into(), json!(1));
    for s in SECTIONS {
        m.insert(s.into(), json!({}));
    }
    Value::Object(m)
}

/// Список удалён: надгробия списка и его задач.
pub fn forget_list(lay: &mut Value, list_id: &str, task_ids: &[String], now: f64) {
    for k in ["lists", "tasks"] {
        if !lay[k].is_object() {
            lay[k] = json!({});
        }
    }
    lay["lists"][list_id] = json!({"gone": true, "t": num(now)});
    for id in task_ids {
        if !lay["tasks"][id].is_null() {
            lay["tasks"][id] = json!({"gone": true, "t": num(now)});
        }
    }
}

pub struct Merged {
    pub merged: Value,
    /// В локальный слой пришло что-то новое.
    pub local_changed: bool,
    /// Облачную копию надо перезаписать.
    pub remote_changed: bool,
}

fn t_of(rec: &Value) -> f64 {
    n(&rec["t"]).filter(|x| x.is_finite()).unwrap_or(0.0)
}

fn newer(x: &Value, y: &Value) -> bool {
    let (ta, tb) = (t_of(x), t_of(y));
    if ta != tb {
        return ta > tb;
    }
    cmp16(&x.to_string(), &y.to_string()) == std::cmp::Ordering::Greater
}

fn combine(l: &Value, r: &Value) -> Value {
    let r_newer = newer(r, l);
    let (nw, old) = if r_newer { (r, l) } else { (l, r) };
    if let (Value::Object(nm), Value::Object(om)) = (nw, old) {
        if !t(&nw["gone"]) {
            let mut m = om.clone();
            for (k, v) in nm {
                m.insert(k.clone(), v.clone());
            }
            return Value::Object(m);
        }
    }
    nw.clone()
}

/// Сливает локальный слой с копией из облака (remote может быть Null).
pub fn merge(local: &Value, remote: &Value) -> Merged {
    let mut merged = o(&empty_layer()).clone();
    for src in [remote, local] {
        for (k, v) in o(src) {
            merged.insert(k.clone(), v.clone());
        }
    }
    let mut local_changed = false;
    let mut remote_changed = !remote.is_object();
    let mut names: Vec<String> = SECTIONS.iter().map(|x| x.to_string()).collect();
    for src in [local, remote] {
        for k in o(src).keys() {
            if !names.contains(k) {
                names.push(k.clone());
            }
        }
    }
    for sec in names.iter().filter(|x| local[x.as_str()].is_object() || remote[x.as_str()].is_object()) {
        let (lm, rm) = (o(&local[sec.as_str()]), o(&remote[sec.as_str()]));
        let mut out = Json::new();
        let mut keys: Vec<&String> = lm.keys().collect();
        keys.extend(rm.keys().filter(|k| !lm.contains_key(*k)));
        for k in keys {
            let m = match (lm.get(k), rm.get(k)) {
                (Some(l), None) => l.clone(),
                (None, Some(r)) => r.clone(),
                (Some(l), Some(r)) => if same_u(l, r) { l.clone() } else { combine(l, r) },
                _ => unreachable!(),
            };
            if lm.get(k).map_or(true, |l| !same_u(&m, l)) {
                local_changed = true;
            }
            if rm.get(k).map_or(true, |r| !same_u(&m, r)) {
                remote_changed = true;
            }
            out.insert(k.clone(), m);
        }
        merged.insert(sec.clone(), Value::Object(out));
    }
    Merged { merged: Value::Object(merged), local_changed, remote_changed }
}

/// Записать поля в запись раздела (как touch в трекере): новое поверх старого, свежий t.
pub fn touch(lay: &mut Value, section: &str, id: &str, patch: &Value, now: f64) {
    if !lay[section].is_object() {
        lay[section] = json!({});
    }
    let rec = &mut lay[section][id];
    if !rec.is_object() || t(&rec["gone"]) {
        *rec = json!({});
    }
    for (k, v) in o(patch) {
        rec[k.as_str()] = v.clone();
    }
    rec["t"] = num(now);
}
