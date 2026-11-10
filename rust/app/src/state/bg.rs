//! Фоновая работа без блокировки окна. Состояние приложения живёт только в потоке окна; сеть и диск — в фоне,
//! результат возвращается в поток окна через slint::invoke_from_event_loop и применяется к App там.
use super::App;
use std::cell::RefCell;
use std::sync::mpsc;

thread_local! {
    static APP: RefCell<Option<App>> = const { RefCell::new(None) };
    static RENDER: RefCell<Option<Box<dyn Fn(&App)>>> = const { RefCell::new(None) };
}

/// Поставить состояние (один раз при запуске, в потоке окна).
pub fn install(app: App, render: impl Fn(&App) + 'static) {
    APP.with(|a| *a.borrow_mut() = Some(app));
    RENDER.with(|r| *r.borrow_mut() = Some(Box::new(render)));
}

/// Изменить состояние и перерисовать окно (только из потока окна).
pub fn with<R>(f: impl FnOnce(&mut App) -> R) -> Option<R> {
    let r = APP.with(|a| a.try_borrow_mut().ok().and_then(|mut g| g.as_mut().map(f)));
    render();
    r
}

/// Прочитать состояние без перерисовки.
pub fn peek<R>(f: impl FnOnce(&App) -> R) -> Option<R> {
    APP.with(|a| a.try_borrow().ok().and_then(|g| g.as_ref().map(f)))
}

pub fn render() {
    APP.with(|a| {
        if let Ok(g) = a.try_borrow() {
            if let Some(app) = g.as_ref() {
                RENDER.with(|r| {
                    if let Some(f) = r.borrow().as_ref() {
                        f(app);
                    }
                });
            }
        }
    });
}

/// Сделать job в фоне, потом then — в потоке окна с доступом к App.
pub fn run<T: Send + 'static>(job: impl FnOnce() -> T + Send + 'static, then: impl FnOnce(&mut App, T) + Send + 'static) {
    std::thread::spawn(move || {
        let r = job();
        let _ = slint::invoke_from_event_loop(move || {
            with(move |app| then(app, r));
        });
    });
}

/// Запись файлов одним фоновым потоком: из очереди берётся последняя версия каждого файла.
pub struct Writer {
    tx: mpsc::Sender<(String, serde_json::Value)>,
}

impl Writer {
    pub fn new() -> Self {
        let (tx, rx) = mpsc::channel::<(String, serde_json::Value)>();
        std::thread::spawn(move || {
            while let Ok(first) = rx.recv() {
                let mut batch = vec![first];
                while let Ok(x) = rx.try_recv() {
                    batch.push(x);
                }
                let mut last: Vec<(String, serde_json::Value)> = vec![];
                for (n, v) in batch {
                    last.retain(|x| x.0 != n);
                    last.push((n, v));
                }
                for (n, v) in last {
                    if n == "layer.json" {
                        crate::data::store::write_layer(&v);
                    } else if let Err(e) = crate::data::store::write_json(&n, &v) {
                        crate::data::store::log("запись", &format!("{n}: {e}"));
                    }
                }
            }
        });
        Writer { tx }
    }
    pub fn write(&self, name: &str, v: serde_json::Value) {
        let _ = self.tx.send((name.to_string(), v));
    }
}
