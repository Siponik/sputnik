//! Тема (Настройки → Вид → Тема): тёмная, светлая или как в Windows.
//! Цвета в разметке — смесь светлого и тёмного значения по `G.lt` (0 тёмная … 1 светлая),
//! здесь это число плавно ведётся к нужному краю. «Как в системе» раз в 2 с смотрит тему окна Windows.
use std::sync::atomic::{AtomicBool, Ordering};
use slint::{ComponentHandle, Timer, TimerMode};

pub const THEMES: [(&str, &str); 3] = [("dark", "Тёмная"), ("light", "Светлая"), ("sys", "Как в системе")];

static LIGHT: AtomicBool = AtomicBool::new(false);
/// Сейчас светлая тема (для цветов, которые считает Rust).
pub fn is_light() -> bool { LIGHT.load(Ordering::Relaxed) }

thread_local! {
    static ANIM: Timer = Timer::default();
    static POLL: Timer = Timer::default();
}

/// Тема Windows сейчас светлая? Неизвестно — тёмная (она основная).
fn system_light(w: &crate::AppWindow) -> bool {
    use slint::winit_030::{winit::window::Theme, WinitWindowAccessor};
    w.window().with_winit_window(|ww| ww.theme() == Some(Theme::Light)).unwrap_or(false)
}

/// Поставить тему. `smooth` — плавно (при смене в настройках), иначе сразу (при запуске).
pub fn apply(w: &crate::AppWindow, mode: &str, smooth: bool) {
    let mode = if THEMES.iter().any(|t| t.0 == mode) { mode } else { "dark" };
    let light = match mode { "light" => true, "sys" => system_light(w), _ => false };
    go(w, light, smooth);
    POLL.with(|p| {
        if mode == "sys" {
            let ww = w.as_weak();
            p.start(TimerMode::Repeated, std::time::Duration::from_secs(2), move || {
                let Some(w) = ww.upgrade() else { return };
                let l = system_light(&w);
                // цвета, которые считает Rust (точки сфер, граф), — тоже по новой теме
                if l != is_light() { go(&w, l, true); super::act(|_, _| {}); }
            });
        } else {
            p.stop();
        }
    });
}

fn go(w: &crate::AppWindow, light: bool, smooth: bool) {
    LIGHT.store(light, Ordering::Relaxed);
    let g = w.global::<crate::G>();
    let to = if light { 1.0f32 } else { 0.0 };
    // «Анимации: выкл» или запуск — сразу
    if !smooth || g.get_motion() == 2 {
        ANIM.with(|a| a.stop());
        g.set_lt(to);
    } else {
        let from = g.get_lt();
        let total = if g.get_motion() == 1 { 160.0 } else { 320.0 };
        let t0 = std::time::Instant::now();
        let ww = w.as_weak();
        ANIM.with(|a| a.start(TimerMode::Repeated, std::time::Duration::from_millis(16), move || {
            let Some(w) = ww.upgrade() else { return };
            let k = (t0.elapsed().as_secs_f32() * 1000.0 / total).min(1.0);
            let e = k * k * (3.0 - 2.0 * k); // плавно в начале и в конце
            w.global::<crate::G>().set_lt(from + (to - from) * e);
            if k >= 1.0 { ANIM.with(|a| a.stop()); }
        }));
    }
}
