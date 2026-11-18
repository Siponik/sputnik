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
    let s = |n: &str| v[n].as_str().unwrap_or("").to_string();
    let img = v["img"].as_str().filter(|x| !x.is_empty()).map(|x| dir().join(x)).filter(|p| p.exists());
    let shot = v["shot"].as_str().filter(|x| !x.is_empty()).map(|x| dir().join(x)).filter(|p| p.exists());
    // старый кэш или неудачная попытка (нет снимка) — показать что есть, но скачать заново
    let full = v["v"].as_i64() == Some(VER) && shot.is_some();
    Some(Peek { meta: Meta { title: s("title"), desc: s("desc"), image: s("image"), site: s("site") }, img, shot, ready: full })
}

/// Версия кэша: всё, что скачано раньше неё, качается заново.
const VER: i64 = 2;
/// Браузер настоящий — сайты за Cloudflare (ArtStation и др.) отвечают ему, а не «роботу».
const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

/// Предпросмотр адреса: готовый — сразу; нет — запускается загрузка, пока пусто (или старое).
pub fn get(url: &str) -> Peek {
    if !url.starts_with("http") {
        return Peek { ready: true, ..Default::default() };
    }
    if let Some(p) = CACHE.with(|c| c.borrow().get(url).cloned()) {
        return p;
    }
    let old = from_disk(url);
    if let Some(p) = old.as_ref().filter(|p| p.ready) {
        CACHE.with(|c| c.borrow_mut().insert(url.to_string(), p.clone()));
        return p.clone();
    }
    // ставим «качается», чтобы не запускать дважды за запуск
    let wait = old.unwrap_or_default();
    CACHE.with(|c| c.borrow_mut().insert(url.to_string(), wait.clone()));
    let u = url.to_string();
    std::thread::spawn(move || {
        let p = fetch(&u);
        let _ = slint::invoke_from_event_loop(move || {
            CACHE.with(|c| c.borrow_mut().insert(u, p));
            super::act(|_, _| {});
        });
    });
    wait
}

fn fetch(url: &str) -> Peek {
    use std::io::Read;
    let mut log = vec![format!("url {url}")];
    let agent = ureq::AgentBuilder::new().timeout(std::time::Duration::from_secs(12)).build();
    let get = |u: &str| {
        agent.get(u).set("User-Agent", UA).set("Accept", "text/html,application/xhtml+xml,image/avif,image/webp,*/*;q=0.8").set("Accept-Language", "ru,en;q=0.8").call()
    };
    let mut meta = Meta::default();
    match get(url) {
        Ok(r) => {
            let mut buf = Vec::new();
            let _ = r.into_reader().take(768 * 1024).read_to_end(&mut buf);
            meta = lp::parse(&String::from_utf8_lossy(&buf), url);
            log.push(format!("page ok, title {:?}", meta.title));
        }
        Err(e) => log.push(format!("page: {e}")),
    }
    let _ = std::fs::create_dir_all(dir());
    let k = key(url);
    // сайт не ответил или прислал проверку «вы не робот» — спросить у браузера, он проходит
    if meta.title.is_empty() || blocked(&meta.title) {
        match dom(url) {
            Some(html) => {
                let m = lp::parse(&html, url);
                log.push(format!("browser dom {} bytes, title {:?}", html.len(), m.title));
                if !blocked(&m.title) {
                    meta = m;
                }
            }
            None => log.push(format!("browser dom: нет, браузеры {:?}", browsers())),
        }
    }
    if blocked(&meta.title) {
        meta = Meta::default();
    }
    if meta.site.is_empty() {
        meta.site = lp::host(url).trim_start_matches("www.").to_string();
    }
    let mut img_name = String::new();
    if !meta.image.is_empty() {
        match get(&meta.image) {
            Ok(r) => {
                let mut buf = Vec::new();
                let _ = r.into_reader().take(8 * 1024 * 1024).read_to_end(&mut buf);
                img_name = save_image(&buf, &k);
                log.push(format!("image {} bytes → {img_name:?}", buf.len()));
            }
            Err(e) => log.push(format!("image: {e}")),
        }
    }
    let shot_name = if screenshot(url, &dir().join(format!("{k}.page.png"))) { format!("{k}.page.png") } else { String::new() };
    log.push(format!("shot {shot_name:?}"));
    let v = serde_json::json!({ "v": VER, "url": url, "title": meta.title, "desc": meta.desc, "image": meta.image, "site": meta.site, "img": img_name, "shot": shot_name });
    let _ = std::fs::write(dir().join(format!("{k}.json")), v.to_string());
    // что получилось и что нет — чтобы было видно, если сайт не отдаёт предпросмотр
    let _ = std::fs::write(dir().join(format!("{k}.log")), log.join("\n"));
    let img = (!img_name.is_empty()).then(|| dir().join(&img_name));
    let shot = (!shot_name.is_empty()).then(|| dir().join(&shot_name));
    Peek { meta, img, shot, ready: true }
}

