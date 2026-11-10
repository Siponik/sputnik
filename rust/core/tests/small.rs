mod common;
use common::run;
use serde_json::{json, Value};
use sputnik_core::j::*;
use sputnik_core::*;
use std::collections::{HashMap, HashSet};

fn st(v: &Value) -> String { s(v).to_string() }

#[test]
fn dupes() {
    run("dupes.json", |_, c| Some(json!(small::find_dupes(&c["tasks"], a(&c["lists"]), &c["lay"]))));
}

#[test]
fn search() {
    run("search.json", |f, c| Some(match f {
        "norm" => json!(search::norm_v(&c["s"])),
        "score" => json!(search::score(s(&c["q"]), &c["title"], &c["notes"])),
        "findTasks" => json!(search::find_tasks(s(&c["q"]), a(&c["lists"]), &c["tasks"], c["limit"].as_u64()? as usize)
            .iter().map(|r| json!({"task": r.task["id"], "list": r.list["id"], "parent": r.parent.as_ref().map(|p| p["id"].clone()), "s": r.s})).collect::<Vec<_>>()),
        "findPlaces" => json!(search::find_places(s(&c["q"]), a(&c["places"])).iter().map(|p| p["id"].clone()).collect::<Vec<_>>()),
        _ => return None,
    }));
}

#[test]
fn timer() {
    run("timer.json", |f, c| Some(match f {
        "spentMin" => num(small::spent_min(&c["L"], n(&c["now"])?)),
        "stopPatch" => small::stop_patch(&c["L"], n(&c["now"])?),
        "runningId" => json!(small::running_id(&c["lay"])),
        "toggle" => json!(small::timer_toggle(&c["lay"], s(&c["id"]), n(&c["now"])?).into_iter().map(|(k, v)| json!([k, v])).collect::<Vec<_>>()),
        "fmtMin" => json!(small::fmt_min(n(&c["m"])?)),
        "clock" => json!(small::clock(n(&c["ms"])?)),
        _ => return None,
    }));
}

#[test]
fn fresh() {
    run("fresh.json", |_, c| {
        let before: HashSet<String> = a(&c["before"]).iter().map(st).collect();
        let touched: HashMap<String, f64> = a(&c["touched"]).iter().map(|p| (st(&p[0]), n(&p[1]).unwrap())).collect();
        Some(json!(small::keep_local(a(&c["fetched"]), a(&c["local"]), &before, &touched, n(&c["t0"]).unwrap_or(0.0))))
    });
}

#[test]
fn accent_() {
    run("accent.json", |f, x| Some(match f {
        "luminance" => num(accent::luminance(s(&x["x"]))),
        "contrast" => num(accent::contrast(s(&x["x"]), s(&x["y"]))),
        "mix" => json!(accent::mix(s(&x["x"]), s(&x["y"]), n(&x["t"])?)),
        "fit" => json!(accent::fit(s(&x["x"]), s(&x["bg"]), n(&x["min"])?)),
        "accentOf" => accent::accent_of(&x["v"]),
        "accentCss" => json!(accent::accent_css(&x["v"])),
        "vars" => accent::vars(s(&x["x"]), s(&x["th"])),
        "ACCENTS" => accent::accents(),
        _ => return None,
    }));
}

#[test]
fn authcheck_() {
    run("authcheck.json", |f, x| Some(match f {
        "checkSecretText" => json!(authcheck::check_secret_text(&x["t"], x["size"].as_u64().map(|v| v as usize))),
        "loginHint" => json!(authcheck::login_hint(&text(&x["e"]))),
        "isStopped" => json!(authcheck::is_stopped(&text(&x["e"]))),
        "isScopeLack" => json!(authcheck::is_scope_lack(&text(&x["e"]))),
        "calDefaultOn" => json!(authcheck::cal_default_on(&x["cal"])),
        _ => return None,
    }));
}

fn text(v: &Value) -> String {
    match v { Value::Null => String::new(), Value::String(x) => x.clone(), x => x.to_string() }
}

