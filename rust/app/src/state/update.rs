//! Обновление из приложения: через 8 с после запуска и раз в 6 ч читаем latest.json служебного релиза
//! `rust-latest`. Новее — чип «Версия …» в шапке и окно обновления открывается само (раз на версию за запуск).
//! «Обновить сейчас» качает сжатый sputnik.exe.gz (втрое меньше exe; у старых latest.json — сам exe)
//! кусками с полосой прогресса: без общего лимита времени, обрыв — сама продолжает с того же места
//! (Range), до `ATTEMPTS` попыток с паузами. Потом проверка подписи тем же ключом, что и у трекера
//! (minisign), замена работающего файла (старый → sputnik.old.exe, Windows так разрешает) и перезапуск.
//! Ошибка — понятная причина и «Повторить» (`sputnik_core::updater::explain`).
use super::{bg::run, App};
use serde_json::Value;
use sputnik_core::updater as up;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

const FEED: &str = "https://github.com/Siponik/sputnik/releases/download/rust-latest/latest.json";
/// Открытый ключ обновлений (тот же, что был у трекера в tauri.conf.json).
const PUBKEY: &str = "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEZGRjVGMDBCOTRGMkI2NkUKUldSdXR2S1VDL0QxLzlxYzdlUlVYNUNIakExdHdDY0N6UnNzaDdTK2xOcnp4aEp3NzFiSlNMV2MK";

pub fn version() -> &'static str {
    option_env!("SPUTNIK_VERSION").unwrap_or(env!("CARGO_PKG_VERSION"))
}

/// «0.1.12» > «0.1.9»: сравнение по числам.
pub fn newer(a: &str, b: &str) -> bool {
    let p = |s: &str| s.split(['.', '-']).map(|x| x.parse::<u64>().unwrap_or(0)).collect::<Vec<_>>();
    p(a) > p(b)
}

/// Что сейчас делает обновление (в окне — `upd-phase`).
#[derive(Clone, Copy, Default, PartialEq)]
pub enum Phase {
    #[default]
    Idle,
    Checking,
    Downloading,
    Installing,
    Failed,
}

impl Phase {
    pub fn code(self) -> i32 {
        match self {
            Phase::Idle => 0,
            Phase::Checking => 1,
            Phase::Downloading => 2,
            Phase::Installing => 3,
            Phase::Failed => 4,
        }
    }
}

#[derive(Clone, Default)]
pub struct Update {
    pub version: String,
    pub notes: String,
    pub url: String,
    pub sig: String,
    /// `url` — сжатый .gz (распаковать после проверки подписи).
    pub gz: bool,
    pub phase: Phase,
    /// Скачано / всего байт, скорость, номер попытки (1 — первая).
    pub done: u64,
    pub total: u64,
    pub bps: f64,
    pub attempt: u32,
    /// Причина ошибки и что сделать.
    pub err: (String, String),
    /// Окно обновления открыто.
    pub open: bool,
    /// Для какой версии окно уже открывалось само в этом запуске.
    pub popped: String,
    pub cancel: Arc<AtomicBool>,
    pub checked: Option<String>,
    /// «Что нового» по версиям, которые приложение видело: version → {date, notes} (updnotes.json, #203).
    pub history: Value,
}

impl Update {
    pub fn busy(&self) -> bool {
        matches!(self.phase, Phase::Checking | Phase::Downloading | Phase::Installing)
    }
}

fn b64(s: &str) -> Option<String> {
    use base64::Engine;
    String::from_utf8(base64::engine::general_purpose::STANDARD.decode(s.trim()).ok()?).ok()
}

pub fn verify(bytes: &[u8], sig_b64: &str) -> Result<(), String> {
    let pk = minisign_verify::PublicKey::decode(&b64(PUBKEY).ok_or("ключ")?).map_err(|e| e.to_string())?;
    let sg = minisign_verify::Signature::decode(&b64(sig_b64).ok_or("подпись не base64")?).map_err(|e| e.to_string())?;
    pk.verify(bytes, &sg, false).map_err(|e| format!("подпись не сошлась: {e}"))
}

