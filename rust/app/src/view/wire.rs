//! Действия окна → App. Каждое действие сразу меняет память (и очередь в Google), потом окно перерисовывается.
use super::dialogs::{cal_of, default_mins, dest_of, lead_mins, Create};
use super::*;
use sputnik_core::{create as cr, habits as hb, route, search, today as td, when};

fn task_of(app: &App, list: &str, id: &str) -> Option<Value> {
    app.task(list, id).cloned()
}

fn habit_by(app: &App, id: &str) -> Option<Value> {
    let hs = app.habits();
    if let Some(k) = id.strip_prefix('#') {
        let i: usize = k.parse().unwrap_or(0);
        return hs.get(i.wrapping_sub(1)).cloned();
    }
    hs.into_iter().find(|h| h["id"] == id)
}

/// Изменить Ui из колбэка App (после фоновой работы): App уже занят, Ui — свободен.
fn ui_now(f: impl FnOnce(&mut Ui)) {
    super::UI.with(|u| {
        if let Ok(mut u) = u.try_borrow_mut() {
            f(&mut u)
        }
    });
}

pub(super) fn ask(u: &mut Ui, q: impl Into<String>, yes: &str, f: impl FnOnce(&mut App, &mut Ui) + 'static) {
    u.confirm = Some((q.into(), yes.into(), Box::new(f)));
}

fn str_(x: &slint::SharedString) -> String {
    x.as_str().to_string()
}

/// Минимальный размер окна при своей рамке (no-frame): иначе winit даёт сжать окно так,
/// что обрезается шапка с кнопками. Держим в двух местах: min-width/min-height в ui/app.slint и здесь.
/// При масштабе Windows 125–150 % экран в логических точках маленький — минимум не больше экрана.
const MIN_W: f64 = 960.0;
const MIN_H: f64 = 540.0;

fn set_min_size(w: &slint::Weak<AppWindow>) {
    if let Some(w) = w.upgrade() {
        use slint::winit_030::{winit::dpi::LogicalSize, WinitWindowAccessor};
        w.window().with_winit_window(|ww| {
            let (mut mw, mut mh) = (MIN_W, MIN_H);
            if let Some(m) = ww.current_monitor() {
                let sf = m.scale_factor().max(0.5);
                let s = m.size().to_logical::<f64>(sf);
                mw = mw.min(s.width - 20.0);
                mh = mh.min(s.height - 60.0);
            }
            ww.set_min_inner_size(Some(LogicalSize::new(mw.max(640.0), mh.max(400.0))));
        });
    }
}

/// Окно больше экрана (масштаб 125–150 %, ноутбук) — ужимаем до экрана и разворачиваем,
/// иначе низ и правый край окна уходят за экран и «половину не видно».
fn fit_screen(w: &slint::Weak<AppWindow>) {
    let Some(w) = w.upgrade() else { return };
    use slint::winit_030::{winit::dpi::{PhysicalPosition, PhysicalSize}, WinitWindowAccessor};
    let big = w.window().with_winit_window(|ww| {
        let m = ww.current_monitor()?;
        let sf = m.scale_factor().max(0.5);
        let (ms, os) = (m.size(), ww.outer_size());
        let (mw, mh) = (ms.width as f64 - 20.0 * sf, ms.height as f64 - 60.0 * sf);
        if os.width as f64 <= mw && os.height as f64 <= mh {
            return Some(false);
        }
        // размер «не развёрнутого» окна — тоже в пределах экрана
        let (nw, nh) = ((os.width as f64).min(mw) as u32, (os.height as f64).min(mh) as u32);
        let _ = ww.request_inner_size(PhysicalSize::new(nw, nh));
        let p = m.position();
        ww.set_outer_position(PhysicalPosition::new(p.x + (ms.width.saturating_sub(nw) / 2) as i32, p.y + 8));
        Some(true)
    });
    if big.flatten() == Some(true) && !w.window().is_maximized() {
        w.window().set_maximized(true);
        w.global::<S>().set_win_maxed(true);
    }
}

