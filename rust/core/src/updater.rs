//! Обновление из приложения — чистая часть: подписи прогресса скачивания, понятные причины ошибок,
//! паузы между повторами и выбор файла из latest.json. Сеть и диск — в app/src/state/update.rs.

/// «12,3 МБ»: размер с одним знаком после запятой.
pub fn mb(bytes: u64) -> String {
    format!("{} {}", dec(bytes as f64 / 1_048_576.0), crate::t!("МБ"))
}

/// Число с одним знаком: «12,3» по-русски, «12.3» по-английски.
fn dec(v: f64) -> String {
    let x = format!("{:.1}", v);
    if crate::i18n::is_en() { x } else { x.replace('.', ",") }
}

/// Скорость: «850 КБ/с» или «1,2 МБ/с».
pub fn speed(bps: f64) -> String {
    if bps < 1_048_576.0 {
        format!("{} {}", (bps / 1024.0).round() as u64, crate::t!("КБ/с"))
    } else {
        format!("{} {}", dec(bps / 1_048_576.0), crate::t!("МБ/с"))
    }
}

/// Сколько ещё ждать: «ещё ~40 с», «ещё ~3 мин»; скорость неизвестна — пусто.
pub fn eta(left: u64, bps: f64) -> String {
    if bps < 1.0 {
        return String::new();
    }
    let s = (left as f64 / bps).ceil() as u64;
    if s < 60 {
        crate::t!("ещё ~{} с", s.max(1))
    } else {
        crate::t!("ещё ~{} мин", s.div_ceil(60))
    }
}

/// Доля скачанного 0…1; размер неизвестен — -1 (полоса «бегает»).
pub fn frac(done: u64, total: u64) -> f32 {
    if total == 0 {
        -1.0
    } else {
        (done as f64 / total as f64).clamp(0.0, 1.0) as f32
    }
}

/// Строка под полосой: «12,3 из 17,0 МБ · 850 КБ/с · ещё ~6 с».
pub fn progress_text(done: u64, total: u64, bps: f64) -> String {
    let mut s = if total > 0 { crate::t!("{} из {}", dec(done as f64 / 1_048_576.0), mb(total)) } else { mb(done) };
    if bps >= 1.0 {
        s += &format!(" · {}", speed(bps));
        if total > done {
            let e = eta(total - done, bps);
            if !e.is_empty() {
                s += &format!(" · {e}");
            }
        }
    }
    s
}

/// Пауза перед повтором номер `attempt` (1, 2, …): 2, 4, 8, 15, 15… секунд.
pub fn backoff_secs(attempt: u32) -> u64 {
    (1u64 << attempt.clamp(1, 4)).min(15)
}

/// Сколько раз пробуем скачать подряд, прежде чем показать ошибку. Каждая попытка продолжает
/// с места обрыва, поэтому медленная связь всё равно дотягивает файл.
pub const ATTEMPTS: u32 = 6;

/// Ошибку стоит повторить сама (сеть), а не сразу показывать (подпись, диск).
pub fn retryable(raw: &str) -> bool {
    let l = raw.to_lowercase();
    !(l.contains("подпись") || l.contains("signature") || l.contains("access is denied") || l.contains("отказано в доступе")
        || l.contains("os error 5") || l.contains("os error 32") || l.contains("os error 112") || l.contains(": status code 404"))
}

/// Понятная причина ошибки для человека: (что случилось, что сделать).
pub fn explain(raw: &str) -> (String, String) {
    let l = raw.to_lowercase();
    let has = |xs: &[&str]| xs.iter().any(|x| l.contains(x));
    let (what, hint) = if has(&["подпись", "signature"]) {
        (crate::t!("Файл скачался, но подпись не сошлась — ставить его нельзя."), crate::t!("Нажми «Повторить»: файл скачается заново."))
    } else if has(&["os error 5", "access is denied", "отказано в доступе", "os error 32", "used by another process"]) {
        (
            crate::t!("Windows не дала заменить файл Спутника."),
            crate::t!("Закрой другие окна Спутника или перенеси sputnik.exe в свою папку (например, Документы) и повтори."),
        )
    } else if has(&["os error 112", "no space", "недостаточно места"]) {
        (crate::t!("На диске не хватило места для новой версии."), crate::t!("Освободи около 100 МБ и повтори."))
    } else if has(&["dns", "resolve", "no such host", "failed to lookup", "name or service"]) {
        (crate::t!("Нет связи с GitHub — адрес не находится."), crate::t!("Проверь интернет и повтори."))
    } else if has(&["timed out", "timeout", "время ожидания"]) {
        (
            crate::t!("GitHub отвечает слишком медленно — скачивание остановилось."),
            crate::t!("Нажми «Повторить»: продолжу с того же места. Не помогает несколько раз — включи VPN на время обновления."),
        )
    } else if has(&["reset", "broken pipe", "connection", "eof", "unexpected end", "os error 10054", "os error 10060", "os error 10061"]) {
        (
            crate::t!("Связь с GitHub оборвалась посреди скачивания."),
            crate::t!("Нажми «Повторить»: продолжу с того же места. Не помогает несколько раз — включи VPN на время обновления."),
        )
    } else if has(&["status code 404"]) {
        (crate::t!("Файл новой версии не нашёлся на GitHub."), crate::t!("Подожди несколько минут — сборка, возможно, ещё выкладывается."))
    } else if has(&["status code 403", "status code 429"]) {
        (crate::t!("GitHub временно не отдаёт файл."), crate::t!("Повтори через несколько минут."))
    } else if has(&["status code 5"]) {
        (crate::t!("У GitHub сбой."), crate::t!("Повтори через несколько минут."))
    } else {
        (crate::t!("Обновление не скачалось."), crate::t!("Нажми «Повторить»."))
    };
    (what.to_string(), hint.to_string())
}

/// Ответ на запрос «с байта `from`»: сервер продолжил (206) — дописываем, ответил целиком (200) — начинаем заново.
pub fn resume_from(status: u16, from: u64) -> u64 {
    if status == 206 {
        from
    } else {
        0
    }
}

/// Общий размер из заголовков: Content-Range «bytes 100-199/5000» главнее Content-Length (+ уже скачанное).
pub fn total_size(content_range: Option<&str>, content_length: Option<&str>, from: u64) -> u64 {
    if let Some(t) = content_range.and_then(|r| r.rsplit('/').next()).and_then(|t| t.trim().parse::<u64>().ok()) {
        return t;
    }
    content_length.and_then(|l| l.trim().parse::<u64>().ok()).map(|l| l + from).unwrap_or(0)
}

/// Что качать из latest.json: сжатый файл (втрое меньше), если он есть, иначе сам exe.
/// Возвращает (адрес, подпись, сжат ли).
pub fn pick(feed: &serde_json::Value) -> Option<(String, String, bool)> {
    let s = |k: &str| feed[k].as_str().unwrap_or("").to_string();
    let (gz, gzsig) = (s("gz"), s("gzSignature"));
    if !gz.is_empty() && !gzsig.is_empty() {
        return Some((gz, gzsig, true));
    }
    let (url, sig) = (s("url"), s("signature"));
    if url.is_empty() || sig.is_empty() {
        None
    } else {
        Some((url, sig, false))
    }
}
