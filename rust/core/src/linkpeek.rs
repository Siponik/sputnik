//! Предпросмотр страницы для ссылки на холсте: название, описание, картинка и сайт из тегов
//! Open Graph (`og:title`…) или `<title>` — то же, что показывают мессенджеры.

#[derive(Debug, Default, Clone, PartialEq)]
pub struct Meta {
    pub title: String,
    pub desc: String,
    pub image: String,
    pub site: String,
}

/// Разобрать начало HTML-страницы `url`. Картинка — полным адресом.
pub fn parse(html: &str, url: &str) -> Meta {
    let mut m = Meta::default();
    let low = html.to_lowercase();
    let mut from = 0;
    while let Some(k) = low[from..].find("<meta").map(|k| from + k) {
        let end = low[k..].find('>').map_or(low.len(), |e| k + e);
        let tag = &html[k..end];
        let key = attr(tag, "property").or_else(|| attr(tag, "name")).unwrap_or_default().to_lowercase();
        let val = decode(&attr(tag, "content").unwrap_or_default());
        match key.as_str() {
            "og:title" | "twitter:title" if m.title.is_empty() => m.title = val,
            "og:description" | "twitter:description" | "description" if m.desc.is_empty() => m.desc = val,
            "og:image" | "og:image:url" | "twitter:image" if m.image.is_empty() => m.image = val,
            "og:site_name" if m.site.is_empty() => m.site = val,
            _ => {}
        }
        from = end;
    }
    if m.title.is_empty() {
        if let (Some(a), Some(b)) = (low.find("<title"), low.find("</title>")) {
            if let Some(gt) = low[a..].find('>').map(|g| a + g + 1) {
                if gt <= b {
                    m.title = decode(html[gt..b].trim());
                }
            }
        }
    }
    if !m.image.is_empty() {
        m.image = absolute(&m.image, url);
    }
    if m.site.is_empty() {
        m.site = host(url).trim_start_matches("www.").to_string();
    }
    m.title = m.title.split_whitespace().collect::<Vec<_>>().join(" ");
    m.desc = m.desc.split_whitespace().collect::<Vec<_>>().join(" ");
    m
}

fn attr(tag: &str, name: &str) -> Option<String> {
    let low = tag.to_lowercase();
    let mut from = 0;
    while let Some(k) = low[from..].find(name).map(|k| from + k) {
        let before_ok = k == 0 || low.as_bytes()[k - 1].is_ascii_whitespace();
        let rest = low[k + name.len()..].trim_start();
        if before_ok && rest.starts_with('=') {
            let off = tag.len() - rest.len() + 1;
            let r = tag[off..].trim_start();
            let q = r.chars().next()?;
            return Some(if q == '"' || q == '\'' {
                r[1..].split(q).next().unwrap_or("").to_string()
            } else {
                r.split(|c: char| c.is_whitespace() || c == '>').next().unwrap_or("").to_string()
            });
        }
        from = k + name.len();
    }
    None
}

fn decode(s: &str) -> String {
    s.replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'").replace("&#039;", "'").replace("&lt;", "<").replace("&gt;", ">").replace("&nbsp;", " ")
}

/// Хост адреса: `https://www.a.com/x` → `www.a.com`.
pub fn host(url: &str) -> &str {
    let rest = url.split_once("://").map_or(url, |p| p.1);
    rest.split(['/', '?', '#']).next().unwrap_or(rest)
}

fn absolute(src: &str, page: &str) -> String {
    if src.contains("://") {
        return src.to_string();
    }
    let scheme = page.split_once("://").map_or("https", |p| p.0);
    if let Some(r) = src.strip_prefix("//") {
        return format!("{scheme}://{r}");
    }
    let base = format!("{scheme}://{}", host(page));
    if src.starts_with('/') {
        format!("{base}{src}")
    } else {
        let dir = page.rsplit_once('/').map_or(page, |p| p.0);
        format!("{dir}/{src}")
    }
}
