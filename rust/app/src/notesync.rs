//! «Знания» ↔ папка «Спутник / Знания» на Google Drive (docs/knowledge.md §1). Сверка раз в 2 минуты и по кнопке
//! «Синхронизировать сейчас»; работа — в фоне. Что делать, решает `sputnik_core::notesync::plan`.
//! Бережно: ничего не затирается — при конфликте обе версии остаются (вторая — «… (с другого компьютера).md»),
//! удалённое уходит в корзину Drive или в `.trash` папки заметок. Прошлая сверка — в папке настроек, не в папке заметок.
use crate::data::api;
use crate::state::App;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use sputnik_core::notesync::{self as ns, Base, Local, Remote, Step};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

const STATE: &str = "notes-sync.json";

/// Что показать в «Состоянии».
#[derive(Default, Clone)]
pub struct Status {
    pub busy: bool,
    pub ok: bool,
    /// «всё отправлено · 22:38», «нет связи — 3 изменения ждут» и т. п.
    pub text: String,
    pub notes_on_drive: usize,
    pub copies: usize,
}

struct Done {
    base: BTreeMap<String, Base>,
    folder: String,
    files: usize,
    changed: usize,
    copies: Vec<String>,
    err: Option<String>,
    pending: usize,
}

fn hash(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

/// Хеши файлов папки; файл с тем же размером и временем правки не перечитывается (картинки бывают большими).
fn scan(root: &Path, cache: &mut BTreeMap<String, (u64, i64, String)>) -> BTreeMap<String, Local> {
    let mut out = BTreeMap::new();
    let mut seen = std::collections::BTreeSet::new();
    let mut stack = vec![root.to_path_buf()];
    while let Some(d) = stack.pop() {
        let Ok(rd) = std::fs::read_dir(&d) else { continue };
        for e in rd.flatten() {
            let p = e.path();
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with('.') {
                continue;
            }
            if p.is_dir() {
                stack.push(p);
                continue;
            }
            let rel = p.strip_prefix(root).unwrap_or(&p).to_string_lossy().replace('\\', "/");
            if !ns::wanted(&rel) {
                continue;
            }
            let Ok(md) = e.metadata() else { continue };
            let mt = md.modified().ok().and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok()).map(|d| d.as_millis() as i64).unwrap_or(0);
            let h = match cache.get(&rel) {
                Some((len, m, h)) if *len == md.len() && *m == mt => h.clone(),
                _ => match std::fs::read(&p) {
                    Ok(b) => hash(&b),
                    Err(_) => continue,
                },
            };
            cache.insert(rel.clone(), (md.len(), mt, h.clone()));
            seen.insert(rel.clone());
            out.insert(rel, Local { hash: h });
        }
    }
    cache.retain(|k, _| seen.contains(k));
    out
}

type Cache = BTreeMap<String, (u64, i64, String)>;

type Hist = BTreeMap<String, Vec<String>>;

/// Какие версии каждого файла уже проходили через эту сверку (хеши): своя старая версия на Drive — не конфликт.
fn load_hist() -> Hist {
    let v = crate::data::store::read(STATE).unwrap_or(Value::Null);
    v["hist"].as_object().map(|m| m.iter().map(|(k, x)| (k.clone(), x.as_array().into_iter().flatten().filter_map(|h| h.as_str().map(String::from)).collect())).collect()).unwrap_or_default()
}

fn remember(hist: &mut Hist, p: &str, h: &str) {
    let v = hist.entry(p.to_string()).or_default();
    if !v.iter().any(|x| x == h) {
        v.push(h.to_string());
        if v.len() > 30 {
            v.remove(0);
        }
    }
}

fn load_base() -> (BTreeMap<String, Base>, String, Cache) {
    let v = crate::data::store::read(STATE).unwrap_or(Value::Null);
    let cache = v["cache"].as_object().map(|m| m.iter().map(|(k, x)| (k.clone(), (x[0].as_u64().unwrap_or(0), x[1].as_i64().unwrap_or(0), x[2].as_str().unwrap_or("").to_string()))).collect()).unwrap_or_default();
    let base = v["files"].as_object().map(|m| m.iter().map(|(k, x)| (k.clone(), Base { hash: x["h"].as_str().unwrap_or("").into(), md5: x["m"].as_str().unwrap_or("").into() })).collect()).unwrap_or_default();
    (base, v["root"].as_str().unwrap_or("").to_string(), cache)
}

fn save_base(base: &BTreeMap<String, Base>, root: &str, cache: &Cache, hist: &Hist) {
    let files: serde_json::Map<String, Value> = base.iter().map(|(k, b)| (k.clone(), json!({"h": b.hash, "m": b.md5}))).collect();
    let cache: serde_json::Map<String, Value> = cache.iter().map(|(k, c)| (k.clone(), json!([c.0, c.1, c.2]))).collect();
    let _ = crate::data::store::write_json(STATE, &json!({"root": root, "files": files, "cache": cache, "hist": hist}));
}

