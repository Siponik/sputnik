//! Где лежат данные. Папка прежнего приложения (%APPDATA%\com.siponik.sputnik) читается: token.json,
//! client_secret.json, слой. Свои файлы новое приложение пишет только в подпапку rust\ — старые
//! трекер и Flutter-версия их не видят, их данные не портятся.
//! Запись — через временный файл и переименование: оборванная запись не портит данные.
use serde_json::Value;
use std::path::PathBuf;

pub fn config_dir() -> PathBuf {
    let base = std::env::var_os("APPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::temp_dir().join("sputnik-data"));
    base.join("com.siponik.sputnik")
}

/// Файл в своей подпапке rust\.
pub fn own(name: &str) -> PathBuf {
    config_dir().join("rust").join(name)
}

fn read_json(p: PathBuf) -> Option<Value> {
    serde_json::from_str(std::fs::read_to_string(p).ok()?.trim_start_matches('\u{feff}')).ok()
}

pub fn write_json(name: &str, v: &Value) -> std::io::Result<()> {
    let p = own(name);
    if let Some(dir) = p.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let tmp = p.with_extension("tmp");
    std::fs::write(&tmp, v.to_string())?;
    std::fs::rename(tmp, p)
}

/// Слой: свой, иначе Flutter-версии, иначе старого трекера. Испорченный свой — из свежей резервной копии.
pub fn read_layer() -> Value {
    if let Some(v) = read_json(own("layer.json")).filter(Value::is_object) {
        return v;
    }
    if own("layer.json").exists() {
        let _ = std::fs::rename(own("layer.json"), own("layer.broken.json"));
        if let Some(v) = backups().into_iter().find_map(|p| read_json(p).filter(Value::is_object)) {
            return v;
        }
    }
    [config_dir().join("flutter").join("layer.json"), config_dir().join("layer.json")]
        .into_iter()
        .find_map(|p| read_json(p).filter(Value::is_object))
        .unwrap_or_else(|| Value::Object(Default::default()))
}

fn backups() -> Vec<PathBuf> {
    let mut all: Vec<PathBuf> = std::fs::read_dir(own("backups"))
        .map(|d| d.filter_map(|e| e.ok().map(|e| e.path())).filter(|p| p.to_string_lossy().contains("layer-")).collect())
        .unwrap_or_default();
    all.sort();
    all.reverse();
    all
}

/// Раз в день перед первой записью — копия backups\layer-ГГГГ-ММ-ДД.json, хранится 14.
pub fn write_layer(layer: &Value) {
    let cur = own("layer.json");
    let day = chrono::Local::now().format("%Y-%m-%d").to_string();
    let b = own("backups").join(format!("layer-{day}.json"));
    if cur.exists() && !b.exists() {
        let _ = std::fs::create_dir_all(own("backups"));
        let _ = std::fs::copy(&cur, &b);
        for old in backups().into_iter().skip(14) {
            let _ = std::fs::remove_file(old);
        }
    }
    let _ = write_json("layer.json", layer);
}

/// Когда последняя резервная копия (имя файла) — для настроек.
pub fn last_backup() -> Option<String> {
    backups().first().and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
}

pub fn read(name: &str) -> Option<Value> {
    read_json(own(name))
}

/// Записать ошибку в errors.log (для разбора, если что-то сломалось у пользователя).
pub fn log(where_: &str, e: &str) {
    use std::io::Write;
    let p = own("errors.log");
    if let Some(d) = p.parent() {
        let _ = std::fs::create_dir_all(d);
    }
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(p) {
        let _ = writeln!(f, "{} [{where_}] {e}", chrono::Local::now().to_rfc3339());
    }
}
