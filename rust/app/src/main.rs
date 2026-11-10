#![cfg_attr(windows, windows_subsystem = "windows")]
//! Спутник на Rust + Slint. Устройство — docs/rust-architecture.md.
mod data;
mod notes;
mod notify;
mod state;
mod view;
slint::include_modules!();

fn main() {
    let app = state::App::load();
    let w = view::start(app);
    w.run().expect("окно");
}
