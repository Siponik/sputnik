//! Ярлык Спутника в меню «Пуск» Windows. Rust-версия — один sputnik.exe без установщика, поэтому
//! ярлык создаёт само приложение при запуске (`app/src/startmenu.rs`). Здесь — чистые проверки.

/// Id приложения для Windows (AppUserModelID): одинаковый у процесса, ярлыка в «Пуске» и уведомлений —
/// так закреплённый значок совпадает с окном, а уведомления показываются с именем и значком Спутника.
pub const APP_ID: &str = "Siponik.Sputnik";

/// Имя ярлыка в меню «Пуск» (у старого трекера — «Sputnik», так их не спутать).
pub const LINK_NAME: &str = "Спутник.lnk";

/// Запущена сборка для разработки (`target\debug|release`) — ей ярлык не нужен.
pub fn dev_build(exe: &str) -> bool {
    exe.to_lowercase().replace('/', "\\").contains("\\target\\")
}

/// Ярлык уже ведёт на этот exe. Путь к значку и рабочая папка хранятся в ярлыке строками UTF-16,
/// поэтому ищем полный путь exe в UTF-16 (с обоих выравниваний), без учёта регистра.
pub fn points_to(lnk: &[u8], exe: &str) -> bool {
    let want = exe.to_lowercase().replace('/', "\\");
    (0..2).any(|start| {
        let units: Vec<u16> = lnk[start.min(lnk.len())..]
            .chunks_exact(2)
            .map(|c| u16::from_le_bytes([c[0], c[1]]))
            .collect();
        String::from_utf16_lossy(&units).to_lowercase().contains(&want)
    })
}

/// Нужно ли (пере)создать ярлык: его нет или он ведёт на другой exe (файл переложили).
pub fn needs_link(existing: Option<&[u8]>, exe: &str) -> bool {
    if dev_build(exe) {
        return false;
    }
    match existing {
        Some(b) => !points_to(b, exe),
        None => true,
    }
}