pub fn wire(w: &AppWindow) {
    let g = w.global::<S>();

    // ---------- оболочка ----------
    // своя рамка окна (no-frame): перетаскивание, свернуть, развернуть, закрыть
    let ww = w.as_weak();
    slint::Timer::single_shot(std::time::Duration::from_millis(50), move || { set_min_size(&ww); fit_screen(&ww); }); // при старте, когда окно уже показано
    // и ещё раз чуть позже: на медленном старте окно и монитор появляются не сразу
    let ww = w.as_weak();
    slint::Timer::single_shot(std::time::Duration::from_millis(600), move || { set_min_size(&ww); fit_screen(&ww); });
    let ww = w.as_weak();
    g.on_win_drag(move || {
        set_min_size(&ww);
        if let Some(w) = ww.upgrade() {
            use slint::winit_030::WinitWindowAccessor;
            w.window().with_winit_window(|ww| { let _ = ww.drag_window(); });
        }
    });
    let ww = w.as_weak();
    g.on_win_resize(move |k| {
        set_min_size(&ww);
        if let Some(w) = ww.upgrade() {
            use slint::winit_030::{winit::window::ResizeDirection as R, WinitWindowAccessor};
            let d = match k { 1 => R::East, 2 => R::South, 3 => R::West, _ => R::SouthEast };
            w.window().with_winit_window(|ww| { let _ = ww.drag_resize_window(d); });
        }
    });
    let ww = w.as_weak();
    g.on_win_min(move || { if let Some(w) = ww.upgrade() { w.window().set_minimized(true); } });
    let ww = w.as_weak();
    g.on_win_max(move || { if let Some(w) = ww.upgrade() { let m = w.window().is_maximized(); w.window().set_maximized(!m); w.global::<S>().set_win_maxed(!m); } });
    let ww = w.as_weak();
    g.on_win_close(move || { if let Some(w) = ww.upgrade() { let _ = w.hide(); } let _ = slint::quit_event_loop(); });
    g.on_go(|i| act(|app, u| {
        u.tab = i;
        if i == 4 {
            app.notes.rescan();
        }
    }));
    g.on_login(|| act(|app, _| app.login()));
    g.on_cancel_login(|| act(|app, _| {
        crate::data::google::cancel_login();
        app.flags.logging_in = false;
    }));
    g.on_refresh(|| act(|app, _| app.refresh()));
    g.on_toast_act(|| {
        crate::state::with(|app| app.toast_act());
    });
    g.on_confirm_yes(|| act(|app, u| {
        if let Some((_, _, f)) = u.confirm.take() {
            f(app, u);
        }
    }));
    g.on_confirm_no(|| act(|_, u| u.confirm = None));

    // ---------- Сегодня ----------
    g.on_quick_changed(|t| act(|_, u| u.quick = str_(&t)));
    g.on_quick_add(|t| act(|app, u| {
        u.quick.clear();
        match app.add_line(&t, None, true) {
            Some((l, title)) => app.say(format!("«{}» → {}", short(&title, 30), app.list_name(&l))),
            None => app.say("Нет ни одного списка — создай его на «Доске»"),
        }
    }));
    g.on_quick_full(|t| act(|_, u| {
        u.quick.clear();
        u.create = Some(Create { text: str_(&t), ..Default::default() });
    }));
    g.on_toggle(|l, id| act(|app, _| {
        if let Some(t) = task_of(app, &l, &id) {
            app.toggle_done(&l, &t);
        }
    }));
    g.on_open_task(|l, id| act(|_, u| {
        u.task = Some((str_(&l), str_(&id)));
        u.saved.clear();
    }));
    g.on_habit_tap(|id| act(|app, _| {
        if let Some(h) = habit_by(app, &id) {
            app.toggle_habit(&h);
        }
    }));
    g.on_accept(|_, id| act(|app, _| {
        let it: Vec<Value> = app.inbox_items().into_iter().filter(|x| x["task"]["id"] == id.as_str()).collect();
        app.accept_inbox(&it);
    }));
    g.on_reject(|_, id| act(|app, _| {
        if let Some(x) = app.inbox_items().into_iter().find(|x| x["task"]["id"] == id.as_str()) {
            app.reject_inbox(&x);
        }
    }));
    g.on_accept_all(|| act(|app, _| {
        let it = app.inbox_items();
        app.accept_inbox(&it);
    }));

    // ---------- Доска ----------
    g.on_pick_list(|id| act(|app, u| {
        u.arch = false;
        let ls = app.board_lists();
        let id = str_(&id);
        let i = ls.iter().position(|l| l["id"] == u.board.as_str()).unwrap_or(0);
        let next = match id.as_str() {
            "<" => ls.get((i + ls.len().max(1) - 1) % ls.len().max(1)).map(|l| text(&l["id"])),
            ">" => ls.get((i + 1) % ls.len().max(1)).map(|l| text(&l["id"])),
            _ => Some(id),
        };
        if let Some(n0) = next {
            u.board = n0.clone();
            app.set_setting("lastBoard", json!(n0));
        }
    }));
    g.on_set_view(|v| act(|app, u| {
        let b = u.board.clone();
        app.set_list_field(&b, json!({"view": str_(&v)}));
    }));
    g.on_move_card(|l, id, ci| act(|app, _| {
        let cols = app.columns(&l);
        let Some(c) = cols.get(ci.max(0) as usize) else { return };
        let col = text(&c.0["id"]);
        if let Some(t) = task_of(app, &l, &id) {
            if app.col_of(&t, &cols.iter().map(|x| x.0.clone()).collect::<Vec<_>>()) != col {
                app.set_stage(&l, &t, &col);
            }
        }
    }));
    g.on_next_stage(|l, id| act(|app, _| {
        let cols: Vec<Value> = app.columns(&l).into_iter().map(|x| x.0).collect();
        if let Some(t) = task_of(app, &l, &id) {
            let cur = app.col_of(&t, &cols);
            if let Some(i) = cols.iter().position(|c| c["id"] == cur.as_str()) {
                if let Some(nx) = cols.get(i + 1) {
                    app.set_stage(&l, &t, s(&nx["id"]));
                    app.say(format!("→ {}", text(&nx["name"])));
                }
            }
        }
    }));
    g.on_add_card(|l, col, t| act(|app, _| {
        let l = str_(&l);
        let view = super::board::view_of(app, &l);
        let p = route::parse_line(&t, hb::now().date(), &json!({}));
        let x = td::task_from(&p, &today_s(), &l, &json!({}));
        let mut patch = if x["layer"].is_object() { x["layer"].clone() } else { json!({}) };
        if !x["slot"].is_null() {
            patch["slot"] = x["slot"].clone();
        }
        let col = str_(&col);
        let title = text(&p["title"]);
        if title.trim().is_empty() {
            return;
        }
        if view == "stickers" {
            if !col.is_empty() {
                patch["topic"] = json!(col);
            }
            app.add_task(&l, &title, x["due"].as_str(), patch, None, "");
        } else {
            app.add_task(&l, &title, x["due"].as_str(), patch, if col.is_empty() { None } else { Some(&col) }, "");
        }
    }));
    g.on_new_list(|t| act(|app, u| {
        let tpl = if u.board.is_empty() { "work".to_string() } else { text(&app.ll(&u.board)["template"]) };
        let tpl = if tpl.is_empty() { "work".into() } else { tpl };
        app.create_list(&t, &tpl, None, None, Some(Box::new(|app: &mut App, id: String| {
            app.say("Список создан");
            ui_now(|u| u.board = id);
        })));
    }));
    g.on_rename_list(|id, t| act(|app, _| {
        if !t.trim().is_empty() {
            app.rename_list(&id, t.trim());
        }
    }));
    g.on_delete_list(|id| act(|app, u| {
        let id = str_(&id);
        let n0 = app.tasks_of(&id).len();
        ask(u, format!("Удалить список «{}» и {} задач в нём? В Google Tasks он удалится насовсем.", app.list_name(&id), n0), "Удалить", move |app, u| {
            app.delete_list(&id);
            u.board.clear();
        });
    }));
    g.on_pin_card(|l, id| act(|app, _| {
        let pin = sputnik_core::j::t(&app.lt(&id)["pin"]);
        let _ = l;
        app.set_task(&id, json!({"pin": !pin}));
    }));
    g.on_pipe_toggle(|id| act(|_, u| { let id = str_(&id); u.pipe_open = if u.pipe_open == id { String::new() } else { id }; }));
    g.on_stk_by_set(|v| act(|_, u| u.stk_by = str_(&v)));
    g.on_open_archive(|| act(|_, u| { u.tab = 2; u.arch = true; }));
    g.on_arch_close(|| act(|_, u| u.arch = false));
    g.on_arch_q_set(|q| act(|_, u| u.arch_q = str_(&q)));
    g.on_arch_sphere_set(|v| act(|_, u| u.arch_sphere = str_(&v)));
    g.on_pipe_gallery_set(|v| act(|_, u| u.pipe_gallery = v));
    g.on_pipe_stage_set(|v| act(|_, u| u.pipe_stage = v + 1));
    g.on_pipe_by_set(|v| act(|_, u| u.pipe_by = str_(&v)));
    g.on_pipe_sub_add(|l, id, t| act(|app, _| app.add_subtask(&l, &id, &t)));
    g.on_pipe_prio_set(|_, id, p| act(|app, _| app.set_priority(&id, Some(p as i64))));
    g.on_pipe_back(|l, id| act(|app, _| {
        let cols = app.columns(&l);
        let Some(t) = task_of(app, &l, &id) else { return };
        let ids: Vec<String> = cols.iter().map(|c| text(&c.0["id"])).collect();
        let cur = app.col_of(&t, &cols.iter().map(|c| c.0.clone()).collect::<Vec<_>>());
        if let Some(i) = ids.iter().position(|x| *x == cur).filter(|&i| i > 0) {
            app.set_stage(&l, &t, &ids[i - 1]);
        }
    }));
    g.on_card_menu(|l, id, what| act(|app, _| {
        let Some(t) = task_of(app, &l, &id) else { return };
        match what.as_str() {
            "dup" => app.duplicate(&l, &t),
            "del" => app.remove(&l, &t),
            "today" => app.set_due(&l, &t, Some(&today_s())),
            "tomorrow" => {
                let d = sputnik_core::dates::ymd(sputnik_core::dates::add_days(sputnik_core::dates::parse_ymd(&today_s()).unwrap(), 1));
                app.set_due(&l, &t, Some(&d));
            }
            _ => {}
        }
    }));

    // ---------- Календарь ----------
    g.on_cal_shift(|d| act(|_, u| {
        let mode = if u.cal_mode == "month" { "month" } else { "week" };
        u.cal_sel = sputnik_core::calendar::shift_period(&u.cal_sel, mode, d as i64);
        u.cal_bands.clear();
    }));
    g.on_cal_today(|| act(|_, u| {
        u.cal_sel = today_s();
        u.cal_bands.clear();
    }));
    g.on_cal_mode_set(|m| act(|_, u| u.cal_mode = str_(&m)));
    g.on_cal_pick(|d| act(|_, u| u.cal_sel = str_(&d)));
    g.on_cal_filter(|f| act(|_, u| {
        let f = str_(&f);
        if let Some(i) = u.cal_off.iter().position(|x| *x == f) { u.cal_off.remove(i); } else { u.cal_off.push(f); }
    }));
    g.on_cal_free_take(|| act(|_, u| {
        if let Some((d, t)) = u.cal_free.clone() { u.cal_sel = d; u.add_time = t; }
    }));
    g.on_cal_add_close(|| act(|_, u| u.add_time.clear()));
    g.on_cal_band(|a0| act(|_, u| u.cal_bands.push(a0 as i64)));
    g.on_cal_grid_click(|d, y| act(|app, u| {
        u.cal_sel = str_(&d);
        let m = super::calendar::min_at(app, u, y as f64);
        u.add_time = sputnik_core::calendar::from_min(m);
    }));
    g.on_cal_add(|d, tm, title, ev| act(|app, u| {
        let day = if d.is_empty() { u.cal_sel.clone() } else { str_(&d) };
        let tm = tm.trim().replace('.', ":");
        let time = if tm.is_empty() { None } else { Some(if tm.len() <= 2 { format!("{:0>2}:00", tm) } else { format!("{:0>5}", tm) }) };
        if ev {
            let slot = time.map(|st| { let en = cr::add_min(&st, 60); (st, en) });
            let cal = cal_of(app, &Create::default());
            let mins = default_mins(app, 1);
            app.create_event(&title, &day, slot, "", &mins, &cal, "", Value::Null);
        } else {
            let r = route::route(&title, &app.board_lists(), &app.layer, &app.tasks, None, crate::state::now_ms());
            let Some(dest) = r.first().map(|x| text(&x["listId"])).or_else(|| app.board_lists().first().map(|l| text(&l["id"]))) else { return };
            let mut patch = json!({});
            if let Some(st) = time {
                patch["slot"] = json!({"s": st, "e": cr::add_min(&st, 60)});
            }
            let rr = sputnik_core::reminders::default_rule(app.settings());
            if !rr.is_null() {
                patch["remind"] = rr;
            }
            app.add_task(&dest, &title, Some(&day), patch, None, "");
            app.say(format!("Задача на {} → {}", sputnik_core::calendar::when_label(&day), app.list_name(&dest)));
        }
        u.add_time.clear();
    }));
    g.on_cal_drop(|l, id, d, y| act(|app, u| {
        let Some(t) = task_of(app, &l, &id) else { return };
        if y < 0.0 {
            app.schedule(&l, &t, &d, Value::Null);
            return;
        }
        let slot = &app.lt(&id)["slot"];
        let len = match (slot["s"].as_str(), slot["e"].as_str()) {
            (Some(a0), Some(b0)) => (cr::to_min(b0) - cr::to_min(a0)).max(15),
            _ => 60,
        };
        let m = super::calendar::min_at(app, u, y as f64);
        let st = sputnik_core::calendar::from_min(m);
        let en = sputnik_core::calendar::from_min((m + len).min(1439));
        app.schedule(&l, &t, &d, json!({"s": st, "e": en}));
    }));
    g.on_open_event(|id| act(|app, _| {
        let (cal, eid) = id.split_once('|').unwrap_or(("", id.as_str()));
        if let Some(e) = app.events.iter().find(|e| e["id"] == eid && (cal.is_empty() || e["calId"] == cal)) {
            if let Some(link) = e["htmlLink"].as_str() {
                let _ = open::that(link);
            }
        }
    }));

    // ---------- Привычки ----------
    g.on_habit_pick(|id| act(|_, u| u.habit_sel = str_(&id)));
    g.on_habit_new(|| act(|_, u| u.create = Some(Create { kind: 2, ..Default::default() })));
    g.on_habit_all(|| act(|app, _| {
        let d = today_s();
        for h in app.habits() {
            if hb::scheduled_on(&h, app.habit_log(), &d) && !hb::is_done(app.habit_log(), &h["id"], &d) && hb::goal_n(&h) <= 1 {
                app.toggle_habit(&h);
            }
        }
    }));
    g.on_habit_mode_set(|m| act(|_, u| u.habit_mode = str_(&m)));
    g.on_habit_part(|p| act(|_, u| u.habit_part = str_(&p)));
    g.on_habit_cell(|id, day| act(|app, _| {
        let Some(h) = habit_by(app, &id) else { return };
        let nd = hb::now().date();
        let d = format!("{}{:02}", &sputnik_core::dates::ymd(nd)[..8], day);
        if d > today_s() {
            return;
        }
        let st = hb::day_state(&h, app.habit_log(), &d, None);
        let next = match st { "d" => "skip", "k" => "none", _ => "done" };
        app.set_habit_day(&h, &d, next);
    }));
    g.on_habit_day_set(|id, day, st| act(|app, _| {
        let Some(h) = habit_by(app, &id) else { return };
        let nd = hb::now().date();
        let d = format!("{}{:02}", &sputnik_core::dates::ymd(nd)[..8], day);
        if d > today_s() {
            return;
        }
        app.set_habit_day(&h, &d, &str_(&st));
    }));
    g.on_habit_add(|t| act(|app, _| add_habit(app, &t)));
    g.on_habit_remove(|id| act(|app, u| {
        let Some(h) = habit_by(app, &id) else { return };
        let id = text(&h["id"]);
        ask(u, format!("Удалить привычку «{}»? История отметок тоже пропадёт.", text(&h["name"])), "Удалить", move |app, _| app.remove_habit(&id));
    }));

    // ---------- Окно задачи ----------
    fn cur(u: &Ui) -> Option<(String, String)> {
        u.task.clone()
    }
    g.on_t_close(|| act(|_, u| u.task = None));
    g.on_t_title_set(|t| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        if let Some(tk) = task_of(app, &l, &id) {
            if !t.trim().is_empty() && tk["title"] != t.as_str() {
                app.rename(&l, &tk, &t);
            }
        }
    }));
    g.on_t_notes_set(|t| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        if let Some(tk) = task_of(app, &l, &id) {
            app.set_notes(&l, &tk, &t);
        }
    }));
    g.on_t_col(|c| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        if let Some(tk) = task_of(app, &l, &id) {
            app.set_stage(&l, &tk, &c);
        }
    }));
    g.on_t_prio_set(|p| act(|app, u| {
        let Some((_, id)) = cur(u) else { return };
        app.set_priority(&id, if p == 0 { None } else { Some(p as i64) });
    }));
    g.on_dp_open_task(|| act(|app, u| {
        if let Some((l, id)) = cur(u) { u.dp = super::datetime::open(app, &l, &id); }
    }));
    g.on_dp_words(|t| act(|_, u| if let Some(d) = u.dp.as_mut() { super::datetime::words(d, &t) }));
    g.on_dp_day(|t| act(|_, u| if let Some(d) = u.dp.as_mut() {
        d.day = chrono::NaiveDate::parse_from_str(&t, "%Y-%m-%d").ok();
        if let Some(x) = d.day { d.month = chrono::Datelike::with_day(&x, 1).unwrap_or(x); }
    }));
    g.on_dp_quick_set(|q| act(|_, u| if let Some(d) = u.dp.as_mut() {
        let t = sputnik_core::habits::now().date();
        use chrono::Datelike;
        d.day = match q.as_str() {
            "today" => Some(t),
            "tomorrow" => Some(t + chrono::Duration::days(1)),
            "weekend" => Some(t + chrono::Duration::days(((5 - t.weekday().num_days_from_monday() as i64) + 7) % 7)),
            "week" => Some(t + chrono::Duration::days(7)),
            _ => { d.hour = None; None }
        };
        if let Some(x) = d.day { d.month = x.with_day(1).unwrap_or(x); }
    }));
    g.on_dp_month_step(|k| act(|_, u| if let Some(d) = u.dp.as_mut() {
        use chrono::Datelike;
        let (y, m) = (d.month.year(), d.month.month0() as i32 + k);
        let (y, m) = (y + m.div_euclid(12), m.rem_euclid(12) as u32 + 1);
        if let Some(x) = chrono::NaiveDate::from_ymd_opt(y, m, 1) { d.month = x; }
    }));
    g.on_dp_hour_set(|h| act(|_, u| if let Some(d) = u.dp.as_mut() {
        d.hour = if d.hour == Some(h as u32) { None } else { Some(h as u32) };
        if d.day.is_none() { d.day = Some(sputnik_core::habits::now().date()); }
    }));
    g.on_dp_min_set(|m| act(|_, u| if let Some(d) = u.dp.as_mut() {
        d.min = m as u32;
        if d.hour.is_none() { d.hour = Some(10); }
    }));
    g.on_dp_exact_set(|t| act(|_, u| if let Some(d) = u.dp.as_mut() {
        let t = t.trim().replace('.', ":");
        if let Some((a0, b0)) = t.split_once(':') {
            if let (Ok(h), Ok(m)) = (a0.parse::<u32>(), b0.parse::<u32>()) {
                if h < 24 && m < 60 { d.hour = Some(h); d.min = m; if d.day.is_none() { d.day = Some(sputnik_core::habits::now().date()); } }
            }
        }
    }));
    g.on_dp_dur_set(|m| act(|_, u| if let Some(d) = u.dp.as_mut() { d.dur = m as i64 }));
    g.on_dp_done(|| act(|app, u| {
        if let Some(d) = u.dp.take() {
            if d.for_create {
                if let Some(c) = u.create.as_mut() { c.m.when = Some(super::datetime::picked(&d)); }
            } else {
                super::datetime::apply(app, &d);
            }
        }
    }));
    g.on_dp_cancel(|| act(|_, u| u.dp = None));
    g.on_ls_show(|| act(|_, u| u.ls = true));
    g.on_tp_show(|| act(|app, u| u.tp = Some(super::tpl::open(app, &sputnik_core::j::text(&sputnik_core::templates::board_of(&u.board, &app.layer)["id"])))));
    g.on_tp_close(|| act(|_, u| u.tp = None));
    g.on_tp_pick(|id| act(|app, u| u.tp = Some(super::tpl::open(app, &id))));
    g.on_tp_set(|k, v| act(|_, u| super::tpl::set(u, &k, &v)));
    g.on_tp_col(|i, k, v| act(|_, u| super::tpl::col(u, i, &k, &v)));
    g.on_tp_save(|| act(|app, u| super::tpl::save(app, u)));
    g.on_tp_new(|| act(|_, u| super::tpl::new(u)));
    g.on_tp_dup(|| act(|_, u| super::tpl::dup(u)));
    g.on_tp_reset(|| act(|app, u| super::tpl::reset(app, u)));
    g.on_ls_close(|| act(|_, u| u.ls = false));
    g.on_menu_ctx(|k, id, x, y| act(|_, u| u.menu = Some(super::menu::Menu { kind: str_(&k), id: str_(&id), x, y, sub: String::new() })));
    g.on_menu_close(|| act(|_, u| u.menu = None));
    g.on_menu_pick(|id| act(|app, u| super::menu::pick(app, u, &id)));
    g.on_ls_set(|k, v| act(|app, u| super::listset::set(app, u, &k, &v)));
    g.on_t_due_set(|t| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        let Some(tk) = task_of(app, &l, &id) else { return };
        if t.trim().is_empty() {
            app.set_due(&l, &tk, None);
            app.set_task(&id, json!({"slot": null}));
            return;
        }
        let w = when::parse_when(&t, hb::now().date());
        match (w.day, w.time) {
            (day, Some(tm)) => {
                let day = day.unwrap_or_else(today_s);
                let old = &app.lt(&id)["slot"];
                let len = match (old["s"].as_str(), old["e"].as_str()) { (Some(a0), Some(b0)) => (cr::to_min(b0) - cr::to_min(a0)).max(15), _ => 60 };
                let en = cr::add_min(&tm, len);
                app.schedule(&l, &tk, &day, json!({"s": tm, "e": en}));
            }
            (Some(day), None) => app.schedule(&l, &tk, &day, if w.all_day { Value::Null } else { app.lt(&id)["slot"].clone() }),
            (None, None) => app.say("Не понял срок — напиши «завтра», «пт 15:00» или «25.11»"),
        }
    }));
    g.on_t_sub_add(|t| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        app.add_subtask(&l, &id, &t);
    }));
    g.on_t_sub_toggle(|sid| act(|app, u| {
        let Some((l, _)) = cur(u) else { return };
        if let Some(tk) = task_of(app, &l, &sid) {
            app.toggle_done(&l, &tk);
        }
    }));
    g.on_t_remind(|m| act(|app, u| {
        let Some((_, id)) = cur(u) else { return };
        let m: i64 = m.parse().unwrap_or(60);
        let mut mins = lead_mins(&app.lt(&id)["remind"]);
        if let Some(i) = mins.iter().position(|x| *x == m) { mins.remove(i); } else { mins.push(m); }
        let r = sputnik_core::reminders::mins_to_rule(&mins.iter().map(|x| json!(x)).collect::<Vec<_>>());
        app.set_task(&id, json!({"remind": r}));
    }));
    g.on_t_repeat(|e| act(|app, u| {
        let Some((_, id)) = cur(u) else { return };
        app.set_task(&id, json!({"repeat": if e.is_empty() { Value::Null } else { json!({"every": str_(&e)}) }}));
    }));
    g.on_t_move(|to| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        if to.as_str() == l {
            return;
        }
        if let Some(tk) = task_of(app, &l, &id) {
            if let Some(nid) = app.move_to_list(&l, &tk, &to) {
                u.task = Some((str_(&to), nid));
                app.say(format!("Перенесено в «{}»", app.list_name(&to)));
            }
        }
    }));
    g.on_t_delete(|| act(|app, u| {
        let Some((l, id)) = u.task.take() else { return };
        if let Some(tk) = task_of(app, &l, &id) {
            app.remove(&l, &tk);
        }
    }));
    g.on_t_dup(|| act(|app, u| {
        let Some((l, id)) = cur(u) else { return };
        if let Some(tk) = task_of(app, &l, &id) {
            app.duplicate(&l, &tk);
        }
    }));

    // ---------- Создать ----------
    g.on_create(|t| act(|_, u| {
        let kind = if u.tab == 3 { 2 } else { 0 };
        u.create = Some(Create { text: str_(&t), kind, ..Default::default() });
    }));
    g.on_c_close(|| act(|_, u| u.create = None));
    g.on_c_changed(|t| act(|_, u| if let Some(c) = u.create.as_mut() { c.text = str_(&t) }));
    g.on_c_tok_off(|k| act(|_, u| if let Some(c) = u.create.as_mut() {
        let k = str_(&k);
        // «×» у срока, приоритета, повтора: сначала снимаем выбранное кнопкой, потом возвращаем кусок в название
        let manual = match k.as_str() { "when" => c.m.when.take().is_some(), "prio" => c.m.prio.take().is_some(), "repeat" => c.m.repeat.take().is_some(), _ => false };
        if !manual && !c.m.off.contains(&k) { c.m.off.push(k); }
    }));
    g.on_c_quick_set(|id| act(|_, u| if let Some(c) = u.create.as_mut() {
        let x = super::dialogs::resolved(c);
        c.m.when = sputnik_core::compose::pick_quick(&id, &x["slot"], sputnik_core::habits::now().date());
    }));
    g.on_c_pick_date(|| act(|_, u| if let Some(c) = u.create.as_ref() {
        let x = super::dialogs::resolved(c);
        u.dp = Some(super::datetime::for_create(&x, c.kind));
    }));
    g.on_c_prio_set(|n| act(|_, u| if let Some(c) = u.create.as_mut() { c.m.prio = Some(n as i64) }));
    g.on_c_rep_set(|r| act(|_, u| if let Some(c) = u.create.as_mut() {
        c.m.repeat = Some(if r.is_empty() { Value::Null } else { json!({"every": str_(&r)}) });
    }));
    g.on_c_notes_set(|t| act(|_, u| if let Some(c) = u.create.as_mut() { c.notes = str_(&t) }));
    g.on_c_kind_set(|k| act(|_, u| if let Some(c) = u.create.as_mut() { c.kind = k; c.remind = None; c.popen.clear(); }));
    g.on_c_dest_set(|d| act(|_, u| if let Some(c) = u.create.as_mut() { c.dest = Some(str_(&d)) }));
    g.on_c_cal_set(|d| act(|_, u| if let Some(c) = u.create.as_mut() { c.cal = Some(str_(&d)) }));
    g.on_c_dur_set(|d| act(|_, u| if let Some(c) = u.create.as_mut() {
        c.dur = d.parse().unwrap_or(60);
        // время выбрано кнопкой — конец сдвигается вместе с длительностью
        if let Some(w) = c.m.when.as_mut() {
            if let Some((st, en)) = w.slot.as_mut() { if c.dur > 0 { *en = sputnik_core::create::add_min(st, c.dur); } }
        }
    }));
    g.on_c_remind(|m| act(|app, u| {
        let Some(c) = u.create.as_mut() else { return };
        let m: i64 = m.parse().unwrap_or(0);
        let mut mins = c.remind.clone().unwrap_or_else(|| default_mins(app, c.kind));
        if let Some(i) = mins.iter().position(|x| *x == m) { mins.remove(i); } else { mins.push(m); }
        c.remind = Some(mins);
    }));
    g.on_c_time_set(|t| act(|_, u| if let Some(c) = u.create.as_mut() {
        let x = super::dialogs::resolved(c);
        let t = str_(&t);
        let day = x["day"].as_str().map(|d| d.to_string()).or_else(|| (!t.is_empty()).then(today_s));
        c.m.when = Some(sputnik_core::compose::Picked { day, slot: (!t.is_empty()).then(|| (t.clone(), t)) });
    }));
    g.on_c_strip_set(|d| act(|_, u| if let Some(c) = u.create.as_mut() {
        let x = super::dialogs::resolved(c);
        let slot = x["slot"]["s"].as_str().map(|st| (st.to_string(), x["slot"]["e"].as_str().unwrap_or(st).to_string()));
        c.m.when = Some(sputnik_core::compose::Picked { day: Some(str_(&d)), slot });
        c.cal_step = 0;
    }));
    g.on_c_cal_step(|k| act(|_, u| if let Some(c) = u.create.as_mut() { c.cal_step += k }));
    g.on_c_prop(|k| act(|_, u| if let Some(c) = u.create.as_mut() {
        let k = str_(&k);
        c.popen = if c.popen == k || ["color", "image", "who"].contains(&k.as_str()) { String::new() } else { k };
    }));
    g.on_c_prop_set(|k, v| act(|app, u| {
        let Some(c) = u.create.as_mut() else { return };
        let v = str_(&v);
        match k.as_str() {
            "list" => { c.dest = Some(v); c.col = None; }
            "col" => c.col = Some(v),
            "cal" => c.cal = Some(v),
            "prio" => c.m.prio = Some(v.parse().unwrap_or(0)),
            "repeat" => c.m.repeat = Some(if v.is_empty() { Value::Null } else { json!({"every": v}) }),
            "remind" => {
                let m: i64 = v.parse().unwrap_or(0);
                let mut mins = c.remind.clone().unwrap_or_else(|| default_mins(app, c.kind));
                if let Some(i) = mins.iter().position(|x| *x == m) { mins.remove(i); } else { mins.push(m); }
                c.remind = Some(mins);
                return; // несколько напоминаний — список остаётся открытым
            }
            _ => {}
        }
        c.popen.clear();
    }));
    // ---------- Окно «Создать»: событие / привычка / день рождения ----------
    g.on_c_place_set(|t| act(|_, u| if let Some(c) = u.create.as_mut() { c.place = str_(&t) }));
    g.on_c_year_set(|t| act(|_, u| if let Some(c) = u.create.as_mut() { c.year = str_(&t) }));
    g.on_c_gift_set(|n| act(|_, u| if let Some(c) = u.create.as_mut() {
        c.gift = Some(str_(&n).parse().unwrap_or(7));
    }));
    g.on_c_hfreq_set(|k| act(|_, u| if let Some(c) = u.create.as_mut() {
        let f = cr::habit_freq_of(&cr::parse_habit(&c.text, &c.m.off_json()), &c.hfreq);
        c.hfreq = match k.as_str() {
            "weekdays" => json!({"freq": "days", "days": [0, 1, 2, 3, 4]}),
            "days" => json!({"freq": "days", "days": if matches!(s(&f["kind"]), "days" | "weekdays") { f["days"].clone() } else { json!([0, 1, 2, 3, 4]) }}),
            "week" => json!({"freq": "week", "perWeek": if s(&f["kind"]) == "week" { f["perWeek"].as_i64().unwrap_or(3).max(2) } else { 3 }}),
            _ => json!({"freq": "daily"}),
        };
    }));
    g.on_c_hday(|i| act(|_, u| if let Some(c) = u.create.as_mut() {
        let f = cr::habit_freq_of(&cr::parse_habit(&c.text, &c.m.off_json()), &c.hfreq);
        let mut d: Vec<i64> = if matches!(s(&f["kind"]), "days" | "weekdays") {
            f["days"].as_array().map(|a| a.iter().filter_map(|x| x.as_i64()).collect()).unwrap_or_default()
        } else {
            vec![0, 1, 2, 3, 4]
        };
        match d.iter().position(|x| *x == i as i64) {
            Some(p) if d.len() > 1 => { d.remove(p); }
            Some(_) => {}
            None => { d.push(i as i64); d.sort_unstable(); }
        }
        c.hfreq = json!({"freq": "days", "days": d});
    }));
    g.on_c_hper_set(|n| act(|_, u| if let Some(c) = u.create.as_mut() {
        c.hfreq = json!({"freq": "week", "perWeek": str_(&n).parse::<i64>().unwrap_or(3).clamp(1, 6)});
    }));
    g.on_c_hpart_set(|p| act(|_, u| if let Some(c) = u.create.as_mut() {
        c.hpart = str_(&p);
        c.hwin = None; // часть дня сбрасывает своё окно
    }));
    g.on_c_hwin_s_set(|t| act(|_, u| if let Some(c) = u.create.as_mut() {
        let (_, en) = habit_win_base(c);
        let st = str_(&t);
        // конец раньше начала — пододвигаем: окно не короче часа
        let en = if cr::to_min(&en) <= cr::to_min(&st) { cr::from_min((cr::to_min(&st) + 60).min(1439)) } else { en };
        c.hwin = Some((st, en));
    }));
    g.on_c_hwin_e_set(|t| act(|_, u| if let Some(c) = u.create.as_mut() {
        let (st, _) = habit_win_base(c);
        let en = str_(&t);
        let st = if cr::to_min(&st) >= cr::to_min(&en) { cr::from_min((cr::to_min(&en) - 60).max(0)) } else { st };
        c.hwin = Some((st, en));
    }));
    g.on_c_hicon(|t| act(|_, u| if let Some(c) = u.create.as_mut() {
        let t = str_(&t);
        c.hicon = if c.hicon == t { String::new() } else { t };
    }));
    g.on_c_sub_add(|t| act(|_, u| if let Some(c) = u.create.as_mut() {
        let t = str_(&t);
        if !t.trim().is_empty() { c.subs.push(t.trim().to_string()); }
    }));
    g.on_c_sub_del(|i| act(|_, u| if let Some(c) = u.create.as_mut() {
        if (i as usize) < c.subs.len() { c.subs.remove(i as usize); }
    }));
    g.on_c_submit(|t, more| act(|app, u| {
        let Some(mut c) = u.create.clone() else { return };
        c.text = str_(&t);
        if submit(app, &c) {
            if more {
                // «и ещё»: список и срок остаются, остальное — с чистого листа
                c.text.clear();
                c.notes.clear();
                c.subs.clear();
                c.popen.clear();
                c.place.clear();
                c.year.clear();
                c.hfreq = Value::Null;
                c.hpart.clear();
                c.hwin = None;
                c.hicon.clear();
                c.gift = None;
                let when = c.m.when.take();
                c.m = Default::default();
                c.m.when = when;
                u.create = Some(c);
            } else {
                u.create = None;
            }
        }
    }));

    // ---------- Поиск ----------
    g.on_search_open_set(|b| act(|_, u| {
        u.search = if b { Some(String::new()) } else { None };
        u.found.clear();
    }));
    g.on_search(|q| act(|app, u| {
        u.search = Some(str_(&q));
        u.found = find(app, &q);
    }));
    g.on_search_go(|i| act(|app, u| {
        let found = std::mem::take(&mut u.found);
        if let Some(x) = found.get(i.max(0) as usize) {
            u.search = None;
            (x.1)(app, u);
        }
    }));

    // ---------- Настройки ----------
    g.on_set_toggle(|sec, id| act(|app, _| {
        let id = str_(&id);
        match sec.as_str() {
            "start" => app.set_setting("start", json!(id)),
            // «Куда слать»: notify — Windows, tgRemind — Telegram
            "flag" if id == "notify" || id == "tgRemind" => {
                let on = app.layer["settings"][id.as_str()]["v"] != false;
                app.set_setting(&id, json!(!on));
                if id == "tgRemind" {
                    app.bot_sync();
                }
            }
            "list" => {
                let hid = app.ll(&id)["hidden"] == true;
                app.set_list_field(&id, json!({"hidden": !hid}));
            }
            "cal" => {
                let shown = app.calendars.iter().find(|c| c["id"] == id.as_str()).map(|c| app.cal_shown(c)).unwrap_or(true);
                app.touch("cals", &id, json!({"hidden": shown}));
                app.refresh();
            }
            s if s == "remind" || s.starts_with("remind-") => {
                let kind = if s == "remind" { "task" } else { &s["remind-".len()..] };
                let m: i64 = id.parse().unwrap_or(60);
                let mut r = app.layer["settings"]["remind"].clone();
                if !r.is_object() {
                    r = json!({});
                }
                let cur: Vec<i64> = a(&sputnik_core::reminders::default_mins(&app.layer["settings"], kind)).iter().filter_map(|x| x.as_i64()).collect();
                r[kind] = json!(sputnik_core::reminders::toggle_min(&cur, m));
                r.as_object_mut().unwrap().shift_remove("t");
                app.touch("settings", "remind", r);
            }
            "hour" => {
                app.set_setting("remindHour", json!(id));
                sputnik_core::reminders::set_default_time(Some(&id));
            }
            _ => {}
        }
    }));
    // акцент и анимации применяются сразу к токенам G и сохраняются
    let ww = w.as_weak();
    g.on_accent_set(move |id| {
        let i: i64 = id.parse().unwrap_or(0);
        act(|app, _| app.set_setting("accent", json!(i)));
        if let Some(w) = ww.upgrade() { settings::apply_accent(&w, i); }
    });
    let ww = w.as_weak();
    g.on_anim_set(move |id| {
        let i: i64 = id.parse().unwrap_or(0);
        act(|app, _| app.set_setting("anim", json!(i)));
        if let Some(w) = ww.upgrade() { settings::apply_anim(&w, i); }
    });
    g.on_tab_move(|from, to| act(|app, _| {
        let mut v = settings::tab_order(app);
        if from >= 0 && to >= 0 && (from as usize) < v.len() && (to as usize) < v.len() {
            let x = v.remove(from as usize);
            v.insert(to as usize, x);
            app.set_setting("tabOrder", json!(v));
        }
    }));
    g.on_set_find(|q| act(|_, u| u.set_q = str_(&q)));
    g.on_bot_link(|c| act(|app, _| app.bot_link(&c)));
    g.on_bot_test(|| act(|app, _| app.bot_test()));
    g.on_bot_unlink(|| act(|app, u| ask(u, "Отключить Telegram? Напоминания перестанут приходить.", "Отключить", |app, _| app.bot_unlink())));
    g.on_sign_out(|| act(|_, u| ask(u, "Выйти из Google на этом компьютере? Правки, которые ещё не ушли, останутся в очереди.", "Выйти", |app, _| app.sign_out())));
    g.on_open_backups(|| act(|_, _| {
        let _ = open::that(crate::data::store::own("backups"));
    }));
    g.on_notes_root_set(|p| act(|app, u| {
        let p = p.trim().to_string();
        set_notes_root(app, u, if p.is_empty() { None } else { Some(p) });
    }));


    // ---------- Знания ----------
    g.on_note_search(|q| act(|_, u| u.note_q = str_(&q)));
    g.on_note_open(|p| act(|app, u| open_note_tab(app, u, &str_(&p))));
    g.on_upd_check(|| act(|app, _| app.update_check(true)));
    g.on_upd_install(|| act(|app, _| app.update_install()));
    g.on_upd_later(|| act(|app, _| app.update.version.clear()));
    g.on_note_graph_set(|v| act(|_, u| u.note_graph = v));
    g.on_note_tab_open(|p| act(|app, u| open_note_tab(app, u, &str_(&p))));
    g.on_note_tab_close(|p| act(|app, u| {
        let p = str_(&p);
        if u.note_path == p {
            save_draft(app, u);
        }
        u.note_tabs.retain(|t| t != &p);
        if u.note_path == p {
            u.note_path = u.note_tabs.last().cloned().unwrap_or_default();
            u.note_dirty = false;
        }
    }));
    g.on_note_line_set(|i, t| act(|app, u| note_set_lines(app, u, i as usize, &str_(&t), 1)));
    g.on_note_commit(|| act(|app, u| save_draft(app, u)));
    g.on_note_line_split(|i, t, at| {
        let mut caret = 0;
        act(|app, u| {
            let t = str_(&t);
            let at = (at.max(0) as usize).min(t.len());
            let at = (0..=at).rev().find(|k| t.is_char_boundary(*k)).unwrap_or(0);
            let (a, b) = t.split_at(at);
            // список продолжается: «- », «- [ ] », «> », «1. »
            let lead = a.trim_start();
            let pre = if lead.starts_with("- [") { "- [ ] " } else if lead.starts_with("- ") { "- " } else if lead.starts_with("* ") { "* " } else if lead.starts_with("> ") { "> " } else { "" };
            let empty_item = !pre.is_empty() && a.trim() == pre.trim() && b.trim().is_empty();
            if empty_item {
                // Enter на пустом пункте — пункт кончается
                note_set_lines(app, u, i as usize, "", 1);
                caret = 0;
            } else {
                note_set_lines(app, u, i as usize, &format!("{a}\n{pre}{}", b.trim_start()), 1);
                caret = pre.len() as i32;
            }
        });
        caret
    });
    g.on_note_line_join(|i| {
        let mut caret = 0;
        act(|app, u| {
            if i <= 0 { return; }
            let body = note_text(app, u);
            let ls = crate::notes::line_blocks(&body);
            let (Some(p), Some(c)) = (ls.get(i as usize - 1), ls.get(i as usize)) else { return };
            caret = p.1.len() as i32;
            note_set_lines(app, u, i as usize - 1, &format!("{}{}", p.1, c.1), 2);
        });
        caret
    });
    g.on_notes_pick(|| act(|app, u| {
        if let Some(dir) = rfd::FileDialog::new().set_title("Папка заметок").pick_folder() {
            set_notes_root(app, u, Some(dir.to_string_lossy().to_string()));
        }
    }));

    g.on_graph_open(|p, t| act(|app, u| {
        u.note_graph = false;
        if p.is_empty() { new_note(app, u, &t) } else { open_note_tab(app, u, &str_(&p)); }
    }));
    g.on_note_edited(|t| act(|_, u| {
        u.note_dirty = true;
        u.note_draft = str_(&t);
    }));
    g.on_note_save(|b| act(|app, u| {
        let p = u.note_path.clone();
        match app.notes.save(&p, &b) {
            Ok(()) => {
                u.note_dirty = false;
                app.say("Заметка сохранена");
            }
            Err(e) => app.say(format!("Не сохранилось: {e}")),
        }
    }));
    g.on_note_new(|t| act(|app, u| new_note(app, u, &t)));
    g.on_note_link(|t| act(|app, u| {
        match app.notes.find(&t).map(|n0| n0.path.clone()) {
            Some(p) => open_note_tab(app, u, &p),
            None => new_note(app, u, &t),
        }
    }));
}

