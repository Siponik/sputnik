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

/// Ярлык ведёт на exe с этим именем.
pub fn points_to(lnk: &[u8], exe_name: &str) -> bool {
    let exe = exe_name.to_lowercase();
    texts(lnk).iter().any(|t| t.contains(&exe))
}

/// Спутник запущен из установленной копии, а не из сборки для разработки (`target\debug|release`).
pub fn installed(exe: &str) -> bool {
    !exe.to_lowercase().replace('/', "\\").contains("\\target\\")
}

/// Ярлык ведёт на наш exe, а значок берёт из папки установщика Windows — после обновления её не будет.
pub fn needs_fix(lnk: &[u8], exe_name: &str) -> bool {
    let all = texts(lnk);
    let ours = points_to(lnk, exe_name);
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

/// Ярлыки .lnk в папке и вложенных (не глубже `depth`).
#[cfg(windows)]
fn links(dir: &std::path::Path, depth: u32, out: &mut Vec<std::path::PathBuf>) {
    let Ok(entries) = std::fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            if depth > 0 {
                links(&path, depth - 1, out);
            }
        } else if path.extension().and_then(|e| e.to_str()).map(|e| e.eq_ignore_ascii_case("lnk")) == Some(true) {
            out.push(path);
        }
    }
}

/// Спутник в меню «Пуск»: если ни в общем, ни в своём меню нет ярлыка на Sputnik.exe (установщик его
/// не оставил или его удалили), создаёт «Спутник» в меню пользователя — его можно найти и закрепить.
/// Тихо: ошибки не мешают запуску.
#[cfg(windows)]
pub fn start_menu(app_id: &str) {
    use std::os::windows::process::CommandExt;
    const NO_WINDOW: u32 = 0x0800_0000;
    const MENU: &str = r"Microsoft\Windows\Start Menu\Programs";

    let Ok(exe) = std::env::current_exe() else { return };
    let Some(name) = exe.file_name().and_then(|n| n.to_str()) else { return };
    if !installed(&exe.to_string_lossy()) {
        return;
    }
    let Some(appdata) = std::env::var_os("APPDATA") else { return };
    let mine = std::path::Path::new(&appdata).join(MENU);
    let mut found = Vec::new();
    links(&mine, 2, &mut found);
    if let Some(common) = std::env::var_os("ProgramData") {
        links(&std::path::Path::new(&common).join(MENU), 2, &mut found);
    }
    let has = found.iter().any(|p| std::fs::read(p).map(|b| points_to(&b, name)).unwrap_or(false));
    if has || std::fs::create_dir_all(&mine).is_err() {
        return;
    }
    let _ = std::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command",
            include_str!("../windows/startmenu.ps1")])
        .env("SP_LNK", mine.join("Спутник.lnk"))
        .env("SP_EXE", &exe)
        .env("SP_ID", app_id)
        .creation_flags(NO_WINDOW)
        .status();
}

#[cfg(not(windows))]
pub fn start_menu(_app_id: &str) {}

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
    fn link_to_our_exe() {
        assert!(points_to(&lnk(EXE, &format!("{EXE},0"), false), "Sputnik.exe"));
        assert!(points_to(&utf16(EXE), "sputnik.exe"));
        assert!(!points_to(&lnk(r"C:\Program Files\Other\other.exe", "", false), "Sputnik.exe"));
    }

    #[test]
    fn dev_build_is_not_installed() {
        assert!(installed(EXE));
        assert!(installed(r"C:\Users\Me\AppData\Local\Sputnik\Sputnik.exe"));
        assert!(!installed(r"D:\Projects\sputnik\tracker\src-tauri\target\debug\sputnik.exe"));
        assert!(!installed("D:/Projects/sputnik/tracker/src-tauri/target/release/sputnik.exe"));
    }

    #[test]
    fn exe_name_in_utf16_only() {
        let mut b = utf16(r"Sputnik\Sputnik.exe");
        b.extend(utf16(OLD));
        assert!(needs_fix(&b, "sputnik.exe"));
    }
}
