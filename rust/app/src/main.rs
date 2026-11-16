#![cfg_attr(windows, windows_subsystem = "windows")]
//! Спутник на Rust + Slint. Устройство — docs/rust-architecture.md.
mod data;
mod notes;
mod notify;
mod startmenu;
mod state;
mod view;
slint::include_modules!();

fn main() {
    // Ярлык в «Пуске» и id приложения для Windows (src/startmenu.rs): ярлык — в фоне, окно не ждёт.
    startmenu::set_app_id();
    std::thread::spawn(startmenu::ensure_link);
    let app = state::App::load();
    let w = view::start(app);
    w.run().expect("окно");
}
