//! Предпросмотр страниц для ссылок на холсте: название, описание и картинка страницы.
//! Качается один раз в фоне и лежит в `rust/links/` (json + картинка) — без сети тоже видно.
use sputnik_core::linkpeek::{self as lp, Meta};
use std::cell::RefCell;
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Clone, Default)]
pub struct Peek {
    pub meta: Meta,
    pub img: Option<PathBuf>,
    pub ready: bool,
}

thread_local! {
    static CACHE: RefCell<HashMap<String, Peek>> = RefCell::new(HashMap::new());
}

fn dir() -> PathBuf {
    crate::data::store::own("links")
}

fn key(url: &str) -> String {
    use std::hash::{Hash, Hasher};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    url.hash(&mut h);
    format!("{:016x}", h.finish())
}

fn from_disk(url: &str) -> Option<Peek> {
    let k = key(url);
    let v: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(dir().join(format!("{k}.json"))).ok()?).ok()?;
    let s = |n: &str| v[n].as_str().unwrap_or("").to_string();
    let img = v["img"].as_str().filter(|x| !x.is_empty()).map(|x| dir().join(x)).filter(|p| p.exists());
    Some(Peek { meta: Meta { title: s("title"), desc: s("desc"), image: s("image"), site: s("site") }, img, ready: true })
}

/// Предпросмотр адреса: готовый — сразу; нет — запускается загрузка, пока пусто.
pub fn get(url: &str) -> Peek {
    if !url.starts_with("http") {
        return Peek { ready: true, ..Default::default() };
    }
    if let Some(p) = CACHE.with(|c| c.borrow().get(url).cloned()) {
        return p;
    }
    if let Some(p) = from_disk(url) {
        CACHE.with(|c| c.borrow_mut().insert(url.to_string(), p.clone()));
        return p;
    }
    // ставим «качается», чтобы не запускать дважды
    CACHE.with(|c| c.borrow_mut().insert(url.to_string(), Peek::default()));
    let u = url.to_string();
    std::thread::spawn(move || {
        let p = fetch(&u);
        let _ = slint::invoke_from_event_loop(move || {
            CACHE.with(|c| c.borrow_mut().insert(u, p));
            super::act(|_, _| {});
        });
    });
    Peek::default()
}

fn fetch(url: &str) -> Peek {
    use std::io::Read;
    let agent = ureq::AgentBuilder::new().timeout(std::time::Duration::from_secs(12)).build();
    let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Sputnik";
    let mut meta = Meta { site: lp::host(url).trim_start_matches("www.").to_string(), ..Default::default() };
    match agent.get(url).set("User-Agent", ua).call() {
        Ok(r) => {
            let mut buf = Vec::new();
            let _ = r.into_reader().take(768 * 1024).read_to_end(&mut buf);
            meta = lp::parse(&String::from_utf8_lossy(&buf), url);
        }
        // нет сети — показать адрес, попробовать снова при следующем запуске (на диск не пишем)
        Err(ureq::Error::Transport(_)) => return Peek { meta, img: None, ready: true },
        Err(_) => {}
    }
    let k = key(url);
    let _ = std::fs::create_dir_all(dir());
    let mut img_name = String::new();
    if !meta.image.is_empty() {
        if let Ok(r) = agent.get(&meta.image).set("User-Agent", ua).call() {
            let ext = match r.content_type() {
                "image/png" => "png",
                "image/jpeg" | "image/jpg" => "jpg",
                _ => "",
            };
            let mut buf = Vec::new();
            let _ = r.into_reader().take(6 * 1024 * 1024).read_to_end(&mut buf);
            // другие форматы (webp…) окно не рисует — перекодировать не умеем, просто без картинки
            let ext = if ext.is_empty() { image::guess_format(&buf).ok().and_then(|f| match f { image::ImageFormat::Png => Some("png"), image::ImageFormat::Jpeg => Some("jpg"), _ => None }).unwrap_or("") } else { ext };
            if !ext.is_empty() && std::fs::write(dir().join(format!("{k}.{ext}")), &buf).is_ok() {
                img_name = format!("{k}.{ext}");
            }
        }
    }
    let v = serde_json::json!({ "url": url, "title": meta.title, "desc": meta.desc, "image": meta.image, "site": meta.site, "img": img_name });
    let _ = std::fs::write(dir().join(format!("{k}.json")), v.to_string());
    let img = (!img_name.is_empty()).then(|| dir().join(&img_name));
    Peek { meta, img, ready: true }
}
