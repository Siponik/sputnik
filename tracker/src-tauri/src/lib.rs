mod backup;
mod beta;
mod google;
mod pin;

use serde_json::Value;
use tauri::Manager;

fn layer_path(app: &tauri::AppHandle) -> Result<std::path::PathBuf, String> {
    let dir = app.path().app_config_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("layer.json"))
}

/// Слой Спутника: поля, которых нет в Google (статус на доске и т.д.). Пока хранится локально.
#[tauri::command]
fn layer_read(app: tauri::AppHandle) -> Result<Value, String> {
    let path = layer_path(&app)?;
    let text = match std::fs::read_to_string(&path) {
        Ok(text) => text,
        Err(_) => return Ok(serde_json::json!({ "version": 1, "tasks": {} })),
    };
    match serde_json::from_str(&text) {
        Ok(v) => Ok(v),
        Err(e) => {
            // Файл испорчен (оборванная запись, ручная правка) — берём свежую целую копию,
            // а испорченный откладываем рядом, чтобы его можно было посмотреть.
            let ok = |t: &str| serde_json::from_str::<Value>(t).is_ok();
            match backup::latest_good(&path, ok) {
                Some(good) => {
                    let _ = std::fs::rename(&path, path.with_extension("broken.json"));
                    serde_json::from_str(&good).map_err(|e| e.to_string())
                }
                None => Err(e.to_string()),
            }
        }
    }
}

#[tauri::command]
fn layer_write(app: tauri::AppHandle, data: Value) -> Result<(), String> {
    let path = layer_path(&app)?;
    let tmp = path.with_extension("json.tmp");
    let text = serde_json::to_string_pretty(&data).map_err(|e| e.to_string())?;
    // Копия на день — до перезаписи; её сбой запись не останавливает.
    let _ = backup::before_write(&path, &backup::today());
    std::fs::write(&tmp, text).map_err(|e| e.to_string())?;
    std::fs::rename(&tmp, &path).map_err(|e| e.to_string())
}

/// Дата последней резервной копии слоя (ГГГГ-ММ-ДД) — для Настроек → Синхронизация.
#[tauri::command]
fn backups_last(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let path = layer_path(&app)?;
    Ok(backup::list(&path).first().and_then(|p| {
        let n = p.file_stem()?.to_str()?;
        n.strip_prefix("layer-").map(|d| d.to_string())
    }))
}

/// Открыть в проводнике папку резервных копий (`backups` рядом со слоем) или страницу релизов на GitHub.
/// Только эти два места — произвольный путь или адрес сюда не передать.
#[tauri::command]
fn open_place(app: tauri::AppHandle, place: String) -> Result<(), String> {
    let target = match place.as_str() {
        "backups" => {
            let dir = layer_path(&app)?.with_file_name("backups");
            std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
            dir.into_os_string()
        }
        "releases" => "https://github.com/Siponik/sputnik/releases".into(),
        // Общий бот — то же имя, что BOT_NAME в src/lib/sharedbot.js.
        "telegram" => "https://t.me/SputnikTasksBot".into(),
        _ => return Err("Неизвестное место".into()),
    };
    #[cfg(target_os = "windows")]
    let mut cmd = std::process::Command::new("explorer");
    #[cfg(target_os = "macos")]
    let mut cmd = std::process::Command::new("open");
    #[cfg(not(any(target_os = "windows", target_os = "macos")))]
    let mut cmd = std::process::Command::new("xdg-open");
    cmd.arg(target).spawn().map(|_| ()).map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        // Обновления: latest.json и подписанный установщик — в релизах Siponik/sputnik.
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .manage(google::Google::default())
        .setup(|_| {
            // Значок на панели задач после обновления (src/pin.rs) — в фоне, запуск не ждёт.
            std::thread::spawn(|| {
                std::thread::sleep(std::time::Duration::from_secs(5));
                pin::heal();
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            google::auth_status,
            google::save_client_secret,
            google::login,
            google::logout,
            google::gapi,
            layer_read,
            layer_write,
            backups_last,
            open_place,
            beta::beta_check,
        ])
        .run(tauri::generate_context!())
        .expect("Спутник не смог запуститься");
}
