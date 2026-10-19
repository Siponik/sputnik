// Без консольного окна в собранной версии для Windows.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    sputnik_lib::run()
}
