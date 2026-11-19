use sputnik_core::calweek::*;

fn it(s: f64, e: f64, kind: i32) -> WItem {
    WItem { s: s * 60.0, e: e * 60.0, kind, done: false }
}

#[test]
fn range_default_and_auto() {
    assert_eq!(week_range(&[vec![]], None, None), (9, 19));
    // 08:00 и до 20:00 раздвигают сами, 07:00 и 21:00 — нет (уходят в чипы)
    let d = vec![vec![it(8.0, 9.0, 1), it(19.0, 20.0, 0), it(7.0, 7.5, 1), it(21.0, 22.0, 0)]];
    assert_eq!(week_range(&d, None, None), (8, 20));
    // клик по чипу раскрывает
    assert_eq!(week_range(&d, Some(7), Some(22)), (7, 22));
    // длинная привычка «Работа 08–17» — фон, часы не двигает
    assert_eq!(week_range(&[vec![it(8.0, 17.0, 2)]], None, None), (9, 19));
}

#[test]
fn outside_chips() {
    let d = vec![it(7.0, 7.5, 1), it(6.0, 6.5, 0), it(19.0, 20.0, 1), it(22.0, 23.0, 0), it(10.0, 11.0, 1), it(8.5, 9.5, 1)];
    let ((nb, fb), (na, fa)) = outside(&d, 9, 19);
    assert_eq!((nb, fb), (2, Some(360.0)));
    assert_eq!((na, fa), (2, Some(1140.0)));
    assert_eq!(chip_text(true, 1, 420.0), "↑ 07:00 · ЕЩЁ 1 РАНЬШЕ");
    assert_eq!(chip_text(false, 2, 1140.0), "↓ 19:00 · ЕЩЁ 2 ПОЗЖЕ");
}

#[test]
fn clusters_and_rows() {
    // 11–13 два дела вместе, 14:00 отдельно; привычка 08–17 — фон
    let d = vec![it(11.0, 12.0, 0), it(11.0, 13.0, 1), it(14.0, 15.0, 1), it(8.0, 17.0, 2)];
    let c = clusters(&d, 9, 19);
    assert_eq!(c, vec![vec![1, 0], vec![2]]);
    assert_eq!(cluster_hours(&d, &c[0], 9, 19), (11, 13));
    // нужно 23 + 2·28 = 79 на 2 часа → 40: часы не растут
    let h = row_heights(&[d.clone()], 9, 19);
    assert!(h.iter().all(|x| *x == 40.0));
    // 11:00–12:30 вдвоём: 79 на полтора часа → 53 px в 11 и 12
    let h = row_heights(&[vec![it(11.0, 12.0, 1), it(11.25, 12.5, 0)]], 9, 19);
    assert_eq!((h[1], h[2], h[3], h[4]), (40.0, 53.0, 53.0, 40.0));
    // четыре дела в одном часе: 22 + 4·28 = 134 → не больше ×2 = 80
    let many = vec![it(11.0, 12.0, 1), it(11.0, 12.0, 1), it(11.25, 12.0, 0), it(11.5, 12.0, 1)];
    let h = row_heights(&[vec![], many.clone()], 9, 19);
    assert_eq!(h[2], 80.0);
    assert_eq!(h[1], 40.0);
    // в блок 77 px: шапка 20 + «+N ещё» 16 → одна строка из четырёх
    assert_eq!(stack_fit(80.0 - 3.0, 4), (1, 3));
    assert_eq!(stack_fit(77.0, 2), (2, 0));
    assert_eq!(stack_fit(150.0, 4), (4, 0));
    // касающиеся дела (10–11 и 11–12) не группа
    assert_eq!(clusters(&[it(10.0, 11.0, 1), it(11.0, 12.0, 1)], 9, 19).len(), 2);
    // короткое дело (10 мин) считается получасовым: 10:00–10:10 и 10:20 — группа
    assert_eq!(clusters(&[WItem { s: 600.0, e: 610.0, kind: 1, done: false }, WItem { s: 620.0, e: 650.0, kind: 1, done: false }], 9, 19).len(), 1);
}

#[test]
fn grid_math() {
    let g = WeekGrid::new(&[vec![]], None, None);
    assert_eq!((g.r0, g.r1, g.height()), (9, 19, 400.0));
    assert_eq!(g.y_at(600.0), 40.0);
    assert_eq!(g.y_at(0.0), 0.0);
    assert_eq!(g.min_at(45.0, 15.0), 615.0);
    assert_eq!(g.min_at(10_000.0, 15.0), 1125.0);
    assert_eq!(g.place(600.0, 610.0), (41.0, MIN_H));
    assert!(show_time(630.0) && !show_time(600.0));
    assert!(one_line(&it(10.0, 10.5, 1)) && !one_line(&it(10.0, 11.0, 1)));
    assert_eq!(stack_head(2, 660.0, 780.0), "2 ДЕЛА · 11–13");
    assert_eq!(dur_text(120.0), "2 Ч");
    assert_eq!(dur_text(90.0), "1 Ч 30 МИН");
    assert_eq!(dur_text(45.0), "45 МИН");
}
