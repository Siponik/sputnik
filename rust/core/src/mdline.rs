//! Строка заметки «как видно» ↔ «как в файле»: чтобы клик по оформленной строке ставил курсор
//! туда же в исходном тексте, а клик по ссылке открывал её.
//!
//! Разбирается то, что окно показывает оформленным: `[[Имя]]`, `[[Имя|подпись]]`, `[текст](адрес)`,
//! `**жирный**`, `__жирный__`, `*курсив*`, `_курсив_`, `` `код` ``, `~~зачёркнутый~~`, `\*` — экранирование.

/// Видимый текст строки и где каждый его символ лежит в исходнике.
#[derive(Debug, Default, PartialEq)]
pub struct Plain {
    /// Текст без разметки — как его рисует окно.
    pub text: String,
    /// Пары (смещение в `text`, смещение в исходнике) — на начало каждого символа и на конец текста.
    pub map: Vec<(usize, usize)>,
    /// Ссылки: (начало, конец) в `text` и куда ведёт.
    pub links: Vec<(usize, usize, String)>,
}

/// Куда попал клик по видимому тексту.
#[derive(Debug, PartialEq)]
pub enum Hit {
    /// Курсор в исходнике (байт).
    Caret(usize),
    /// Ссылка: название заметки или адрес.
    Link(String),
}

/// Разобрать кусок строки после значка («# », «- », «> »…).
pub fn plain(src: &str) -> Plain {
    let mut p = Plain::default();
    walk(src, 0, &mut p);
    p.map.push((p.text.len(), src.len()));
    p
}

fn push(p: &mut Plain, c: char, raw: usize) {
    p.map.push((p.text.len(), raw));
    p.text.push(c);
}

fn walk(s: &str, base: usize, p: &mut Plain) {
    let mut i = 0;
    while i < s.len() {
        let rest = &s[i..];
        // [[Имя]] / [[Имя|подпись]]
        if let Some(r) = rest.strip_prefix("[[") {
            if let Some(j) = r.find("]]") {
                let inner = &r[..j];
                if !inner.contains('\n') && !inner.trim().is_empty() {
                    let (target, label, loff) = match inner.split_once('|') {
                        Some((t, l)) => (t, l, t.len() + 1),
                        None => (inner, inner, 0),
                    };
                    let a = p.text.len();
                    for (k, c) in label.char_indices() {
                        push(p, c, base + i + 2 + loff + k);
                    }
                    p.links.push((a, p.text.len(), target.trim().to_string()));
                    i += 2 + j + 2;
                    continue;
                }
            }
        }
        // [текст](адрес)
        if rest.starts_with('[') && !rest.starts_with("[[") {
            if let Some(j) = rest.find("](") {
                if let Some(k) = rest[j + 2..].find(')') {
                    let label = &rest[1..j];
                    if !label.is_empty() && !label.contains('[') {
                        let url = rest[j + 2..j + 2 + k].trim_matches(['<', '>']).to_string();
                        let a = p.text.len();
                        walk(label, base + i + 1, p);
                        p.links.push((a, p.text.len(), url));
                        i += j + 2 + k + 1;
                        continue;
                    }
                }
            }
        }
        // `код` — внутри разметки нет
        if rest.starts_with('`') {
            if let Some(j) = rest[1..].find('`') {
                if j > 0 {
                    for (k, c) in rest[1..1 + j].char_indices() {
                        push(p, c, base + i + 1 + k);
                    }
                    i += j + 2;
                    continue;
                }
            }
        }
        // **x** __x__ ~~x~~ *x* _x_
        if let Some((mark, inner)) = emphasis(s, i) {
            walk(&s[i + mark..i + mark + inner], base + i + mark, p);
            i += mark * 2 + inner;
            continue;
        }
        // \* — сам символ
        if rest.starts_with('\\') {
            if let Some(c) = rest[1..].chars().next() {
                if c.is_ascii_punctuation() {
                    push(p, c, base + i + 1);
                    i += 1 + c.len_utf8();
                    continue;
                }
            }
        }
        let c = rest.chars().next().unwrap();
        push(p, c, base + i);
        i += c.len_utf8();
    }
}

/// Выделение с позиции `i`: (длина знака, длина текста внутри) — если есть пара.
fn emphasis(s: &str, i: usize) -> Option<(usize, usize)> {
    let rest = &s[i..];
    let mark = ["**", "__", "~~", "*", "_"].into_iter().find(|m| rest.starts_with(m))?;
    let ch = mark.chars().next().unwrap();
    let before = s[..i].chars().next_back();
    // «_» внутри слова (snake_case) — не выделение
    if ch == '_' && before.is_some_and(char::is_alphanumeric) {
        return None;
    }
    let body = &rest[mark.len()..];
    if body.starts_with(char::is_whitespace) || body.starts_with(ch) {
        return None;
    }
    let mut from = 0;
    while let Some(j) = body[from..].find(mark) {
        let at = from + j;
        let prev = body[..at].chars().next_back();
        let next = body[at + mark.len()..].chars().next();
        let ok = at > 0 && !prev.is_some_and(char::is_whitespace) && next != Some(ch)
            && !(ch == '_' && next.is_some_and(char::is_alphanumeric));
        if ok {
            return Some((mark.len(), at));
        }
        from = at + mark.len();
    }
    None
}

/// Клик по видимому тексту в байте `at`: ссылка или место курсора в исходнике `src`.
pub fn hit(src: &str, at: usize) -> Hit {
    let p = plain(src);
    if let Some((_, _, to)) = p.links.iter().find(|(a, b, _)| *a <= at && at <= *b && a < b) {
        return Hit::Link(to.clone());
    }
    Hit::Caret(caret(&p, at))
}

/// Место в исходнике для байта `at` видимого текста.
pub fn caret(p: &Plain, at: usize) -> usize {
    match p.map.binary_search_by_key(&at, |m| m.0) {
        Ok(k) => p.map[k].1,
        Err(k) => p.map.get(k).map_or(0, |m| m.1),
    }
}

/// Курсор в той же колонке на другой строке: `col` — номер символа, ответ — байт в `to`.
pub fn same_col(from: &str, byte: usize, to: &str) -> usize {
    let col = from.get(..byte.min(from.len())).map_or(0, |s| s.chars().count());
    to.char_indices().nth(col).map_or(to.len(), |(b, _)| b)
}
