use sputnik_core::edcmd::apply;

#[test]
fn wraps_and_unwraps() {
    assert_eq!(apply("мир тесен", 0, 6, "bold"), ("**мир** тесен".into(), 2, 8));
    assert_eq!(apply("**мир** тесен", 2, 8, "bold"), ("мир тесен".into(), 0, 6));
    assert_eq!(apply("ab", 1, 1, "italic"), ("a**b".into(), 2, 2));
}

#[test]
fn paragraph_kinds() {
    assert_eq!(apply("- пункт", 2, 2, "h2").0, "## пункт");
    assert_eq!(apply("## пункт", 3, 3, "todo").0, "- [ ] пункт");
    assert_eq!(apply("1. раз", 0, 0, "p").0, "раз");
}

#[test]
fn blocks_go_after_line() {
    let (t, a, _) = apply("текст", 0, 0, "hr");
    assert_eq!(t, "текст\n\n---");
    assert_eq!(a, t.len());
    assert!(apply("", 0, 0, "table").0.starts_with("| Колонка 1"));
    assert_eq!(apply("слово", 10, 10, "footnote").0, "слово[^1]\n\n[^1]: ");
    assert_eq!(apply("abc", 0, 3, "clear").0, "abc");
    assert_eq!(apply("**a** b", 0, 0, "clear").0, "a b");
}
