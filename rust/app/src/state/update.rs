//! Обновление из приложения, как в трекере: раз в 6 ч (и через 30 с после запуска) читаем latest.json
//! служебного релиза `rust-latest`, новее — чип «✦ Версия …» в шапке. «Обновить» скачивает sputnik.exe,
//! проверяет подпись тем же ключом, что и трекер (minisign, открытый ключ ниже), кладёт файл на место
//! работающего (старый переименовывается в sputnik.old.exe — Windows так разрешает) и перезапускает.
use super::{bg::run, App};
use serde_json::Value;
use std::time::Duration;

const FEED: &str = "https://github.com/Siponik/sputnik/releases/download/rust-latest/latest.json";
/// Открытый ключ обновлений (тот же, что в tracker/src-tauri/tauri.conf.json).
const PUBKEY: &str = "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEZGRjVGMDBCOTRGMkI2NkUKUldSdXR2S1VDL0QxLzlxYzdlUlVYNUNIakExdHdDY0N6UnNzaDdTK2xOcnp4aEp3NzFiSlNMV2MK";

pub fn version() -> &'static str {
    option_env!("SPUTNIK_VERSION").unwrap_or(env!("CARGO_PKG_VERSION"))
}

/// «0.1.12» > «0.1.9»: сравнение по числам.
pub fn newer(a: &str, b: &str) -> bool {
    let p = |s: &str| s.split(['.', '-']).map(|x| x.parse::<u64>().unwrap_or(0)).collect::<Vec<_>>();
    p(a) > p(b)
}

#[derive(Clone, Default)]
pub struct Update {
    pub version: String,
    pub notes: String,
    pub url: String,
    pub sig: String,
    pub busy: bool,
    pub checked: Option<String>,
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

fn get(url: &str) -> Result<ureq::Response, String> {
    ureq::get(url).timeout(Duration::from_secs(120)).call().map_err(|e| e.to_string())
}

/// Убрать файл прошлого обновления.
pub fn cleanup() {
    if let Ok(me) = std::env::current_exe() {
        let _ = std::fs::remove_file(me.with_file_name("sputnik.old.exe"));
    }
}

impl App {
    pub fn update_check(&mut self, manual: bool) {
        if self.flags.demo || self.update.busy {
            return;
        }
        self.update.busy = true;
        run(
            || -> Result<Value, String> { get(FEED)?.into_json::<Value>().map_err(|e| e.to_string()) },
            move |app, r| {
                app.update.busy = false;
                app.update.checked = Some(chrono::Local::now().format("%H:%M").to_string());
                match r {
                    Ok(v) => {
                        let ver = v["version"].as_str().unwrap_or("").to_string();
                        if newer(&ver, version()) {
                            app.update.version = ver;
                            app.update.notes = v["notes"].as_str().unwrap_or("").to_string();
                            app.update.url = v["url"].as_str().unwrap_or("").to_string();
                            app.update.sig = v["signature"].as_str().unwrap_or("").to_string();
                        } else if manual {
                            app.say(format!("Стоит последняя версия {}", version()));
                        }
                    }
                    Err(e) if manual => app.say(format!("Не проверилось: {e}")),
                    Err(_) => {}
                }
            },
        );
    }

    pub fn update_install(&mut self) {
        if self.update.url.is_empty() || self.update.busy {
            return;
        }
        self.update.busy = true;
        self.say("Скачиваю обновление…".to_string());
        let (url, sig) = (self.update.url.clone(), self.update.sig.clone());
        run(
            move || -> Result<(), String> {
                let mut bytes = vec![];
                std::io::Read::read_to_end(&mut get(&url)?.into_reader(), &mut bytes).map_err(|e| e.to_string())?;
                verify(&bytes, &sig)?;
                let me = std::env::current_exe().map_err(|e| e.to_string())?;
                let new = me.with_file_name("sputnik.new.exe");
                std::fs::write(&new, &bytes).map_err(|e| e.to_string())?;
                let old = me.with_file_name("sputnik.old.exe");
                let _ = std::fs::remove_file(&old);
                std::fs::rename(&me, &old).map_err(|e| e.to_string())?;
                if let Err(e) = std::fs::rename(&new, &me) {
                    let _ = std::fs::rename(&old, &me);
                    return Err(e.to_string());
                }
                std::process::Command::new(&me).spawn().map_err(|e| e.to_string())?;
                Ok(())
            },
            |app, r| {
                app.update.busy = false;
                match r {
                    Ok(()) => {
                        // новая копия уже запущена; даём записи файлов 2 с и выходим
                        app.say("Перезапускаю…".to_string());
                        slint::Timer::single_shot(Duration::from_secs(2), || std::process::exit(0));
                    }
                    Err(e) => app.say(format!("Обновление не встало: {e}")),
                }
            },
        );
    }

    pub fn update_timers(&mut self) -> Vec<slint::Timer> {
        cleanup();
        let once = slint::Timer::default();
        once.start(slint::TimerMode::SingleShot, Duration::from_secs(30), || { super::bg::with(|a| a.update_check(false)); });
        let rep = slint::Timer::default();
        rep.start(slint::TimerMode::Repeated, Duration::from_secs(6 * 3600), || { super::bg::with(|a| a.update_check(false)); });
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
}
