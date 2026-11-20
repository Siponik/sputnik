use serde_json::json;
use sputnik_core::updater::*;

#[test]
fn sizes_and_speed() {
    assert_eq!(mb(17_825_792), "17,0 МБ");
    assert_eq!(speed(870_400.0), "850 КБ/с");
    assert_eq!(speed(1_258_291.0), "1,2 МБ/с");
    assert_eq!(eta(10_000_000, 1_000_000.0), "ещё ~10 с");
    assert_eq!(eta(200_000_000, 1_000_000.0), "ещё ~4 мин");
    assert_eq!(eta(100, 0.0), "");
}

#[test]
fn progress_line() {
    assert_eq!(progress_text(12_897_485, 17_825_792, 870_400.0), "12,3 из 17,0 МБ · 850 КБ/с · ещё ~6 с");
    assert_eq!(progress_text(1_048_576, 0, 0.0), "1,0 МБ");
    assert_eq!(frac(50, 100), 0.5);
    assert_eq!(frac(5, 0), -1.0);
    assert_eq!(frac(200, 100), 1.0);
}

#[test]
fn retries() {
    assert_eq!((1..=6).map(backoff_secs).collect::<Vec<_>>(), vec![2, 4, 8, 15, 15, 15]);
    assert!(retryable("timed out reading response"));
    assert!(retryable("Connection reset by peer (os error 10054)"));
    assert!(!retryable("подпись не сошлась: ..."));
    assert!(!retryable("Access is denied. (os error 5)"));
    assert!(!retryable("https://x: status code 404"));
}

#[test]
fn reasons() {
    assert!(explain("timed out reading response").0.contains("медленно"));
    assert!(explain("timed out reading response").1.contains("VPN"));
    assert!(explain("Connection reset by peer (os error 10054)").0.contains("оборвалась"));
    assert!(explain("Dns Failed: failed to lookup address").0.contains("адрес"));
    assert!(explain("подпись не сошлась").0.contains("подпись"));
    assert!(explain("Access is denied. (os error 5)").0.contains("Windows"));
    assert!(explain("https://github.com/x: status code 404").0.contains("не нашёлся"));
    assert_eq!(explain("что-то странное").0, "Обновление не скачалось.");
}

#[test]
fn resume() {
    assert_eq!(resume_from(206, 500), 500);
    assert_eq!(resume_from(200, 500), 0);
    assert_eq!(total_size(Some("bytes 500-999/5000"), Some("500"), 500), 5000);
    assert_eq!(total_size(None, Some("4500"), 500), 5000);
    assert_eq!(total_size(None, None, 0), 0);
}

#[test]
fn pick_file() {
    let both = json!({"url": "u", "signature": "s", "gz": "g", "gzSignature": "gs"});
    assert_eq!(pick(&both), Some(("g".into(), "gs".into(), true)));
    let old = json!({"url": "u", "signature": "s"});
    assert_eq!(pick(&old), Some(("u".into(), "s".into(), false)));
    assert_eq!(pick(&json!({"url": "u"})), None);
}
