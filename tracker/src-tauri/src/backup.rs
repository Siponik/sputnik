//! Резервные копии слоя: раз в день перед первой записью старый layer.json
//! копируется в `backups/layer-ГГГГ-ММ-ДД.json`, хранятся последние 14.
//! Если layer.json испорчен, слой читается из самой свежей целой копии.
//! Только std — модуль проверяется отдельно: `rustc --test src/backup.rs`.

use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

pub const KEEP: usize = 14;

/// Дата ГГГГ-ММ-ДД (UTC) по числу дней от 1970-01-01.
pub fn civil(days: i64) -> String {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + if m <= 2 { 1 } else { 0 };
    format!("{:04}-{:02}-{:02}", y, m, d)
}

pub fn today() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    civil((secs / 86_400) as i64)
}

fn dir(layer: &Path) -> PathBuf {
    layer.with_file_name("backups")
}

/// Копии от новой к старой.
pub fn list(layer: &Path) -> Vec<PathBuf> {
    let mut v: Vec<PathBuf> = fs::read_dir(dir(layer))
        .map(|rd| {
            rd.filter_map(|e| e.ok().map(|e| e.path()))
                .filter(|p| {
                    let n = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
                    n.starts_with("layer-") && n.ends_with(".json")
                })
                .collect()
        })
        .unwrap_or_default();
    v.sort();
    v.reverse();
    v
}

/// Перед записью: если за `day` копии ещё нет — сохранить текущий файл, лишние удалить.
pub fn before_write(layer: &Path, day: &str) -> std::io::Result<()> {
    if !layer.exists() {
        return Ok(());
    }
    let d = dir(layer);
    let target = d.join(format!("layer-{}.json", day));
    if target.exists() {
        return Ok(());
    }
    fs::create_dir_all(&d)?;
    fs::copy(layer, &target)?;
    for old in list(layer).into_iter().skip(KEEP) {
        let _ = fs::remove_file(old);
    }
    Ok(())
}

/// Текст самой свежей копии, которую `ok` признаёт целой.
pub fn latest_good(layer: &Path, ok: impl Fn(&str) -> bool) -> Option<String> {
    list(layer)
        .into_iter()
        .filter_map(|p| fs::read_to_string(p).ok())
        .find(|t| ok(t))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let d =
            std::env::temp_dir().join(format!("sputnik-backup-{}-{}", name, std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d.join("layer.json")
    }

    #[test]
    fn civil_dates() {
        assert_eq!(civil(0), "1970-01-01");
        assert_eq!(civil(11_016), "2000-02-29");
        assert_eq!(civil(20_747), "2026-10-21");
    }

    #[test]
    fn one_copy_per_day() {
        let l = tmp("day");
        before_write(&l, "2026-10-21").unwrap(); // файла ещё нет — копировать нечего
        assert!(list(&l).is_empty());
        fs::write(&l, "a").unwrap();
        before_write(&l, "2026-10-21").unwrap();
        fs::write(&l, "b").unwrap();
        before_write(&l, "2026-10-21").unwrap();
        let v = list(&l);
        assert_eq!(v.len(), 1);
        assert_eq!(fs::read_to_string(&v[0]).unwrap(), "a");
    }

    #[test]
    fn keeps_last_14() {
        let l = tmp("keep");
        fs::write(&l, "x").unwrap();
        for i in 1..=20 {
            before_write(&l, &format!("2026-10-{:02}", i)).unwrap();
        }
        let v = list(&l);
        assert_eq!(v.len(), KEEP);
        assert!(v[0].ends_with("layer-2026-10-20.json"));
        assert!(v[KEEP - 1].ends_with("layer-2026-10-07.json"));
    }

    #[test]
    fn latest_good_skips_broken() {
        let l = tmp("good");
        fs::write(&l, "{\"ok\":1}").unwrap();
        before_write(&l, "2026-10-19").unwrap();
        fs::write(&l, "{broken").unwrap();
        before_write(&l, "2026-10-20").unwrap();
        let t = latest_good(&l, |t| t.starts_with("{\"")).unwrap();
        assert_eq!(t, "{\"ok\":1}");
    }
}
