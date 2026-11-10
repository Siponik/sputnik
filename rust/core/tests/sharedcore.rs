mod common;
use serde_json::json;
use sputnik_core::j::*;
use sputnik_core::sharedcore as sh;

fn os(v: &Value) -> Option<&str> {
    v.as_str()
}

#[test]
fn sharedcore() {
    let cases = common::load("sharedcore.json");
    let recs = cases.iter().find(|x| x["fn"] == "setup").unwrap()["a"][0].clone();
    let people = sh::members_of(&recs);
    let name = |c: &Value| match s(c) {
        "review" => "Ревью".to_string(),
        "doing" => "В работе".to_string(),
        _ => if c.is_null() { "null".into() } else { text(c) },
    };
    let now = chrono::NaiveDate::from_ymd_opt(2026, 10, 21).unwrap().and_hms_opt(14, 0, 0).unwrap();
    let now = sputnik_core::reminders::local(now).timestamp_millis() as f64;
    common::run("sharedcore.json", |f, x| {
        let a0 = &x["a"][0];
        let a1 = &x["a"][1];
        let a2 = &x["a"][2];
        Some(match f {
            "setup" => Value::Null,
            "same" => json!(sh::same(Some(a0), Some(a1))),
            "sameU" => json!(sh::same(None, None)),
            "newKey" => {
                let vals: Vec<f64> = a(a1).iter().filter_map(n).collect();
                let mut j = 0;
                json!(sh::new_key(s(a0), &mut || { j += 1; vals[j - 1] }))
            }
            "kindOf" => json!(sh::kind_of(a0)),
            "memberKey" => json!(sh::member_key(&if a0.is_null() { String::new() } else { text(a0) })),
            "ids" => {
                let id = s(a0);
                let sh_ = a0.is_string() && sh::is_shared_id(id);
                json!([sh_, if sh_ { sh::list_key(id) } else { None }, if sh_ { sh::cal_of_sphere(id) } else { None }])
            }
            "listId" => json!(sh::list_id(s(a0))),
            "sphereId" => json!(sh::sphere_id(s(a0))),
            "make" => sh::make(s(a0), a1, n(a2)),
            "edit" => sh::edit(a0, a1, n(a2)),
            "mergeRec" => sh::merge_rec(a0, a1),
            "lastTime" => num(sh::last_time(a0)),
            "toEvent" => sh::to_event(a0),
            "fromEvent" => sh::from_event(a0),
            "newPos" => json!(sh::new_pos(n(a0))),
            "taskView" => sh::task_view(a0),
            "listView" => sh::list_view(a0, a1),
            "taskPatch" => sh::task_patch(a0, n(a1)),
            "layerOf" => sh::layer_of(a0),
            "sharedOf" => Value::Object(sh::shared_of(a0, if a1.is_string() { s(a1) } else { "task" })),
            "reconcile" => sh::reconcile(a0, a1, a2, "task"),
            "reconcileList" => sh::reconcile(a0, a1, a2, "list"),
            "reconcileSphere" => sh::reconcile_sphere(a0, a1, a2),
            "tasksOf" => json!(sh::tasks_of(&recs, s(a0))),
            "listsOf" => json!(sh::lists_of(&recs, a0)),
            "withChildren" => json!(sh::with_children(&recs, s(a0))),
            "isSphereCal" => json!(sh::is_sphere_cal(a0)),
            "membersOf" => json!(people),
            "membersOf0" => json!(sh::members_of(&Value::Null)),
            "okPic" => sh::ok_pic(a0),
            "profilePatch" => sh::profile_patch(a0, a1),
            "profileFields" => sh::profile_fields(a0),
            "nameOf" => json!(sh::name_of(a0)),
            "nextOrder" => num(sh::next_order(&recs)),
            "nextOrder0" => num(sh::next_order(&json!({}))),
            "whoOf" => json!(sh::who_of(a0)),
            "assignedMatch" => json!(sh::assigned_match(a0, os(a1), s(a2))),
            "handoff" => sh::handoff(a0, s(a1)),
            "setStageWho" => sh::set_stage_who(a0, s(a1), a2),
            "stagePass" => sh::stage_pass(a0, s(a1), s(a2), s(&x["a"][3]), n(&x["a"][4])),
            "isTogether" => json!(sh::is_together(a(a0))),
            "seenText" => json!(sh::seen_text(a0, n(a1))),
            "parseEmails" => sh::parse_emails(a0),
            "memberOf" => sh::member_of(&people, a0),
            "whoOptions" => json!(sh::who_options(&people, os(a0), s(a1), a2)),
            "whoByDigit" => match sh::who_by_digit(&people, os(a0), s(a1)) {
                None => json!("<undefined>"),
                Some(v) => v,
            },
            "memberByWord" => sh::member_by_word(&people, s(a0)),
            "editOf" => sh::edit_of(a0),
            "changeText" => json!(sh::change_text(a0, &people, os(a1), &name, Some(now))),
            "assignedToMe" => json!(sh::assigned_to_me(a0, a1, os(a2))),
            "whoCounts" => sh::who_counts(a(a0), a1),
            "whoTally" => sh::who_tally(a(a0), a1, os(a2)),
            "WHO_MODES" => json!(sh::WHO_MODES),
            "forMe" => sh::for_me(a0, a1, os(a2), &|id| id != "L2"),
            "passText" => json!(sh::pass_text(a0, &people, os(a1), &name)),
            "nextHint" => json!(sh::next_hint(a0, os(a1), os(a2), &people)),
            "stageCrew" => json!(sh::stage_crew(a0, a(a1), a2)),
            "isInvite" => json!(sh::is_invite(a0, s(a1))),
            "inviteInfo" => sh::invite_info(a0, os(a1)),
            "waitingFor" => sh::waiting_for(a0, &people, os(a1)),
            "unseenBy" => json!(sh::unseen_by(&recs, &people, os(a0))),
            "seenDue" => json!(sh::seen_due(a0, a1 == true, n(a2))),
            "askAccessText" => json!(sh::ask_access_text(s(a0), os(a1))),
            "consts" => json!([sh::MARK, sh::SUMMARY, sh::PREFIX, sh::NOTES_MAX, sh::SPHERE_FIELDS, sh::SPHERE_KEY, sh::MEMBER_COLORS, sh::NAME_MAX, sh::PIC_MAX]),
            _ => return None,
        })
    });
}
