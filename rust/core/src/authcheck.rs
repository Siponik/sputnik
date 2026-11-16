//! Проверка client_secret.json и тексты ошибок входа. Порт tracker/src/lib/authcheck.js.
use crate::j::*;
use crate::rx;

pub const SECRET_MAX: usize = 64 * 1024;

fn text_of(v: &Value) -> String {
    match v {
        Value::Null => String::new(),
        Value::String(x) => x.clone(),
        x => x.to_string(),
    }
}

/// "" — похоже на ключ Desktop app; иначе — что не так. size — размер файла (если известен).
pub fn check_secret_text(text: &Value, size: Option<usize>) -> String {
    let st = text_of(text);
    if size.unwrap_or(st.encode_utf16().count()) > SECRET_MAX {
        return "Файл слишком большой — это не client_secret.json. Нужен маленький файл ключа из Google Cloud.".into();
    }
    let tt = st.strip_prefix('\u{feff}').unwrap_or(&st).trim();
    if tt.is_empty() {
        return "Файл пустой. Скачай JSON клиента в Google Cloud ещё раз.".into();
    }
    let Ok(j) = serde_json::from_str::<Value>(tt) else { return "Это не похоже на client_secret.json: в файле не JSON.".into() };
    if !j.is_object() {
        return "Это не похоже на client_secret.json из Google Cloud.".into();
    }
    if !t(&j["installed"]) && t(&j["web"]) {
        return "Это ключ типа «Веб-приложение», а нужен «Приложение для компьютера» (Desktop app). Создай в Google Cloud клиента Desktop app и скачай его JSON.".into();
    }
    if s(&j["type"]) == "service_account" {
        return "Это ключ сервисного аккаунта, а нужен ключ OAuth типа Desktop app (Google Cloud → Clients).".into();
    }
    let inst = &j["installed"];
    if !t(inst) || !inst.is_object() {
        return "В файле нет раздела «installed» — нужен ключ OAuth типа Desktop app из Google Cloud → Clients.".into();
    }
    let id = text_of(&inst["client_id"]);
    let id = id.trim();
    if id.is_empty() || id.chars().any(char::is_whitespace) || !id.ends_with(".apps.googleusercontent.com") {
        return "В файле неправильный client_id — скачай JSON клиента заново.".into();
    }
    String::new()
}

pub fn is_stopped(e: &str) -> bool {
    e.contains("Вход прерван")
}

pub fn is_scope_lack(e: &str) -> bool {
    rx::is(r"(?i)не дал(?: Спутнику все)? доступ|insufficient authentication scopes", e)
}

pub fn login_hint(e: &str) -> String {
    let st = rx::first(r"^Error:\s*", e, "");
    if st.is_empty() || is_stopped(&st) {
        return String::new();
    }
    if is_scope_lack(&st) {
        let head = match rx::cap(r"не дал доступ — (.+?)\.", &st).and_then(|c| c[1].clone()) {
            Some(n) => format!("Google не дал доступ: {n}."),
            None => "Google не дал Спутнику все доступы.".into(),
        };
        return format!("{head} Нажми «Открыть вход» ещё раз и на странице Google отметь все галочки (или «Выбрать всё»).");
    }
    if st.contains("access_denied") {
        return "Вход отменён на странице Google. Если там было «доступ заблокирован» — приложение в Google Cloud ещё в режиме теста: добавь свою почту в тестовые пользователи или опубликуй его.".into();
    }
    if rx::is(r"(?i)invalid_client|unauthorized_client|401", &st) {
        return "Google не принял ключ приложения. Верни встроенный ключ или скачай client_secret.json заново.".into();
    }
    if st.contains("за 5 минут") {
        return "Вход не завершился за 5 минут. Нажми «Открыть вход» ещё раз.".into();
    }
    st
}

/// Первый запуск: включены только основной календарь и праздники.
pub fn cal_default_on(c: &Value) -> bool {
    c.is_object() && (t(&c["primary"]) || text_of(&c["id"]).contains("#holiday@"))
}