/// Несохранённую правку текущей заметки — сохранить, прежде чем уйти с неё (на другую вкладку,
/// заметку из списка, по ссылке). Иначе правка терялась или, хуже, текст одной заметки попадал в другую.
/// Текст заметки с учётом несохранённой правки.
fn note_text(app: &App, u: &Ui) -> String {
    if u.note_dirty { return u.note_draft.clone(); }
    app.notes.notes.iter().find(|x| x.path == u.note_path).map(|x| x.body.clone()).unwrap_or_default()
}

/// Заменить `drop` строк тела, начиная с `i`, на `t` (строки через \n). Пишет в черновик.
fn note_set_lines(app: &App, u: &mut Ui, i: usize, t: &str, drop: usize) {
    if u.note_path.is_empty() { return; }
    let base = note_text(app, u);
    let parts: Vec<&str> = t.split('\n').collect();
    let new = crate::notes::replace_line(&base, i, &parts, drop);
    if new != base {
        u.note_draft = new;
        u.note_dirty = true;
    }
}

pub(super) fn save_draft(app: &mut App, u: &mut Ui) {
    if !u.note_dirty || u.note_path.is_empty() {
        return;
    }
    match app.notes.save(&u.note_path, &u.note_draft) {
        Ok(()) => u.note_dirty = false,
        Err(e) => app.say(format!("Не сохранилось: {e}")),
    }
}

