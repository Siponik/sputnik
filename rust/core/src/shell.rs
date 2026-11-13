//! Шапка, «Состояние», обновления, левая колонка и настройки — чистая логика. Порт tracker/src/lib/shell.js.
use crate::j::*;
use crate::rx;
use chrono::{Local, NaiveDateTime, TimeZone, Timelike};

pub fn settings_tabs() -> Value {
    json!([
  {
    "id": "look",
    "name": "Вид"
  },
  {
    "id": "show",
    "name": "Что показывать"
  },
  {
    "id": "rem",
    "name": "Напоминания"
  },
  {
    "id": "sync",
    "name": "Синхронизация"
  },
  {
    "id": "upd",
    "name": "Обновления"
  },
  {
    "id": "keys",
    "name": "Клавиши"
  }
])
}

pub fn settings_index() -> Value {
    json!([
  {
    "tab": "look",
    "id": "theme",
    "title": "Тема",
    "hint": "Тёмная — основная. «Как в Windows» переключается вместе с системой.",
    "also": "светлая цвет оформление"
  },
  {
    "tab": "look",
    "id": "accent",
    "title": "Акцент",
    "hint": "Цвет кнопок, выделения и подсветки",
    "also": "акцентный цвет оформление глина палитра"
  },
  {
    "tab": "look",
    "id": "motion",
    "title": "Анимации",
    "hint": "«Минимум» — только мягкое появление. «Выкл» — всё сразу.",
    "also": "движение"
  },
  {
    "tab": "look",
    "id": "tabs",
    "title": "Порядок вкладок",
    "hint": "Сегодня, Календарь, Доска, Привычки — в каком порядке стоят в шапке. Клавиши 1–4 идут так же.",
    "also": "меню шапка разделы переставить порядок верхнее"
  },
  {
    "tab": "look",
    "id": "start",
    "title": "Открывать при запуске",
    "hint": "Какой раздел показывать первым",
    "also": "старт"
  },
  {
    "tab": "look",
    "id": "tips",
    "title": "Енот-советчик",
    "hint": "Советы внизу колонки доски",
    "also": "совет подсказки"
  },
  {
    "tab": "show",
    "id": "lists",
    "title": "Списки задач",
    "hint": "Какие списки видны на доске, в «Сегодня» и в календаре",
    "also": "скрыть показывать"
  },
  {
    "tab": "show",
    "id": "cals",
    "title": "Календари",
    "hint": "Какие календари Google показывать",
    "also": "скрыть показывать дни рождения праздники"
  },
  {
    "tab": "rem",
    "id": "tgbot",
    "title": "Telegram",
    "hint": "Общий бот: напоминания и задачи текстом",
    "also": "телеграм бот подключить код"
  },
  {
    "tab": "rem",
    "id": "bot",
    "title": "Свой бот (Apps Script)",
    "hint": "Только у владельца: файл напоминаний, проверка связи, выключить",
    "also": "телеграм бот проверить apps script выключить"
  },
  {
    "tab": "rem",
    "id": "rtask",
    "title": "Задачи — по умолчанию",
    "hint": "Напоминание, которое ставится новой задаче со сроком"
  },
  {
    "tab": "rem",
    "id": "revent",
    "title": "События",
    "hint": "Напоминание о событии по умолчанию"
  },
  {
    "tab": "rem",
    "id": "rbday",
    "title": "Дни рождения",
    "hint": "Напоминание о дне рождения по умолчанию"
  },
  {
    "tab": "rem",
    "id": "rhour",
    "title": "Задачи без времени",
    "hint": "Во сколько напоминать, если у задачи только дата, или не напоминать",
    "also": "выключить отключить уведомление"
  },
  {
    "tab": "rem",
    "id": "notify",
    "title": "Уведомления Windows",
    "hint": "Вехи привычек; основное — в боте"
  },
  {
    "tab": "sync",
    "id": "acct",
    "title": "Google-аккаунт",
    "hint": "Задачи, календарь, скрытая папка",
    "also": "выйти войти почта"
  },
  {
    "tab": "sync",
    "id": "google",
    "title": "Google Задачи и Календарь",
    "hint": "Обновляется само раз в 2 минуты",
    "also": "обновить синхронизация"
  },
  {
    "tab": "sync",
    "id": "cloud",
    "title": "Между компьютерами",
    "hint": "Слой Спутника в скрытой папке на Drive",
    "also": "синхронизация второй компьютер"
  },
  {
    "tab": "sync",
    "id": "dupes",
    "title": "Дубли задач",
    "hint": "Одинаковые задачи в одном списке",
    "also": "дубли копии повторы двойные"
  },
  {
    "tab": "sync",
    "id": "backup",
    "title": "Резервные копии",
    "hint": "Каждый день, хранятся 14",
    "also": "бэкап копия папка"
  },
  {
    "tab": "upd",
    "id": "ver",
    "title": "Версия Спутника",
    "hint": "Обновить или проверить обновления",
    "also": "обновление"
  },
  {
    "tab": "upd",
    "id": "auto",
    "title": "Проверять самому",
    "hint": "Через 30 секунд после запуска и раз в 6 часов",
    "also": "обновления автоматически"
  },
  {
    "tab": "upd",
    "id": "night",
    "title": "Ставить ночью",
    "hint": "Если компьютер включён — обновится в 3:00 без вопросов",
    "also": "обновления"
  },
  {
    "tab": "upd",
    "id": "all",
    "title": "Все версии",
    "hint": "Список изменений на GitHub",
    "also": "релизы"
  },
  {
    "tab": "keys",
    "id": "keys",
    "title": "Клавиши",
    "hint": "Горячие клавиши — работают и в русской раскладке",
    "also": "сочетания хоткеи"
  }
])
}

