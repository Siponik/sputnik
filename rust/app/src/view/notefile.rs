//! «Знания»: действия с файлами заметок — переименовать (со ссылками в других заметках и на холстах),
//! удалить в корзину `.trash` (как Obsidian), новая заметка из шаблона папки «Шаблоны», «Связать» упоминание.
use super::*;
use sputnik_core::notefile as nf;

const TEMPLATES: &str = "Шаблоны/";

pub fn clean(name: &str) -> String {
    name.chars().filter(|c| !"/\\:*?\"<>|".contains(*c)).collect::<String>().trim().to_string()
}

/// Имя без папки и расширения.
fn stem(path: &str) -> &str {
    let name = path.rsplit('/').next().unwrap_or(path);
    name.strip_suffix(".md").or_else(|| name.strip_suffix(".canvas")).unwrap_or(name)
}

/// Шаблоны: заметки из папки «Шаблоны» (путь, название).
pub fn templates(app: &App) -> Vec<(String, String)> {
    app.notes.notes.iter().filter(|n| n.path.starts_with(TEMPLATES)).map(|n| (n.path.clone(), n.title.clone())).collect()
}

/// Окно «Переименовать»: поле с нынешним названием.
pub fn ask_rename(u: &mut Ui, path: String) {
    u.ask_field = Some(stem(&path).to_string());
    let q = if super::canvas::is_canvas(&path) { "Новое название холста" } else { "Новое название заметки — ссылки на неё в других заметках и на холстах обновятся" };
    super::wire::ask(u, q, "Переименовать", move |app, u| {
        let name = clean(&u.answer);
        rename(app, u, &path, &name);
    });
}

pub fn rename(app: &mut App, u: &mut Ui, path: &str, name: &str) {
    let old = stem(path).to_string();
    if name.is_empty() || name == old {
        return;
    }
    let Some(root) = app.notes.root.clone() else { return };
    super::wire::save_draft(app, u);
    let ext = if super::canvas::is_canvas(path) { ".canvas" } else { ".md" };
    let dir = path.rfind('/').map_or("", |k| &path[..k + 1]);
    let new_path = format!("{dir}{name}{ext}");
    if root.join(&new_path).exists() && !new_path.eq_ignore_ascii_case(path) {
        app.say(format!("«{name}» уже есть в этой папке"));
        return;
    }
    if let Err(e) = std::fs::rename(root.join(path), root.join(&new_path)) {
        app.say(format!("Не переименовалось: {e}"));
        return;
    }
    // ссылки: в заметках [[old]] → [[name]], на холстах — путь файла
    let mut files = 0;
    if ext == ".md" {
        for n in &app.notes.notes {
            if n.path == path {
                continue;
            }
            let (body, k) = nf::rename_links(&n.body, &old, name);
            if k > 0 && std::fs::write(root.join(&n.path), body).is_ok() {
                files += 1;
            }
        }
    }
    for c in app.notes.canvases.clone() {
        let p = root.join(&c);
        let Ok(text) = std::fs::read_to_string(&p) else { continue };
        let Ok(mut doc) = sputnik_core::canvas::Doc::parse(&text) else { continue };
        if doc.rename_file(path, &new_path) > 0 && std::fs::write(&p, doc.encode()).is_ok() {
            files += 1;
        }
    }
    for t in u.note_tabs.iter_mut().filter(|t| t.as_str() == path) {
        *t = new_path.clone();
    }
    if u.note_path == path {
        u.note_path = new_path.clone();
    }
    // открытый холст перечитать: в нём могли поменяться пути
    u.cv = None;
    app.notes.rescan();
    super::canvas::ensure(app, u);
    app.say(match files {
        0 => format!("Переименовано в «{name}»"),
        k => format!("Переименовано в «{name}», ссылки обновлены в {k} {}", plural(k)),
    });
}

fn plural(k: usize) -> &'static str {
    match (k % 10, k % 100) {
        (1, x) if x != 11 => "файле",
        _ => "файлах",
    }
}

/// Удалить в корзину: файл уходит в `.trash` папки заметок, вернуть можно руками (Obsidian делает так же).
pub fn ask_trash(app: &App, u: &mut Ui, path: String) {
    let back = if path.ends_with(".md") { app.notes.backlinks(stem(&path)).len() } else { 0 };
    let tail = if back > 0 { format!(" Ссылок на неё: {back} — они останутся, но станут «ещё не созданными».") } else { String::new() };
    super::wire::ask(u, format!("Удалить «{}» в корзину?{tail} Файл ляжет в папку .trash внутри папки заметок.", stem(&path)), "Удалить", move |app, u| {
        trash(app, u, &path);
    });
}