/// Сменить папку заметок: вкладки прежней папки закрываются.
fn set_notes_root(app: &mut App, u: &mut Ui, p: Option<String>) {
    save_draft(app, u);
    app.notes.root = p.as_ref().map(std::path::PathBuf::from);
    let _ = crate::data::store::write_json("notes.json", &json!({"root": p.unwrap_or_default()}));
    app.notes.rescan();
    app.notes.watch();
    u.note_tabs.clear();
    u.note_path.clear();
    u.note_dirty = false;
    app.say(format!("Заметок в папке: {}", app.notes.notes.len()));
}

/// Открыть заметку вкладкой: запоминает в списке открытых и делает активной.
pub(super) fn open_note_tab(app: &mut App, u: &mut Ui, path: &str) {
    if path == u.note_path {
        return;
    }
    save_draft(app, u);
    if u.note_dirty {
        return; // не сохранилось — остаёмся на заметке, чтобы правка не пропала
    }
    if !path.is_empty() && !u.note_tabs.iter().any(|t| t == path) {
        u.note_tabs.push(path.to_string());
    }
    u.note_path = path.to_string();
    u.note_dirty = false;
}

fn new_note(app: &mut App, u: &mut Ui, title: &str) {
    let name: String = title.chars().filter(|c| !"/\\:*?\"<>|".contains(*c)).collect();
    if app.notes.root.is_none() {
        app.notes.root = Some(crate::data::store::own("notes"));
        let _ = std::fs::create_dir_all(crate::data::store::own("notes"));
        app.notes.watch();
    }
    // такой файл уже есть (дважды «+» → «Новая заметка») — не затирать, а взять «Имя 2», «Имя 3»…
    let root = app.notes.root.clone().unwrap_or_default();
    let path = crate::notes::free_name(name.trim(), |p| root.join(p).exists());
    match app.notes.save(&path, &format!("# {}\n\n", title.trim())) {
        Ok(()) => {
            open_note_tab(app, u, &path);
        }
        Err(e) => app.say(format!("Заметка не создалась: {e}")),
    }
}

