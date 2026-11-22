//! Сферы (G_Spheres, п.40): обзор сфер, правка выбранной, меню сферы; архив сфер и списков (G_Archive, п.41).
use super::*;
use crate::{ArchSph, MItem, SphCard, SphList, SphRow};
use sputnik_core::{spheres as sph, t};

/// Тёмная шапка ноды по цвету сферы (FILL макетов).
pub fn head(v: &str) -> Color {
    hex(match v.trim() {
        "var(--clay)" | "clay" | "accent" | "var(--type-creative)" => 0x8A5320,
        "var(--gold)" | "gold" => 0x7A6620,
        "var(--type-work)" | "work" | "blue" => 0x2F4F86,
        "var(--type-study)" | "study" | "violet" => 0x5E3F92,
        "var(--type-personal)" | "personal" | "green" => 0x2E6B3E,
        "var(--signal-done)" | "done" | "teal" => 0x2D5F6E,
        "red" => 0x8A3A2E,
        _ => 0x3D3E45,
    })
}

/// 1 сфера, 2 сферы, 5 сфер.
pub fn plural(k: usize, one: &str, few: &str, many: &str) -> String {
    format!("{k} {}", sputnik_core::habits::plural(k as i64, [one, few, many]))
}

fn since(rec: &Value) -> String {
    use chrono::TimeZone;
    n(&rec["archivedAt"]).and_then(|ms| chrono::Local.timestamp_millis_opt(ms as i64).single()).map(|d| d.format("%d.%m").to_string()).map(|d| t!("С {}", d)).unwrap_or_default()
}

fn letter(view: &str) -> &'static str {
    match view { "pipe" => t!("К"), "stickers" => t!("С"), "list" => t!("Л"), _ => t!("К") }
}

/// Списки сферы (без архивных), что видны на доске.
fn lists_of(app: &App, id: &str) -> Vec<Value> {
    app.board_lists().into_iter().filter(|l| app.sphere_of(s(&l["id"])).as_deref() == Some(id)).collect()
}

fn open_n(app: &App, l: &str) -> usize {
    app.tasks_of(l).iter().filter(|t| App::top(t) && !App::is_done(t)).count()
}

/// Все списки сферы, включая скрытые архивом, — для подписи «2 списка · 31 задач».
fn all_lists_of(app: &App, id: &str) -> Vec<String> {
    app.lists.iter().map(|l| text(&l["id"])).filter(|l| s(&app.ll(l)["sphere"]) == id).collect()
}

fn arch_rows(app: &App, q: &str) -> Vec<ArchSph> {
    let q = q.to_lowercase().replace('ё', "е");
    let hit = |t: &str| q.is_empty() || t.to_lowercase().replace('ё', "е").contains(&q);
    let mut out = vec![];
    for x in sph::archived_spheres(&app.layer) {
        let id = text(&x["id"]);
        let name = text(&x["name"]);
        if !hit(&name) { continue }
        let ls = all_lists_of(app, &id);
        let tn: usize = ls.iter().map(|l| app.tasks_of(l).iter().filter(|t| App::top(t)).count()).sum();
        let first = out.is_empty();
        out.push(ArchSph { kind: ss("sphere"), id: ss(id), name: ss(name), group: ss(t!("Сферы")), first,
            meta: ss(format!("{} · {}{}", plural(ls.len(), "список", "списка", "списков"), plural(tn, "задача", "задачи", "задач"), if first { t!(" · все внутри вернутся вместе со сферой") } else { "" })),
            date: ss(since(&x)), head: head(&sph::sphere_color(&x)), letter: ss(t!("СФ")) });
    }
    let mut lf = true;
    for l in &app.lists {
        let id = text(&l["id"]);
        let ll = app.ll(&id);
        if !sph::is_archived(ll) || ll["gone"] == true { continue }
        let name = text(&l["title"]);
        if !hit(&name) { continue }
        let sp = s(&ll["sphere"]).to_string();
        let spr = &app.layer["spheres"][&sp];
        let tn = app.tasks_of(&id).iter().filter(|t| App::top(t)).count();
        let meta = if spr.is_object() { t!("был в сфере «{}» · {}", text(&spr["name"]), plural(tn, "задача", "задачи", "задач")) } else { plural(tn, "задача", "задачи", "задач") };
        out.push(ArchSph { kind: ss("list"), id: ss(id.clone()), name: ss(name), group: ss(t!("Списки")), first: lf, meta: ss(meta), date: ss(since(ll)),
            head: head(&if spr.is_object() { sph::sphere_color(spr) } else { String::new() }), letter: ss(letter(&super::board::view_of(app, &id))) });
        lf = false;
    }
    out
}

