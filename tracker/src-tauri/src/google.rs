//! Вход в Google (OAuth 2.0 для установленных приложений с PKCE) и запросы к Google API.
//! Токен живёт только здесь, в Rust, и в файле token.json в папке настроек приложения.

use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Manager, State};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::Mutex;

const SCOPES: &str = "https://www.googleapis.com/auth/tasks https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.appdata https://www.googleapis.com/auth/userinfo.email";
const AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const SIGN_IN_AGAIN: &str = "Войдите в Google заново";
/// Общий ключ приложения (содержимое client_secret.json), встраивается при сборке из секрета GOOGLE_CLIENT_JSON.
/// Свой client_secret.json в папке настроек главнее. Для приложений на компьютере это не тайна — так задумано Google.
const BUILT_IN_SECRET: Option<&str> = option_env!("SPUTNIK_GOOGLE_CLIENT");

#[derive(Default)]
pub struct Google {
    http: reqwest::Client,
    token: Mutex<Option<Token>>,
}

#[derive(Clone, Serialize, Deserialize)]
struct Token {
    access_token: String,
    refresh_token: Option<String>,
    expires_at: u64,
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
    web: Option<Secret>,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: Option<u64>,
    refresh_token: Option<String>,
}

#[derive(Serialize)]
pub struct AuthStatus {
    has_secret: bool,
    signed_in: bool,
    /// Ключ встроен в сборку и своего файла нет.
    built_in: bool,
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn config_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app.path().app_config_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir)
}

fn parse_secret(text: &str) -> Result<Secret, String> {
    let file: SecretFile = serde_json::from_str(text)
        .map_err(|_| "Это не похоже на client_secret.json из Google Cloud".to_string())?;
    file.installed
        .or(file.web)
        .ok_or_else(|| "В файле нет раздела «installed» — нужен ключ типа Desktop app".to_string())
}

fn built_in_secret() -> Option<Secret> {
    BUILT_IN_SECRET.filter(|t| !t.trim().is_empty()).and_then(|t| parse_secret(t).ok())
}

fn own_secret(app: &AppHandle) -> Result<Secret, String> {
    let text = std::fs::read_to_string(config_dir(app)?.join("client_secret.json"))
        .map_err(|_| "Нет ключа приложения (client_secret.json)".to_string())?;
    parse_secret(&text)
}

fn read_secret(app: &AppHandle) -> Result<Secret, String> {
    own_secret(app).or_else(|e| built_in_secret().ok_or(e))
}

fn load_token(app: &AppHandle) -> Option<Token> {
    let text = std::fs::read_to_string(config_dir(app).ok()?.join("token.json")).ok()?;
    serde_json::from_str(&text).ok()
}

fn store_token(app: &AppHandle, token: &Token) -> Result<(), String> {
    let text = serde_json::to_string(token).map_err(|e| e.to_string())?;
    std::fs::write(config_dir(app)?.join("token.json"), text).map_err(|e| e.to_string())
}

fn drop_token_file(app: &AppHandle) {
    if let Ok(dir) = config_dir(app) {
        let _ = std::fs::remove_file(dir.join("token.json"));
    }
}

fn random_b64(len: usize) -> String {
    let mut bytes = vec![0u8; len];
    rand::thread_rng().fill_bytes(&mut bytes);
    URL_SAFE_NO_PAD.encode(bytes)
}

async fn google_error(resp: reqwest::Response) -> String {
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    let parsed: Option<Value> = serde_json::from_str(&text).ok();
    let msg = parsed
        .as_ref()
        .and_then(|v| {
            v.pointer("/error/message")
                .or_else(|| v.get("error_description"))
                .or_else(|| v.get("error"))
                .and_then(|m| m.as_str().map(str::to_string))
        })
        .unwrap_or_else(|| text.chars().take(300).collect());
    format!("Google ответил {}: {}", status.as_u16(), msg)
}

// ---------- команды для интерфейса ----------

#[tauri::command]
pub fn auth_status(app: AppHandle) -> AuthStatus {
    let own = own_secret(&app).is_ok();
    let built_in = !own && built_in_secret().is_some();
    let signed_in = load_token(&app).map(|t| t.refresh_token.is_some()).unwrap_or(false);
    AuthStatus { has_secret: own || built_in, signed_in, built_in }
}

