//! Значок Спутника, закреплённого на панели задач Windows.
//! Старые установщики давали ярлыку в «Пуске» значок из C:\Windows\Installer\{код продукта}\ — папки,
//! которая удаляется при каждом обновлении; закреплённый ярлык (копия того, что в «Пуске») оставался
//! без значка. Новый установщик так не делает (windows/main.wxs), а уже закреплённые ярлыки
//! приложение чинит при запуске: значок берётся из самого Sputnik.exe.
//! Разбор ярлыка — только std, проверяется отдельно: `rustc --edition 2021 --test src/pin.rs`.

/// Строки ярлыка (.lnk) в нижнем регистре: UTF-16 (с обоих выравниваний) и однобайтовые.
fn texts(lnk: &[u8]) -> Vec<String> {
    let mut out = Vec::new();
    for start in 0..2 {
        let units: Vec<u16> = lnk[start.min(lnk.len())..]
            .chunks_exact(2)
            .map(|c| u16::from_le_bytes([c[0], c[1]]))
            .collect();
        out.push(String::from_utf16_lossy(&units).to_lowercase());
    }
    out.push(String::from_utf8_lossy(lnk).to_lowercase());
    out
}

/// Ярлык ведёт на наш exe, а значок берёт из папки установщика Windows — после обновления её не будет.
pub fn needs_fix(lnk: &[u8], exe_name: &str) -> bool {
    let all = texts(lnk);
    let exe = exe_name.to_lowercase();
    let ours = all.iter().any(|t| t.contains(&exe));
    // Значок в ярлыке хранится строкой UTF-16; однобайтовую копию не смотрим.
    let installer_icon = all[..2].iter().any(|t| t.contains("\\installer\\{"));
    ours && installer_icon
}

/// Чинит закреплённые ярлыки Спутника на панели задач. Тихо: ошибки не мешают запуску.
#[cfg(windows)]
pub fn heal() {
    use std::os::windows::process::CommandExt;
    const NO_WINDOW: u32 = 0x0800_0000;

    let Ok(exe) = std::env::current_exe() else { return };
    let Some(name) = exe.file_name().and_then(|n| n.to_str()) else { return };
    let Some(appdata) = std::env::var_os("APPDATA") else { return };
    let dir = std::path::Path::new(&appdata)
        .join(r"Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar");
    let Ok(entries) = std::fs::read_dir(&dir) else { return };

    let mut fixed = false;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()).map(|e| e.eq_ignore_ascii_case("lnk")) != Some(true) {
            continue;
        }
        let Ok(bytes) = std::fs::read(&path) else { continue };
        if !needs_fix(&bytes, name) {
            continue;
        }
        // Пути — через переменные окружения: так кириллица и пробелы не ломают команду.
        let ok = std::process::Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command",
                "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:SP_LNK); \
                 $s.IconLocation = \"$env:SP_EXE,0\"; $s.Save()"])
            .env("SP_LNK", &path)
            .env("SP_EXE", &exe)
            .creation_flags(NO_WINDOW)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
        fixed |= ok;
    }
    if fixed {
        // Сбросить кэш значков, чтобы панель задач перерисовала значок без перезапуска проводника.
        let _ = std::process::Command::new("ie4uinit.exe")
            .arg("-show")
            .creation_flags(NO_WINDOW)
            .status();
    }
}

#[cfg(not(windows))]
pub fn heal() {}

#[cfg(test)]
mod tests {
    use super::*;

    fn utf16(s: &str) -> Vec<u8> {
        s.encode_utf16().flat_map(|u| u.to_le_bytes()).collect()
    }

    fn lnk(target: &str, icon: &str, odd: bool) -> Vec<u8> {
        let mut b = vec![0x4c, 0, 0, 0, 1, 2, 3];
        if odd {
            b.push(9);
        }
        b.extend(target.as_bytes()); // LinkInfo — однобайтовый путь
        b.push(0);
        b.extend(utf16(icon)); // StringData — UTF-16
        b
    }

    const EXE: &str = r"C:\Program Files\Sputnik\Sputnik.exe";
    const OLD: &str = r"C:\WINDOWS\Installer\{8A1B2C3D-0000-1111-2222-333344445555}\ProductIcon";

    #[test]
    fn broken_pin_found() {
        assert!(needs_fix(&lnk(EXE, OLD, false), "Sputnik.exe"));
        assert!(needs_fix(&lnk(EXE, OLD, true), "Sputnik.exe"));
    }

    #[test]
    fn icon_from_exe_is_fine() {
        assert!(!needs_fix(&lnk(EXE, &format!("{EXE},0"), false), "Sputnik.exe"));
    }

    #[test]
    fn other_apps_untouched() {
        let other = r"C:\Program Files\Other\other.exe";
        assert!(!needs_fix(&lnk(other, OLD, false), "Sputnik.exe"));
    }

    #[test]
    fn exe_name_in_utf16_only() {
        let mut b = utf16(r"Sputnik\Sputnik.exe");
        b.extend(utf16(OLD));
        assert!(needs_fix(&b, "sputnik.exe"));
    }
}
