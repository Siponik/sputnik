use sputnik_core::wikilink::about;

#[test]
fn links_first_then_title_words() {
    let t: Vec<String> = ["Щит паладина", "Кейдж", "Запекание нормалей", "Щит"].iter().map(|s| s.to_string()).collect();
    // ссылка из заметки задачи — первой; название задачи содержит «щит» и «щит паладина» целыми словами
    assert_eq!(about("Перепечь щит паладина", "см. [[Запекание нормалей]]", &t), vec![2, 0, 3]);
    // кусок слова не считается
    assert_eq!(about("Кейджи", "", &t), Vec::<usize>::new());
    assert_eq!(about("Новый кейдж", "", &t), vec![1]);
}
