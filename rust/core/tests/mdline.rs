use sputnik_core::mdline::{caret, hit, plain, same_col, Hit};

#[test]
fn plain_text_as_shown() {
    assert_eq!(plain("Блики на **металле** и [[Палитра|палитра]].").text, "Блики на металле и палитра.");
    assert_eq!(plain("[[Металл]], `код *нет*`, ~~было~~ _курсив_ \\*звезда").text, "Металл, код *нет*, было курсив *звезда");
    assert_eq!(plain("snake_case_name и 5 * 3 = 15").text, "snake_case_name и 5 * 3 = 15");
    assert_eq!(plain("[сайт](<https://x.ru>) и **не закрыто").text, "сайт и **не закрыто");
}

#[test]
fn click_maps_to_source() {
    let s = "Блики на **металле** и [[Палитра|палитра]].";
    let p = plain(s);
    // «мет|алле»: в видимом тексте после «Блики на мет»
    let at = "Блики на мет".len();
    assert_eq!(&s[..caret(&p, at)], "Блики на **мет");
    // клик в самом начале и в самом конце
    assert_eq!(caret(&p, 0), 0);
    assert_eq!(caret(&p, p.text.len()), s.len());
    // по ссылке — открыть её
    assert_eq!(hit(s, "Блики на металле и па".len()), Hit::Link("Палитра".into()));
    assert_eq!(hit("см. [[Металл#Блики]]", "см. Мет".len()), Hit::Link("Металл#Блики".into()));
    assert_eq!(hit("[сайт](https://x.ru)", 2), Hit::Link("https://x.ru".into()));
    // мимо ссылки — курсор
    assert_eq!(hit(s, "Бл".len()), Hit::Caret("Бл".len()));
}

#[test]
fn arrows_keep_column() {
    assert_eq!(same_col("абвгд", "абв".len(), "ёжзий"), "ёжз".len());
    assert_eq!(same_col("абвгд", "абвгд".len(), "аб"), "аб".len());
    assert_eq!(same_col("", 0, "текст"), 0);
}