#[tauri::command]
pub fn save_client_secret(app: AppHandle, contents: String) -> Result<(), String> {
    parse_secret(&contents)?;
    std::fs::write(config_dir(&app)?.join("client_secret.json"), contents).map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn logout(app: AppHandle, google: State<'_, Google>) -> Result<(), String> {
    *google.token.lock().await = None;
    drop_token_file(&app);
    Ok(())
}

#[tauri::command]
pub async fn login(app: AppHandle, google: State<'_, Google>) -> Result<(), String> {
    let secret = read_secret(&app)?;
    let verifier = random_b64(32);
    let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()));
    let state = random_b64(16);

    let listener = TcpListener::bind("127.0.0.1:0").await.map_err(|e| e.to_string())?;
    let port = listener.local_addr().map_err(|e| e.to_string())?.port();
    let redirect = format!("http://127.0.0.1:{port}");

    let mut url = url::Url::parse(AUTH_URL).map_err(|e| e.to_string())?;
    url.query_pairs_mut()
        .append_pair("client_id", &secret.client_id)
        .append_pair("redirect_uri", &redirect)
        .append_pair("response_type", "code")
        .append_pair("scope", SCOPES)
        .append_pair("code_challenge", &challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("access_type", "offline")
        .append_pair("prompt", "consent")
        .append_pair("state", &state);
    open::that(url.as_str()).map_err(|e| format!("Не удалось открыть браузер: {e}"))?;

    let code = tokio::time::timeout(Duration::from_secs(300), wait_for_code(&listener, &state))
        .await
        .map_err(|_| "Вход не завершён за 5 минут, попробуйте ещё раз".to_string())??;

    let resp = google
        .http
        .post(TOKEN_URL)
        .form(&[
            ("code", code.as_str()),
            ("client_id", secret.client_id.as_str()),
            ("client_secret", secret.client_secret.as_str()),
            ("redirect_uri", redirect.as_str()),
            ("grant_type", "authorization_code"),
            ("code_verifier", verifier.as_str()),
        ])
        .send()
        .await
        .map_err(|e| format!("Нет связи с Google: {e}"))?;
    if !resp.status().is_success() {
        return Err(google_error(resp).await);
    }
    let tr: TokenResponse = resp.json().await.map_err(|e| e.to_string())?;
    let token = Token {
        access_token: tr.access_token,
        refresh_token: tr.refresh_token,
        expires_at: now() + tr.expires_in.unwrap_or(3600),
    };
    store_token(&app, &token)?;
    *google.token.lock().await = Some(token);
    Ok(())
}

async fn wait_for_code(listener: &TcpListener, state: &str) -> Result<String, String> {
    loop {
        let (mut sock, _) = listener.accept().await.map_err(|e| e.to_string())?;
        let mut buf = vec![0u8; 8192];
        let n = sock.read(&mut buf).await.unwrap_or(0);
        let request = String::from_utf8_lossy(&buf[..n]).to_string();
        let path = request
            .lines()
            .next()
            .and_then(|line| line.split_whitespace().nth(1))
            .unwrap_or("/")
            .to_string();
        let Ok(u) = url::Url::parse(&format!("http://127.0.0.1{path}")) else { continue };
        if u.path() != "/" {
            let _ = sock.write_all(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").await;
            continue;
        }
        let q: HashMap<String, String> = u.query_pairs().into_owned().collect();
        let result: Result<String, String> = if let Some(err) = q.get("error") {
            Err(format!("Вход отменён: {err}"))
        } else if q.get("state").map(String::as_str) != Some(state) {
            Err("Ответ Google не совпал с запросом, попробуйте ещё раз".to_string())
        } else if let Some(code) = q.get("code") {
            Ok(code.clone())
        } else {
            let _ = sock.write_all(b"HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n").await;
            continue;
        };
        let text = if result.is_ok() {
            "Готово, Спутник подключён к Google. Вернитесь в приложение — это окно можно закрыть."
        } else {
            "Вход не завершён. Вернитесь в Спутник и попробуйте ещё раз."
        };
        let html = format!(
            "<!doctype html><meta charset=utf-8><title>Спутник</title><body style=\"font:16px -apple-system,'Segoe UI',sans-serif;background:#1C1B19;color:#ECEAE3;display:grid;place-items:center;height:100vh;margin:0\"><p>{text}</p></body>"
        );
        let head = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            html.len()
        );
        let _ = sock.write_all(head.as_bytes()).await;
        let _ = sock.write_all(html.as_bytes()).await;
        let _ = sock.flush().await;
        return result;
    }
}

/// Действующий токен доступа: из памяти, с диска или обновлённый через refresh_token.
async fn access_token(app: &AppHandle, google: &Google) -> Result<String, String> {
    let mut guard = google.token.lock().await;
    if guard.is_none() {
        *guard = load_token(app);
    }
    let current = guard.clone().ok_or_else(|| SIGN_IN_AGAIN.to_string())?;
    if current.expires_at > now() + 60 {
        return Ok(current.access_token);
    }
    let refresh = current.refresh_token.clone().ok_or_else(|| SIGN_IN_AGAIN.to_string())?;
    let secret = read_secret(app)?;
    let resp = google
        .http
        .post(TOKEN_URL)
        .form(&[
            ("client_id", secret.client_id.as_str()),
            ("client_secret", secret.client_secret.as_str()),
            ("refresh_token", refresh.as_str()),
            ("grant_type", "refresh_token"),
        ])
        .send()
        .await
        .map_err(|e| format!("Нет связи с Google: {e}"))?;
    if !resp.status().is_success() {
        let msg = google_error(resp).await;
        if msg.contains("invalid_grant") || msg.contains("expired") || msg.contains("revoked") {
            *guard = None;
            drop_token_file(app);
            return Err(format!("{SIGN_IN_AGAIN} (invalid_grant)"));
        }
        return Err(msg);
    }
    let tr: TokenResponse = resp.json().await.map_err(|e| e.to_string())?;
    let token = Token {
        access_token: tr.access_token,
        refresh_token: tr.refresh_token.or(current.refresh_token),
        expires_at: now() + tr.expires_in.unwrap_or(3600),
    };
    store_token(app, &token)?;
    let access = token.access_token.clone();
    *guard = Some(token);
    Ok(access)
}

