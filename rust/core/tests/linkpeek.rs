use sputnik_core::linkpeek::*;

#[test]
fn open_graph() {
    let html = r#"<html><head><title>Fallback</title>
<meta property="og:title" content="Tileable Materials &amp; Props">
<meta name="description" content="  Modular   environment ">
<meta property='og:image' content="/img/cover.jpg" />
</head>"#;
    let m = parse(html, "https://www.artstation.com/artwork/ZGAbmR");
    assert_eq!(m.title, "Tileable Materials & Props");
    assert_eq!(m.desc, "Modular environment");
    assert_eq!(m.image, "https://www.artstation.com/img/cover.jpg");
    assert_eq!(m.site, "artstation.com");
}

#[test]
fn title_only() {
    let m = parse("<TITLE>Привет</TITLE>", "http://a.b/c");
    assert_eq!(m.title, "Привет");
    assert_eq!(m.image, "");
}