fn agent() -> ureq::Agent {
    // общего лимита нет: медленная связь дотягивает файл; молчит 30 с — обрыв, и попытка продолжит с места
    ureq::AgentBuilder::new().timeout_connect(Duration::from_secs(20)).timeout_read(Duration::from_secs(30)).build()
}

/// Файл недокачанной версии лежит рядом с exe, чтобы продолжить после обрыва или перезапуска.
fn part_path(me: &Path, ver: &str) -> PathBuf {
    me.with_file_name(format!("sputnik.update-{ver}.part"))
}

/// Убрать файлы прошлого обновления и недокачанные старые версии.
pub fn cleanup() {
    let Ok(me) = std::env::current_exe() else { return };
    let _ = std::fs::remove_file(me.with_file_name("sputnik.old.exe"));
    let Some(dir) = me.parent() else { return };
    for e in std::fs::read_dir(dir).into_iter().flatten().flatten() {
        let name = e.file_name().to_string_lossy().to_string();
        if let Some(v) = name.strip_prefix("sputnik.update-").and_then(|n| n.strip_suffix(".part")) {
            if !newer(v, version()) {
                let _ = std::fs::remove_file(e.path());
            }
        }
    }
}

/// Ход скачивания для окна: (скачано, всего, байт/с, попытка).
type Tick = Box<dyn Fn(u64, u64, f64, u32) + Send>;

/// Скачать `url` в `part` с продолжением после обрывов. Возвращает содержимое файла.
fn download(url: &str, part: &Path, cancel: &AtomicBool, tick: Tick) -> Result<Vec<u8>, String> {
    let stop = || -> Result<(), String> { if cancel.load(Ordering::Relaxed) { Err("cancel".into()) } else { Ok(()) } };
    let mut attempt = 1;
    loop {
        stop()?;
        match fetch_once(url, part, cancel, &tick, attempt) {
            Ok(()) => break,
            Err(e) if e == "cancel" => return Err(e),
            Err(e) if attempt >= up::ATTEMPTS || !up::retryable(&e) => return Err(e),
            Err(_) => {
                // пауза перед новой попыткой, отмена прерывает её сразу
                let until = Instant::now() + Duration::from_secs(up::backoff_secs(attempt));
                while Instant::now() < until {
                    stop()?;
                    std::thread::sleep(Duration::from_millis(200));
                }
                attempt += 1;
            }
        }
    }
    std::fs::read(part).map_err(|e| e.to_string())
}

fn fetch_once(url: &str, part: &Path, cancel: &AtomicBool, tick: &Tick, attempt: u32) -> Result<(), String> {
    let have = std::fs::metadata(part).map(|m| m.len()).unwrap_or(0);
    let mut req = agent().get(url);
    if have > 0 {
        req = req.set("Range", &format!("bytes={have}-"));
    }
    let resp = match req.call() {
        Ok(r) => r,
        // 416 — кусок уже целиком или от другого файла: начинаем заново
        Err(ureq::Error::Status(416, _)) => {
            let _ = std::fs::remove_file(part);
            return Err("connection: range".into());
        }
        Err(e) => return Err(e.to_string()),
    };
    let from = up::resume_from(resp.status(), have);
    let total = up::total_size(resp.header("Content-Range"), resp.header("Content-Length"), from);
    let mut f = if from > 0 {
        std::fs::OpenOptions::new().append(true).open(part)
    } else {
        std::fs::File::create(part)
    }
    .map_err(|e| e.to_string())?;
    let mut rd = resp.into_reader();
    let mut buf = vec![0u8; 64 * 1024];
    let mut done = from;
    let (mut mark_t, mut mark_b, mut bps) = (Instant::now(), done, 0f64);
    let mut last = Instant::now() - Duration::from_secs(1);
    tick(done, total, 0.0, attempt);
    loop {
        if cancel.load(Ordering::Relaxed) {
            return Err("cancel".into());
        }
        let n = rd.read(&mut buf).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        f.write_all(&buf[..n]).map_err(|e| e.to_string())?;
        done += n as u64;
        // скорость — по последним ~2 с, окно обновляем 4 раза в секунду
        let dt = mark_t.elapsed().as_secs_f64();
        if dt >= 2.0 {
            let now = (done - mark_b) as f64 / dt;
            bps = if bps > 0.0 { bps * 0.5 + now * 0.5 } else { now };
            mark_t = Instant::now();
            mark_b = done;
        } else if bps == 0.0 && dt >= 0.5 {
            bps = (done - mark_b) as f64 / dt;
        }
        if last.elapsed() >= Duration::from_millis(250) {
            last = Instant::now();
            tick(done, total, bps, attempt);
        }
    }
    f.flush().map_err(|e| e.to_string())?;
    tick(done, total, bps, attempt);
    if total > 0 && done < total {
        return Err("unexpected end of file".into());
    }
    Ok(())
}

