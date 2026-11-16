use sputnik_core::shortcut::*;

fn utf16(s: &str) -> Vec<u8> {
    s.encode_utf16().flat_map(|u| u.to_le_bytes()).collect()
}

fn lnk(icon: &str, odd: bool) -> Vec<u8> {
    let mut b = vec![0x4c, 0, 0, 0, 1, 2, 3];
    if odd {
        b.push(9);
    }
    b.extend(utf16(icon));
    b
}

const EXE: &str = r"D:\Программы\Спутник\sputnik.exe";

#[test]
fn link_to_this_exe() {
    assert!(points_to(&lnk(&format!("{EXE},0"), false), EXE));
    assert!(points_to(&lnk(&format!("{EXE},0"), true), &EXE.to_uppercase()));
    assert!(!points_to(&lnk(r"C:\Program Files\Sputnik\sputnik.exe,0", false), EXE));
}

#[test]
fn when_to_make_link() {
    assert!(needs_link(None, EXE));
    assert!(!needs_link(Some(&lnk(&format!("{EXE},0"), false)), EXE));
    // Файл переложили — ярлык пересоздаётся.
    assert!(needs_link(Some(&lnk(r"C:\Users\Me\Downloads\sputnik.exe,0", false)), EXE));
    // Сборка для разработки — не трогаем.
    assert!(!needs_link(None, r"D:\Projects\sputnik\rust\target\release\sputnik.exe"));
    assert!(dev_build("D:/x/target/debug/sputnik.exe"));
    assert!(!dev_build(EXE));
}
