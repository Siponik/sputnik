//! Акцентный цвет (settings.accent.v = id набора или «#RRGGBB»). Порт app/lib/core/accent.dart.
use crate::j::*;
use crate::rx;

pub fn accents() -> Value {
    json!([
        {"id": "clay", "name": "Глина", "dark": "#D9774F", "light": "#AD4F2C"},
        {"id": "coral", "name": "Коралл", "dark": "#E8766E", "light": "#B23A33"},
        {"id": "rose", "name": "Роза", "dark": "#E07A9B", "light": "#A83A60"},
        {"id": "lavender", "name": "Лаванда", "dark": "#A68BE8", "light": "#5B45A8"},
        {"id": "sky", "name": "Небо", "dark": "#6E9EE8", "light": "#2D5BA8"},
        {"id": "mint", "name": "Мята", "dark": "#5DBB98", "light": "#1E7356"},
        {"id": "olive", "name": "Олива", "dark": "#A8B85A", "light": "#55661A"},
    ])
}
pub const DEFAULT: &str = "clay";
const BG_DARK: &str = "#1C1B19";
const BG_LIGHT: &str = "#FFFFFF";

fn hex(v: &Value) -> Option<String> {
    let x = v.as_str()?.trim();
    rx::is(r"(?i)^#?[0-9a-f]{6}$", x).then(|| format!("#{}", x.replacen('#', "", 1).to_uppercase()))
}

pub fn rgb(h: &str) -> [f64; 3] {
    [1, 3, 5].map(|i| u8::from_str_radix(&h[i..i + 2], 16).unwrap_or(0) as f64)
}

fn js_round(x: f64) -> i64 {
    (x + 0.5).floor() as i64
}

fn to_hex(c: [f64; 3]) -> String {
    format!("#{}", c.iter().map(|x| format!("{:02x}", js_round(x.clamp(0.0, 255.0)))).collect::<String>().to_uppercase())
}

pub fn mix(a: &str, b: &str, t: f64) -> String {
    let (x, y) = (rgb(a), rgb(b));
    to_hex([0, 1, 2].map(|i| x[i] * t + y[i] * (1.0 - t)))
}

pub fn luminance(h: &str) -> f64 {
    let c = rgb(h).map(|v| {
        let x = v / 255.0;
        if x <= 0.03928 { x / 12.92 } else { ((x + 0.055) / 1.055).powf(2.4) }
    });
    0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

pub fn contrast(a: &str, b: &str) -> f64 {
    let (x, y) = (luminance(a), luminance(b));
    (x.max(y) + 0.05) / (x.min(y) + 0.05)
}

pub fn fit(c: &str, bg: &str, min: f64) -> String {
    let toward = if luminance(bg) < 0.5 { "#FFFFFF" } else { "#000000" };
    let mut out = c.to_string();
    let mut t = 1.0;
    while t >= 0.3 && contrast(&out, bg) < min {
        out = mix(c, toward, t);
        t -= 0.05;
    }
    out
}

pub fn accent_of(v: &Value) -> Value {
    if let Some(x) = a(&accents()).iter().find(|x| x["id"] == *v) {
        return x.clone();
    }
    match hex(v) {
        None => accents()[0].clone(),
        Some(h) => json!({"id": "custom", "name": "Свой", "dark": fit(&h, BG_DARK, 4.5), "light": fit(&h, BG_LIGHT, 4.5)}),
    }
}

pub fn vars(c: &str, theme: &str) -> Value {
    if theme == "light" {
        return json!({"clay": c, "soft": mix(c, BG_LIGHT, 0.1), "on": if contrast(c, "#FFFFFF") >= 3.0 { "#FFFFFF" } else { "#1C1B19" }});
    }
    json!({"clay": c, "soft": mix(c, BG_DARK, 0.13), "on": if contrast(c, BG_DARK) >= contrast(c, "#FFFFFF") { BG_DARK } else { "#FFFFFF" }})
}

fn block(v: &Value) -> String {
    format!("--clay: {}; --clay-soft: {}; --on-clay: {};", s(&v["clay"]), s(&v["soft"]), s(&v["on"]))
}

pub fn accent_css(v: &Value) -> String {
    let x = accent_of(v);
    if s(&x["id"]) == DEFAULT {
        return String::new();
    }
    let d = block(&vars(s(&x["dark"]), "dark"));
    let l = block(&vars(s(&x["light"]), "light"));
    format!(":root:root {{ {d} }}\n@media (prefers-color-scheme: light) {{ :root:root:not([data-theme=\"dark\"]) {{ {l} }} }}\n:root:root[data-theme=\"light\"] {{ {l} }}\n")
}