fn gunzip(bytes: &[u8]) -> Result<Vec<u8>, String> {
    let mut out = Vec::with_capacity(bytes.len() * 3);
    flate2::read::GzDecoder::new(bytes).read_to_end(&mut out).map_err(|e| format!("распаковка: {e}"))?;
    Ok(out)
}

/// Положить новый exe на место работающего и запустить его.
fn swap_and_start(exe: &[u8]) -> Result<(), String> {
    let me = std::env::current_exe().map_err(|e| e.to_string())?;
    let new = me.with_file_name("sputnik.new.exe");
    std::fs::write(&new, exe).map_err(|e| e.to_string())?;
    let old = me.with_file_name("sputnik.old.exe");
    let _ = std::fs::remove_file(&old);
    std::fs::rename(&me, &old).map_err(|e| e.to_string())?;
    if let Err(e) = std::fs::rename(&new, &me) {
        let _ = std::fs::rename(&old, &me);
        return Err(e.to_string());
    }
    std::process::Command::new(&me).spawn().map_err(|e| e.to_string())?;
    Ok(())
}

impl App {
    pub fn update_check(&mut self, manual: bool) {
        if self.flags.demo || self.update.busy() {
            return;
        }
        let was = self.update.phase;
        self.update.phase = Phase::Checking;
        run(
            || -> Result<Value, String> { agent().get(FEED).timeout(Duration::from_secs(60)).call().map_err(|e| e.to_string())?.into_json::<Value>().map_err(|e| e.to_string()) },
            move |app, r| {
                app.update.phase = if was == Phase::Failed { Phase::Failed } else { Phase::Idle };
                app.update.checked = Some(chrono::Local::now().format("%H:%M").to_string());
                match r {
                    Ok(v) => app.update_feed(&v, manual),
                    Err(e) if manual => {
                        let (what, _) = up::explain(&e);
                        app.say(format!("Не проверилось: {}", what.trim_end_matches('.')));
                    }
                    Err(_) => {}
                }
            },
        );
    }

    fn update_feed(&mut self, v: &Value, manual: bool) {
        let ver = v["version"].as_str().unwrap_or("").to_string();
        let notes = v["notes"].as_str().unwrap_or("").to_string();
        // запоминаем «Что нового» каждой увиденной версии — карточка «Обновления» показывает списком
        if !ver.is_empty() && !notes.trim().is_empty() {
            let date = v["date"].as_str().map(String::from).unwrap_or_else(|| chrono::Local::now().format("%Y-%m-%d").to_string());
            self.update.history[&ver] = serde_json::json!({"date": date, "notes": notes});
            // держим 8 свежих версий
            let mut vers: Vec<String> = self.update.history.as_object().map(|m| m.keys().cloned().collect()).unwrap_or_default();
            vers.sort_by(|a, b| newer(b, a).cmp(&newer(a, b)));
            for old in vers.into_iter().skip(8) {
                self.update.history.as_object_mut().map(|m| m.remove(&old));
            }
            self.put("updnotes.json", self.update.history.clone());
        }
        match up::pick(v) {
            Some((url, sig, gz)) if newer(&ver, version()) => {
                if self.update.version != ver && self.update.phase == Phase::Failed {
                    self.update.phase = Phase::Idle; // вышла ещё более новая — старая ошибка уже не про неё
                }
                self.update.version = ver.clone();
                self.update.notes = notes;
                self.update.url = url;
                self.update.sig = sig;
                self.update.gz = gz;
                // окно открывается само: раз на версию за запуск (и всегда по «Проверить»)
                if manual || self.update.popped != ver {
                    self.update.popped = ver;
                    self.update.open = true;
                }
            }
            _ if manual => self.say(format!("Стоит последняя версия {}", version())),
            _ => {}
        }
    }

