//! Вход в Google (OAuth 2.0 для установленных приложений, PKCE, loopback 127.0.0.1) и запросы к Google API.
//! Порт tracker/src-tauri/src/google.rs без Tauri: те же файлы token.json и client_secret.json в папке
//! настроек, тот же встроенный ключ (переменная сборки SPUTNIK_GOOGLE_CLIENT), те же доступы (scopes.rs).
//! Всё блокирующее — зовётся из фоновых потоков, не из потока окна.
use super::scopes;
use super::store::{config_dir, own};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::Mutex;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
pub const SIGN_IN_AGAIN: &str = "Войдите в Google заново";
const BUILT_IN_SECRET: Option<&str> = option_env!("SPUTNIK_GOOGLE_CLIENT");

#[derive(Clone, Serialize, Deserialize)]
struct Token {
    access_token: String,
    refresh_token: Option<String>,
    expires_at: u64,
    #[serde(default)]
    scope: Option<String>,
}

#[derive(Deserialize)]
struct Secret {
    client_id: String,
    #[serde(default)]
    client_secret: String,
}

#[derive(Deserialize)]
struct SecretFile {
    installed: Option<Secret>,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: Option<u64>,
    refresh_token: Option<String>,
    scope: Option<String>,
}

static TOKEN: Mutex<Option<Token>> = Mutex::new(None);

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn agent() -> ureq::Agent {
    ureq::AgentBuilder::new().timeout(Duration::from_secs(30)).build()
}

fn parse_secret(text: &str) -> Option<Secret> {
    let f: SecretFile = serde_json::from_str(text.trim_start_matches('\u{feff}')).ok()?;
    let s = f.installed?;
    let id = s.client_id.trim();
    id.ends_with(".apps.googleusercontent.com")
        .then(|| Secret { client_id: id.to_string(), client_secret: s.client_secret.trim().to_string() })
}

fn read_secret() -> Result<Secret, String> {
    [own("client_secret.json"), config_dir().join("client_secret.json")]
        .iter()
        .find_map(|p| std::fs::read_to_string(p).ok().and_then(|t| parse_secret(&t)))
        .or_else(|| BUILT_IN_SECRET.and_then(parse_secret))
        .ok_or_else(|| "Нет ключа приложения (client_secret.json)".to_string())
}

/// Вход: свой rust\token.json, иначе токен прежнего приложения (только чтение).
fn load_token() -> Option<Token> {
    if FORGOT.load(std::sync::atomic::Ordering::Relaxed) {
        return serde_json::from_str(&std::fs::read_to_string(own("token.json")).ok()?).ok();
    }
    [own("token.json"), config_dir().join("token.json")]
        .iter()
        .find_map(|p| serde_json::from_str(&std::fs::read_to_string(p).ok()?).ok())
}

fn store_token(t: &Token) {
    let p = own("token.json");
    if let Some(d) = p.parent() {
        let _ = std::fs::create_dir_all(d);
    }
    if let Ok(s) = serde_json::to_string(t) {
        let _ = std::fs::write(p, s);
    }
    FORGOT.store(false, std::sync::atomic::Ordering::Relaxed);
}

/// Забыть вход: свой файл удаляется, чужой (прежнего приложения) больше не читается до нового входа.
fn drop_token() {
    *TOKEN.lock().unwrap() = None;
    let _ = std::fs::remove_file(own("token.json"));
    FORGOT.store(true, std::sync::atomic::Ordering::Relaxed);
}

static FORGOT: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
static CANCEL: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// Остановить ожидание входа (кнопка «Отмена»).
pub fn cancel_login() {
    CANCEL.store(true, std::sync::atomic::Ordering::Relaxed);
}

/// Выйти из Google в этом приложении.
pub fn sign_out() {
    drop_token();
}

/// Есть ли действующий вход со всеми доступами.
pub fn signed_in() -> bool {
    load_token()
        .filter(|t| t.refresh_token.is_some())
        .map(|t| t.scope.as_deref().map_or(true, |g| scopes::missing(g).is_empty()))
        .unwrap_or(false)
}

fn random_b64(len: usize) -> String {
    let mut b = vec![0u8; len];
    rand::thread_rng().fill_bytes(&mut b);
    URL_SAFE_NO_PAD.encode(b)
}

fn error_text(e: ureq::Error) -> String {
    match e {
        ureq::Error::Status(code, resp) => {
            let text = resp.into_string().unwrap_or_default();
            let v: Option<Value> = serde_json::from_str(&text).ok();
            let msg = v
                .as_ref()
                .and_then(|v| v.pointer("/error/message").or_else(|| v.get("error_description")).or_else(|| v.get("error")))
                .and_then(|m| m.as_str().map(str::to_string))
                .unwrap_or_else(|| text.chars().take(300).collect());
            format!("Google ответил {code}: {msg}")
        }
        ureq::Error::Transport(t) => format!("Нет связи с Google: {t}"),
    }
}