/// Окно времени привычки для полей «с … до …»: своё → окно выбранной части дня → из строки → 07:00–09:00.
fn habit_win_base(c: &Create) -> (String, String) {
    if let Some(w) = &c.hwin {
        return w.clone();
    }
    let part = if c.hpart.is_empty() { text(&cr::parse_habit(&c.text, &c.m.off_json())["part"]) } else { c.hpart.clone() };
    let w = hb::part_win(&json!(part));
    match (w["s"].as_str(), w["e"].as_str()) {
        (Some(a), Some(b)) => (a.to_string(), b.to_string()),
        _ => ("07:00".into(), "09:00".into()),
    }
}

fn add_habit(app: &mut App, t: &str) {
    let h = cr::parse_habit(t, &json!({}));
    let name = text(&h["name"]);
    if name.trim().is_empty() {
        return;
    }
    let mut f = json!({});
    match s(&h["freq"]) {
        "week" => {
            f["days"] = json!([0, 1, 2, 3, 4, 5, 6]);
            f["perWeek"] = h["perWeek"].clone();
        }
        "days" => f["days"] = h["days"].clone(),
        _ => f["days"] = json!([0, 1, 2, 3, 4, 5, 6]),
    }
    if !h["part"].is_null() {
        f["part"] = h["part"].clone();
    }
    if !h["goal"].is_null() {
        f["goal"] = h["goal"].clone();
    }
    app.add_habit(name.clone(), f, "");
    app.say(format!("Привычка «{name}» заведена"));
}

