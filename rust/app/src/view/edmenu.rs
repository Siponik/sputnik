//! Меню правки строки заметки (правый клик в тексте): правка, ссылка, поиск, оформление, абзац, вставка.
//! Сами правки делает поле строки (Slint) — сюда приходит только выбор команды.
use super::*;
use crate::MItem;

fn it(id: &str, label: &str, icon: &str, key: &str) -> MItem {
    MItem { id: ss(id), label: ss(label), icon: ss(icon), key: ss(key), ..Default::default() }
}

/// `m.id` — выделенный текст (может быть пустым).
pub fn items(m: &super::menu::Menu) -> (String, Vec<MItem>) {
    let sel = !m.id.is_empty();
    match m.sub.as_str() {
        "fmt" => (String::from("Оформление"), vec![
            it("bold", "Жирный", "edit", "**"),
            it("italic", "Курсив", "edit", "*"),
            it("strike", "Зачёркнутый", "edit", "~~"),
            it("mark", "Маркер", "star", "=="),
            it("code", "Код в строке", "keyboard", "`"),
            it("math", "Формула в строке", "edit", "$"),
            MItem { sep: true, ..it("clear", "Убрать оформление", "close", "") },
        ]),
        "par" => (String::from("Абзац"), vec![
            it("h1", "Заголовок 1", "note", "#"),
            it("h2", "Заголовок 2", "note", "##"),
            it("h3", "Заголовок 3", "note", "###"),
            it("p", "Обычный текст", "note", ""),
            MItem { sep: true, ..it("li", "Список", "sort", "-") },
            it("ol", "Нумерованный список", "sort", "1."),
            it("todo", "Чек-лист", "check", "[ ]"),
            it("quote", "Цитата", "read", ">"),
        ]),
        "ins" => (String::from("Вставить"), vec![
            it("table", "Таблица", "board", ""),
            it("callout", "Выноска", "info", ""),
            it("fence", "Блок кода", "keyboard", "```"),
            it("formula", "Формула", "edit", "$$"),
            it("footnote", "Сноска", "pin", "[^1]"),
            it("hr", "Линия", "move", "---"),
        ]),
        _ => (String::from("Правка"), vec![
            MItem { off: !sel, ..it("cut", "Вырезать", "move", "Ctrl X") },
            MItem { off: !sel, ..it("copy", "Копировать", "copy", "Ctrl C") },
            it("paste", "Вставить", "copy", "Ctrl V"),
            it("all", "Выделить всё", "check", "Ctrl A"),
            MItem { sep: true, ..it("link", if sel { "Сделать ссылкой [[…]]" } else { "Ссылка на заметку [[" }, "link", "") },
            MItem { off: !sel, ..it("ed-search", "Найти выделенное в заметках", "search", "") },
            MItem { sep: true, sub: true, ..it("sub:fmt", "Оформление", "edit", "") },
            MItem { sub: true, ..it("sub:par", "Абзац", "note", "") },
            MItem { sub: true, ..it("sub:ins", "Вставить", "plus", "") },
        ]),
    }
}

pub fn pick(u: &mut Ui, m: &super::menu::Menu, id: &str) {
    if id == "ed-search" {
        u.note_q = m.id.clone();
        u.note_graph = false;
        return;
    }
    u.ed_cmd = (id.to_string(), u.ed_cmd.1 + 1);
}
