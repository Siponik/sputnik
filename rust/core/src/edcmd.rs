//! Команды меню правки строки заметки: оформление выделения, вид абзаца, вставки.
//! На входе — текст строки и выделение (байты), на выходе — новый текст и новое выделение.

fn snap(t: &str, mut i: usize) -> usize {
    i = i.min(t.len());
    while !t.is_char_boundary(i) {
        i -= 1;
    }
    i
}

/// Знаки оформления по команде.
fn mark(cmd: &str) -> Option<&'static str> {
    Some(match cmd {
        "bold" => "**",
        "italic" => "*",
        "strike" => "~~",
        "mark" => "==",
        "code" => "`",
        "math" => "$",
        _ => return None,
    })
}

/// Начало строки, отвечающее за вид абзаца (`# `, `- [ ] `, `1. `, `> `…).
fn prefix_len(t: &str) -> usize {
    let s = t.trim_start();
    let lead = t.len() - s.len();
    for p in ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "> ", "### ", "## ", "# "] {
        if s.starts_with(p) {
            return lead + p.len();
        }
    }
    let d = s.chars().take_while(|c| c.is_ascii_digit()).count();
    if d > 0 && s[d..].starts_with(". ") {
        return lead + d + 2;
    }
    0
}

pub fn apply(t: &str, a: usize, b: usize, cmd: &str) -> (String, usize, usize) {
    let (a, b) = (snap(t, a.min(b)), snap(t, a.max(b)));
    if let Some(m) = mark(cmd) {
        let sel = &t[a..b];
        // уже обёрнуто — снять
        if sel.len() >= 2 * m.len() && sel.starts_with(m) && sel.ends_with(m) {
            let inner = &sel[m.len()..sel.len() - m.len()];
            return (format!("{}{inner}{}", &t[..a], &t[b..]), a, a + inner.len());
        }
        if a >= m.len() && t[..a].ends_with(m) && t[b..].starts_with(m) {
            let s = a - m.len();
            return (format!("{}{sel}{}", &t[..s], &t[b + m.len()..]), s, s + sel.len());
        }
        return (format!("{}{m}{sel}{m}{}", &t[..a], &t[b..]), a + m.len(), b + m.len());
    }
    if cmd == "clear" {
        let (s, e) = if a == b { (0, t.len()) } else { (a, b) };
        let mut mid = t[s..e].to_string();
        for m in ["**", "~~", "==", "`", "*", "$"] {
            mid = mid.replace(m, "");
        }
        return (format!("{}{mid}{}", &t[..s], &t[e..]), s, s + mid.len());
    }
    if cmd == "link" {
        let sel = &t[a..b];
        return (format!("{}[[{sel}]]{}", &t[..a], &t[b..]), a + 2, b + 2);
    }
    let par = match cmd {
        "h1" => Some("# "),
        "h2" => Some("## "),
        "h3" => Some("### "),
        "p" => Some(""),
        "li" => Some("- "),
        "ol" => Some("1. "),
        "todo" => Some("- [ ] "),
        "quote" => Some("> "),
        _ => None,
    };
    if let Some(p) = par {
        let k = prefix_len(t);
        let body = &t[k..];
        let shift = |x: usize| (x.max(k) - k + p.len()) as isize;
        return (format!("{p}{body}"), shift(a) as usize, shift(b) as usize);
    }
    let block = match cmd {
        "table" => "| Колонка 1 | Колонка 2 | Колонка 3 |\n|---|---|---|\n|  |  |  |",
        "callout" => "> [!note] Заметка\n> ",
        "hr" => "---",
        "fence" => "```\n\n```",
        "formula" => "$$\n\n$$",
        _ => "",
    };
    if cmd == "footnote" {
        let n = t.matches("[^").count() + 1;
        let tag = format!("[^{n}]");
        let out = format!("{}{tag}{}\n\n{tag}: ", &t[..b], &t[b..]);
        let end = out.len();
        return (out, end, end);
    }
    if !block.is_empty() {
        let sep = if t.trim().is_empty() { "" } else { "\n\n" };
        let head = format!("{t}{sep}");
        // курсор — в первую ячейку / внутрь блока
        let at = head.len() + match cmd { "table" => 2, "fence" | "formula" => 4, _ => block.len() };
        return (format!("{head}{block}"), at, at);
    }
    (t.to_string(), a, b)
}
