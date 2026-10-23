fn main() {
    // Встроенный ключ Google (google.rs, BUILT_IN_SECRET) — пересобрать, если он поменялся.
    println!("cargo:rerun-if-env-changed=SPUTNIK_GOOGLE_CLIENT");
    tauri_build::build()
}
