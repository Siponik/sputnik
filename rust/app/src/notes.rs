//! «Знания»: папка Markdown-файлов — источник правды. Здесь — чтение папки, ссылки [[…]] и поиск;
//! правка файла — только по действию пользователя.
use std::path::PathBuf;

#[derive(Clone, Debug, Default)]
pub struct Note {
    pub path: String,
    pub title: String,
    pub body: String,
    pub links: Vec<String>,
    pub tags: Vec<String>,
    /// Свойства из шапки YAML (frontmatter): `тип`, `где` и т. п. — пары «ключ: значение».
    pub props: Vec<(String, String)>,
}

#[derive(Default)]
pub struct Notes {
    /// Слежение за папкой (notify, CC0): правка в Obsidian или проводнике сразу видна здесь.
    pub watcher: Option<notify::RecommendedWatcher>,
    pub root: Option<PathBuf>,
    pub notes: Vec<Note>,
    /// Раскладка графа — считается при перечитывании папки, не на каждый кадр.
    pub graph: (Vec<sputnik_core::graph::GNode>, Vec<(usize, usize)>),
}

/// Разбор заметки через pulldown-cmark (MIT): [[ссылки]] в любой форме ([[Имя]], [[Имя|подпись]], [[Имя#раздел]]),
/// #теги и первый заголовок. Внутри кода ссылок и тегов нет — их разбор берёт на себя библиотека.
#[derive(Default, Debug, PartialEq)]
pub struct Parsed {
    pub title: Option<String>,
    pub links: Vec<String>,
    pub tags: Vec<String>,
}

pub fn parse(body: &str) -> Parsed {
    use pulldown_cmark::{Event, HeadingLevel, LinkType, Options, Parser, Tag, TagEnd};
    let mut out = Parsed::default();
    let mut in_h1 = false;
    let mut h1 = String::new();
    let mut in_code = 0;
    for ev in Parser::new_ext(body, Options::ENABLE_WIKILINKS | Options::ENABLE_TASKLISTS) {
        match ev {
            Event::Start(Tag::Heading { level: HeadingLevel::H1, .. }) if out.title.is_none() => in_h1 = true,
            Event::End(TagEnd::Heading(HeadingLevel::H1)) if in_h1 => {
                in_h1 = false;
                out.title = Some(h1.trim().to_string()).filter(|x| !x.is_empty());
            }
            Event::Start(Tag::CodeBlock(_)) => in_code += 1,
            Event::End(TagEnd::CodeBlock) => in_code -= 1,
            Event::Start(Tag::Link { link_type: LinkType::WikiLink { .. }, dest_url, .. }) => {
                let name = dest_url.split('#').next().unwrap_or("").trim().to_string();
                if !name.is_empty() && !out.links.contains(&name) {
                    out.links.push(name);
                }
            }
            Event::Text(t) => {
                if in_h1 {
                    h1.push_str(&t);
                }
                if in_code == 0 {
                    for w in t.split_whitespace() {
                        if let Some(tag) = w.strip_prefix('#') {
                            let tag: String = tag.chars().take_while(|c| c.is_alphanumeric() || *c == '_' || *c == '-' || *c == '/').collect();
                            if !tag.is_empty() && !tag.chars().all(|c| c.is_ascii_digit()) && !out.tags.contains(&tag) {
                                out.tags.push(tag);
                            }
                        }
                    }
                }
            }
            _ => {}
        }
    }
    out
}

pub fn links_of(body: &str) -> Vec<String> {
    parse(body).links
}

/// Шапка YAML в начале файла: строки «ключ: значение» между первой `---` и следующей `---`.
pub fn frontmatter(body: &str) -> Vec<(String, String)> {
    let mut lines = body.lines();
    if lines.next().map(str::trim) != Some("---") {
        return vec![];
    }
    let mut out = vec![];
    for l in lines {
        let l = l.trim_end();
        if l.trim() == "---" {
            break;
        }
        if let Some((k, v)) = l.split_once(':') {
            let k = k.trim();
            let v = v.trim().trim_matches('"');
            if !k.is_empty() && !v.is_empty() {
                out.push((k.to_string(), v.to_string()));
            }
        }
    }
    out
}

