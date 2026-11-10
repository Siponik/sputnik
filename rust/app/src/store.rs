//! Где лежат данные. Папка прежнего приложения (%APPDATA%\com.siponik.sputnik) читается: token.json,
//! client_secret.json, слой. Свои файлы новое приложение пишет только в подпапку rust\ — старые
//! трекер и Flutter-версия их не видят, их данные не портятся.
use serde_json::Value;
use std::path::PathBuf;

pub fn config_dir() -> PathBuf {
    let base = std::env::var_os("APPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::temp_dir().join("sputnik-data"));
    base.join("com.siponik.sputnik")
}

fn own(name: &str) -> PathBuf {
    config_dir().join("rust").join(name)
}

fn read_json(p: PathBuf) -> Option<Value> {
    serde_json::from_str(&std::fs::read_to_string(p).ok()?).ok()
}

/// Слой Спутника (только чтение в пробе): свой, иначе Flutter-версии, иначе старого трекера.
pub fn read_layer() -> Value {
    [own("layer.json"), config_dir().join("flutter").join("layer.json"), config_dir().join("layer.json")]
        .into_iter()
        .find_map(|p| read_json(p).filter(Value::is_object))
        .unwrap_or_else(|| Value::Object(Default::default()))
}

/// Кэш задач для мгновенного запуска: окно сразу показывает прошлые задачи, Google обновляет их фоном.
pub fn read_cache() -> Option<Value> {
    read_json(own("cache.json"))
}

/// Запись через временный файл и переименование: оборванная запись не портит кэш.
pub fn write_cache(v: &Value) {
    let p = own("cache.json");
    if let Some(dir) = p.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    let tmp = p.with_extension("tmp");
    if std::fs::write(&tmp, v.to_string()).is_ok() {
        let _ = std::fs::rename(tmp, p);
    }
}
