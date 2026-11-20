//! Таблицы в заметке (как редактор таблиц Obsidian): таблица рисуется целиком, ячейка правится на месте,
//! строки и колонки — по меню (правый клик, ручки) и клавишам. Сама логика — `sputnik_core::mdtable`.
use super::wire::{note_set_parts, note_text, save_draft};
use super::*;
use crate::MItem;
use sputnik_core::mdtable::{edit_text, Table};

/// Куда встать после правки таблицы: строка заметки (первая строка таблицы), строка и колонка таблицы,
/// номер (окно ловит смену), выделить ли весь текст ячейки.
#[derive(Clone, Copy, Default)]
pub struct Focus {
    pub line: i32,
    pub r: i32,
    pub c: i32,
    pub n: i32,
    pub all: bool,
}

/// Таблица заметки, где строка `line`: правка `f`, запись и сохранение. Ответ `f` — куда встать.
fn edit(app: &mut App, u: &mut Ui, line: usize, focus: bool, f: impl FnOnce(&mut Table) -> Option<(usize, usize)>) {
    let body = note_text(app, u);
    let Some((top, tn)) = crate::notes::table_at(&body, line) else { return };
    let rows = crate::notes::line_rows(&body);
    let lines: Vec<&str> = rows[top..top + tn].iter().map(|r| r.raw.as_str()).collect();
    let mut t = Table::parse(&lines);
    let Some((r, c)) = f(&mut t) else { return };
    let out = t.lines();
    let parts: Vec<&str> = if t.rows() == 0 { vec![] } else { out.iter().map(|s| s.as_str()).collect() };
    note_set_parts(app, u, top, &parts, tn);
    save_draft(app, u);
    if focus && t.rows() > 0 {
        u.tf = Focus { line: top as i32, r: r as i32, c: c as i32, n: u.tf.n + 1, all: false };
    }
}

fn table(app: &App, u: &Ui, line: usize) -> Option<Table> {
    let body = note_text(app, u);
    let (top, tn) = crate::notes::table_at(&body, line)?;
    let rows = crate::notes::line_rows(&body);
    let lines: Vec<&str> = rows[top..top + tn].iter().map(|r| r.raw.as_str()).collect();
    Some(Table::parse(&lines))
}

/// Таблица для окна: ячейки по строкам (с оформлением), ширина колонок, выравнивание.
fn model_of(block: &str) -> crate::TModel {
    if block.trim().is_empty() {
        return crate::TModel::default();
    }
    let lines: Vec<&str> = block.split('\n').collect();
    let t = Table::parse(&lines);
    let mut cells = vec![];
    for r in 0..t.rows() {
        for c in 0..t.cols() {
            let raw = t.cell(r, c);
            let text = edit_text(raw);
            // <br> — перенос строки: каждая часть — своё оформление (**жирный**, _курсив_, ссылки)
            let bold = t.head && r == 0;
            let md = text
                .split('\n')
                .map(|p| {
                    let x = crate::notes::inline_md(p.trim());
                    // шапка — жирная
                    if bold && !x.trim().is_empty() { format!("**{x}**") } else { x }
                })
                .collect::<Vec<_>>()
                .join("\n\n");
            cells.push(crate::MdRow {
                kind: ss("p"),
                raw: ss(raw),
                md: slint::StyledText::from_markdown(&md).unwrap_or_else(|_| slint::StyledText::from_plain_text(&text)),
                plain: ss(text),
                ..Default::default()
            });
        }
    }
    let w = t.widths();
    crate::TModel {
        rows: t.rows() as i32,
        cols: t.cols() as i32,
        head: t.head,
        sum: w.iter().sum(),
        w: model(w),
        align: model(t.align.iter().map(|a| a.code()).collect()),
        cells: model(cells),
    }
}

pub fn wire(g: &S) {
    g.on_table_model(|b| model_of(b.as_str()));
    g.on_note_tcell(|line, r, c, t| act(|app, u| {
        edit(app, u, line.max(0) as usize, false, |x| x.set(r.max(0) as usize, c.max(0) as usize, t.as_str()).then_some((0, 0)));
    }));
    g.on_note_top(|line, op, r, c| act(|app, u| {
        edit(app, u, line.max(0) as usize, true, |x| x.op(op.as_str(), r.max(0) as usize, c.max(0) as usize));
    }));
    // «Таблица»: шапка и две пустые строки после строки, где курсор (иначе в конец); курсор — в первую ячейку
    g.on_note_table(|i| act(|app, u| {
        let n = crate::notes::line_rows(&note_text(app, u)).len();
        let at = if i >= 0 { (i as usize + 1).min(n) } else { n };
        let lines = Table::new(3, 2).lines();
        let mut parts = vec![""];
        parts.extend(lines.iter().map(|s| s.as_str()));
        parts.push("");
        super::wire::note_set_parts(app, u, at, &parts, 0);
        save_draft(app, u);
        u.tf = Focus { line: at as i32 + 1, r: 0, c: 0, n: u.tf.n + 1, all: true };
    }));
}

