//! Предпросмотр страниц для ссылок на холсте: название, описание и картинка страницы.
//! Качается один раз в фоне и лежит в `rust/links/` (json + картинка) — без сети тоже видно.
//! Снимок самой страницы делает браузер, который уже есть на компьютере (Edge или Chrome без окна).
use sputnik_core::linkpeek::{self as lp, Meta};
use std::cell::RefCell;
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Clone, Default)]
pub struct Peek {
    pub meta: Meta,
    pub img: Option<PathBuf>,
    /// снимок верха страницы (как она выглядит в браузере)
    pub shot: Option<PathBuf>,
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
    // старый кэш без снимка страницы — скачать заново
    v.get("shot")?;
    let s = |n: &str| v[n].as_str().unwrap_or("").to_string();
    let img = v["img"].as_str().filter(|x| !x.is_empty()).map(|x| dir().join(x)).filter(|p| p.exists());
    let shot = v["shot"].as_str().filter(|x| !x.is_empty()).map(|x| dir().join(x)).filter(|p| p.exists());
    Some(Peek { meta: Meta { title: s("title"), desc: s("desc"), image: s("image"), site: s("site") }, img, shot, ready: true })
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
        Err(ureq::Error::Transport(_)) => return Peek { meta, img: None, shot: None, ready: true },
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
    let shot_name = if screenshot(url, &dir().join(format!("{k}.page.png"))) { format!("{k}.page.png") } else { String::new() };
    let v = serde_json::json!({ "url": url, "title": meta.title, "desc": meta.desc, "image": meta.image, "site": meta.site, "img": img_name, "shot": shot_name });
    let _ = std::fs::write(dir().join(format!("{k}.json")), v.to_string());
    let img = (!img_name.is_empty()).then(|| dir().join(&img_name));
    let shot = (!shot_name.is_empty()).then(|| dir().join(&shot_name));
    Peek { meta, img, shot, ready: true }
}

/// Браузер для снимка: Edge есть на любой Windows 10/11, иначе Chrome; на Linux — chromium.
fn browser() -> Option<PathBuf> {
    let env = |k: &str| std::env::var(k).ok().map(PathBuf::from);
    let mut c: Vec<PathBuf> = vec![];
    for base in [env("ProgramFiles(x86)"), env("ProgramFiles"), env("LOCALAPPDATA")].into_iter().flatten() {
        c.push(base.join(r"Microsoft\Edge\Application\msedge.exe"));
        c.push(base.join(r"Google\Chrome\Application\chrome.exe"));
    }
    for p in ["/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome", "/opt/pw-browsers/chromium"] {
        c.push(PathBuf::from(p));
    }
    c.into_iter().find(|p| p.is_file())
}

/// Снимок страницы шириной как у телефона (так она читается в карточке), высота — с запасом для прокрутки.
fn screenshot(url: &str, to: &std::path::Path) -> bool {
    let Some(exe) = browser() else { return false };
    let _ = std::fs::remove_file(to);
    // без окна браузер сам берёт временный профиль — открытому Edge не мешает
    let mut cmd = std::process::Command::new(exe);
    cmd.args(["--headless=new", "--disable-gpu", "--hide-scrollbars", "--mute-audio", "--no-first-run", "--no-default-browser-check"])
        .args(["--window-size=480,2400", "--force-device-scale-factor=1", "--virtual-time-budget=8000"])
        .arg(format!("--screenshot={}", to.display()))
        .arg(url)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    #[cfg(not(windows))]
    cmd.arg("--no-sandbox");
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x0800_0000); // без чёрного окна
    }
    let Ok(mut child) = cmd.spawn() else { return false };
    let start = std::time::Instant::now();
    loop {
        match child.try_wait() {
            Ok(Some(_)) => break,
            Ok(None) if start.elapsed() < std::time::Duration::from_secs(40) => std::thread::sleep(std::time::Duration::from_millis(200)),
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                break;
            }
        }
    }
    to.metadata().is_ok_and(|m| m.len() > 0)
}
