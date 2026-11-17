use sputnik_core::canvas::*;

const OBS: &str = r##"{
	"nodes":[
		{"id":"a1","type":"text","text":"# Идея\nтекст","x":0,"y":0,"width":250,"height":120,"color":"2","myPlugin":{"k":1}},
		{"id":"b2","type":"file","file":"DND/Таверна.md","x":400,"y":0,"width":300,"height":200},
		{"id":"g","type":"group","label":"Кампания","x":-50,"y":-50,"width":900,"height":400},
		{"type":"text","text":"без id"}
	],
	"edges":[
		{"id":"e1","fromNode":"a1","fromSide":"right","toNode":"b2","toSide":"left","label":"ведёт"},
		{"id":"bad","fromNode":"a1"}
	],
	"sputnik":{"v":1}
}"##;

#[test]
fn reads_obsidian_and_keeps_unknown() {
    let d = Doc::parse(OBS).unwrap();
    assert_eq!(d.nodes.len(), 3);
    assert_eq!(d.edges.len(), 1);
    assert_eq!(d.nodes[0].title(), "Идея");
    assert_eq!(d.nodes[1].title(), "Таверна");
    assert_eq!(d.nodes[2].title(), "Кампания");
    assert_eq!(color_hex(d.nodes[0].color()), "#F0A04B");
    let out = d.encode();
    assert!(out.contains("\t\"nodes\""));
    let back = Doc::parse(&out).unwrap();
    assert_eq!(back.nodes, d.nodes);
    assert_eq!(back.extra["sputnik"]["v"], 1);
    assert_eq!(back.nodes[0].0["myPlugin"]["k"], 1);
    assert!(Doc::parse("[1,2]").is_err());
    assert!(Doc::parse("не json").is_err());
    assert_eq!(Doc::parse("  ").unwrap().nodes.len(), 0);
}

#[test]
fn add_connect_remove() {
    let mut d = Doc::default();
    let a = d.add("text", 3.0, 7.0, 250.0, 120.0, "Привет");
    let b = d.add("file", 400.0, 0.0, 300.0, 200.0, "Металл.md");
    let g = d.add("group", -50.0, -50.0, 900.0, 400.0, "Рамка");
    assert_eq!(d.nodes[0].id(), g, "группа — под остальными");
    assert_eq!((d.node(&a).unwrap().x(), d.node(&a).unwrap().y()), (0.0, 10.0), "сетка 10");
    let e = d.connect(&a, &b, Some(Side::Right), Some(Side::Left)).unwrap();
    assert!(d.connect(&b, &a, None, None).is_none(), "второй провод между теми же — нет");
    assert!(d.connect(&a, &a, None, None).is_none());
    d.edge_mut(&e).unwrap().set_label("дальше");
    assert_eq!(d.edges[0].label(), "дальше");
    // группа тянет за собой то, что внутри
    let mv = d.movable(std::slice::from_ref(&g));
    assert_eq!(mv.len(), 3);
    d.shift(&mv, 100.0, 0.0);
    assert_eq!(d.node(&b).unwrap().x(), 500.0);
    // клик: нода поверх группы
    assert_eq!(d.hit(120.0, 50.0).unwrap().id(), a);
    assert_eq!(d.hit(60.0, -40.0).unwrap().id(), g);
    assert!(d.hit(5000.0, 0.0).is_none());
    // рамка
    let sel = d.in_rect(0.0, 0.0, 200.0, 200.0);
    assert_eq!(sel, vec![a.clone()]);
    d.remove(std::slice::from_ref(&a));
    assert!(d.edges.is_empty(), "провод ушёл вместе с нодой");
}

#[test]
fn copy_paste_group_rename() {
    let mut d = Doc::parse(OBS).unwrap();
    let ids = vec!["a1".to_string(), "b2".to_string()];
    let made = d.duplicate(&ids);
    assert_eq!(made.len(), 2);
    assert_eq!(d.nodes.len(), 5);
    assert_eq!(d.edges.len(), 2, "провод между копиями тоже скопирован");
    assert!(d.paste("просто текст", 0.0, 0.0).is_none());
    let g = d.group_around(&ids, "Новая").unwrap();
    assert_eq!(d.nodes[0].id(), g);
    assert_eq!(d.rename_file("DND/Таверна.md", "DND/Корчма.md"), 2, "и в копии");
    assert_eq!(d.node("b2").unwrap().title(), "Корчма");
    // провод находится по точке на кривой
    let c = edge_curve(&d.edges[0].clone(), d.node("a1").unwrap(), d.node("b2").unwrap());
    let (x, y) = c.at(0.5);
    assert_eq!(d.edge_at(x, y + 3.0, 8.0).as_deref(), Some("e1"));
}

#[test]
fn sides_and_history() {
    let d = Doc::parse(OBS).unwrap();
    let n = d.node("b2").unwrap();
    assert_eq!(nearest_side(n, 402.0, 100.0), Side::Left);
    assert_eq!(nearest_side(n, 550.0, 199.0), Side::Bottom);
    let mut h = History::default();
    h.push("1".into());
    h.push("2".into());
    assert_eq!(h.undo("3".into()).as_deref(), Some("2"));
    assert_eq!(h.redo("2".into()).as_deref(), Some("3"));
    h.push("3".into());
    assert!(h.redo("x".into()).is_none(), "новая правка стирает «вперёд»");
}

#[test]
fn auto_layout_no_overlap() {
    let mut d = Doc::default();
    let ids: Vec<String> = (0..8).map(|i| d.add("text", 0.0, 0.0, 250.0, 120.0, &format!("{i}"))).collect();
    for w in ids.windows(2) {
        d.connect(&w[0], &w[1], None, None);
    }
    d.auto_layout();
    for (i, a) in d.nodes.iter().enumerate() {
        for b in d.nodes.iter().skip(i + 1) {
            let over = a.x() < b.x() + b.w() && b.x() < a.x() + a.w() && a.y() < b.y() + b.h() && b.y() < a.y() + a.h();
            assert!(!over, "ноды не налезают");
        }
    }
}

#[test]
fn auto_layout_keeps_group_members_inside() {
    let mut d = Doc::default();
    let g = d.add("group", 0.0, 0.0, 800.0, 600.0, "");
    let a = d.add("text", 40.0, 60.0, 250.0, 120.0, "a");
    let b = d.add("text", 400.0, 300.0, 250.0, 120.0, "b");
    let c = d.add("text", 1200.0, 0.0, 250.0, 120.0, "c");
    d.connect(&a, &b, None, None);
    d.connect(&b, &c, None, None);
    d.auto_layout();
    let gn = d.node(&g).unwrap().clone();
    let inside = d.inside(&gn);
    assert!(inside.contains(&a) && inside.contains(&b) && !inside.contains(&c));
    assert!(d.node(&a).unwrap().x() < d.node(&b).unwrap().x(), "слева направо по проводам");
}
