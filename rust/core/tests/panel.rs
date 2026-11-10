mod common;
use serde_json::{json, Value};
use sputnik_core::j::*;
use sputnik_core::{preview as p, taskpanel as tp};

#[test]
fn taskpanel() {
    common::run("taskpanel.json", |f, x| {
        Some(match f {
            "colCounts" => tp::col_counts(a(&x["tasks"]), a(&x["cols"]), &x["lay"]),
            "stageMode" => json!(tp::stage_mode(s(&x["v"]), a(&x["cols"]).len())),
            "leadChip" => json!(tp::lead_chip(n(&x["m"])?)),
            "customChip" => json!(tp::custom_chip(&x["r"])),
            "splitRemind" => tp::split_remind(&x["r"]),
            "joinRemind" => tp::join_remind(a(&x["l"]), &x["c"]),
            "moreFilled" => json!(tp::more_filled(&x["L"])),
            _ => return None,
        })
    });
}

#[test]
fn preview() {
    common::run("preview.json", |f, x| {
        Some(match f {
            "fitSize" => {
                let (w, h) = p::fit_size(n(&x["w"]), n(&x["h"]), n(&x["m"])?);
                json!({"w": w, "h": h})
            }
            "dataUrlParts" => p::data_url_parts(s(&x["u"])).map(|(m, b)| json!({"mime": m, "b64": b})).unwrap_or(Value::Null),
            "isImage" => json!(p::is_image(&x["f"])),
            "rejectWhy" => json!(p::reject_why(&x["f"])),
            "dragHasFile" => json!(p::drag_has_file(&x["t"])),
            "fileName" => json!(p::file_name(&if x["t"].is_null() { String::new() } else { text(&x["t"]) })),
            "has" => json!(p::has(&x["L"])),
            "consts" => json!([p::THUMB, p::FULL, p::MAX_BYTES]),
            _ => return None,
        })
    });
    let _ = Value::Null;
}