/// Тело без шапки YAML (по ссылке, без копий). Переводы строк могут быть и `\r\n` (Windows).
pub fn body_without_front(body: &str) -> &str {
    let mut it = body.split_inclusive('\n');
    if it.next().map(str::trim) != Some("---") {
        return body;
    }
    let mut off = body.split_inclusive('\n').next().map_or(0, str::len);
    for l in it {
        off += l.len();
        if l.trim() == "---" {
            return &body[off..];
        }
    }
    body
}

/// Свободное имя файла для новой заметки: `Имя.md`, занято — `Имя 2.md`, `Имя 3.md`…
pub fn free_name(name: &str, taken: impl Fn(&str) -> bool) -> String {
    let first = format!("{name}.md");
    if !taken(&first) {
        return first;
    }
    (2..).map(|i| format!("{name} {i}.md")).find(|p| !taken(p)).unwrap()
}

/// Строка заметки для живого вида: (вид, исходный текст строки, текст в разметке StyledText).
/// Одна запись на каждую строку после шапки YAML — номер записи = номер строки тела.
/// Виды: h1 h2 h3 li todo done quote code fence hr img p empty.
pub fn line_blocks(body: &str) -> Vec<(String, String, String)> {
    let mut out = vec![];
    let mut code = false;
    for raw in body_without_front(body).split('\n') {
        let l = raw.trim_end_matches('\r');
        let t = l.trim();
        let (kind, rest): (&str, &str) = if t.starts_with("```") {
            code = !code;
            ("fence", "")
        } else if code {
            ("code", l)
        } else if t.is_empty() {
            ("empty", "")
        } else if let Some(x) = t.strip_prefix("### ") {
            ("h3", x)
        } else if let Some(x) = t.strip_prefix("## ") {
            ("h2", x)
        } else if let Some(x) = t.strip_prefix("# ") {
            ("h1", x)
        } else if t == "---" || t == "***" {
            ("hr", "")
        } else if let Some(x) = t.strip_prefix("- [ ]") {
            ("todo", x.trim())
        } else if let Some(x) = t.strip_prefix("- [x]").or_else(|| t.strip_prefix("- [X]")) {
            ("done", x.trim())
        } else if let Some(x) = t.strip_prefix("- ").or_else(|| t.strip_prefix("* ")) {
            ("li", x)
        } else if let Some(x) = t.strip_prefix("> ") {
            ("quote", x)
        } else if t.starts_with("![[") || (t.starts_with("![") && t.ends_with(')')) {
            ("img", t.trim_start_matches('!').trim_start_matches('[').trim_end_matches([')', ']']))
        } else {
            ("p", t)
        };
        let md = if kind == "code" { rest.to_string() } else { inline_md(rest) };
        out.push((kind.to_string(), l.to_string(), md));
    }
    out
}

/// [[Заметка]] и [[Заметка|подпись]] → ссылка Markdown `[подпись](Заметка)`, остальное как есть.
pub fn inline_md(s: &str) -> String {
    let mut r = String::new();
    let mut rest = s;
    while let Some(a) = rest.find("[[") {
        let Some(b) = rest[a + 2..].find("]]") else { break };
        let inner = &rest[a + 2..a + 2 + b];
        let (target, label) = inner.split_once('|').unwrap_or((inner, inner));
        r.push_str(&rest[..a]);
        r.push_str(&format!("[{}](<{}>)", label.trim(), target.trim()));
        rest = &rest[a + 2 + b + 2..];
    }
    r.push_str(rest);
    r
}

/// Сколько строк в начале файла занимает шапка YAML (0 — шапки нет).
pub fn front_lines(body: &str) -> usize {
    let skip = body.len() - body_without_front(body).len();
    body[..skip].matches('\n').count()
}

/// Заменить строку тела `i` (без шапки) на `lines` (одну или несколько строк).
pub fn replace_line(body: &str, i: usize, lines: &[&str], drop: usize) -> String {
    let f = front_lines(body);
    let mut all: Vec<&str> = body.split('\n').collect();
    let at = (f + i).min(all.len());
    let end = (at + drop).min(all.len());
    all.splice(at..end, lines.iter().copied());
    all.join("\n")
}