/// Создать по виду окна. false — не получилось (окно остаётся).
fn submit(app: &mut App, c: &Create) -> bool {
    let mins = c.remind.clone().unwrap_or_else(|| default_mins(app, c.kind));
    if c.kind == 2 {
        let h = cr::parse_habit(&c.text, &c.m.off_json());
        let name = text(&h["name"]);
        if name.trim().is_empty() {
            app.say("Напиши название");
            return false;
        }
        let win = c.hwin.clone().map(|(a, b)| json!({ "s": a, "e": b })).unwrap_or(Value::Null);
        let f = cr::habit_fields(&h, &c.hfreq, &c.hpart, &win, &c.hicon);
        app.add_habit(name.clone(), f, c.notes.trim());
        app.say(format!("Привычка «{name}» заведена"));
        return true;
    }
    let x = super::dialogs::resolved(c);
    let title = text(&x["title"]);
    if title.trim().is_empty() {
        app.say(if c.kind == 3 { "Нужно имя: «Мама 12 марта»" } else { "Напиши название" });
        return false;
    }
    let slot = x["slot"]["s"].as_str().map(|st| (st.to_string(), x["slot"]["e"].as_str().unwrap_or(st).to_string()));
    match c.kind {
        3 => {
            let Some(day) = x["day"].as_str() else {
                app.say("Нужна дата: «Мама 12 марта» или кнопка «Выбрать…»");
                return false;
            };
            let cal = cal_of(app, c);
            app.create_birthday(&title, day, cr::bday_year(&c.year), &mins, &cal, c.gift.unwrap_or(7), None);
            true
        }
        1 => {
            let day = text(&x["day"]);
            let cal = cal_of(app, c);
            let rec = if x["repeat"].is_object() { cr::recurrence_of(&x["repeat"]) } else { Value::Null };
            app.create_event(&title, &day, slot.filter(|_| c.dur >= 0), c.notes.trim(), &mins, &cal, c.place.trim(), rec);
            true
        }
        _ => {
            let (dest, _) = dest_of(app, c);
            if dest.is_empty() {
                app.say("Сначала создай список на «Доске»");
                return false;
            }
            let p = &x["parsed"];
            let tdy = today_s();
            let from = td::task_from(p, &tdy, &dest, &json!({}));
            let mut patch = if from["layer"].is_object() { from["layer"].clone() } else { json!({}) };
            // приоритет и повтор — итоговые (кнопки главнее текста)
            match x["priority"].as_i64().filter(|p| *p > 0) { Some(pr) => patch["priority"] = json!(pr), None => { patch.as_object_mut().map(|o| o.remove("priority")); } }
            match &x["repeat"] { r if r.is_object() => patch["repeat"] = r.clone(), _ => { patch.as_object_mut().map(|o| o.remove("repeat")); } }
            if x["slot"].is_object() {
                patch["slot"] = x["slot"].clone();
            }
            let due = x["day"].as_str();
            if due.is_some() {
                let r = sputnik_core::reminders::mins_to_rule(&mins.iter().map(|m| json!(m)).collect::<Vec<_>>());
                if !r.is_null() {
                    patch["remind"] = r;
                }
            }
            let col = c.col.clone().filter(|k| app.columns(&dest).first().is_some_and(|f| f.0["id"] != k.as_str()));
            let t0 = app.add_task(&dest, &title, due, patch, col.as_deref(), c.notes.trim());
            for st in &c.subs {
                app.add_subtask(&dest, s(&t0["id"]), st);
            }
            if c.dest.is_some() {
                app.learn_route(&title, &dest, &Value::Null);
            }
            let (l, id) = (dest.clone(), text(&t0["id"]));
            app.say_act(format!("Создано в «{}»", app.list_name(&dest)), "Открыть", Some(Box::new(move |_app: &mut App| {
                ui_now(|u| u.task = Some((l, id)));
            })));
            true
        }
    }
}

