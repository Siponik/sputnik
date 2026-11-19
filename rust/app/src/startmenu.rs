//! Спутник в меню «Пуск»: id приложения для Windows и ярлык «Спутник» в меню пользователя.
//! Проверки — `sputnik_core::shortcut`, создание ярлыка — PowerShell (`startmenu.ps1`).
#[cfg(windows)]
use sputnik_core::shortcut::{icon_refresh_due, needs_link, APP_ID, ICON_REV, LINK_NAME};

/// Id приложения процессу — до создания окна, чтобы окно на панели задач совпало с закреплённым ярлыком.
#[cfg(windows)]
pub fn set_app_id() {
    #[link(name = "shell32")]
    extern "system" {
        fn SetCurrentProcessExplicitAppUserModelID(id: *const u16) -> i32;
    }
    let id: Vec<u16> = APP_ID.encode_utf16().chain(Some(0)).collect();
    unsafe {
        SetCurrentProcessExplicitAppUserModelID(id.as_ptr());
    }
}

/// Создаёт или чинит ярлык «Спутник» в меню «Пуск». Тихо: ошибки не мешают работе.
#[cfg(windows)]
pub fn ensure_link() {
    let Ok(exe) = std::env::current_exe() else { return };
    let Some(appdata) = std::env::var_os("APPDATA") else { return };
    let dir = std::path::Path::new(&appdata).join(r"Microsoft\Windows\Start Menu\Programs");
    let link = dir.join(LINK_NAME);
    let old = std::fs::read(&link).ok();
    if needs_link(old.as_deref(), &exe.to_string_lossy()) && std::fs::create_dir_all(&dir).is_ok() {
        make_link(&link, &exe);
    }
    refresh_icons(&exe.to_string_lossy());
}

/// Новый значок в exe: один раз на номер `ICON_REV` просим Windows перечитать значки,
/// чтобы ярлык в «Пуске» и закреплённый на панели задач не держали старый из кэша.
#[cfg(windows)]
fn refresh_icons(exe: &str) {
    #[link(name = "shell32")]
    extern "system" {
        fn SHChangeNotify(event: i32, flags: u32, a: *const u8, b: *const u8);
    }
    let mark = crate::data::store::own("icon-rev");
    let saved = std::fs::read_to_string(&mark).ok();
    if !icon_refresh_due(saved.as_deref(), exe) {
        return;
    }
    const SHCNE_ASSOCCHANGED: i32 = 0x0800_0000;
    unsafe {
        SHChangeNotify(SHCNE_ASSOCCHANGED, 0, std::ptr::null(), std::ptr::null());
    }
    if let Some(dir) = mark.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    let _ = std::fs::write(&mark, ICON_REV);
}

#[cfg(windows)]
fn make_link(link: &std::path::Path, exe: &std::path::Path) {
    use std::os::windows::process::CommandExt;
    let _ = std::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", include_str!("startmenu.ps1")])
        .env("SP_LNK", link)
        .env("SP_EXE", exe)
        .env("SP_ID", APP_ID)
        .creation_flags(0x0800_0000)
        .status();
}

#[cfg(not(windows))]
pub fn set_app_id() {}

#[cfg(not(windows))]
pub fn ensure_link() {}
