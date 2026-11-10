//! Вид: собирает модели для окна из App (state) и состояния экрана (Ui) и ловит действия окна.
//! Слои: data (сеть, файлы) → state (App, действия) → view (модели Slint) → ui/*.slint (разметка).
//! Окно ничего не считает: после любого действия render() заново кладёт модели только активного раздела.
mod board;
mod calendar;
mod dialogs;
mod habits;
mod notes;
mod settings;
mod today;
mod wire;

use crate::state::App;
use crate::{AppWindow, S};
use serde_json::Value;
use slint::{Color, ComponentHandle, ModelRc, SharedString, VecModel};
use sputnik_core::j::*;
use std::cell::RefCell;

/// Состояние экрана (не данные): открытый раздел, список доски, день календаря, открытые окна.
#[derive(Default)]
pub struct Ui {
    pub tab: i32,
    pub board: String,
    pub cal_sel: String,
    pub cal_mode: String,
    pub cal_off: Vec<String>,
    pub cal_bands: Vec<i64>,
    pub add_time: String,
    pub quick: String,
    pub task: Option<(String, String)>,
    pub saved: String,
    pub create: Option<dialogs::Create>,
    pub search: Option<String>,
    pub found: Vec<(Found, Box<dyn Fn(&mut App, &mut Ui)>)>,
    pub confirm: Option<(String, String, Box<dyn FnOnce(&mut App, &mut Ui)>)>,
    pub habit_mode: String,
    pub habit_part: String,
    pub note_q: String,
    pub note_path: String,
    pub note_dirty: bool,
    pub note_graph: bool,
}
pub use crate::Found;

thread_local! {
    static UI: RefCell<Ui> = RefCell::new(Ui::default());
    static WIN: RefCell<Option<slint::Weak<AppWindow>>> = const { RefCell::new(None) };
}

/// Действие окна: меняет App и Ui, потом перерисовка.
pub fn act(f: impl FnOnce(&mut App, &mut Ui)) {
    crate::state::with(|app| UI.with(|u| f(app, &mut u.borrow_mut())));
}

pub fn start(app: App) -> AppWindow {
    let w = AppWindow::new().expect("окно");
    WIN.with(|x| *x.borrow_mut() = Some(w.as_weak()));
    UI.with(|u| {
        let mut u = u.borrow_mut();
        u.cal_mode = "week".into();
        u.habit_mode = "today".into();
        u.habit_part = "all".into();
        u.tab = match app.layer["settings"]["start"]["v"].as_str() {
            Some("calendar") => 1,
            Some("board") => 2,
            Some("habits") => 3,
            _ => 0,
        };
        u.board = app.layer["settings"]["lastBoard"]["v"].as_str().unwrap_or("").to_string();
        // для проверки окна: SPUTNIK_TAB=2 SPUTNIK_BOARD=icons
        if let Ok(t) = std::env::var("SPUTNIK_TAB") {
            u.tab = t.parse().unwrap_or(0);
        }
        if let Ok(b) = std::env::var("SPUTNIK_BOARD") {
            u.board = b;
        }
        if let Ok(m) = std::env::var("SPUTNIK_CAL") {
            u.cal_mode = m;
        }
        match std::env::var("SPUTNIK_OPEN").unwrap_or_default().split(':').collect::<Vec<_>>().as_slice() {
            ["create", k, rest @ ..] => u.create = Some(dialogs::Create { kind: k.parse().unwrap_or(0), text: rest.join(":"), ..Default::default() }),
            ["task", l, id] => u.task = Some((l.to_string(), id.to_string())),
            ["search", q] => {
                u.search = Some(q.to_string());
                u.found = wire::find(&app, q);
            }
            ["note", p] => u.note_path = p.to_string(),
            ["graph", p] => { u.note_graph = true; u.note_path = p.to_string(); }
            _ => {}
        }
    });
    wire::wire(&w);
    crate::state::bg::install(app, render);
    crate::state::with(|a| a.start_timers());
    w
}

fn render(app: &App) {
    let Some(w) = WIN.with(|x| x.borrow().as_ref().and_then(|w| w.upgrade())) else { return };
    UI.with(|u| {
        let Ok(mut u) = u.try_borrow_mut() else { return };
        let g = w.global::<S>();
        shell(app, &u, &g);
        match u.tab {
            0 => today::render(app, &u, &g),
            1 => calendar::render(app, &mut u, &g),
            2 => board::render(app, &mut u, &g),
            3 => habits::render(app, &u, &g),
            4 => notes::render(app, &u, &g),
            _ => settings::render(app, &u, &g),
        }
        if u.tab != 0 {
            // счётчик «Сегодня» в шапке считается всегда
            g.set_today_count(app.today_items().iter().filter(|x| !App::is_done(&x.1)).count() as i32);
        }
        dialogs::render(app, &mut u, &g);
    });
}

