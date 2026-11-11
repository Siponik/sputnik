//! Картинка задачи: tasks[id].preview = { thumb, file, w, h, at }. Порт tracker/src/lib/preview.js.
use crate::j::*;
use crate::rx;

pub const THUMB: i64 = 240;
pub const FULL: i64 = 1600;
pub const MAX_BYTES: i64 = 30 * 1024 * 1024;

/// Размер, вписанный в квадрат max×max; меньше — не растягиваем.
pub fn fit_size(w: Option<f64>, h: Option<f64>, max: f64) -> (i64, i64) {
    let (Some(w), Some(h)) = (w, h) else { return (0, 0) };
    if !(w > 0.0) || !(h > 0.0) {
        return (0, 0);
    }
    let k = (max / w.max(h)).min(1.0);
    let r = |x: f64| ((x * k + 0.5).floor() as i64).max(1);
    (r(w), r(h))
}

/// `data:<mime>;base64,<данные>` → (mime, b64).
pub fn data_url_parts(url: &str) -> Option<(String, String)> {
    let c = rx::cap(r"(?s)^data:([^;,]+);base64,(.*)$", url)?;
    Some((c[1].clone()?, c[2].clone()?))
}

pub fn is_image(f: &Value) -> bool {
    !f.is_null() && rx::is(r"(?i)^image/(png|jpe?g|webp|gif|bmp|avif)$", s(&f["type"]))
}

pub fn drag_has_file(types: &Value) -> bool {
    a(types).iter().any(|x| x == "Files")
}

pub fn reject_why(f: &Value) -> &'static str {
    if f.is_null() {
        return "Это не картинка";
    }
    if !is_image(f) {
        return "Подходят картинки PNG, JPG, WebP, GIF";
    }
    if n(&f["size"]).is_some_and(|x| x > MAX_BYTES as f64) {
        return "Картинка больше 30 МБ — сохрани поменьше";
    }
    ""
}

pub fn file_name(title: &str) -> String {
    let b = rx::all(r#"[\\/:*?"<>|\n\r\t]+"#, title, " ");
    let b = rx::all(r"\s+", &b, " ").trim().to_string();
    let b: String = b.chars().take(80).collect();
    format!("{} · превью.jpg", if b.is_empty() { "Задача" } else { &b })
}

pub fn has(l: &Value) -> bool {
    t(&l["preview"]["thumb"])
}