/// Заглушки защиты от роботов вместо страницы.
fn blocked(title: &str) -> bool {
    let t = title.to_lowercase();
    ["just a moment", "attention required", "access denied", "один момент", "403 forbidden"].iter().any(|s| t.contains(s))
}

/// Картинка страницы: png и jpeg как есть, остальное (webp, gif…) — перекодировать в png.
fn save_image(buf: &[u8], k: &str) -> String {
    let Ok(f) = image::guess_format(buf) else { return String::new() };
    let (name, ok) = match f {
        image::ImageFormat::Png => (format!("{k}.png"), std::fs::write(dir().join(format!("{k}.png")), buf).is_ok()),
        image::ImageFormat::Jpeg => (format!("{k}.jpg"), std::fs::write(dir().join(format!("{k}.jpg")), buf).is_ok()),
        _ => match image::load_from_memory(buf) {
            Ok(im) => (format!("{k}.png"), im.save_with_format(dir().join(format!("{k}.png")), image::ImageFormat::Png).is_ok()),
            Err(_) => (String::new(), false),
        },
    };
    if ok { name } else { String::new() }
}

/// Браузеры для снимка: Edge есть на любой Windows 10/11, ещё Chrome; на Linux — chromium.
fn browsers() -> Vec<PathBuf> {
    let env = |k: &str| std::env::var(k).ok().map(PathBuf::from);
    let mut c: Vec<PathBuf> = vec![];
    for base in [env("ProgramFiles(x86)"), env("ProgramFiles"), env("LOCALAPPDATA")].into_iter().flatten() {
        c.push(base.join(r"Microsoft\Edge\Application\msedge.exe"));
        c.push(base.join(r"Google\Chrome\Application\chrome.exe"));
    }
    for p in ["/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome", "/opt/pw-browsers/chromium"] {
        c.push(PathBuf::from(p));
    }
    c.retain(|p| p.is_file());
    c
}

/// Не больше одного браузера без окна за раз, даже если на холсте много ссылок.
static BROWSER: std::sync::Mutex<()> = std::sync::Mutex::new(());

/// Запуск браузера без окна. Профиль он берёт временный сам — открытому Edge не мешает
/// (свой постоянный профиль, наоборот, заставляет его ждать сеть и виснуть).
fn run_browser(exe: &std::path::Path, args: &[String], url: &str, out: std::process::Stdio, secs: u64) -> bool {
    let _g = BROWSER.lock();
    let mut cmd = std::process::Command::new(exe);
    cmd.args(["--headless=new", "--disable-gpu", "--hide-scrollbars", "--mute-audio", "--no-first-run", "--no-default-browser-check"])
        .args(["--disable-sync", "--disable-extensions", "--disable-component-update", "--disable-background-networking", "--disable-features=msEdgeSidebarV2,msUndersideButton,EdgeCollections"])
        .arg(format!("--user-agent={UA}"))
        .args(args)
        .arg(url)
        .stdin(std::process::Stdio::null())
        .stdout(out)
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
            Ok(Some(_)) => return true,
            Ok(None) if start.elapsed() < std::time::Duration::from_secs(secs) => std::thread::sleep(std::time::Duration::from_millis(200)),
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                return false;
            }
        }
    }
}

/// Страница глазами браузера (после скриптов и проверки «не робот»).
fn dom(url: &str) -> Option<String> {
    let f = dir().join("dom.tmp");
    for exe in browsers() {
        let out = std::fs::File::create(&f).ok()?;
        let ok = run_browser(&exe, &["--virtual-time-budget=8000".into(), "--dump-dom".into()], url, out.into(), 40);
        let html = std::fs::read_to_string(&f).unwrap_or_default();
        let _ = std::fs::remove_file(&f);
        if ok && !html.trim().is_empty() {
            return Some(html);
        }
    }
    None
}

/// Снимок страницы шириной как у телефона (так она читается в карточке), высота — с запасом для прокрутки.
fn screenshot(url: &str, to: &std::path::Path) -> bool {
    let _ = std::fs::remove_file(to);
    let args = ["--window-size=480,2400".to_string(), "--force-device-scale-factor=1".into(), "--virtual-time-budget=8000".into(), format!("--screenshot={}", to.display())];
    // не вышло в Edge — пробуем Chrome
    browsers().iter().any(|exe| {
        run_browser(exe, &args, url, std::process::Stdio::null(), 40);
        to.metadata().is_ok_and(|m| m.len() > 0)
    })
}
