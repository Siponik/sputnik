//! Правки текста заметок при работе с файлами: переименование со ссылками, «Связать» упоминание,
//! новая заметка из шаблона.

/// Заменить в тексте ссылки на заметку `old` ссылками на `new`: `[[old]]`, `[[old|подпись]]`,
/// `[[old#раздел]]`, `![[old]]`, `[[папка/old]]`. Регистр названия не важен. Ответ — новый текст и число замен.
pub fn rename_links(body: &str, old: &str, new: &str) -> (String, usize) {
    let low = old.to_lowercase();
    let mut out = String::with_capacity(body.len());
    let mut n = 0;
    let mut rest = body;
    while let Some(i) = rest.find("[[") {
        let after = &rest[i + 2..];
        let Some(j) = after.find("]]") else { break };
        let inner = &after[..j];
        out.push_str(&rest[..i + 2]);
        let cut = inner.find(['|', '#']).unwrap_or(inner.len());
        let target = &inner[..cut];
        let t = target.trim();
        let (dir, name) = match t.rfind('/') {
            Some(k) => (&t[..k + 1], &t[k + 1..]),
            None => ("", t),
        };
        let name_md = name.strip_suffix(".md").unwrap_or(name);
        if !inner.contains('\n') && name_md.to_lowercase() == low {
            out.push_str(dir);
            out.push_str(new);
            if name.ends_with(".md") {
                out.push_str(".md");
            }
            out.push_str(&inner[cut..]);
            n += 1;
        } else {
            out.push_str(inner);
        }
        out.push_str("]]");
        rest = &after[j + 2..];
    }
    out.push_str(rest);
    (out, n)
}

/// Первое упоминание `title` обычным словом (не внутри `[[…]]`, не часть другого слова) сделать ссылкой.
/// Написано иначе по регистру — `[[Название|как в тексте]]`. Нет такого места — None.
pub fn link_mention(body: &str, title: &str) -> Option<String> {
    let tl: Vec<char> = title.to_lowercase().chars().collect();
    if tl.is_empty() {
        return None;
    }
    let idx: Vec<(usize, char)> = body.char_indices().collect();
    for s in 0..idx.len() {
        if s + tl.len() > idx.len() {
            break;
        }
        if (0..tl.len()).all(|k| idx[s + k].1.to_lowercase().eq(std::iter::once(tl[k]))) {
            let a = idx[s].0;
            let b = idx.get(s + tl.len()).map_or(body.len(), |x| x.0);
            if free_word(body, a, b) {
                return Some(wrap(body, a, b, title));
            }
        }
    }
    None
}

/// Место [a, b) — целое слово и не внутри ссылки `[[…]]`.
fn free_word(body: &str, a: usize, b: usize) -> bool {
    let before = body[..a].chars().next_back();
    let after = body[b..].chars().next();
    if before.is_some_and(char::is_alphanumeric) || after.is_some_and(char::is_alphanumeric) {
        return false;
    }
    // внутри [[ … ]]: последняя «[[» до места не закрыта
    let head = &body[..a];
    match (head.rfind("[["), head.rfind("]]")) {
        (Some(o), Some(c)) if o > c => false,
        (Some(_), None) => false,
        _ => true,
    }
}

fn wrap(body: &str, a: usize, b: usize, title: &str) -> String {
    let seen = &body[a..b];
    let link = if seen == title { format!("[[{title}]]") } else { format!("[[{title}|{seen}]]") };
    format!("{}{}{}", &body[..a], link, &body[b..])
}

/// Новая заметка из шаблона: `{{title}}`, `{{date}}` (ГГГГ-ММ-ДД), `{{time}}` (ЧЧ:ММ) — как в Obsidian.
pub fn fill_template(tpl: &str, title: &str, date: &str, time: &str) -> String {
    tpl.replace("{{title}}", title).replace("{{date}}", date).replace("{{time}}", time)
}

/// Куда положить удалённый файл: `.trash/<путь>`; занято — «Имя 2», «Имя 3»…
pub fn trash_path(path: &str, taken: impl Fn(&str) -> bool) -> String {
    let base = format!(".trash/{path}");
    if !taken(&base) {
        return base;
    }
    let (stem, ext) = match base.rfind('.') {
        Some(k) if k > base.rfind('/').unwrap_or(0) => (&base[..k], &base[k..]),
        _ => (base.as_str(), ""),
    };
    (2..).map(|i| format!("{stem} {i}{ext}")).find(|p| !taken(p)).unwrap_or(base.clone())
}
