//! Бета-канал обновлений: та же проверка, что `check()` у tauri-plugin-updater, но адрес — latest.json релиза
//! tracker-beta (его пишет сборка ветки beta). Ответ — в том же виде, что у плагина, поэтому скачивает и ставит
//! обычный `Update` из @tauri-apps/plugin-updater (подпись проверяется тем же открытым ключом из tauri.conf.json).

use serde::Serialize;
use tauri::{Manager, ResourceId, Url, Webview};
use tauri_plugin_updater::UpdaterExt;

const FEED: &str = "https://github.com/Siponik/sputnik/releases/download/tracker-beta/latest.json";

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Found {
    rid: ResourceId,
    current_version: String,
    version: String,
    date: Option<String>,
    body: Option<String>,
    raw_json: serde_json::Value,
}

/// Есть ли бета новее установленной версии. None — нет.
#[tauri::command]
pub async fn beta_check(webview: Webview) -> Result<Option<Found>, String> {
    let feed = Url::parse(FEED).map_err(|e| e.to_string())?;
    let updater = webview
        .updater_builder()
        .endpoints(vec![feed])
        .map_err(|e| e.to_string())?
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| e.to_string())?;
    let Some(update) = updater.check().await.map_err(|e| e.to_string())? else {
        return Ok(None);
    };
    Ok(Some(Found {
        current_version: update.current_version.clone(),
        version: update.version.clone(),
        date: update.date.map(|d| d.to_string()),
        body: update.body.clone(),
        raw_json: update.raw_json.clone(),
        rid: webview.resources_table().add(update),
    }))
}