/// Тело запроса к Google: JSON, двоичный файл (картинка превью) или ничего.
enum Payload {
    None,
    Json(Value),
    Bytes(String, Vec<u8>),
}

/// Запрос к Google API от имени пользователя. Только https://*.googleapis.com.
/// Повторы при «занят», обновление токена при 401. Возвращает удачный ответ.
async fn send(app: &AppHandle, google: &State<'_, Google>, method: &str, url: &str, body: Payload) -> Result<reqwest::Response, String> {
    let parsed = url::Url::parse(url).map_err(|e| e.to_string())?;
    let host_ok = parsed.scheme() == "https"
        && parsed.host_str().map(|h| h.ends_with(".googleapis.com")).unwrap_or(false);
    if !host_ok {
        return Err("Разрешены только запросы к googleapis.com".to_string());
    }
    let method = reqwest::Method::from_bytes(method.to_uppercase().as_bytes()).map_err(|e| e.to_string())?;

    // Google иногда отвечает «занят» (429, 5xx) или рвёт связь. Запросы, которые можно
    // безопасно повторить (всё, кроме POST — он мог успеть создать задачу), повторяем
    // ещё дважды: через 1 и через 3 секунды.
    let repeatable = method != reqwest::Method::POST;
    let mut waits = [1u64, 3].into_iter();
    let mut refreshed = false;
    loop {
        let token = access_token(app, google).await?;
        let mut req = google.http.request(method.clone(), parsed.clone()).bearer_auth(&token);
        match &body {
            Payload::None => {}
            Payload::Json(b) => req = req.json(b),
            Payload::Bytes(mime, data) => req = req.header(reqwest::header::CONTENT_TYPE, mime.as_str()).body(data.clone()),
        }
        let resp = match req.send().await {
            Ok(r) => r,
            Err(e) => match waits.next().filter(|_| repeatable) {
                Some(w) => {
                    tokio::time::sleep(std::time::Duration::from_secs(w)).await;
                    continue;
                }
                None => return Err(format!("Нет связи с Google: {e}")),
            },
        };
        let status = resp.status();
        if status == reqwest::StatusCode::UNAUTHORIZED && !refreshed {
            refreshed = true;
            if let Some(t) = google.token.lock().await.as_mut() {
                t.expires_at = 0; // заставит обновить токен
            }
            continue;
        }
        if busy(status) && repeatable {
            if let Some(w) = waits.next() {
                tokio::time::sleep(std::time::Duration::from_secs(w)).await;
                continue;
            }
        }
        if !status.is_success() {
            return Err(google_error(resp).await);
        }
        return Ok(resp);
    }
}

async fn json_of(resp: reqwest::Response) -> Result<Value, String> {
    let text = resp.text().await.map_err(|e| e.to_string())?;
    if text.trim().is_empty() {
        return Ok(Value::Null);
    }
    serde_json::from_str(&text).map_err(|e| e.to_string())
}

/// Запрос к Google API с JSON-телом.
#[tauri::command]
pub async fn gapi(
    app: AppHandle,
    google: State<'_, Google>,
    method: String,
    url: String,
    body: Option<Value>,
) -> Result<Value, String> {
    let payload = body.map(Payload::Json).unwrap_or(Payload::None);
    json_of(send(&app, &google, &method, &url, payload).await?).await
}

/// Загрузить файл (картинку превью) — данные приходят base64, ответ Google — JSON.
#[tauri::command]
pub async fn gapi_upload(
    app: AppHandle,
    google: State<'_, Google>,
    method: String,
    url: String,
    mime: String,
    data: String,
) -> Result<Value, String> {
    let bytes = base64::engine::general_purpose::STANDARD.decode(data.as_bytes()).map_err(|e| e.to_string())?;
    json_of(send(&app, &google, &method, &url, Payload::Bytes(mime, bytes)).await?).await
}

/// Скачать файл (картинку превью) — ответ base64.
#[tauri::command]
pub async fn gapi_bytes(app: AppHandle, google: State<'_, Google>, url: String) -> Result<String, String> {
    let resp = send(&app, &google, "GET", &url, Payload::None).await?;
    let bytes = resp.bytes().await.map_err(|e| e.to_string())?;
    Ok(base64::engine::general_purpose::STANDARD.encode(&bytes))
}

/// Временные ответы Google: стоит подождать и повторить.
fn busy(status: reqwest::StatusCode) -> bool {
    status == reqwest::StatusCode::TOO_MANY_REQUESTS || status.is_server_error()
}
