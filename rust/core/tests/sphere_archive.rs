use serde_json::json;
use sputnik_core::spheres::*;

#[test]
fn archived_sphere_hides_with_lists() {
    let lay = json!({
        "spheres": {"a": {"name": "Дом", "order": 1}, "b": {"name": "Фриланс", "order": 2, "archived": true, "archivedAt": 5}},
        "lists": {"l1": {"sphere": "a"}, "l2": {"sphere": "b"}, "l3": {"archived": true}, "l4": {}}
    });
    let names: Vec<String> = spheres_from(&lay).iter().map(|x| x["name"].as_str().unwrap().to_string()).collect();
    assert_eq!(names, vec!["Дом"]);
    assert_eq!(archived_spheres(&lay).len(), 1);
    assert!(!list_archived("l1", &lay));
    assert!(list_archived("l2", &lay));
    assert!(list_archived("l3", &lay));
    assert!(!list_archived("l4", &lay));
}
