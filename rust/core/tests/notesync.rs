use std::collections::BTreeMap;
use sputnik_core::notesync::*;

fn l(h: &str) -> Local { Local { hash: h.into() } }
fn r(m: &str) -> Remote { Remote { id: format!("id-{m}"), md5: m.into() } }
fn b(h: &str, m: &str) -> Base { Base { hash: h.into(), md5: m.into() } }

#[test]
fn steps_by_side() {
    let mut lo = BTreeMap::new();
    let mut re = BTreeMap::new();
    let mut ba = BTreeMap::new();
    // без изменений
    lo.insert("a.md".to_string(), l("1")); re.insert("a.md".to_string(), r("x")); ba.insert("a.md".to_string(), b("1", "x"));
    // правка здесь
    lo.insert("b.md".to_string(), l("2")); re.insert("b.md".to_string(), r("y")); ba.insert("b.md".to_string(), b("1", "y"));
    // правка на Drive
    lo.insert("c.md".to_string(), l("1")); re.insert("c.md".to_string(), r("z")); ba.insert("c.md".to_string(), b("1", "y"));
    // правка с обеих сторон
    lo.insert("d.md".to_string(), l("2")); re.insert("d.md".to_string(), r("z")); ba.insert("d.md".to_string(), b("1", "y"));
    // новая здесь, новая на Drive, новая с обеих сторон
    lo.insert("e.md".to_string(), l("1"));
    re.insert("f.md".to_string(), r("x"));
    lo.insert("g.md".to_string(), l("1")); re.insert("g.md".to_string(), r("x"));
    // удалили здесь (на Drive не меняли) / удалили здесь, но на Drive поменяли
    re.insert("h.md".to_string(), r("x")); ba.insert("h.md".to_string(), b("1", "x"));
    re.insert("i.md".to_string(), r("z")); ba.insert("i.md".to_string(), b("1", "x"));
    // удалили на Drive (здесь не меняли) / удалили на Drive, но здесь поменяли
    lo.insert("j.md".to_string(), l("1")); ba.insert("j.md".to_string(), b("1", "x"));
    lo.insert("k.md".to_string(), l("2")); ba.insert("k.md".to_string(), b("1", "x"));
    // нет нигде
    ba.insert("z.md".to_string(), b("1", "x"));
    let s = |x: &str| x.to_string();
    assert_eq!(plan(&lo, &re, &ba), vec![
        Step::Upload(s("b.md")), Step::Download(s("c.md")), Step::Conflict(s("d.md")), Step::Upload(s("e.md")),
        Step::Download(s("f.md")), Step::Conflict(s("g.md")), Step::TrashRemote(s("h.md")), Step::Download(s("i.md")),
        Step::TrashLocal(s("j.md")), Step::Upload(s("k.md")), Step::Forget(s("z.md")),
    ]);
}

#[test]
fn copy_names_and_filter() {
    assert_eq!(conflict_name("3D/Запекание.md", |_| false), "3D/Запекание (с другого компьютера).md");
    assert_eq!(conflict_name("a.md", |n| n == "a (с другого компьютера).md"), "a (с другого компьютера 2).md");
    assert!(wanted("DND/Карта.canvas") && wanted("Вложения/щит.PNG"));
    assert!(!wanted(".trash/a.md") && !wanted(".obsidian/app.json") && !wanted("a.exe"));
}

#[test]
fn mass_delete_is_not_trusted() {
    let s = |x: &str| x.to_string();
    let few = vec![Step::TrashLocal(s("a.md")), Step::Upload(s("b.md"))];
    assert_eq!(guard(few.clone(), 10), few);
    let many: Vec<Step> = (0..8).map(|i| Step::TrashLocal(format!("{i}.md"))).collect();
    assert!(guard(many, 10).iter().all(|x| matches!(x, Step::Upload(_))));
    let gone: Vec<Step> = (0..8).map(|i| Step::TrashRemote(format!("{i}.md"))).collect();
    assert!(guard(gone, 10).iter().all(|x| matches!(x, Step::Download(_))));
}

#[test]
fn extra_copies_found() {
    use sputnik_core::notesync::{extra_copies, original_of, Local};
    use std::collections::BTreeMap;
    assert_eq!(original_of("a/Заметка (с другого компьютера 2).md").as_deref(), Some("a/Заметка.md"));
    assert_eq!(original_of("a/Заметка (с другого компьютера) (с другого компьютера).md").as_deref(), Some("a/Заметка.md"));
    assert_eq!(original_of("a/Заметка.md"), None);
    let mut f = BTreeMap::new();
    let l = |h: &str| Local { hash: h.into() };
    f.insert("Н.md".to_string(), l("1"));
    f.insert("Н (с другого компьютера).md".to_string(), l("1"));
    f.insert("Н (с другого компьютера 2).md".to_string(), l("2"));
    f.insert("Н (с другого компьютера 3).md".to_string(), l("2"));
    let x = extra_copies(&f);
    assert!(x.contains(&"Н (с другого компьютера).md".to_string()));
    assert_eq!(x.len(), 2);
}
