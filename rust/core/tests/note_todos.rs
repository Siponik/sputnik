use sputnik_core::notefile::open_todos;

#[test]
fn only_open_items_outside_code() {
    let b = "# План\n- [ ] Перепечь щит с новым [[Кейдж|кейджем]]\n- [x] Готово\n  - [ ] Проверить фаски\n```\n- [ ] не задача\n```\nтекст";
    assert_eq!(open_todos(b), vec!["Перепечь щит с новым кейджем", "Проверить фаски"]);
}
