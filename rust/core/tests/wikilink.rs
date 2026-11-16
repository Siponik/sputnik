use sputnik_core::wikilink as w;

#[test]
fn query_insert_links() {
    assert_eq!(w::query("смотри [[Мет"), Some("Мет".into()));
    assert_eq!(w::query("смотри [[Металл]] и"), None);
    assert_eq!(w::query("без ссылок"), None);
    assert_eq!(w::query("[[a\nb"), None);
    assert_eq!(w::insert("смотри [[Мет", "Металл"), "смотри [[Металл]]");
    assert_eq!(w::links("[[Металл]] и [[Палитра|цвета]], снова [[Металл]]"), vec!["Металл", "Палитра"]);
}
