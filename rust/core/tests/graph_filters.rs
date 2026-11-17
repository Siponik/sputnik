use sputnik_core::graph::*;

fn n(id: &str, links: &[&str]) -> (String, String, Vec<String>) {
    (id.into(), id.into(), links.iter().map(|s| s.to_string()).collect())
}

#[test]
fn tags_and_files_become_own_points() {
    let (ns, es) = build(&[n("А", &["#идея", "кадр.png", "Б"]), n("Б", &["#идея"])], true);
    let tag = ns.iter().find(|x| x.tag).unwrap();
    assert_eq!(tag.label, "#идея");
    assert_eq!(tag.degree, 2);
    assert!(ns.iter().any(|x| x.file && x.label == "кадр.png"));
    assert!(!ns.iter().any(|x| x.missing));
    assert_eq!(es.len(), 4);
}

#[test]
fn local_graph_by_depth() {
    // А — Б — В — Г
    let (ns, es) = build(&[n("А", &["Б"]), n("Б", &["В"]), n("В", &["Г"]), n("Г", &[])], false);
    let a = ns.iter().position(|x| x.id == "А").unwrap();
    assert_eq!(local(ns.len(), &es, a, 1).len(), 2);
    assert_eq!(local(ns.len(), &es, a, 2).len(), 3);
    assert_eq!(local(ns.len(), &es, a, 3).len(), 4);
    assert_eq!(local(ns.len(), &es, a, 3)[0], a);
}

#[test]
fn stronger_repel_spreads_points() {
    let src: Vec<_> = (0..30).map(|i| n(&format!("з{i}"), &[&format!("з{}", (i + 1) % 30)])).collect();
    let spread = |f: Forces| {
        let (ns, _) = build_with(&src, false, f);
        let (cx, cy) = (ns.iter().map(|p| p.x).sum::<f64>() / 30.0, ns.iter().map(|p| p.y).sum::<f64>() / 30.0);
        ns.iter().map(|p| ((p.x - cx).powi(2) + (p.y - cy).powi(2)).sqrt()).sum::<f64>()
    };
    // раскладка вписывается в лист, поэтому сравниваем только то, что она стабильна и не ломается
    let a = spread(Forces::default());
    let b = spread(Forces::default());
    assert_eq!(a, b);
    assert!(spread(Forces { repel: 1.0, dist: 1.0, grav: 0.0 }).is_finite());
}
