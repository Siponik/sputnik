mod common;
use common::run;
use serde_json::json;
use sputnik_core::j::*;
use sputnik_core::{boardedit as b, templates as t};

#[test]
fn templates() {
    run("templates.json", |f, x| Some(match f {
        "templatesFrom" => json!(t::templates_from(&x["lay"])),
        "templateOf" => t::template_of(&x["id"], &x["lay"]),
        "boardOf" => t::board_of(s(&x["id"]), &x["lay"]),
        "follows" => json!(t::follows(s(&x["id"]), &x["lay"], s(&x["tid"]))),
        "shortName" => json!(t::short_name(&x["t"])),
        "colColor" => json!(t::col_color(&x["c"])),
        "isBuiltin" => json!(t::is_builtin(&x["id"])),
        "isHabitList" => json!(t::is_habit_list(&x["list"], &x["lay"])),
        "isOwn" => json!(t::is_own(&x["L"])),
        "ownPatch" => t::own_patch(&x["d"]),
        "resetPatch" => t::reset_patch(),
        "sameShape" => json!(t::same_shape(&x["a"], &x["b"])),
        "matchCols" => Value::Object(t::match_cols(a(&x["o"]), a(&x["n"]))),
        "lostMoves" => Value::Object(t::lost_moves(a(&x["o"]), a(&x["n"]))),
        "relocate" => json!(t::relocate(&x["tl"], &x["lt"], o(&x["mv"]))),
        "saveListPlan" => t::save_list_plan(&x["lay"], s(&x["id"]), &x["draft"], &x["tl"], a(&x["removed"])),
        "resetListPlan" => t::reset_list_plan(&x["lay"], s(&x["id"]), &x["tl"]),
        "switchPlan" => t::switch_plan(&x["lay"], s(&x["id"]), s(&x["tid"]), &x["tl"], &x["mp"]),
        "sortOf" => json!(t::sort_of(&x["L"])),
        "orderTasks" => json!(t::order_tasks(a(&x["items"]), &x["lay"], if x["sort"].is_null() { "own" } else { s(&x["sort"]) }).iter().map(|e| e["id"].clone()).collect::<Vec<_>>()),
        "archiveDays" => json!(t::archive_days(&x["L"])),
        "isArchived" => json!(t::is_archived(&x["task"], int(&x["days"]).unwrap_or(3), n(&x["now"])?)),
        "blankTemplate" => t::blank_template(if x["name"].is_null() { "Свой шаблон" } else { s(&x["name"]) }, x["now"].as_u64()?),
        "BUILTIN" => t::builtin(),
        "VIEWS" => t::views(),
        "FIELDS" => t::fields_list(),
        "SORTS" => t::sorts(),
        _ => return None,
    }));
}

#[test]
fn boardedit() {
    run("boardedit.json", |f, x| Some(match f {
        "draftOf" => b::draft_of(&x["b"]),
        "moveCol" => json!(b::move_col(a(&x["cols"]), int(&x["from"])?, int(&x["to"])?)),
        "recolor" => b::recolor(&x["c"]),
        "relimit" => b::relimit(&x["c"], int(&x["d"])?),
        "newCol" => b::new_col(x["now"].as_u64()?),
        "dropCol" => b::drop_col(a(&x["cols"]), int(&x["i"])?, a(&x["removed"]), int(&x["n"]).unwrap_or(0)),
        "toggleField" => json!(b::toggle_field(a(&x["fields"]), &x["f"])),
        "tasksWord" => json!(b::tasks_word(int(&x["n"])?)),
        "listsWord" => json!(b::lists_word(int(&x["n"])?)),
        "colIsOwn" => json!(b::col_is_own(&x["c"], a(&x["base"]))),
        "changes" => json!(b::changes(&x["from"], &x["draft"])),
        "sampleTask" => b::sample_task(a(&x["tasks"]), &x["lay"], |id| a(&x["subs"][s(id)]).len())["id"].clone(),
        "previewCount" => json!(b::preview_count(int(&x["n"]), int(&x["i"])?, int(&x["total"])?)),
        "fieldInfo" => { let fi = b::field_info(&x["id"]); if fi.is_null() { fi } else { let mut w = o(&x["out"]).clone(); w.remove("icon"); if same(&fi, &Value::Object(w)) { x["out"].clone() } else { fi } } }
        _ => return None,
    }));
}