impl Notes {
    /// Следить за папкой: события копятся 400 мс, потом одно перечитывание в потоке окна.
    pub fn watch(&mut self) {
        use notify::Watcher;
        use std::sync::atomic::{AtomicBool, Ordering};
        use std::sync::Arc;
        self.watcher = None;
        let Some(root) = self.root.clone() else { return };
        let pending = Arc::new(AtomicBool::new(false));
        let w = notify::recommended_watcher(move |ev: notify::Result<notify::Event>| {
            let Ok(ev) = ev else { return };
            if !ev.paths.iter().any(|p| p.extension().is_some_and(|e| e == "md") || p.extension().is_none()) {
                return;
            }
            if pending.swap(true, Ordering::SeqCst) {
                return;
            }
            let pending = pending.clone();
            std::thread::spawn(move || {
                std::thread::sleep(std::time::Duration::from_millis(400));
                pending.store(false, Ordering::SeqCst);
                let _ = slint::invoke_from_event_loop(|| {
                    crate::state::with(|a| a.notes.rescan());
                });
            });
        });
        if let Ok(mut w) = w {
            if w.watch(&root, notify::RecursiveMode::Recursive).is_ok() {
                self.watcher = Some(w);
            }
        }
    }

    pub fn load() -> Notes {
        let root = crate::data::store::read("notes.json")
            .and_then(|v| v["root"].as_str().map(PathBuf::from))
            .or_else(|| Some(crate::data::store::own("notes")));
        let mut n = Notes { root, ..Default::default() };
        n.rescan();
        n
    }

    pub fn rescan(&mut self) {
        self.notes.clear();
        let Some(root) = self.root.clone() else { return };
        let mut stack = vec![root.clone()];
        while let Some(d) = stack.pop() {
            let Ok(rd) = std::fs::read_dir(&d) else { continue };
            for e in rd.flatten() {
                let p = e.path();
                let name = e.file_name().to_string_lossy().to_string();
                if name.starts_with('.') {
                    continue;
                }
                if p.is_dir() {
                    stack.push(p);
                } else if name.ends_with(".md") {
                    let body = std::fs::read_to_string(&p).unwrap_or_default();
                    let rel = p.strip_prefix(&root).unwrap_or(&p).to_string_lossy().replace('\\', "/");
                    let pr = parse(&body);
                    self.notes.push(Note { title: name.trim_end_matches(".md").to_string(), links: pr.links, tags: pr.tags, props: frontmatter(&body), path: rel, body });
                }
            }
        }
        self.notes.sort_by(|a, b| a.path.cmp(&b.path));
        self.relayout();
    }

    pub fn relayout(&mut self) {
        let src: Vec<_> = self.notes.iter().map(|n| (n.path.clone(), n.title.clone(), n.links.clone())).collect();
        self.graph = sputnik_core::graph::build(&src, true);
    }

    pub fn find(&self, title: &str) -> Option<&Note> {
        let t = title.to_lowercase();
        self.notes.iter().find(|n| n.title.to_lowercase() == t)
    }

    pub fn backlinks(&self, title: &str) -> Vec<&Note> {
        let t = title.to_lowercase();
        self.notes.iter().filter(|n| n.links.iter().any(|l| l.to_lowercase() == t)).collect()
    }

    pub fn search(&self, q: &str) -> Vec<&Note> {
        let words: Vec<String> = q.to_lowercase().replace('ё', "е").split_whitespace().map(String::from).collect();
        self.notes.iter().filter(|n| {
            let hay = format!("{} {}", n.title, n.body).to_lowercase().replace('ё', "е");
            words.iter().all(|w| hay.contains(w.as_str()))
        }).collect()
    }

    /// Сохранить заметку (только по действию пользователя).
    pub fn save(&mut self, path: &str, body: &str) -> std::io::Result<()> {
        let Some(root) = &self.root else { return Ok(()) };
        let p = root.join(path);
        if let Some(d) = p.parent() {
            std::fs::create_dir_all(d)?;
        }
        std::fs::write(&p, body)?;
        self.rescan();
        Ok(())
    }
}

