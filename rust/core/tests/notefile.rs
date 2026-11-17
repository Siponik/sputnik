use sputnik_core::notefile::*;

#[test]
fn rename_all_link_forms() {
    let body = "См. [[Таверна]], [[таверна|кабак]], [[Таверна#Хозяин]], ![[DND/Таверна.md]] и [[Таверна 2]].";
    let (out, n) = rename_links(body, "Таверна", "Трактир");
    assert_eq!(n, 4);
    assert_eq!(out, "См. [[Трактир]], [[Трактир|кабак]], [[Трактир#Хозяин]], ![[DND/Трактир.md]] и [[Таверна 2]].");
    assert_eq!(rename_links("без ссылок [[", "А", "Б"), ("без ссылок [[".to_string(), 0));
}

#[test]
fn mention_becomes_link() {
    assert_eq!(link_mention("Идём в таверну? Нет, в Таверна.", "Таверна").as_deref(), Some("Идём в таверну? Нет, в [[Таверна]]."));
    assert_eq!(link_mention("мира тёрн знает", "Мира Тёрн").as_deref(), Some("[[Мира Тёрн|мира тёрн]] знает"));
    assert_eq!(link_mention("[[Мира Тёрн]] и всё", "Мира Тёрн"), None, "уже ссылка");
    assert_eq!(link_mention("[[Мира Тёрн]], а потом Мира Тёрн", "Мира Тёрн").as_deref(), Some("[[Мира Тёрн]], а потом [[Мира Тёрн]]"));
}

#[test]
fn template_vars() {
    assert_eq!(fill_template("# {{title}}\nдата: {{date}} {{time}}", "НПС", "2026-11-17", "09:30"), "# НПС\nдата: 2026-11-17 09:30");
}

#[test]
fn trash_names() {
    assert_eq!(trash_path("DND/НПС.md", |_| false), ".trash/DND/НПС.md");
    assert_eq!(trash_path("DND/НПС.md", |p| p == ".trash/DND/НПС.md"), ".trash/DND/НПС 2.md");
}

#[test]
fn link_under_caret() {
    let l = "См. [[Таверна|кабак]] и [сайт](https://a.b) тут";
    assert_eq!(link_at(l, 8).as_deref(), Some("Таверна"));
    assert_eq!(link_at(l, l.find("сайт").unwrap()).as_deref(), Some("https://a.b"));
    assert_eq!(link_at(l, 0), None);
    assert_eq!(link_at(l, l.len()), None);
}

#[test]
fn lift_path_moves_up() {
    use sputnik_core::notefile::lift_path;
    assert_eq!(lift_path("a/b/c.md", "a/b"), "a/c.md");
    assert_eq!(lift_path("a/b/x/c.md", "a/b"), "a/x/c.md");
    assert_eq!(lift_path("a/c.md", "a"), "c.md");
    assert_eq!(lift_path("ab/c.md", "a"), "ab/c.md");
}