pub fn view_tabs() -> Value {
    json!([
  {
    "id": "today",
    "name": "Сегодня"
  },
  {
    "id": "calendar",
    "name": "Календарь"
  },
  {
    "id": "board",
    "name": "Доска"
  },
  {
    "id": "habits",
    "name": "Привычки"
  }
])
}

fn dt_ms(ms: f64) -> NaiveDateTime {
    Local.timestamp_millis_opt(ms as i64).single().map(|d| d.naive_local()).unwrap_or_default()
}

/// «09:05» по местному времени; d — мс или строка ISO.
pub fn hm(d: &Value) -> String {
    if !t(d) {
        return String::new();
    }
    let x = match d {
        Value::Number(n) => dt_ms(n.as_f64().unwrap_or(0.0)),
        v => match crate::reminders::parse_any(&text(v)) {
            Some(a) => a.with_timezone(&Local).naive_local(),
            None => return String::new(),
        },
    };
    format!("{:02}:{:02}", x.hour(), x.minute())
}

fn line(text_: impl Into<Value>, cls: &str) -> Value {
    json!({"text": text_.into(), "cls": cls})
}

pub fn status_dots(sync: &Value, offline: bool, cloud: &Value, upd: &Value) -> Value {
    let g = json!({"c": if t(&sync["err"]) { "e" } else { "" }, "busy": t(&sync["busy"])});
    let st = &cloud["state"];
    let l = json!({"c": if st == "login" { "w" } else if st == "err" { "e" } else { "" }, "busy": st == "busy"});
    let v = json!({"c": if t(&upd["found"]) { "w" } else if t(&upd["err"]) { "e" } else { "" }, "busy": t(&upd["busy"])});
    let label = if offline {
        "Нет связи".into()
    } else if st == "login" {
        "Нужен вход".into()
    } else if t(&sync["err"]) {
        "Ошибка".into()
    } else {
        hm(&sync["at"])
    };
    json!({"dots": [g, l, v], "label": label})
}

pub fn google_line(sync: &Value, offline: bool) -> Value {
    if t(&sync["busy"]) {
        return line("обновляю…", "");
    }
    if offline {
        return line("нет связи — повторю через минуту", "e");
    }
    if t(&sync["err"]) {
        return line(sync["err"].clone(), "e");
    }
    if !t(&sync["at"]) {
        return line("ещё не обновлялось", "");
    }
    line(format!("обновлено в {} · раз в 2 минуты", hm(&sync["at"])), "ok")
}

pub fn cloud_line(c: &Value) -> Value {
    match s(&c["state"]) {
        "login" => line("нужно разрешить скрытую папку на Drive", "w"),
        "err" => line(if t(&c["err"]) { c["err"].clone() } else { json!("не удалось синхронизировать") }, "e"),
        "busy" => line("синхронизирую…", ""),
        "ok" if t(&c["at"]) => line(format!("синхронизировано в {}", hm(&c["at"])), "ok"),
        _ => line("ещё не синхронизировано", ""),
    }
}