fn write_local(root: &Path, rel: &str, bytes: &[u8]) -> std::io::Result<()> {
    let p = root.join(rel);
    if let Some(d) = p.parent() {
        std::fs::create_dir_all(d)?;
    }
    let tmp = p.with_extension("sputnik-tmp");
    std::fs::write(&tmp, bytes)?;
    std::fs::rename(tmp, p)
}

/// Одна сверка целиком (в фоне). `root_ok` — папка заметок та же, что при прошлой сверке
/// (другая папка — прошлую сверку не используем, чтобы не принять пустую папку за «всё удалили»).
fn run(root: PathBuf) -> Done {
    let (mut base, old_root, mut cache) = load_base();
    let mut hist = load_hist();
    let root_s = root.to_string_lossy().to_string();
    if old_root != root_s {
        base.clear();
        cache.clear();
        hist.clear();
    }
    let mut done = Done { base: BTreeMap::new(), folder: root_s.clone(), files: 0, changed: 0, copies: vec![], err: None, pending: 0 };
    let res: Result<(), crate::data::google::Fail> = (|| {
        let top = api::ensure_folder(None, "Спутник")?;
        let drive_root = api::ensure_folder(Some(&top), "Знания")?;
        let (files, dirs) = api::notes_tree(&drive_root)?;
        let mut dir_ids: BTreeMap<String, String> = dirs.into_iter().collect();
        let remote: BTreeMap<String, Remote> = files.iter().filter(|f| ns::wanted(&f.0)).map(|f| (f.0.clone(), Remote { id: f.1.clone(), md5: f.2.clone() })).collect();
        let mut local = scan(&root, &mut cache);
        // прежние лишние копии «(с другого компьютера)» — слово в слово как оригинал или другая копия — в корзину
        for p in ns::extra_copies(&local) {
            let to = root.join(".trash").join(&p);
            if let Some(d) = to.parent() {
                let _ = std::fs::create_dir_all(d);
            }
            if std::fs::rename(root.join(&p), &to).is_ok() {
                local.remove(&p);
                done.changed += 1;
            }
        }
        let steps = ns::guard(ns::plan(&local, &remote, &base), base.len());
        done.pending = steps.iter().filter(|s| !matches!(s, Step::Forget(_))).count();
        let folder_of = |rel: &str, dir_ids: &mut BTreeMap<String, String>| -> Result<String, crate::data::google::Fail> {
            let dir = rel.rsplit_once('/').map(|x| x.0).unwrap_or("");
            if let Some(id) = dir_ids.get(dir) {
                return Ok(id.clone());
            }
            let mut cur = String::new();
            let mut id = drive_root.clone();
            for part in dir.split('/').filter(|s| !s.is_empty()) {
                cur = if cur.is_empty() { part.to_string() } else { format!("{cur}/{part}") };
                id = match dir_ids.get(&cur) {
                    Some(x) => x.clone(),
                    None => {
                        let x = api::ensure_folder(Some(&id), part)?;
                        dir_ids.insert(cur.clone(), x.clone());
                        x
                    }
                };
            }
            Ok(id)
        };
        let name_of = |rel: &str| rel.rsplit('/').next().unwrap_or(rel).to_string();
        for st in steps {
            match st {
                Step::Upload(p) => {
                    let bytes = std::fs::read(root.join(&p)).map_err(|e| crate::data::google::Fail::Net(e.to_string()))?;
                    let h = hash(&bytes);
                    let (_, md5) = match remote.get(&p) {
                        Some(r) => api::upload_to(&r.id, bytes)?,
                        None => api::upload_new(&folder_of(&p, &mut dir_ids)?, &name_of(&p), bytes)?,
                    };
                    remember(&mut hist, &p, &h);
                    base.insert(p, Base { hash: h, md5 });
                }
                Step::Download(p) => {
                    let r = &remote[&p];
                    let bytes = api::download(&r.id)?;
                    // на всякий случай: здесь успели поменять — не затираем, кладём копию рядом
                    if let Some(l) = local.get(&p) {
                        if base.get(&p).is_some_and(|b| b.hash != l.hash) {
                            continue;
                        }
                    }
                    write_local(&root, &p, &bytes).map_err(|e| crate::data::google::Fail::Net(e.to_string()))?;
                    remember(&mut hist, &p, &hash(&bytes));
                    base.insert(p, Base { hash: hash(&bytes), md5: r.md5.clone() });
                }
                Step::Conflict(p) => {
                    let r = &remote[&p];
                    let theirs = api::download(&r.id)?;
                    let mine = std::fs::read(root.join(&p)).map_err(|e| crate::data::google::Fail::Net(e.to_string()))?;
                    if hash(&theirs) == hash(&mine) {
                        base.insert(p, Base { hash: hash(&mine), md5: r.md5.clone() });
                        continue;
                    }
                    // на Drive на самом деле то же, что было при прошлой сверке (поменялась только отметка md5) —
                    // это не конфликт: просто отправляем нашу правку, без копии
                    // и копию не делаем, если «их» версия — это наша же прошлая версия или сам файл — уже копия
                    if base.get(&p).is_some_and(|b| b.hash == hash(&theirs)) || hist.get(&p).is_some_and(|v| v.contains(&hash(&theirs))) || ns::original_of(&p).is_some() {
                        let (_, md5) = api::upload_to(&r.id, mine.clone())?;
                        remember(&mut hist, &p, &hash(&mine));
                        base.insert(p, Base { hash: hash(&mine), md5 });
                        done.changed += 1;
                        continue;
                    }
                    // их версия — копией рядом (уйдёт на Drive следующей сверкой), наша — на Drive под своим именем
                    let copy = ns::conflict_name(&p, |n| root.join(n).exists() || remote.contains_key(n));
                    write_local(&root, &copy, &theirs).map_err(|e| crate::data::google::Fail::Net(e.to_string()))?;
                    let (_, md5) = api::upload_to(&r.id, mine.clone())?;
                    base.insert(p, Base { hash: hash(&mine), md5 });
                    done.copies.push(copy);
                }
                Step::TrashRemote(p) => {
                    api::trash(&remote[&p].id)?;
                    base.remove(&p);
                }
                Step::TrashLocal(p) => {
                    let to = root.join(".trash").join(&p);
                    if let Some(d) = to.parent() {
                        let _ = std::fs::create_dir_all(d);
                    }
                    let _ = std::fs::rename(root.join(&p), to);
                    base.remove(&p);
                }
                Step::Forget(p) => {
                    base.remove(&p);
                }
            }
            done.changed += 1;
            done.pending = done.pending.saturating_sub(1);
        }
        done.files = base.keys().filter(|p| p.ends_with(".md")).count();
        Ok(())
    })();
    if let Err(e) = res {
        done.err = Some(e.to_string());
    }
    // запоминаем и то, что успели до ошибки
    save_base(&base, &root_s, &cache, &hist);
    done.base = base;
    done
}

