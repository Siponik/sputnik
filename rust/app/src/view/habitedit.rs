//! Окно правки привычки (G_HabitEdit, #193): модель для ui/habitedit.slint.
//! Правок «черновика» нет: каждое действие сразу пишется в слой (wire.rs), здесь — только чтение.
use super::today::habit_color;
use super::*;
use crate::Opt;
use sputnik_core::create as cr;
use sputnik_core::habits as hb;

/// Открытая правка привычки (id задачи-привычки в списке «Привычки»).
#[derive(Clone, Default)]
pub struct HEdit {
    pub id: String,
}

pub fn render(app: &App, u: &mut Ui, g: &S) {
    let Some(he) = u.hedit.clone() else {
        g.set_he_open(false);
        return;
    };
    let Some(h) = app.habits().into_iter().find(|h| text(&h["id"]) == he.id) else {
        // привычку удалили (или список ещё не загружен) — окно закрывается
        u.hedit = None;
        g.set_he_open(false);
        return;
    };
    let hue = habit_color(&h);
    let opt = |id: &str, label: String, on: bool| Opt { id: ss(id), label: ss(label), hint: ss(""), hue, on };
    g.set_he_open(true);
    g.set_he_name(ss(text(&h["name"])));
    g.set_he_hue(hue);
    g.set_he_streak(hb::stats(&h, app.habit_log())["streak"].as_i64().unwrap_or(0) as i32);
    let icon = s(&h["icon"]).to_string();
    g.set_he_icon(ss(icon.clone()));
    g.set_he_icons(model(cr::HABIT_ICONS.iter().map(|i| opt(*i, i.to_string(), icon == *i)).collect()));
    let fr = cr::habit_freq_of(&h, &Value::Null);
    let kind = s(&fr["kind"]);
    g.set_he_freq(model([("daily", "Каждый день"), ("weekdays", "По будням"), ("days", "Свои дни"), ("week", "N раз в неделю")].iter().map(|(k, l)| opt(*k, (*l).to_string(), kind == *k)).collect()));
    let dsel: Vec<i64> = a(&fr["days"]).iter().filter_map(|x| x.as_i64()).collect();
    g.set_he_days(model(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"].iter().enumerate().map(|(i, l)| opt("", l.to_string(), dsel.contains(&(i as i64)))).collect()));
    let per = n(&fr["perWeek"]).unwrap_or(0.0) as i64;
    g.set_he_per(model((2..=6).map(|nn| opt(&nn.to_string(), nn.to_string(), per == nn)).collect()));
    // своё окно (не совпадает с окном части дня) выключает чипы части дня
    let w = hb::habit_win(&h);
    let custom = !w.is_null() && !hb::whole_part(&w);
    let part_eff = if custom { String::new() } else { hb::part_of(&h) };
    g.set_he_part(model([("morning", "Утро"), ("day", "День"), ("evening", "Вечер"), ("any", "Любое")].iter().map(|(k, l)| opt(*k, l.to_string(), part_eff == *k)).collect()));
    g.set_he_win_s(ss(if w.is_null() { String::new() } else { s(&w["s"]).to_string() }));
    g.set_he_win_e(ss(if w.is_null() { String::new() } else { s(&w["e"]).to_string() }));
    let goal = hb::goal_n(&h);
    g.set_he_goal_n(goal as i32);
    g.set_he_goal(ss(if goal > 1 { format!("{} {}", goal, text(&h["goal"]["unit"])) } else { "Сделать".into() }));
    g.set_he_tg(h["remind"]["tg"] != false);
    g.set_he_wrem(h["remind"]["win"] != false);
    // заметка привычки — заметка её задачи в Google
    let notes = app.habit_list().and_then(|l| app.task(s(&l["id"]), &he.id).map(|t| text(&t["notes"]))).unwrap_or_default();
    g.set_he_notes(ss(notes));
}
