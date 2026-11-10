mod common;
use serde_json::json;
use sputnik_core::inbox as ib;
use sputnik_core::j::*;

#[test]
fn inbox() {
    sputnik_core::habits::set_clock(chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0));
    let lists = vec![json!({"id": "L1", "title": "Дом"}), json!({"id": "L2", "title": "Работа"}), json!({"id": "L3", "title": "X"})];
    let tbl = json!({"L1": [{"id": "t1"}, {"id": "t2"}, {"id": "t5", "status": "completed"}],
                     "L2": [{"id": "t3"}, {"id": "t6"}, {"id": "zz"}], "L3": [{"id": "t4"}]});
    common::run("inbox.json", |f, x| {
        Some(match f {
            "claudeTasks" => Value::Object(ib::claude_tasks(&x["status"])),
            "pending" => json!(ib::pending(&x["status"], &lists, &tbl, &x["lt"])),
            "layerPatches" => json!(ib::layer_patches(&x["status"], &x["lt"], None)),
            "pullPatches" => ib::pull_patches(&x["status"], &x["lay"]),
            _ => return None,
        })
    });
}