/// Название с подсвеченными словами запроса (ё = е, без регистра).
fn mark(title: &str, q: &str) -> slint::StyledText {
    let esc = |x: &str| x.replace('\\', "\\\\").replace(['*', '_', '[', ']', '<', '>', '`', '#'], " ");
    let low: Vec<char> = title.to_lowercase().replace('ё', "е").chars().collect();
    let chars: Vec<char> = title.chars().collect();
    let mut on = vec![false; chars.len()];
    for w in q.to_lowercase().replace('ё', "е").split_whitespace() {
        let wc: Vec<char> = w.chars().collect();
        if wc.is_empty() || wc.len() > low.len() { continue; }
        for i in 0..=low.len() - wc.len() {
            if low[i..i + wc.len()] == wc[..] { for k in i..i + wc.len() { on[k] = true; } }
        }
    }
    let mut md = String::new();
    let mut i = 0;
    while i < chars.len() {
        let st = on[i];
        let mut j = i;
        while j < chars.len() && on[j] == st { j += 1; }
        let part: String = chars[i..j].iter().collect();
        if st { md.push_str(&format!("<font color=\"#F0A04B\">**{}**</font>", esc(&part))); } else { md.push_str(&esc(&part)); }
        i = j;
    }
    slint::StyledText::from_markdown(&md).unwrap_or_else(|_| slint::StyledText::from_plain_text(title))
}