thread_local! {
    static TIMER: std::cell::RefCell<Option<slint::Timer>> = const { std::cell::RefCell::new(None) };
}

/// Сверка каждые 2 минуты, пока окно открыто; первая — сразу.
pub fn start() {
    TIMER.with(|t| {
        let tm = slint::Timer::default();
        tm.start(slint::TimerMode::Repeated, std::time::Duration::from_secs(120), || {
            crate::state::with(sync_now);
        });
        *t.borrow_mut() = Some(tm);
    });
    crate::state::with(sync_now);
}

/// Сверить сейчас (если есть папка заметок, вход в Google и сверка не идёт).
pub fn sync_now(app: &mut App) {
    if app.flags.demo || app.flags.need_login || app.notes_sync.busy {
        return;
    }
    let Some(root) = app.notes.root.clone() else { return };
    app.notes_sync.busy = true;
    app.notes_sync.text = "сверяю…".into();
    crate::state::run(move || run(root), |app, d: Done| {
        app.notes_sync.busy = false;
        let at = chrono::Local::now().format("%H:%M");
        match &d.err {
            None => {
                app.notes_sync.ok = true;
                app.notes_sync.notes_on_drive = d.files;
                app.notes_sync.text = format!("всё отправлено · {} на Drive · {at}", sputnik_plural(d.files));
            }
            Some(e) => {
                app.notes_sync.ok = false;
                app.notes_sync.text = if d.pending > 0 { format!("{e} — изменений ждут: {}, отправлю сам", d.pending) } else { e.clone() };
            }
        }
        if !d.copies.is_empty() {
            app.notes_sync.copies += d.copies.len();
            let first = d.copies[0].rsplit('/').next().unwrap_or("").to_string();
            app.say(format!("Заметку поменяли на двух компьютерах — сохранены обе версии: «{first}»"));
        }
        if d.changed > 0 && app.notes.root.as_ref().map(|r| r.to_string_lossy().to_string()) == Some(d.folder.clone()) {
            app.notes.rescan();
        }
        let _ = d.base;
    });
}

fn sputnik_plural(n: usize) -> String {
    let w = if n % 10 == 1 && n % 100 != 11 { "заметка" } else if (2..=4).contains(&(n % 10)) && !(12..=14).contains(&(n % 100)) { "заметки" } else { "заметок" };
    format!("{n} {w}")
}