pub fn version_line(u: &Value) -> Value {
    let f = &u["found"];
    if t(&u["busy"]) {
        let p = (n(&u["progress"]).unwrap_or(0.0) * 100.0 + 0.5).floor() as i64;
        let v = if f["version"].is_null() { String::new() } else { text(&f["version"]) };
        return line(format!("ставлю {v} · {p}%"), "w");
    }
    if !f.is_null() {
        return line(format!("вышла {} · меньше минуты", text(&f["version"])), "c");
    }
    if t(&u["err"]) {
        return line(u["err"].clone(), "e");
    }
    if t(&u["checkedAt"]) {
        return line(format!("последняя версия · проверено в {}", hm(&u["checkedAt"])), "ok");
    }
    line("обновления проверяются сами", "")
}

pub fn remind_line(r: &Value) -> Value {
    if t(&r["shared"]) {
        if t(&r["err"]) {
            return line(r["err"].clone(), "e");
        }
        return if t(&r["linked"]) { line("через общий бот", "ok") } else { line("бот не подключён — Настройки → Напоминания", "w") };
    }
    if t(&r["err"]) {
        return line(r["err"].clone(), "e");
    }
    if !t(&r["at"]) {
        return line("файл ещё не обновлялся", "");
    }
    line(format!("файл обновлён {} · {} впереди", hm(&r["at"]), text(&r["n"])), "ok")
}

/// Свой бот на Apps Script — только у владельца.
pub fn own_bot(settings: &Value, inbox: &Value) -> Value {
    let v = &settings["ownBot"]["v"];
    let found = t(inbox);
    json!({"show": found || *v == true, "on": if v.is_boolean() { v.clone() } else { json!(found) }})
}

pub fn is_beta(v: &Value) -> bool {
    rx::is(r"-beta\.\d+$", &if v.is_null() { String::new() } else { text(v) })
}

pub fn beta_show(own: &Value, version: &Value, pref: &Value) -> bool {
    t(&own["show"]) || pref["beta"] == true || is_beta(version)
}

/// «Что нового»: первые n пунктов списка из заметки релиза.
pub fn notes_of(text_: &Value, n_: usize) -> Vec<String> {
    let src = if text_.is_null() { String::new() } else { text(text_) };
    let lines: Vec<String> = rx::rx(r"\r?\n").split(&src).filter_map(|x| x.ok()).map(|x| x.trim().to_string()).filter(|x| !x.is_empty()).collect();
    let items: Vec<String> = lines.iter().filter(|x| rx::is(r"^[-*•✦]\s+", x)).map(|x| rx::first(r"^[-*•✦]\s+", x, "")).collect();
    let src = if items.is_empty() { lines } else { items };
    src.into_iter().take(n_).collect()
}

pub fn show_upd_chip(found: &Value, pref: &Value, now: Option<f64>) -> bool {
    if found.is_null() {
        return false;
    }
    if t(&pref["skip"]) && pref["skip"] == found["version"] {
        return false;
    }
    let now = now.unwrap_or_else(|| chrono::Utc::now().timestamp_millis() as f64);
    if t(&pref["remindAt"]) && now < n(&pref["remindAt"]).unwrap_or(0.0) {
        return false;
    }
    true
}

/// «Вечером» — сегодня в 20:00, а если уже позже — завтра в 20:00.
pub fn evening_at(now: NaiveDateTime) -> i64 {
    let mut d = now.date().and_hms_opt(20, 0, 0).unwrap();
    if d <= now {
        d = (now.date() + chrono::Duration::days(1)).and_hms_opt(20, 0, 0).unwrap();
    }
    crate::reminders::local(d).timestamp_millis()
}

pub fn night_now(pref: &Value, now: NaiveDateTime) -> bool {
    t(&pref["night"]) && now.hour() == 3
}

pub fn ms_local(ms: f64) -> NaiveDateTime {
    dt_ms(ms)
}

// ---------- левая колонка доски ----------

/// Выезд откреплённой колонки: наведение — через in_ms выезжает, уход — через out_ms уезжает.
/// Время двигает [Slider::tick] (в приложении — таймер интерфейса).
#[derive(Debug)]
pub struct Slider {
    pub in_ms: i64,
    pub out_ms: i64,
    open: bool,
    inside: bool,
    held: bool,
    now: i64,
    pending: Option<(bool, i64)>,
    /// Смены open по порядку (для интерфейса: что показать).
    pub log: Vec<bool>,
}

