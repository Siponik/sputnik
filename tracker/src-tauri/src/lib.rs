mod google;

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
    match std::fs::read_to_string(&path) {
        Ok(text) => serde_json::from_str(&text).map_err(|e| e.to_string()),
        Err(_) => Ok(serde_json::json!({ "version": 1, "tasks": {} })),
    }
}

#[tauri::command]
fn layer_write(app: tauri::AppHandle, data: Value) -> Result<(), String> {
    let path = layer_path(&app)?;
    let tmp = path.with_extension("json.tmp");
    let text = serde_json::to_string_pretty(&data).map_err(|e| e.to_string())?;
    std::fs::write(&tmp, text).map_err(|e| e.to_string())?;
    std::fs::rename(&tmp, &path).map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        // Обновления: latest.json и подписанный установщик — в релизах Siponik/sputnik.
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .manage(google::Google::default())
        .invoke_handler(tauri::generate_handler![
            google::auth_status,
            google::save_client_secret,
            google::login,
            google::logout,
            google::gapi,
            layer_read,
            layer_write,
        ])
        .run(tauri::generate_context!())
        .expect("Спутник не смог запуститься");
}