#[test]
fn dropdown_() {
    let cases = common::load("dropdown.json");
    let opts = cases.iter().find(|x| x["fn"] == "moveActive").unwrap()["opts"].clone();
    run("dropdown.json", |f, x| {
        let o = if x["opts"].is_null() { &opts } else { &x["opts"] };
        let cur = || x["cur"].as_i64().unwrap_or(-1);
        Some(match f {
            "filterOpts" => json!(dropdown::filter_opts(a(&opts), s(&x["q"])).iter().map(|e| e["id"].clone()).collect::<Vec<_>>()),
            "marks" => dropdown::marks(&x["label"], s(&x["q"])),
            "moveActive" => json!(dropdown::move_active(a(o), cur(), s(&x["key"]))),
            "jumpTo" => json!(dropdown::jump_to(a(o), cur(), s(&x["ch"]))),
            "toggleIn" => json!(dropdown::toggle_in(a(&x["values"]), &x["id"], a(o))),
            "buttonText" => json!(dropdown::button_text(a(&opts), &x["value"], x["multi"] == true)),
            "placeMenu" => {
                let p = &x["opt"];
                dropdown::place_menu(&x["btn"], n(&x["h"])?, n(&x["w"])?, &x["view"], n(&p["gap"]).unwrap_or(6.0), n(&p["max"]).unwrap_or(320.0), n(&p["pad"]).unwrap_or(8.0))
            }
            _ => return None,
        })
    });
}

#[test]
fn meta() {
    let human = |due: &str| format!("пт, {}.{}", &due[8..10], &due[5..7]);
    run("meta.json", |f, x| Some(match f {
        "typeLabel" => json!(small::type_label(&x["id"])),
        "priorityOf" => small::priority_of(&x["n"]),
        "priorityRank" => json!(small::priority_rank(&x["n"])),
        "pickNext" => small::pick_next(a(&x["items"]), &x["lay"], s(&x["today"]))["task"]["id"].clone(),
        "nextReason" => json!(small::next_reason(&x["task"], &x["lay"], s(&x["today"]), human)),
        "TYPES" => small::types_json(),
        "PRIORITIES" => small::priorities(),
        _ => return None,
    }));
}

#[test]
fn spheres_() {
    run("spheres.json", |f, x| Some(match f {
        "spheresFrom" => json!(spheres::spheres_from(&x["lay"])),
        "sphereOf" => json!(spheres::sphere_of(s(&x["id"]), &x["lay"])),
        "sphereColor" => json!(spheres::sphere_color(&x["sp"])),
        "iconPath" => json!(spheres::icon_path(&x["sp"])),
        "listChoices" => spheres::list_choices(a(&x["lists"]), &x["lay"]),
        _ => return None,
    }));
}

#[test]
fn repeat_() {
    run("repeat.json", |f, c| Some(match f {
        "nextDue" => json!(repeat::next_due(&c["rule"], s(&c["due"]), s(&c["today"]))),
        "repeatLabel" => json!(repeat::repeat_label(&c["rule"])),
        "takeRepeat" => { let (r, rest) = repeat::take_repeat(s(&c["text"])); json!({"rule": r, "rest": rest}) }
        "dueRepeats" => json!(repeat::due_repeats(a(&c["lists"]), &c["tasks"], &c["lay"])),
        "existingNext" => repeat::existing_next(a(&c["list"]), &c["task"], s(&c["day"])),
        "CARRY" => json!(repeat::CARRY),
        _ => return None,
    }));
}

#[test]
fn layer_merge() {
    let cases = common::load("layer_merge.json");
    for (i, c) in cases.iter().enumerate() {
        let m = sputnik_core::layer::merge(&c["local"], &c["remote"]);
        assert_eq!(json!(m.local_changed), c["out"]["localChanged"], "#{i}");
        assert_eq!(json!(m.remote_changed), c["out"]["remoteChanged"], "#{i}");
        assert!(same_u(&m.merged, &c["out"]["merged"]), "#{i}: {} ≠ {}", m.merged, c["out"]["merged"]);
    }
}
