mod common;
use common::run;
use serde_json::{json, Value};
use sputnik_core::j::*;
use sputnik_core::{stickers as st, today as td};

fn day(v: &Value) -> chrono::NaiveDate {
    chrono::NaiveDate::from_ymd_opt(v[0].as_i64().unwrap() as i32, v[1].as_u64().unwrap() as u32, v[2].as_u64().unwrap() as u32).unwrap()
}

fn lanes_of(x: &Value) -> Vec<Value> {
    let o_ = &x["o"];
    let dt = st::default_topics();
    let topics = if o_["topics"].is_null() { &dt } else { &o_["topics"] };
    st::lanes(a(&x["tasks"]), &st::LaneOpts {
        group: if o_["group"].is_null() { "topic" } else { s(&o_["group"]) },
        topics, lay_tasks: &o_["layTasks"], today: s(&o_["today"]),
        sort: if o_["sort"].is_null() { "pin" } else { s(&o_["sort"]) },
        people: a(&o_["people"]), me: s(&o_["me"]),
    })
}

fn ids(lanes: Vec<Value>) -> Value {
    json!(lanes.into_iter().map(|e| { let mut m = o(&e).clone(); m.insert("items".into(), json!(a(&e["items"]).iter().map(|t| t["id"].clone()).collect::<Vec<_>>())); Value::Object(m) }).collect::<Vec<_>>())
}

#[test]
fn today() {
    run("today.json", |f, x| Some(match f {
        "understood" => json!(td::understood(&x["p"], s(&x["today"]))),
        "taskFrom" => td::task_from(&x["p"], s(&x["today"]), s(&x["dest"]), &x["r"]),
        _ => return None,
    }));
}

#[test]
fn stickers() {
    let all = common::load("stickers.json");
    let tasks = all.iter().find(|x| x["fn"] == "lanes").unwrap()["tasks"].clone();
    run("stickers.json", |f, x| Some(match f {
        "weekEnd" => json!(st::week_end(s(&x["today"]))),
        "todaySub" => json!(st::today_sub(s(&x["today"]))),
        "plusDays" => json!(st::plus_days(s(&x["d"]), int(&x["n"])?)),
        "bucket" => json!(st::bucket(s(&x["due"]), s(&x["today"]))),
        "whenDue" => json!(st::when_due(s(&x["target"]), s(&x["cur"]), s(&x["today"]))),
        "dueLabel" => st::due_label(s(&x["due"]), s(&x["today"]), &x["slot"], x["hide"] == true),
        "newDue" => json!(st::new_due(s(&x["target"]), s(&x["today"]))),
        "topicsOf" => st::topics_of(&x["L"]),
        "topicColor" => json!(st::topic_color(&x["t"])),
        "order" => json!(st::order(a(&x["items"]), &x["lay"], s(&x["today"]), if x["sort"].is_null() { "pin" } else { s(&x["sort"]) }).iter().map(|t| t["id"].clone()).collect::<Vec<_>>()),
        "lanes" => ids(lanes_of(x)),
        "visibleLanes" => {
            let l = lanes_of(&json!({"tasks": tasks, "o": x["o"]}));
            let g = if x["o"]["group"].is_null() { "topic" } else { s(&x["o"]["group"]) };
            let (sh, hi) = st::visible_lanes(&l, g, &x["keep"]);
            json!({"shown": sh.iter().map(|e| e["id"].clone()).collect::<Vec<_>>(), "hidden": hi.iter().map(|e| e["id"].clone()).collect::<Vec<_>>()})
        }
        "nextGroup" => json!(st::next_group(s(&x["cur"]), if x["to"] == "obj" { &Value::Null } else { &x["to"] }, x["sh"] == true)),
        "topicOfTask" => st::topic_of_task(&x["task"], &x["lay"], &st::default_topics()),
        "tilt" => num(st::tilt(&x["id"])),
        "jarCount" => json!(st::jar_count(a(&x["tasks"]), n(&x["now"])?)),
        "parseSticker" => st::parse_sticker(s(&x["raw"]), &st::default_topics(), day(&x["today"])),
        "consts" => json!({"DEFAULT_TOPICS": st::default_topics(), "MISC": st::misc(), "WHEN": st::when_lanes()}),
        _ => return None,
    }));
}
