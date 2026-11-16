//! Спутник в меню «Пуск»: id приложения для Windows и ярлык «Спутник» в меню пользователя.
//! Проверки — `sputnik_core::shortcut`, создание ярлыка — PowerShell (`startmenu.ps1`).
#[cfg(windows)]
use sputnik_core::shortcut::{needs_link, APP_ID, LINK_NAME};

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
    use std::os::windows::process::CommandExt;
    let Ok(exe) = std::env::current_exe() else { return };
    let Some(appdata) = std::env::var_os("APPDATA") else { return };
    let dir = std::path::Path::new(&appdata).join(r"Microsoft\Windows\Start Menu\Programs");
    let link = dir.join(LINK_NAME);
    let old = std::fs::read(&link).ok();
    if !needs_link(old.as_deref(), &exe.to_string_lossy()) || std::fs::create_dir_all(&dir).is_err() {
        return;
    }
    let _ = std::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", include_str!("startmenu.ps1")])
        .env("SP_LNK", &link)
        .env("SP_EXE", &exe)
        .env("SP_ID", APP_ID)
        .creation_flags(0x0800_0000)
        .status();
}

#[cfg(not(windows))]
pub fn set_app_id() {}

#[cfg(not(windows))]
pub fn ensure_link() {}