    pub fn update_install(&mut self) {
        if self.update.url.is_empty() || self.update.busy() {
            return;
        }
        let u = &mut self.update;
        u.phase = Phase::Downloading;
        u.open = true;
        u.done = 0;
        u.total = 0;
        u.bps = 0.0;
        u.attempt = 1;
        u.err = Default::default();
        u.cancel = Arc::new(AtomicBool::new(false));
        let (url, sig, gz, ver, cancel) = (u.url.clone(), u.sig.clone(), u.gz, u.version.clone(), u.cancel.clone());
        run(
            move || -> Result<(), String> {
                let me = std::env::current_exe().map_err(|e| e.to_string())?;
                let part = part_path(&me, &ver);
                let tick: Tick = Box::new(|done, total, bps, attempt| {
                    let _ = slint::invoke_from_event_loop(move || {
                        super::bg::with(|a| {
                            if a.update.phase == Phase::Downloading {
                                (a.update.done, a.update.total, a.update.bps, a.update.attempt) = (done, total, bps, attempt);
                            }
                        });
                    });
                });
                let bytes = download(&url, &part, &cancel, tick)?;
                let _ = slint::invoke_from_event_loop(|| {
                    super::bg::with(|a| a.update.phase = Phase::Installing);
                });
                if let Err(e) = verify(&bytes, &sig) {
                    let _ = std::fs::remove_file(&part); // битый файл — в следующий раз качаем заново
                    return Err(e);
                }
                let exe = if gz { gunzip(&bytes)? } else { bytes };
                swap_and_start(&exe)?;
                let _ = std::fs::remove_file(&part);
                Ok(())
            },
            |app, r| match r {
                Ok(()) => {
                    // новая копия уже запущена; даём записи файлов 2 с и выходим
                    app.update.phase = Phase::Installing;
                    slint::Timer::single_shot(Duration::from_secs(2), || std::process::exit(0));
                }
                Err(e) if e == "cancel" => {
                    app.update.phase = Phase::Idle;
                    app.say("Скачивание остановлено — в следующий раз продолжу с того же места".to_string());
                }
                Err(e) => {
                    app.update.phase = Phase::Failed;
                    app.update.err = up::explain(&e);
                    app.update.open = true;
                    eprintln!("обновление: {e}");
                }
            },
        );
    }

    pub fn update_cancel(&mut self) {
        self.update.cancel.store(true, Ordering::Relaxed);
    }

    pub fn update_timers(&mut self) -> Vec<slint::Timer> {
        cleanup();
        let once = slint::Timer::default();
        once.start(slint::TimerMode::SingleShot, Duration::from_secs(8), || {
            super::bg::with(|a| a.update_check(false));
        });
        let rep = slint::Timer::default();
        rep.start(slint::TimerMode::Repeated, Duration::from_secs(6 * 3600), || {
            super::bg::with(|a| a.update_check(false));
        });
        vec![once, rep]
    }
}

#[cfg(test)]
mod t {
    #[test]
    fn order() {
        assert!(super::newer("0.1.12", "0.1.9"));
        assert!(!super::newer("0.1.9", "0.1.9"));
        assert!(super::newer("0.2.0", "0.1.99"));
    }

    #[test]
    fn gz_roundtrip() {
        use std::io::Write;
        let mut e = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::default());
        e.write_all(b"sputnik").unwrap();
        assert_eq!(super::gunzip(&e.finish().unwrap()).unwrap(), b"sputnik");
    }
}
