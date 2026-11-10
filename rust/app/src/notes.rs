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
                    self.notes.push(Note { title: name.trim_end_matches(".md").to_string(), links: pr.links, tags: pr.tags, path: rel, body });
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
mod t {
    #[test]
    fn links() {
        assert_eq!(super::links_of("а [[Б|бэ]] и [[В#х]] [[Б]]"), vec!["Б", "В"]);
        let p = super::parse("# Заголовок\n\nтекст #идея и #3d-арт, не #12\n\n```\n[[НеСсылка]] #нет\n```\n- [ ] [[Задача]]");
        assert_eq!(p.title.as_deref(), Some("Заголовок"));
        assert_eq!(p.links, vec!["Задача"]);
        assert_eq!(p.tags, vec!["идея", "3d-арт"]);
    }
}