pub fn render(u: &Ui, g: &S) {
    g.set_tf_line(u.tf.line);
    g.set_tf_r(u.tf.r);
    g.set_tf_c(u.tf.c);
    g.set_tf_all(u.tf.all);
    g.set_tf_n(u.tf.n);
}

fn it(id: &str, label: &str, icon: &str, key: &str) -> MItem {
    MItem { id: ss(id), label: ss(label), icon: ss(icon), key: ss(key), ..Default::default() }
}

/// `m.id` — «строка заметки:строка таблицы:колонка:что» (cell — ячейка, row — ручка строки, col — ручка колонки).
fn parse_id(id: &str) -> (usize, usize, usize, String) {
    let p: Vec<&str> = id.split(':').collect();
    let n = |k: usize| p.get(k).and_then(|x| x.parse().ok()).unwrap_or(0);
    (n(0), n(1), n(2), p.get(3).unwrap_or(&"cell").to_string())
}

pub fn items(app: &App, u: &Ui, m: &super::menu::Menu) -> (String, Vec<MItem>) {
    let (line, r, c, part) = parse_id(&m.id);
    let Some(t) = table(app, u, line) else { return (String::from("Таблица"), vec![]) };
    let head = t.head && r == 0;
    let b0 = usize::from(t.head);
    let al = t.align.get(c).map(|a| a.code()).unwrap_or(0);
    let mut row = vec![
        it("row-above", "Строка выше", "plus", ""),
        it("row-below", "Строка ниже", "plus", "Ctrl Enter"),
        it("row-dup", "Дублировать строку", "copy", ""),
        MItem { sep: true, off: r <= b0, ..it("row-up", "Переместить вверх", "prev", "Alt ↑") },
        MItem { off: head || r + 1 >= t.rows(), ..it("row-down", "Переместить вниз", "next", "Alt ↓") },
    ];
    if !head {
        row.push(MItem { sep: true, red: true, ..it("row-del", "Удалить строку", "trash", "") });
    }
    let col = vec![
        it("col-left", "Колонка слева", "plus", ""),
        it("col-right", "Колонка справа", "plus", ""),
        it("col-dup", "Дублировать колонку", "copy", ""),
        MItem { sep: true, off: c == 0, ..it("col-move-left", "Переместить влево", "prev", "Alt ←") },
        MItem { off: c + 1 >= t.cols(), ..it("col-move-right", "Переместить вправо", "next", "Alt →") },
        MItem { sep: true, sub: true, ..it("sub:align", "Выравнивание", "sort", "") },
        MItem { sub: true, ..it("sub:sort", "Сортировка", "sort", "") },
        MItem { sep: true, red: true, ..it("col-del", "Удалить колонку", "trash", "") },
    ];
    let sub = if m.sub.is_empty() { part.as_str() } else { m.sub.as_str() };
    match sub {
        "align" => (String::from("Выравнивание колонки"), vec![
            MItem { on: al <= 1, ..it("align-left", "По левому краю", "sort", "") },
            MItem { on: al == 2, ..it("align-center", "По центру", "sort", "") },
            MItem { on: al == 3, ..it("align-right", "По правому краю", "sort", "") },
        ]),
        "sort" => (String::from("Сортировка строк"), vec![
            it("sort-asc", "По возрастанию · А→Я, 1→9", "sort", ""),
            it("sort-desc", "По убыванию · Я→А, 9→1", "sort", ""),
        ]),
        "row" => (String::from("Строка"), row),
        "col" => (String::from("Колонка"), col),
        _ => {
            let mut v = vec![
                it("row-above", "Строка выше", "plus", ""),
                it("row-below", "Строка ниже", "plus", "Ctrl Enter"),
                it("col-left", "Колонка слева", "plus", ""),
                it("col-right", "Колонка справа", "plus", ""),
                MItem { sep: true, sub: true, ..it("sub:row", "Строка", "sort", "") },
                MItem { sub: true, ..it("sub:col", "Колонка", "board", "") },
                MItem { sub: true, ..it("sub:align", "Выравнивание", "sort", "") },
                MItem { sub: true, ..it("sub:sort", "Сортировка", "sort", "") },
            ];
            // шапку не удаляем — только колонку или всю таблицу
            if !head {
                v.push(MItem { sep: true, red: true, ..it("row-del", "Удалить строку", "trash", "") });
            }
            v.push(MItem { sep: head, red: true, ..it("col-del", "Удалить колонку", "trash", "") });
            v.push(MItem { sep: true, red: true, ..it("table-del", "Удалить таблицу", "trash", "") });
            (String::from("Таблица"), v)
        }
    }
}

pub fn pick(app: &mut App, u: &mut Ui, m: &super::menu::Menu, id: &str) {
    let (line, r, c, _) = parse_id(&m.id);
    edit(app, u, line, true, |x| x.op(id, r, c));
}
