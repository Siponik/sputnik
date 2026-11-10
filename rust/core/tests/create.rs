mod common;
use serde_json::json;
use sputnik_core::create as c;
use sputnik_core::j::*;

#[test]
fn create() {
    let today = "2026-10-21";
    common::run("create.json", |f, x| {
        let d = s(&x["d"]);
        Some(match f {
            "plus" => json!(c::plus(d, int(&x["n"])?)),
            "shortDay" => json!(c::short_day(d)),
            "longDay" => json!(c::long_day(d)),
            "eventDay" => json!(c::event_day(d, today)),
            "dayMonth" => json!(c::day_month(d)),
            "weekday" => json!(c::weekday(d)),
            "whenChip" => json!(c::when_chip(d, today)),
            "nextBirthday" => json!(c::next_birthday(d, today)),
            "daysTill" => json!(c::days_till(d, today)),
            "dueShort" => json!(c::due_short(d, today, &x["sl"])),
            "ageAt" => json!(c::age_at(&x["y"], d, today)),
            "toMin" => json!(c::to_min(s(&x["s"]))),
            "fromMin" => json!(c::from_min(int(&x["n"])?)),
            "addMin" => json!(c::add_min(s(&x["s"]), int(&x["n"])?)),
            "dative" => json!(c::dative(&if x["n"].is_null() { String::new() } else { text(&x["n"]) })),
            "years" => json!(c::years(int(&x["n"])?)),
            "dayChunk" => c::day_chunk(a(&x["events"]), s(&x["day"]), &x["sl"], "Моё", 5),
            "dayChunk3" => c::day_chunk(a(&x["events"]), s(&x["day"]), &x["sl"], "", 3),
            "freeCheck" => c::free_check(a(&x["events"]), s(&x["day"]), &x["sl"]),
            "colCount" => json!(c::col_count(a(&x["lt"]), &x["lay"], &x["col"], &x["first"])),
            "topOrd" => num(c::top_ord(a(&x["lt"]), &x["lay"], &x["col"], &x["first"])),
            "stageChecklist" => json!(c::stage_checklist(a(&x["lt"]), &x["lay"])),
            "initials" => json!(c::initials(&if x["t"].is_null() { String::new() } else { text(&x["t"]) })),
            "suggestKind" => c::suggest_kind(&if x["s"].is_null() { String::new() } else { text(&x["s"]) }, &x["p"]),
            "kindHint" => c::kind_hint(&if x["s"].is_null() { String::new() } else { text(&x["s"]) }, &x["p"], s(&x["k"])),
            "recurrenceOf" => c::recurrence_of(&x["r"]),
            "parseHabit" => c::parse_habit(&if x["s"].is_null() { String::new() } else { text(&x["s"]) }, &x["off"]),
            "GIFT_DAYS" => json!(c::GIFT_DAYS.iter().map(|g| json!([g.0, g.1])).collect::<Vec<_>>()),
            "giftDate" => json!(c::gift_date(s(&x["b"]), int(&x["d"])?)),
            "bdayName" => json!(c::bday_name(&if x["s"].is_null() { String::new() } else { text(&x["s"]) })),
            "giftsDue" => json!(c::gifts_due(a(&x["ev"]), s(&x["t"]))),
            _ => return None,
        })
    });
}