/// Вход через браузер. Ждёт до 5 минут.
pub fn login() -> Result<(), String> {
    CANCEL.store(false, std::sync::atomic::Ordering::Relaxed);
    let secret = read_secret()?;
    let verifier = random_b64(32);
    let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()));
    let state = random_b64(16);
    let listener = TcpListener::bind("127.0.0.1:0").map_err(|e| e.to_string())?;
    let redirect = format!("http://127.0.0.1:{}", listener.local_addr().map_err(|e| e.to_string())?.port());
    let mut u = url::Url::parse(AUTH_URL).unwrap();
    u.query_pairs_mut()
        .append_pair("client_id", &secret.client_id)
        .append_pair("redirect_uri", &redirect)
        .append_pair("response_type", "code")
        .append_pair("scope", &scopes::requested())
        .append_pair("code_challenge", &challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("access_type", "offline")
        .append_pair("prompt", "consent")
        .append_pair("state", &state);
    open::that(u.as_str()).map_err(|e| format!("Не удалось открыть браузер: {e}"))?;
    let code = wait_for_code(&listener, &state)?;
    let tr: TokenResponse = agent()
        .post(TOKEN_URL)
        .send_form(&[
            ("code", code.as_str()),
            ("client_id", secret.client_id.as_str()),
            ("client_secret", secret.client_secret.as_str()),
            ("redirect_uri", redirect.as_str()),
            ("grant_type", "authorization_code"),
            ("code_verifier", verifier.as_str()),
        ])
        .map_err(error_text)?
        .into_json()
        .map_err(|e| e.to_string())?;
    if let Some(g) = tr.scope.as_deref() {
        let lack = scopes::missing(g);
        if !lack.is_empty() {
            drop_token();
            return Err(scopes::missing_text(&lack));
        }
    }
    let t = Token {
        access_token: tr.access_token,
        refresh_token: tr.refresh_token,
        expires_at: now() + tr.expires_in.unwrap_or(3600),
        scope: tr.scope,
    };
    store_token(&t);
    *TOKEN.lock().unwrap() = Some(t);
    Ok(())
}

fn wait_for_code(listener: &TcpListener, state: &str) -> Result<String, String> {
    listener.set_nonblocking(true).map_err(|e| e.to_string())?;
    let until = Instant::now() + Duration::from_secs(300);
    loop {
        let (mut sock, _) = match listener.accept() {
            Ok(s) => s,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                if CANCEL.load(std::sync::atomic::Ordering::Relaxed) {
                    return Err("Вход отменён".into());
                }
                if Instant::now() > until {
                    return Err("Вход не завершён за 5 минут, попробуй ещё раз".into());
                }
                std::thread::sleep(Duration::from_millis(100));
                continue;
            }
            Err(e) => return Err(e.to_string()),
        };
        let _ = sock.set_nonblocking(false);
        let _ = sock.set_read_timeout(Some(Duration::from_secs(5)));
        let mut buf = vec![0u8; 8192];
        let n = sock.read(&mut buf).unwrap_or(0);
        let req = String::from_utf8_lossy(&buf[..n]).to_string();
        let path = req.lines().next().and_then(|l| l.split_whitespace().nth(1)).unwrap_or("/").to_string();
        let Ok(u) = url::Url::parse(&format!("http://127.0.0.1{path}")) else { continue };
        if u.path() != "/" {
            let _ = sock.write_all(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
            continue;
        }
        let q: HashMap<String, String> = u.query_pairs().into_owned().collect();
        let result = if let Some(e) = q.get("error") {
            Err(format!("Вход отменён: {e}"))
        } else if q.get("state").map(String::as_str) != Some(state) {
            Err("Ответ Google не совпал с запросом, попробуй ещё раз".to_string())
        } else if let Some(c) = q.get("code") {
            Ok(c.clone())
        } else {
            let _ = sock.write_all(b"HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n");
            continue;
        };
        let text = if result.is_ok() {
            "Готово, Спутник подключён к Google. Вернись в приложение — это окно можно закрыть."
        } else {
            "Вход не завершён. Вернись в Спутник и попробуй ещё раз."
        };
        let html = format!("<!doctype html><meta charset=utf-8><title>Спутник</title><body style=\"font:16px 'Segoe UI',sans-serif;background:#191A1E;color:#E2E3E8;display:grid;place-items:center;height:100vh;margin:0\"><p>{text}</p></body>");
        let head = format!("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n", html.len());
        let _ = sock.write_all(head.as_bytes());
        let _ = sock.write_all(html.as_bytes());
        return result;
    }
}

