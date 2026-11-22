use sputnik_core::mdtable::{cells, edit_text, is_sep, Align, Table};

fn t(s: &str) -> Table {
    let lines: Vec<&str> = s.lines().collect();
    Table::parse(&lines)
}

const T: &str = "| Имя | Срок |\n|:---|---:|\n| Бэ | 2 |\n| а | 10 |";

#[test]
fn parses_head_align_and_pipes() {
    let x = t(T);
    assert!(x.head);
    assert_eq!((x.rows(), x.cols()), (3, 2));
    assert_eq!(x.align, vec![Align::Left, Align::Right]);
    assert_eq!(cells(r"| a \| b | [[x\|y]] |"), vec!["a | b", "[[x|y]]"]);
    assert!(is_sep("|---|:-:|") && !is_sep("| a | b |"));
    // строки разной длины выравниваются по самой длинной
    assert_eq!(t("| a |\n| b | c |").cols(), 2);
}

#[test]
fn untouched_lines_stay_as_they_were() {
    let src = "|  Имя   | Срок |\n| :--- | ---: |\n|Бэ|2|\n| а | 10 |";
    let mut x = t(src);
    assert_eq!(x.lines().join("\n"), src);
    assert!(x.set(2, 1, "11"));
    assert_eq!(x.lines(), vec!["|  Имя   | Срок |", "| :--- | ---: |", "|Бэ|2|", "| а | 11 |"]);
    assert!(!x.set(2, 1, "11"));
}

#[test]
fn cell_text_escapes_pipes_and_breaks() {
    let mut x = t(T);
    x.set(1, 0, "a|b\nвторая");
    assert_eq!(x.lines()[2], r"| a\|b<br>вторая | 2 |");
    assert_eq!(edit_text(x.cell(1, 0)), "a|b\nвторая");
}

#[test]
fn rows_insert_move_delete() {
    let mut x = t(T);
    // над шапкой нельзя — встаёт первой строкой тела
    assert_eq!(x.op("row-above", 0, 1), Some((1, 1)));
    assert_eq!(x.rows(), 4);
    assert_eq!(x.op("row-del", 1, 0), Some((1, 0)));
    assert_eq!(x.op("row-down", 1, 0), Some((2, 0)));
    assert_eq!(x.cell(2, 0), "Бэ");
    assert_eq!(x.op("row-up", 1, 0), None);
    assert_eq!(x.op("row-up", 2, 0), Some((1, 0)));
    assert_eq!(x.op("row-dup", 1, 0), Some((2, 0)));
    assert_eq!(x.cell(2, 0), "Бэ");
    assert_eq!(x.op("row-del", 0, 0), None, "шапку не удаляем");
    assert_eq!(x.op("row-below", 3, 0), Some((4, 0)));
    assert_eq!(x.lines()[5], "|  |  |");
}

#[test]
fn columns_insert_move_delete() {
    let mut x = t(T);
    assert_eq!(x.op("col-left", 1, 0), Some((1, 0)));
    assert_eq!(x.lines(), vec!["|  | Имя | Срок |", "|---|:---|---:|", "|  | Бэ | 2 |", "|  | а | 10 |"]);
    assert_eq!(x.op("col-move-right", 0, 0), Some((0, 1)));
    assert_eq!(x.lines()[0], "| Имя |  | Срок |");
    assert_eq!(x.lines()[1], "|:---|---|---:|");
    assert_eq!(x.op("col-move-left", 0, 0), None);
    assert_eq!(x.op("col-dup", 0, 2), Some((0, 3)));
    assert_eq!(x.lines()[0], "| Имя |  | Срок | Срок |");
    assert_eq!(x.op("col-del", 0, 1), Some((0, 1)));
    assert_eq!(x.op("col-del", 0, 2), Some((0, 1)));
    assert_eq!(x.lines()[0], "| Имя | Срок |");
    x.op("col-del", 0, 0);
    assert_eq!(x.op("col-del", 0, 0), Some((0, 0)));
    assert_eq!(x.rows(), 0, "последняя колонка — таблица убирается");
}

#[test]
fn align_and_sort() {
    let mut x = t(T);
    assert_eq!(x.op("align-center", 0, 0), Some((0, 0)));
    assert_eq!(x.op("align-center", 0, 0), None);
    assert_eq!(x.lines()[1], "|:---:|---:|");
    x.op("sort-asc", 0, 1);
    assert_eq!((x.cell(1, 1), x.cell(2, 1)), ("2", "10"), "числа — как числа");
    x.op("sort-asc", 0, 0);
    assert_eq!((x.cell(1, 0), x.cell(2, 0)), ("а", "Бэ"), "без учёта регистра");
    x.op("sort-desc", 0, 0);
    assert_eq!(x.cell(1, 0), "Бэ");
    assert_eq!(x.cell(0, 0), "Имя", "шапка на месте");
    // таблица без шапки: выравнивание делает первую строку шапкой
    let mut y = t("| a | b |\n| c | d |");
    assert!(!y.head);
    y.op("align-right", 0, 1);
    assert_eq!(y.lines(), vec!["| a | b |", "|---|---:|", "| c | d |"]);
}

#[test]
fn widths_follow_content() {
    let x = t("| a | Очень длинное название колонки, которое не влезет |\n|---|---|\n| 1 | x |");
    let w = x.widths();
    assert_eq!(w[0], 4.0);
    assert_eq!(w[1], 24.0);
    let n = Table::new(3, 1);
    assert_eq!(n.lines(), vec!["| Колонка 1 | Колонка 2 | Колонка 3 |", "|---|---|---|", "|  |  |  |"]);
}