impl Default for Slider {
    fn default() -> Self {
        Slider { in_ms: 150, out_ms: 300, open: false, inside: false, held: false, now: 0, pending: None, log: vec![] }
    }
}

impl Slider {
    pub fn open(&self) -> bool {
        self.open
    }
    fn go(&mut self, v: bool) {
        self.pending = None;
        if self.open != v {
            self.open = v;
            self.log.push(v);
        }
    }
    fn later(&mut self, v: bool, ms: i64) {
        self.pending = None;
        if ms == 0 {
            self.go(v);
        } else {
            self.pending = Some((v, self.now + ms));
        }
    }
    pub fn tick(&mut self, ms: i64) {
        let end = self.now + ms;
        while let Some((v, at)) = self.pending {
            if at > end {
                break;
            }
            self.pending = None;
            self.now = at;
            self.go(v);
        }
        self.now = end;
    }
    pub fn enter(&mut self) {
        self.inside = true;
        if self.open {
            self.pending = None;
        } else {
            self.later(true, self.in_ms);
        }
    }
    pub fn leave(&mut self) {
        self.inside = false;
        if !self.open {
            self.pending = None;
        } else if !self.held {
            self.later(false, self.out_ms);
        }
    }
    pub fn hold(&mut self, v: bool) {
        self.held = v;
        if v {
            self.pending = None;
        } else if self.open && !self.inside {
            self.later(false, self.out_ms);
        }
    }
    pub fn show(&mut self) {
        self.go(true);
    }
    pub fn peek(&mut self, ms: i64) {
        self.go(true);
        if !self.inside && !self.held {
            self.later(false, ms);
        }
    }
    pub fn hide(&mut self) {
        self.held = false;
        self.go(false);
    }
    pub fn instant(&mut self, v: bool) {
        if v {
            self.in_ms = 0;
            self.out_ms = 0;
        }
    }
}

fn norm(x: &Value) -> String {
    (if x.is_null() { String::new() } else { text(x) }).to_lowercase().replace('ё', "е")
}
fn words(q: &str) -> Vec<String> {
    norm(&json!(q)).split_whitespace().map(String::from).collect()
}

/// Фильтр «Список…»: сферы и списки, где есть все слова запроса.
pub fn filter_side(query: &str, spheres: &[Value], lists_of: &dyn Fn(&Value) -> Vec<Value>, no_sphere: &[Value]) -> Value {
    let ws = words(query);
    let hit = |v: &Value| ws.iter().all(|w| norm(v).contains(w.as_str()));
    if ws.is_empty() {
        return json!({"spheres": spheres.iter().map(|sp| json!({"sp": sp, "lists": lists_of(&sp["id"])})).collect::<Vec<_>>(),
                      "noSphere": no_sphere, "first": null});
    }
    let mut out = vec![];
    for sp in spheres {
        let all = lists_of(&sp["id"]);
        let lists: Vec<Value> = if hit(&sp["name"]) { all } else { all.into_iter().filter(|l| hit(&l["title"])).collect() };
        if !lists.is_empty() || hit(&sp["name"]) {
            out.push(json!({"sp": sp, "lists": lists}));
        }
    }
    let rest: Vec<Value> = no_sphere.iter().filter(|l| hit(&l["title"])).cloned().collect();
    let flat: Vec<&Value> = out.iter().flat_map(|x| a(&x["lists"]).iter()).collect();
    let first = flat.first().map(|x| (*x).clone()).or_else(|| rest.first().cloned()).unwrap_or(Value::Null);
    let fs = if first.is_null() { out.first().map(|x| x["sp"].clone()).unwrap_or(Value::Null) } else { Value::Null };
    json!({"spheres": out, "noSphere": rest, "first": first, "firstSphere": fs})
}