fn access_token(force: bool) -> Result<String, String> {
    let mut g = TOKEN.lock().unwrap();
    if g.is_none() {
        *g = load_token();
    }
    let cur = g.clone().ok_or_else(|| SIGN_IN_AGAIN.to_string())?;
    if !force && cur.expires_at > now() + 60 {
        return Ok(cur.access_token);
    }
    let refresh = cur.refresh_token.clone().ok_or_else(|| SIGN_IN_AGAIN.to_string())?;
    let s = read_secret()?;
    let r = agent().post(TOKEN_URL).send_form(&[
        ("client_id", s.client_id.as_str()),
        ("client_secret", s.client_secret.as_str()),
        ("refresh_token", refresh.as_str()),
        ("grant_type", "refresh_token"),
    ]);
    let tr: TokenResponse = match r {
        Ok(r) => r.into_json().map_err(|e| e.to_string())?,
        Err(e) => {
            let msg = error_text(e);
            if msg.contains("invalid_grant") || msg.contains("revoked") {
                drop(g);
                drop_token();
                return Err(format!("{SIGN_IN_AGAIN} (invalid_grant)"));
            }
            return Err(msg);
        }
    };
    let t = Token {
        access_token: tr.access_token,
        refresh_token: tr.refresh_token.or(cur.refresh_token),
        expires_at: now() + tr.expires_in.unwrap_or(3600),
        scope: tr.scope.or(cur.scope),
    };
    store_token(&t);
    let a = t.access_token.clone();
    *g = Some(t);
    Ok(a)
}

/// Почему запрос не прошёл: отказ Google (код), нет связи, нужен вход.
#[derive(Debug, Clone)]
pub enum Fail {
    Status(u16, String),
    Net(String),
    Auth(String),
}

impl std::fmt::Display for Fail {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Fail::Status(_, m) | Fail::Net(m) | Fail::Auth(m) => f.write_str(m),
        }
    }
}

impl Fail {
    /// Стоит ли повторить позже (сеть, «занят», сбой Google).
    pub fn later(&self) -> bool {
        match self {
            Fail::Status(c, _) => *c == 429 || *c >= 500,
            Fail::Net(_) | Fail::Auth(_) => true,
        }
    }
    pub fn need_login(&self) -> bool {
        matches!(self, Fail::Auth(m) if m.starts_with(SIGN_IN_AGAIN))
    }
    pub fn status(&self) -> u16 {
        if let Fail::Status(c, _) = self { *c } else { 0 }
    }
}

fn auth_fail(m: String) -> Fail {
    if m.starts_with("Нет связи") { Fail::Net(m) } else { Fail::Auth(m) }
}

/// Запрос к Google API (только https://*.googleapis.com). Повтор при 401 (новый токен) и при «занят» (кроме POST).
pub fn api(method: &str, url: &str, body: Option<&Value>) -> Result<Value, Fail> {
    api_raw(method, url, body.map(|b| (b.to_string().into_bytes(), "application/json")))
}

/// То же с любым телом (загрузка файлов на Drive).
pub fn api_raw(method: &str, url: &str, body: Option<(Vec<u8>, &str)>) -> Result<Value, Fail> {
    let u = url::Url::parse(url).map_err(|e| Fail::Status(400, e.to_string()))?;
    if u.scheme() != "https" || !u.host_str().is_some_and(|h| h.ends_with(".googleapis.com")) {
        return Err(Fail::Status(400, "Разрешены только запросы к googleapis.com".into()));
    }
    let repeatable = method != "POST";
    let mut waits = [1u64, 3].into_iter();
    let mut refreshed = false;
    loop {
        let token = access_token(refreshed).map_err(auth_fail)?;
        let req = agent().request(method, url).set("Authorization", &format!("Bearer {token}"));
        let res = match &body {
            Some((b, ct)) => req.set("Content-Type", ct).send_bytes(b),
            None => req.call(),
        };
        match res {
            Ok(r) => {
                let text = r.into_string().map_err(|e| Fail::Net(e.to_string()))?;
                return if text.trim().is_empty() {
                    Ok(Value::Null)
                } else {
                    serde_json::from_str(&text).map_err(|e| Fail::Status(500, e.to_string()))
                };
            }
            Err(ureq::Error::Status(401, _)) if !refreshed => refreshed = true,
            Err(ureq::Error::Status(c, r)) if (c == 429 || c >= 500) && repeatable => match waits.next() {
                Some(w) => std::thread::sleep(Duration::from_secs(w)),
                None => return Err(Fail::Status(c, error_text(ureq::Error::Status(c, r)))),
            },
            Err(ureq::Error::Transport(t)) if repeatable => match waits.next() {
                Some(w) => std::thread::sleep(Duration::from_secs(w)),
                None => return Err(Fail::Net(format!("Нет связи с Google: {t}"))),
            },
            Err(ureq::Error::Transport(t)) => return Err(Fail::Net(format!("Нет связи с Google: {t}"))),
            Err(ureq::Error::Status(c, r)) => {
                let msg = error_text(ureq::Error::Status(c, r));
                if c == 403 && scopes::is_insufficient(&msg) {
                    drop_token();
                    return Err(Fail::Auth(scopes::missing_text(&[])));
                }
                return Err(Fail::Status(c, msg));
            }
        }
    }
}