#[cfg(test)]
mod live_tests {
    use super::*;
    #[test]
    fn lines_and_links() {
        let b = "---\ntags: [a]\n---\n# Заголовок\n\nТекст про [[Металл|металл]].";
        let l = line_blocks(b);
        assert_eq!(l.len(), 3);
        assert_eq!(l[0].0, "h1");
        assert_eq!(l[2].2, "Текст про [металл](<Металл>).");
        assert_eq!(replace_line(b, 1, &["новое", ""], 1), "---\ntags: [a]\n---\n# Заголовок\nновое\n\nТекст про [[Металл|металл]].");
        assert_eq!(replace_line(b, 2, &[], 1), "---\ntags: [a]\n---\n# Заголовок\n");
    }
}

#[cfg(test)]
mod t {
    #[test]
    fn links() {
        assert_eq!(super::links_of("а [[Б|бэ]] и [[В#х]] [[Б]]"), vec!["Б", "В"]);
        let p = super::parse("# Заголовок\n\nтекст #идея и #3d-арт, не #12\n\n```\n[[НеСсылка]] #нет\n```\n- [ ] [[Задача]]");
        assert_eq!(p.title.as_deref(), Some("Заголовок"));
        assert_eq!(p.links, vec!["Задача"]);
        assert_eq!(p.tags, vec!["идея", "3d-арт"]);
    }

    #[test]
    fn front() {
        let b = "---\ntype: техника\ntags: [baking]\nгде: Substance\n---\n# Тело\nтекст";
        assert_eq!(super::frontmatter(b), vec![("type".into(), "техника".into()), ("tags".into(), "[baking]".into()), ("где".into(), "Substance".into())]);
        assert!(super::frontmatter("# Без шапки\nтекст").is_empty());
        assert!(super::body_without_front(b).starts_with("# Тело"));
        assert_eq!(super::body_without_front("# Без шапки\nтекст"), "# Без шапки\nтекст");
        // Windows: \r\n и русские буквы в шапке — тело не съезжает и не пропадает
        let w = "---\r\nгде: Substance\r\nтип: техника\r\n---\r\n# Тело\r\nтекст";
        assert_eq!(super::body_without_front(w), "# Тело\r\nтекст");
        assert_eq!(super::line_blocks(w)[0].0, "h1");
        assert_eq!(super::line_blocks(w)[0].2, "Тело");
    }

    #[test]
    fn free() {
        let have = ["Новая заметка.md", "Новая заметка 2.md"];
        assert_eq!(super::free_name("Идея", |p| have.contains(&p)), "Идея.md");
        assert_eq!(super::free_name("Новая заметка", |p| have.contains(&p)), "Новая заметка 3.md");
    }

    #[test]
    fn blocks() {
        let b = "---\ntype: x\n---\n# Раздел\n\nАбзац с [[Ссылка|подписью]] и [[Именем]].\n\n- пункт\n- [ ] сделать\n- [x] готово\n> цитата\n```\nlet x = [[не ссылка]];\n```\n---\n### Мелкий";
        let v: Vec<(String, String)> = super::line_blocks(b).into_iter().filter(|x| x.0 != "empty" && x.0 != "fence").map(|x| (x.0, x.2)).collect();
        assert_eq!(v[0], ("h1".into(), "Раздел".into()));
        assert_eq!(v[1], ("p".into(), "Абзац с [подписью](<Ссылка>) и [Именем](<Именем>).".into()));
        assert_eq!(v[2], ("li".into(), "пункт".into()));
        assert_eq!(v[3], ("todo".into(), "сделать".into()));
        assert_eq!(v[4], ("done".into(), "готово".into()));
        assert_eq!(v[5], ("quote".into(), "цитата".into()));
        assert_eq!(v[6], ("code".into(), "let x = [[не ссылка]];".into()));
        assert_eq!(v[7], ("hr".into(), "".into()));
        assert_eq!(v[8], ("h3".into(), "Мелкий".into()));
    }
}