/// Поиск: разделы, списки, задачи.
pub fn find(app: &App, q: &str) -> Vec<(Found, Box<dyn Fn(&mut App, &mut Ui)>)> {
    let mut out: Vec<(Found, Box<dyn Fn(&mut App, &mut Ui)>)> = vec![];
    if q.trim().is_empty() {
        return out;
    }
    let nq = search::norm(q);
    // порядок групп по макету G_Search: задачи, заметки, разделы; head — заголовок с числом у первой в группе
    for f in search::find_tasks(q, &app.board_lists(), &app.tasks, 8) {
        let t0 = f.parent.clone().unwrap_or(f.task.clone());
        let (l, id) = (text(&f.list["id"]), text(&t0["id"]));
        let due = super::due_text(&f.task, &app.lt(s(&f.task["id"]))["slot"]).0;
        out.push((Found { kind: ss("задача"), title: ss(text(&f.task["title"])), sub: ss(text(&f.list["title"])), list_id: ss(l.clone()), id: ss(id.clone()), head: ss(""),
            mark: mark(&text(&f.task["title"]), q), hue: super::list_hue(app, &l), due: ss(due.to_lowercase()) },
            Box::new(move |_, u| u.task = Some((l.clone(), id.clone())))));
    }
    for n0 in app.notes.search(q).into_iter().take(4) {
        let p = n0.path.clone();
        let sub = super::notes::snippet(&n0.body, &n0.title);
        out.push((Found { kind: ss("заметка"), title: ss(n0.title.clone()), sub: ss(sub), list_id: ss(""), id: ss(""), head: ss(""), mark: mark(&n0.title, q), hue: color("#7C7E88"), due: ss("") },
            Box::new(move |app, u| { u.tab = 4; open_note_tab(app, u, &p); })));
    }
    for (i, name) in ["Сегодня", "Календарь", "Доска", "Привычки", "Знания", "Настройки"].iter().enumerate() {
        if search::norm(name).starts_with(&nq) {
            out.push((Found { kind: ss("раздел"), title: ss(*name), sub: ss(""), list_id: ss(""), id: ss(""), head: ss(""), mark: mark(name, q), hue: color("clay"), due: ss("") }, Box::new(move |_, u| u.tab = i as i32)));
        }
    }
    for l in app.board_lists() {
        if search::norm(s(&l["title"])).contains(&nq) {
            let id = text(&l["id"]);
            out.push((Found { kind: ss("раздел"), title: ss(format!("Доска · {}", text(&l["title"]))), sub: ss(""), list_id: ss(id.clone()), id: ss(""), head: ss(""), mark: mark(&format!("Доска · {}", text(&l["title"])), q), hue: super::list_hue(app, &id), due: ss("") },
                Box::new(move |_, u| { u.tab = 2; u.board = id.clone(); })));
        }
    }
    // заголовки групп с числом найденного
    let names = [("задача", "Задачи"), ("заметка", "В заметках"), ("раздел", "Разделы и списки")];
    for (kind, label) in names {
        let n = out.iter().filter(|(f, _)| f.kind.as_str() == kind).count();
        if let Some((f, _)) = out.iter_mut().find(|(f, _)| f.kind.as_str() == kind) {
            f.head = ss(format!("{label} · {n}"));
        }
    }
    out
}