pub fn render(app: &App, u: &Ui, g: &S) {
    let arch = arch_rows(app, &u.arch_q);
    g.set_arch_tab(u.arch_tab);
    g.set_sph_add(u.sph_add);
    g.set_sph_arch3(model(arch.iter().take(3).cloned().collect()));
    g.set_arch_n(arch.len() as i32);
    g.set_sph_arch(model(arch));
    let open = u.sph.is_some();
    g.set_sph_open(open);
    if !open { return }
    let sps = app.spheres();
    let mut cards = vec![];
    let mut nl = 0;
    for x in &sps {
        let id = text(&x["id"]);
        let ls = lists_of(app, &id);
        nl += ls.len();
        let cal = sputnik_core::sharedcore::cal_of_sphere(&id).map(String::from);
        let aside = match &cal { Some(c) => t!("ВМЕСТЕ · {}", app.shared.people(c).len().max(1)), None => t!("{} СП.", ls.len()) };
        cards.push(SphCard { id: ss(id.clone()), name: ss(text(&x["name"]).to_uppercase()), head: head(&sph::sphere_color(x)), aside: ss(aside),
            sel: u.sph.as_deref() == Some(id.as_str()),
            lists: model(ls.iter().map(|l| { let lid = text(&l["id"]); SphList { name: ss(text(&l["title"])), letter: ss(letter(&super::board::view_of(app, &lid))), count: open_n(app, &lid) as i32, id: ss(lid) } }).collect()) });
    }
    let na = sph::archived_spheres(&app.layer).len();
    g.set_sph_info(ss(format!("{} · {}{}", plural(sps.len(), "СФЕРА", "СФЕРЫ", "СФЕР"), plural(nl, "СПИСОК", "СПИСКА", "СПИСКОВ"), if na > 0 { t!(" · {} В АРХИВЕ", na) } else { String::new() })));
    let (l, r): (Vec<_>, Vec<_>) = cards.into_iter().enumerate().partition(|(i, _)| i % 2 == 0);
    g.set_sph_cards_l(model(l.into_iter().map(|x| x.1).collect()));
    g.set_sph_cards_r(model(r.into_iter().map(|x| x.1).collect()));
    // правка
    let eid = u.sph.clone().unwrap_or_default();
    let rec = sps.iter().find(|x| x["id"] == eid.as_str()).cloned().unwrap_or(Value::Null);
    g.set_sph_edit(ss(if rec.is_null() { String::new() } else { eid.clone() }));
    g.set_sph_ename(ss(text(&rec["name"])));
    let c = s(&rec["color"]);
    g.set_sph_ecolor(sph::PICKER.iter().position(|x| *x == c).map(|i| i as i32).unwrap_or(if c == "done" { -1 } else { 0 }));
    g.set_sph_colors(model(sph::PICKER.iter().map(|x| color(x)).collect()));
    g.set_sph_ehead(head(&sph::sphere_color(&rec)));
    // фишки списков по строкам: ширину прикидываем по числу букв (13px Onest ≈ 7.3px на букву)
    let mut rows: Vec<Vec<Opt>> = vec![vec![]];
    let mut w = 0.0;
    for l in lists_of(app, &eid) {
        let name = text(&l["title"]);
        let cw = 24.0 + 7.3 * name.chars().count() as f32;
        if w > 0.0 && w + cw > 284.0 { rows.push(vec![]); w = 0.0; }
        w += cw + 6.0;
        rows.last_mut().unwrap().push(Opt { id: ss(text(&l["id"])), label: ss(name), hint: ss(""), hue: color(""), on: true });
    }
    if w > 0.0 && w + 100.0 > 284.0 { rows.push(vec![]); }
    let k = rows.len();
    g.set_sph_erows(model(rows.into_iter().enumerate().map(|(i, v)| SphRow { items: model(v), last: i + 1 == k }).collect()));
    let cal = sputnik_core::sharedcore::cal_of_sphere(&eid).map(String::from);
    g.set_sph_shared(cal.is_some());
    g.set_sph_people(ss(match &cal {
        Some(c) => {
            let names: Vec<String> = app.shared.people(c).iter().map(sputnik_core::sharedcore::name_of).filter(|x| !x.is_empty()).collect();
            if names.is_empty() { t!("Общая сфера.").into() } else { t!("С тобой работают {}.", names.join(", ")) }
        }
        None => t!("Пока только ты.").into(),
    }));
}

/// Пункты меню сферы (тот же вид, что меню списка).
pub fn menu_items(app: &App, id: &str) -> (String, Vec<MItem>) {
    let name = app.spheres().iter().find(|x| x["id"] == id).map(|x| text(&x["name"])).unwrap_or_default();
    let shared = sputnik_core::sharedcore::cal_of_sphere(id).is_some();
    let it = |id: &str, label: &str, icon: &str, key: &str| MItem { id: ss(id), label: ss(label), icon: ss(icon), key: ss(key), ..Default::default() };
    (name, vec![
        it("sph-edit", t!("Править сферу"), "settings", "Enter"),
        it("sph-list", t!("Новый список в сфере"), "plus", ""),
        MItem { off: !shared, ..it("sph-share", if shared { t!("Участники") } else { t!("Поделиться") }, "share", "") },
        MItem { sep: true, off: shared, ..it("sph-arch", t!("В архив"), "archive", "Ctrl E") },
        MItem { red: true, ..it("sph-del", t!("Удалить сферу"), "close", "") },
    ])
}

pub fn ask_delete(app: &App, u: &mut Ui, id: String) {
    let name = app.spheres().iter().chain(sph::archived_spheres(&app.layer).iter()).find(|x| x["id"] == id.as_str()).map(|x| text(&x["name"])).unwrap_or_default();
    super::wire::ask(u, t!("Удалить сферу «{}»? Её списки и задачи останутся — просто без сферы.", name), t!("Удалить"), move |app, u| {
        app.delete_sphere(&id);
        if u.sph.as_deref() == Some(id.as_str()) { u.sph = Some(String::new()); }
    });
}

pub fn archive(app: &mut App, u: &mut Ui, kind: &str, id: &str, on: bool) {
    app.set_archived(kind, id, on);
    if on && u.sph.as_deref() == Some(id) { u.sph = Some(String::new()); }
    app.say(if on { t!("Убрано в архив — вернуть можно в «Архив → Сферы и списки»") } else { t!("Возвращено из архива") });
}
