//! Разбор «Что нового» из latest.json в пункты для карточки «Обновления» (#203).
use sputnik_core::updnotes as un;

#[test]
fn items_plain_lines() {
    let notes = "- Окно «Создать» переделано по новым макетам\n- В настройках видно, что нового\n- Мелкие правки";
    assert_eq!(
        un::items(notes, 5),
        vec!["Окно «Создать» переделано по новым макетам", "В настройках видно, что нового", "Мелкие правки"]
    );
}

#[test]
fn items_skip_service_commits() {
    let notes = "- Merge pull request #196 from Siponik/kimi\n- Слил свежую бету\n- Сливаю main\n- Настоящее изменение\n- \n-  \n";
    assert_eq!(un::items(notes, 5), vec!["Настоящее изменение"]);
}

#[test]
fn items_strip_pr_tail_and_cap() {
    let notes = "- Первое (#123)\n- Второе\n- Третье\n- Четвёртое\n- Пятое\n- Шестое";
    let got = un::items(notes, 5);
    assert_eq!(got.len(), 5, "не больше cap");
    assert_eq!(got[0], "Первое", "хвост «(#123)» снят");
}

#[test]
fn items_empty_and_marks() {
    assert_eq!(un::items("", 5), Vec::<String>::new());
    assert_eq!(un::items("\n  \n- \n", 5), Vec::<String>::new());
    assert_eq!(un::items("• один\n* два\nтри", 5), vec!["один", "два", "три"]);
}
