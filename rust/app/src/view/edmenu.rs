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
        "fmt" => (String::from(t!("Оформление")), vec![
            it("bold", t!("Жирный"), "edit", "**"),
            it("italic", t!("Курсив"), "edit", "*"),
            it("strike", t!("Зачёркнутый"), "edit", "~~"),
            it("mark", t!("Маркер"), "star", "=="),
            it("code", t!("Код в строке"), "keyboard", "`"),
            it("math", t!("Формула в строке"), "edit", "$"),
            MItem { sep: true, ..it("clear", t!("Убрать оформление"), "close", "") },
        ]),
        "par" => (String::from(t!("Абзац")), vec![
            it("h1", t!("Заголовок 1"), "note", "#"),
            it("h2", t!("Заголовок 2"), "note", "##"),
            it("h3", t!("Заголовок 3"), "note", "###"),
            it("p", t!("Обычный текст"), "note", ""),
            MItem { sep: true, ..it("li", t!("Список"), "sort", "-") },
            it("ol", t!("Нумерованный список"), "sort", "1."),
            it("todo", t!("Чек-лист"), "check", "[ ]"),
            it("quote", t!("Цитата"), "read", ">"),
        ]),
        "ins" => (String::from(t!("Вставить")), vec![
            it("table", t!("Таблица"), "board", ""),
            it("callout", t!("Выноска"), "info", ""),
            it("fence", t!("Блок кода"), "keyboard", "```"),
            it("formula", t!("Формула"), "edit", "$$"),
            it("footnote", t!("Сноска"), "pin", "[^1]"),
            it("hr", t!("Линия"), "move", "---"),
        ]),
        _ => (String::from(t!("Правка")), vec![
            MItem { off: !sel, ..it("cut", t!("Вырезать"), "move", "Ctrl X") },
            MItem { off: !sel, ..it("copy", t!("Копировать"), "copy", "Ctrl C") },
            it("paste", t!("Вставить"), "copy", "Ctrl V"),
            it("all", t!("Выделить всё"), "check", "Ctrl A"),
            MItem { sep: true, ..it("link", if sel { t!("Сделать ссылкой [[…]]") } else { t!("Ссылка на заметку [[") }, "link", "") },
            MItem { off: !sel, ..it("ed-search", t!("Найти выделенное в заметках"), "search", "") },
            MItem { sep: true, sub: true, ..it("sub:fmt", t!("Оформление"), "edit", "") },
            MItem { sub: true, ..it("sub:par", t!("Абзац"), "note", "") },
            MItem { sub: true, ..it("sub:ins", t!("Вставить"), "plus", "") },
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