/// Советы енота для доски: 2–3 штуки { id, text, act, kind, ref }.
pub fn board_tips(open: &[Value], cols: &[Value], col_of: &dyn Fn(&Value) -> Value, first: &Value) -> Vec<Value> {
    if open.is_empty() {
        return vec![json!({"id": "empty", "text": "Всё разобрано. Новые задачи — кнопкой «+ Добавить задачу» в колонке или «Создать».",
                           "act": "Новая задача", "kind": "new"})];
    }
    let mut tips = vec![];
    if !first.is_null() {
        let task = &first["task"];
        let title = if t(&task["title"]) { text(&task["title"]) } else { "Без названия".into() };
        let head = format!("Начни с «{title}»{}", if t(&first["why"]) { format!(" — {}", text(&first["why"])) } else { String::new() });
        let dot = if head.ends_with('.') { "" } else { "." };
        tips.push(json!({"id": "first", "text": format!("{head}{dot} Остальное подождёт."), "act": "Открыть", "kind": "task", "ref": task["id"]}));
    }
    let cnt = |c: &Value| open.iter().filter(|tk| col_of(tk) == c["id"]).count() as f64;
    if let Some(lim) = cols.iter().find(|c| t(&c["limit"]) && cnt(c) >= n(&c["limit"]).unwrap_or(0.0) - 1.0) {
        let k = cnt(lim);
        let (nm, li) = (text(&lim["name"]), text(&lim["limit"]));
        let txt = if k > n(&lim["limit"]).unwrap_or(0.0) {
            format!("В «{nm}» {k} из {li} — больше лимита. Закончи что-нибудь, прежде чем брать новое.")
        } else {
            format!("«{nm}» уже {k} из {li} — закончи одну, прежде чем брать новую.")
        };
        tips.push(json!({"id": "limit", "kind": "col", "ref": lim["id"], "act": format!("К «{nm}»"), "text": txt}));
    }
    if let Some(inbox) = cols.first() {
        let ni = cnt(inbox);
        if ni >= 3.0 && cols.len() > 2 {
            let nm = text(&inbox["name"]);
            tips.push(json!({"id": "inbox", "kind": "col", "ref": inbox["id"], "act": format!("К «{nm}»"),
                             "text": format!("Во «{nm}» {ni} — разбери: что в работу, что на потом.")}));
        }
    }
    tips.truncate(3);
    tips
}

// ---------- Настройки ----------

/// Найти настройку: все слова запроса — в заголовке, пояснении или словах для поиска.
pub fn search_settings(query: &str) -> Vec<Value> {
    search_in(&settings_index(), query)
}

/// То же по своему перечню настроек: записи `{ title, hint, also, … }`.
pub fn search_in(index: &Value, query: &str) -> Vec<Value> {
    let ws = words(query);
    if ws.is_empty() {
        return vec![];
    }
    a(index)
        .iter()
        .filter(|r| {
            let tx = norm(&json!(format!("{} {} {}", text(&r["title"]), s(&r["hint"]), s(&r["also"]))));
            ws.iter().all(|w| tx.contains(w.as_str()))
        })
        .cloned()
        .collect()
}

/// ↑ ↓ по вкладкам настроек.
pub fn step_tab(cur: &str, dir: i64) -> String {
    let tabs = settings_tabs();
    let tabs = a(&tabs);
    let i = tabs.iter().position(|x| x["id"] == cur).map(|i| i as i64).unwrap_or(-1);
    let l = tabs.len() as i64;
    text(&tabs[((i + dir + l) % l) as usize]["id"])
}

pub const VIEWS: [&str; 4] = ["today", "calendar", "board", "habits"];

/// Порядок вкладок из настройки: неизвестные и повторы отбрасываются, забытые — в конец.
pub fn tab_order(saved: &Value) -> Vec<String> {
    let mut out: Vec<String> = vec![];
    for id in a(saved) {
        let id = s(id);
        if VIEWS.contains(&id) && !out.iter().any(|x| x == id) {
            out.push(id.into());
        }
    }
    for id in VIEWS {
        if !out.iter().any(|x| x == id) {
            out.push(id.into());
        }
    }
    out
}

pub fn move_tab(order: &[String], id: &str, to: i64) -> Vec<String> {
    let mut rest: Vec<String> = order.iter().filter(|x| *x != id).cloned().collect();
    if rest.len() == order.len() {
        return order.to_vec();
    }
    let i = to.clamp(0, rest.len() as i64) as usize;
    rest.insert(i, id.into());
    rest
}

pub fn tabs_default(order: &[String]) -> bool {
    order.join(",") == VIEWS.join(",")
}

/// С какого раздела открыться: today | board | last.
pub fn start_view(pref: &Value, last: &Value) -> String {
    if pref == "board" {
        return "board".into();
    }
    if pref == "last" && VIEWS.contains(&s(last)) {
        return text(last);
    }
    "today".into()
}
