//! Синхронизация «Знаний» с папкой «Спутник / Знания» на Google Drive (docs/knowledge.md §1): что отправить,
//! что скачать, где конфликт. Чистая логика без сети и диска: на входе — что есть здесь, что на Drive
//! и что было при прошлой сверке; на выходе — список шагов.
use std::collections::{BTreeMap, BTreeSet};

/// Файл на этом компьютере: путь от корня папки заметок и хеш содержимого.
#[derive(Clone, Debug, PartialEq)]
pub struct Local {
    pub hash: String,
}

/// Файл на Drive: id и md5 содержимого (его считает сам Drive).
#[derive(Clone, Debug, PartialEq)]
pub struct Remote {
    pub id: String,
    pub md5: String,
}

/// Что было при прошлой удачной сверке: хеш здесь и md5 на Drive.
#[derive(Clone, Debug, PartialEq)]
pub struct Base {
    pub hash: String,
    pub md5: String,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Step {
    /// Отправить на Drive (новый файл или новая версия).
    Upload(String),
    /// Скачать с Drive поверх здешнего (здесь не меняли).
    Download(String),
    /// Изменили и здесь, и на Drive (или файл появился с обеих сторон): скачать копию рядом —
    /// «… (с другого компьютера).md»; если содержимое совпало, просто запомнить.
    Conflict(String),
    /// Убрать на Drive в корзину (здесь удалили, там не меняли).
    TrashRemote(String),
    /// Убрать здесь в `.trash` (на Drive удалили, здесь не меняли).
    TrashLocal(String),
    /// Забыть запись прошлой сверки (файла нет нигде).
    Forget(String),
}

pub fn plan(local: &BTreeMap<String, Local>, remote: &BTreeMap<String, Remote>, base: &BTreeMap<String, Base>) -> Vec<Step> {
    let mut paths: BTreeSet<&String> = local.keys().collect();
    paths.extend(remote.keys());
    paths.extend(base.keys());
    let mut out = vec![];
    for p in paths {
        let (l, r, b) = (local.get(p), remote.get(p), base.get(p));
        let lch = |l: &Local| b.is_none_or(|b| b.hash != l.hash);
        let rch = |r: &Remote| b.is_none_or(|b| b.md5 != r.md5);
        let step = match (l, r) {
            (Some(l), Some(r)) => match (lch(l), rch(r)) {
                (false, false) => None,
                (true, false) => Some(Step::Upload(p.clone())),
                (false, true) => Some(Step::Download(p.clone())),
                (true, true) => Some(Step::Conflict(p.clone())),
            },
            (Some(l), None) => match b {
                Some(_) if !lch(l) => Some(Step::TrashLocal(p.clone())),
                _ => Some(Step::Upload(p.clone())),
            },
            (None, Some(r)) => match b {
                Some(_) if !rch(r) => Some(Step::TrashRemote(p.clone())),
                _ => Some(Step::Download(p.clone())),
            },
            (None, None) => b.map(|_| Step::Forget(p.clone())),
        };
        out.extend(step);
    }
    out
}

/// Имя второй копии при конфликте: «Заметка.md» → «Заметка (с другого компьютера).md»; занято — «… 2».
pub fn conflict_name(path: &str, taken: impl Fn(&str) -> bool) -> String {
    let (stem, ext) = match path.rsplit_once('.') {
        Some((s, e)) if !s.is_empty() && !e.contains('/') => (s, format!(".{e}")),
        _ => (path, String::new()),
    };
    let mut n = 1;
    loop {
        let name = if n == 1 { format!("{stem} (с другого компьютера){ext}") } else { format!("{stem} (с другого компьютера {n}){ext}") };
        if !taken(&name) {
            return name;
        }
        n += 1;
    }
}

/// Лишние копии «… (с другого компьютера N)»: те, что слово в слово как оригинал или как более ранняя копия.
/// `files` — путь → хеш содержимого. Возвращает пути, которые можно убрать в корзину.
pub fn extra_copies(files: &BTreeMap<String, Local>) -> Vec<String> {
    let mut out = vec![];
    let mut kept: BTreeMap<(String, String), ()> = BTreeMap::new();
    for (p, l) in files {
        let Some(orig) = original_of(p) else { continue };
        let same_as_orig = files.get(&orig).is_some_and(|o| o.hash == l.hash);
        if same_as_orig || kept.contains_key(&(orig.clone(), l.hash.clone())) {
            out.push(p.clone());
        } else {
            kept.insert((orig, l.hash.clone()), ());
        }
    }
    out
}

/// Свободный путь: занято — «… 2», «… 3».
pub fn trash_free(path: &str, taken: impl Fn(&str) -> bool) -> String {
    if !taken(path) {
        return path.to_string();
    }
    let (stem, ext) = match path.rsplit_once('.') {
        Some((s, e)) if !e.contains('/') => (s, format!(".{e}")),
        _ => (path, String::new()),
    };
    (2..).map(|i| format!("{stem} {i}{ext}")).find(|p| !taken(p)).unwrap_or(path.to_string())
}

/// «Заметка (с другого компьютера 2).md» → «Заметка.md» (и копия копии — тоже к самому первому имени).
pub fn original_of(path: &str) -> Option<String> {
    let mut p = path.to_string();
    let mut found = false;
    while let Some(a) = p.find(" (с другого компьютера") {
        let Some(b) = p[a..].find(')') else { break };
        p.replace_range(a..a + b + 1, "");
        found = true;
    }
    found.then_some(p)
}

/// Какие файлы папки заметок синхронизировать: заметки, холсты и вложения; не служебные папки.
pub fn wanted(path: &str) -> bool {
    if path.split('/').any(|s| s.starts_with('.')) {
        return false;
    }
    let low = path.to_lowercase();
    let ext = low.rsplit_once('.').map(|x| x.1).unwrap_or("");
    matches!(ext, "md" | "canvas" | "png" | "jpg" | "jpeg" | "gif" | "webp" | "svg" | "pdf" | "txt")
}

/// Защита от массового удаления: если с одной стороны вдруг пропало много файлов (папку отключили,
/// Drive не отдал список, сменился вход), удалять на другой стороне нельзя — такие шаги заменяются
/// повторной отправкой/загрузкой. Порог — больше 5 файлов и больше трети прошлой сверки.
pub fn guard(steps: Vec<Step>, base_len: usize) -> Vec<Step> {
    let many = |n: usize| n > 5 && n * 3 > base_len;
    let tl = steps.iter().filter(|s| matches!(s, Step::TrashLocal(_))).count();
    let tr = steps.iter().filter(|s| matches!(s, Step::TrashRemote(_))).count();
    steps.into_iter().filter_map(|s| match s {
        Step::TrashLocal(p) if many(tl) => Some(Step::Upload(p)),
        Step::TrashRemote(p) if many(tr) => Some(Step::Download(p)),
        x => Some(x),
    }).collect()
}