pub fn trash(app: &mut App, u: &mut Ui, path: &str) {
    let Some(root) = app.notes.root.clone() else { return };
    if u.note_path == path {
        super::wire::save_draft(app, u);
        u.note_dirty = false;
    }
    let to = sputnik_core::notefile::trash_path(path, |p| root.join(p).exists());
    if let Some(d) = root.join(&to).parent() {
        let _ = std::fs::create_dir_all(d);
    }
    if let Err(e) = std::fs::rename(root.join(path), root.join(&to)) {
        app.say(format!("Не удалилось: {e}"));
        return;
    }
    u.note_tabs.retain(|t| t != path);
    if u.note_path == path {
        u.note_path = u.note_tabs.last().cloned().unwrap_or_default();
    }
    if u.cv.as_ref().is_some_and(|c| c.path == path) {
        u.cv = None;
    }
    app.notes.rescan();
    super::canvas::ensure(app, u);
    app.say(format!("«{}» — в корзине (.trash)", stem(path)));
}

/// Новая заметка `title`; `tpl` — путь шаблона или пусто.
pub fn create(app: &mut App, u: &mut Ui, title: &str, tpl: &str) {
    let body = match app.notes.notes.iter().find(|n| n.path == tpl) {
        Some(t) => {
            let now = chrono::Local::now();
            let b = nf::fill_template(&t.body, title.trim(), &now.format("%Y-%m-%d").to_string(), &now.format("%H:%M").to_string());
            // в шаблоне нет своего заголовка — добавить
            if crate::notes::body_without_front(&b).trim_start().starts_with("# ") { b } else { add_title(&b, title.trim()) }
        }
        None => format!("# {}\n\n", title.trim()),
    };
    super::wire::new_note_with(app, u, title, &body);
}

fn add_title(b: &str, title: &str) -> String {
    let f = crate::notes::front_lines(b);
    let mut lines: Vec<&str> = b.split('\n').collect();
    let h = format!("# {title}");
    let at = f.min(lines.len());
    lines.insert(at, "");
    lines.insert(at, &h);
    lines.join("\n")
}

/// «Связать»: первое упоминание открытой заметки в заметке `path` делается ссылкой.
pub fn link_mention(app: &mut App, u: &mut Ui, path: &str) {
    let Some(title) = app.notes.notes.iter().find(|n| n.path == u.note_path).map(|n| n.title.clone()) else { return };
    let Some(body) = app.notes.notes.iter().find(|n| n.path == path).map(|n| n.body.clone()) else { return };
    match nf::link_mention(&body, &title) {
        Some(b) => match app.notes.save(path, &b) {
            Ok(()) => app.say(format!("Связано: в «{}» теперь ссылка", stem(path))),
            Err(e) => app.say(format!("Не сохранилось: {e}")),
        },
        None => app.say("Упоминание не нашлось — может, уже ссылка"),
    }
}

/// Предпросмотр ссылки: название, подпись (папка или «адрес»), первые строки заметки.
pub fn peek(app: &App, link: &str) -> (String, String, Vec<crate::MdRow>) {
    if link.contains("://") {
        return (link.to_string(), "адрес в интернете · откроется в браузере".into(), vec![]);
    }
    let Some(n) = app.notes.find(link) else {
        return (link.to_string(), "заметки ещё нет · Ctrl+клик создаст".into(), vec![]);
    };
    let dir = n.path.rsplit_once('/').map(|(d, _)| d.replace('/', " › ")).unwrap_or_default();
    let rows = crate::notes::line_rows(&n.body).into_iter()
        .filter(|r| r.kind != "empty" && !(r.kind == "h1" && r.plain.trim() == n.title.trim()))
        .take(7)
        .map(|r| crate::MdRow {
            kind: ss(r.kind),
            md: slint::StyledText::from_markdown(&r.md).unwrap_or_else(|_| slint::StyledText::from_plain_text(&r.md)),
            raw: ss(r.raw),
            plain: ss(r.plain),
        }).collect();
    (n.title.clone(), dir, rows)
}

/// Папка открытой заметки (для нового холста рядом), "" — корень.
pub fn cur_dir(u: &Ui) -> String {
    u.note_path.rsplit_once('/').map(|(d, _)| d.to_string()).unwrap_or_default()
}

/// «Папка…»: имя новой папки; в ней сразу заметка — пустые папки список не показывает.
pub fn ask_folder(u: &mut Ui) {
    u.ask_field = Some("Новая папка".into());
    super::wire::ask(u, "Название новой папки", "Создать", |app, u| {
        let name = clean(&u.answer);
        if name.is_empty() {
            return;
        }
        if app.notes.root.is_none() {
            app.notes.root = Some(crate::data::store::own("notes"));
            app.notes.watch();
        }
        let root = app.notes.root.clone().unwrap_or_default();
        if let Err(e) = std::fs::create_dir_all(root.join(&name)) {
            app.say(format!("Папка не создалась: {e}"));
            return;
        }
        let path = crate::notes::free_name(&format!("{name}/Новая заметка"), |p| root.join(p).exists());
        match app.notes.save(&path, "# Новая заметка\n\n") {
            Ok(()) => super::wire::open_note_tab(app, u, &path),
            Err(e) => app.say(format!("Заметка не создалась: {e}")),
        }
    });
}