fn shell(app: &App, u: &Ui, g: &S) {
    let f = &app.flags;
    g.set_tab(u.tab);
    g.set_signed_in(!f.need_login);
    g.set_logging_in(f.logging_in);
    g.set_busy(f.syncing);
    g.set_offline(f.offline);
    g.set_error(f.error.clone().unwrap_or_default().into());
    let status = match (&f.error, f.synced_at) {
        (Some(e), _) if !f.offline => short(e, 40),
        (_, Some(t)) => format!("синхр. {}", hm(t)),
        _ => if app.outbox.ops.is_empty() { "не синхронизировано".into() } else { format!("в очереди {}", app.outbox.ops.len()) },
    };
    let status = if !app.outbox.ops.is_empty() && f.synced_at.is_some() { format!("{status} · ждут {}", app.outbox.ops.len()) } else { status };
    g.set_status(status.into());
    g.set_inbox_count(app.inbox_items().len() as i32);
    g.set_version(env!("CARGO_PKG_VERSION").into());
    match &app.toast {
        Some(t) => {
            g.set_toast(t.text.clone().into());
            g.set_toast_label(t.label.clone().into());
            g.set_toast_id(t.id as i32);
        }
        None => g.set_toast("".into()),
    }
    match &u.confirm {
        Some((q, yes, _)) => {
            g.set_confirm(q.clone().into());
            g.set_confirm_yes_label(yes.clone().into());
        }
        None => g.set_confirm("".into()),
    }
}

// ---------- помощники ----------

pub fn short(t: &str, n: usize) -> String {
    if t.chars().count() <= n { t.to_string() } else { format!("{}…", t.chars().take(n).collect::<String>()) }
}

pub fn model<T: Clone + 'static>(v: Vec<T>) -> ModelRc<T> {
    ModelRc::new(VecModel::from(v))
}

pub fn ss(v: impl Into<String>) -> SharedString {
    SharedString::from(v.into())
}

pub fn strings(v: Vec<String>) -> ModelRc<SharedString> {
    model(v.into_iter().map(SharedString::from).collect())
}

fn hex(h: u32) -> Color {
    Color::from_rgb_u8((h >> 16) as u8, (h >> 8) as u8, h as u8)
}

/// Цвет из имён старого трекера (var(--clay) и т. п.), #RRGGBB или номера палитры.
pub fn color(v: &str) -> Color {
    let v = v.trim();
    if let Some(h) = v.strip_prefix('#') {
        if let Ok(x) = u32::from_str_radix(&h[..h.len().min(6)], 16) {
            return hex(x);
        }
    }
    hex(match v {
        "var(--clay)" | "clay" | "accent" => 0xF0A04B,
        "var(--gold)" | "gold" => 0xE8C65A,
        "var(--type-work)" | "work" | "blue" => 0x6FA2F2,
        "var(--type-study)" | "study" | "violet" => 0xB48CF0,
        "var(--type-personal)" | "personal" | "green" => 0x7FD18C,
        "var(--type-creative)" | "creative" => 0xF0A04B,
        "var(--signal-done)" | "done" | "teal" => 0x6FB6CF,
        "red" => 0xF0785F,
        _ => 0xA3A5AE,
    })
}

/// Цвет списка = цвет его сферы.
pub fn list_hue(app: &App, list: &str) -> Color {
    match app.sphere_of(list) {
        Some(sp) => app.spheres().iter().find(|x| x["id"] == sp.as_str()).map(|x| color(&sputnik_core::spheres::sphere_color(x))).unwrap_or(color("")),
        None => color(""),
    }
}

pub fn today_s() -> String {
    crate::state::today_ymd()
}

pub fn due_text(t: &Value, slot: &Value) -> (String, bool) {
    let due = day10(&t["due"]);
    let x = sputnik_core::stickers::due_label(&due, &today_s(), slot, false);
    (text(&x["text"]), x["cls"] == "late")
}

/// Время «ЧЧ:ММ» по местным часам из мс.
pub fn hm(ms: f64) -> String {
    chrono::DateTime::from_timestamp_millis(ms as i64).map(|d| d.with_timezone(&chrono::Local).format("%H:%M").to_string()).unwrap_or_default()
}
