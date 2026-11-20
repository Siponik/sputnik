use sputnik_core::mdedit::split;

#[test]
fn enter_splits_plain_line() {
    assert_eq!(split("привет мир", "привет".len()), ("привет\nмир".to_string(), 0));
}

#[test]
fn enter_continues_lists() {
    assert_eq!(split("- молоко", 100), ("- молоко\n- ".to_string(), 2));
    assert_eq!(split("- [x] хлеб", 100), ("- [x] хлеб\n- [ ] ".to_string(), 6));
    assert_eq!(split("> цитата", 100), ("> цитата\n> ".to_string(), 2));
}

#[test]
fn enter_on_empty_item_ends_list() {
    assert_eq!(split("- ", 2), (String::new(), 0));
    assert_eq!(split("- [ ] ", 6), (String::new(), 0));
}

#[test]
fn caret_inside_letter_is_safe() {
    // байт посреди буквы — режем по её началу
    assert_eq!(split("ая", 1), ("\nая".to_string(), 0));
}
