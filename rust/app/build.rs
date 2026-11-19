fn main() {
    slint_build::compile_with_config("ui/app.slint", slint_build::CompilerConfiguration::new().with_style("fluent-dark".into())).expect("Slint");

    // Значок и подпись внутри sputnik.exe (Windows). Из exe значок берут ярлык в «Пуске», закреплённый
    // на панели задач и «Проводник»; обновление меняет exe целиком, поэтому значок не слетает.
    // Картинка — rust/assets/icon (рисует design/system-g/icon/gen.py).
    println!("cargo:rerun-if-changed=../assets/icon/sputnik.ico");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        let mut res = winresource::WindowsResource::new();
        res.set_icon("../assets/icon/sputnik.ico")
            .set("FileDescription", "Спутник")
            .set("ProductName", "Спутник");
        res.compile().expect("значок exe");
    }
}
