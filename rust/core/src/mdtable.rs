//! Таблица markdown в «Знаниях» (как редактор таблиц Obsidian): разбор строк «| a | b |», правки
//! (ячейка, строки и колонки — вставить, удалить, переместить, дублировать; выравнивание; сортировка),
//! ширина колонок по содержимому и запись обратно в markdown.
//!
//! Бережность к файлу: строка, которую не трогали, записывается как была (с её пробелами и видом),
//! строка-разделитель — тоже, пока не менялись колонки и выравнивание.

/// Выравнивание колонки: строка-разделитель `---`, `:--`, `:-:`, `--:`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub enum Align {
    #[default]
    None,
    Left,
    Center,
    Right,
}

impl Align {
    fn sep(self) -> &'static str {
        match self {
            Align::None => "---",
            Align::Left => ":---",
            Align::Center => ":---:",
            Align::Right => "---:",
        }
    }
    /// Для окна: 0 — как обычно, 1 — влево, 2 — по центру, 3 — вправо.
    pub fn code(self) -> i32 {
        match self {
            Align::None => 0,
            Align::Left => 1,
            Align::Center => 2,
            Align::Right => 3,
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
struct Row {
    cells: Vec<String>,
    /// Строка файла как была; `None` — строку меняли, записать заново.
    raw: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Table {
    rows: Vec<Row>,
    pub align: Vec<Align>,
    /// Есть строка-разделитель: первая строка — заголовок.
    pub head: bool,
    sep_raw: Option<String>,
}

/// Строка — разделитель шапки: «|---|:--:|».
pub fn is_sep(line: &str) -> bool {
    let t = line.trim();
    t.contains('-') && t.trim_matches('|').split('|').all(|c| {
        let c = c.trim();
        !c.is_empty() && c.chars().all(|x| matches!(x, '-' | ':' | ' '))
    })
}

/// Ячейки строки «| a | b |». «\|» внутри ячейки — сам символ «|», не граница.
pub fn cells(line: &str) -> Vec<String> {
    let t = line.trim();
    let t = t.strip_prefix('|').unwrap_or(t);
    let t = if t.ends_with('|') && !t.ends_with("\\|") { &t[..t.len() - 1] } else { t };
    let mut out = vec![];
    let mut cur = String::new();
    let mut it = t.chars().peekable();
    while let Some(c) = it.next() {
        match c {
            '\\' if it.peek() == Some(&'|') => {
                cur.push('|');
                it.next();
            }
            '|' => out.push(std::mem::take(&mut cur).trim().to_string()),
            _ => cur.push(c),
        }
    }
    out.push(cur.trim().to_string());
    out
}

/// Строка таблицы из ячеек: «| a | b |». «|» в тексте экранируется, перенос строки — `<br>`.
pub fn row_line(cells: &[String]) -> String {
    let c: Vec<String> = cells.iter().map(|x| to_cell(x)).collect();
    format!("| {} |", c.join(" | "))
}

/// Текст из поля правки → ячейка файла: перенос строки — `<br>`, без «|»-границ.
fn to_cell(t: &str) -> String {
    t.trim().replace('\r', "").replace('\n', "<br>").replace('|', "\\|")
}

/// Ячейка файла → текст для поля правки: `<br>` — перенос строки.
pub fn edit_text(cell: &str) -> String {
    let mut s = cell.to_string();
    for b in ["<br />", "<br/>", "<BR>", "<br>"] {
        s = s.replace(b, "\n");
    }
    s
}

fn parse_align(c: &str) -> Align {
    let c = c.trim();
    match (c.starts_with(':'), c.ends_with(':') && c.len() > 1) {
        (true, true) => Align::Center,
        (true, false) => Align::Left,
        (false, true) => Align::Right,
        _ => Align::None,
    }
}

/// Сравнение для сортировки: числа — как числа, текст — без учёта регистра (ё = е).
fn sort_key(a: &str, b: &str) -> std::cmp::Ordering {
    let num = |s: &str| s.trim().replace(' ', "").replace(',', ".").parse::<f64>().ok();
    match (num(a), num(b)) {
        (Some(x), Some(y)) => x.partial_cmp(&y).unwrap_or(std::cmp::Ordering::Equal),
        (Some(_), None) => std::cmp::Ordering::Less,
        (None, Some(_)) => std::cmp::Ordering::Greater,
        _ => {
            let k = |s: &str| s.to_lowercase().replace('ё', "е");
            // пустые — в конец
            match (a.trim().is_empty(), b.trim().is_empty()) {
                (true, false) => std::cmp::Ordering::Greater,
                (false, true) => std::cmp::Ordering::Less,
                _ => k(a).cmp(&k(b)),
            }
        }
    }
}

impl Table {
    /// Разбор строк одной таблицы (как они идут в файле).
    pub fn parse(lines: &[&str]) -> Table {
        let mut rows = vec![];
        let mut sep: Option<String> = None;
        let mut head = false;
        for (k, l) in lines.iter().enumerate() {
            if is_sep(l) {
                // разделитель сразу под первой строкой — шапка; лишние разделители ниже пропадут при правке колонок
                if k == 1 && sep.is_none() {
                    head = true;
                    sep = Some(l.to_string());
                }
                continue;
            }
            rows.push(Row { cells: cells(l), raw: Some(l.to_string()) });
        }
        let n = rows.iter().map(|r| r.cells.len()).max().unwrap_or(0).max(1);
        let mut align: Vec<Align> = sep.as_deref().map(|s| cells(s).iter().map(|c| parse_align(c)).collect()).unwrap_or_default();
        align.resize(n, Align::None);
        for r in &mut rows {
            r.cells.resize(n, String::new());
        }
        Table { rows, align, head, sep_raw: sep }
    }

    /// Новая таблица: шапка «Колонка 1…n» и пустые строки.
    pub fn new(cols: usize, body: usize) -> Table {
        let cols = cols.max(1);
        let mut rows = vec![Row { cells: (1..=cols).map(|i| format!("Колонка {i}")).collect(), raw: None }];
        rows.extend((0..body).map(|_| Row { cells: vec![String::new(); cols], raw: None }));
        Table { rows, align: vec![Align::None; cols], head: true, sep_raw: None }
    }

    pub fn cols(&self) -> usize {
        self.align.len()
    }
    pub fn rows(&self) -> usize {
        self.rows.len()
    }
    pub fn cell(&self, r: usize, c: usize) -> &str {
        self.rows.get(r).and_then(|x| x.cells.get(c)).map(|s| s.as_str()).unwrap_or("")
    }
    /// Первая строка тела (под шапкой).
    fn body0(&self) -> usize {
        usize::from(self.head)
    }
    fn shape_changed(&mut self) {
        self.sep_raw = None;
        for r in &mut self.rows {
            r.raw = None;
        }
    }

    /// Строки файла.
    pub fn lines(&self) -> Vec<String> {
        let mut out = vec![];
        for (k, r) in self.rows.iter().enumerate() {
            out.push(r.raw.clone().unwrap_or_else(|| row_line(&r.cells)));
            if k == 0 && self.head {
                out.push(self.sep_raw.clone().unwrap_or_else(|| format!("|{}|", self.align.iter().map(|a| a.sep()).collect::<Vec<_>>().join("|"))));
            }
        }
        out
    }

    /// Текст ячейки из поля правки. false — ничего не поменялось.
    pub fn set(&mut self, r: usize, c: usize, text: &str) -> bool {
        let v = to_cell(text).replace("\\|", "|");
        let Some(row) = self.rows.get_mut(r) else { return false };
        let Some(cell) = row.cells.get_mut(c) else { return false };
        if *cell == v {
            return false;
        }
        *cell = v;
        row.raw = None;
        true
    }

    /// Правка таблицы по команде; ответ — куда встать после неё (строка, колонка).
    /// `None` — команда не подошла (таблица не изменилась). Пустая таблица (колонок или строк не осталось)
    /// — `rows() == 0`: её убирают из заметки целиком.
    pub fn op(&mut self, op: &str, r: usize, c: usize) -> Option<(usize, usize)> {
        let (nr, nc, b0) = (self.rows.len(), self.cols(), self.body0());
        let r = r.min(nr.saturating_sub(1));
        let c = c.min(nc.saturating_sub(1));
        let blank = || Row { cells: vec![String::new(); nc], raw: None };
        match op {
            "row-above" | "row-below" => {
                let at = if op == "row-above" { r } else { r + 1 }.max(b0).min(nr);
                self.rows.insert(at, blank());
                Some((at, c))
            }
            "row-dup" => {
                let mut x = self.rows.get(r)?.clone();
                x.raw = None;
                let at = (r + 1).max(b0);
                self.rows.insert(at, x);
                Some((at, c))
            }
            "row-up" if r > b0 => {
                self.rows.swap(r, r - 1);
                Some((r - 1, c))
            }
            "row-down" if r >= b0 && r + 1 < nr => {
                self.rows.swap(r, r + 1);
                Some((r + 1, c))
            }
            "row-del" if r >= b0 && nr > 0 => {
                self.rows.remove(r);
                if self.rows.is_empty() {
                    return Some((0, 0));
                }
                Some((r.min(self.rows.len() - 1), c))
            }
            "col-left" | "col-right" => {
                let at = if op == "col-left" { c } else { c + 1 }.min(nc);
                for x in &mut self.rows {
                    x.cells.insert(at, String::new());
                }
                self.align.insert(at, Align::None);
                self.shape_changed();
                Some((r, at))
            }
            "col-dup" => {
                for x in &mut self.rows {
                    let v = x.cells[c].clone();
                    x.cells.insert(c + 1, v);
                }
                self.align.insert(c + 1, self.align[c]);
                self.shape_changed();
                Some((r, c + 1))
            }
            "col-move-left" if c > 0 => {
                self.swap_cols(c, c - 1);
                Some((r, c - 1))
            }
            "col-move-right" if c + 1 < nc => {
                self.swap_cols(c, c + 1);
                Some((r, c + 1))
            }
            "col-del" => {
                if nc <= 1 {
                    self.rows.clear();
                    return Some((0, 0));
                }
                for x in &mut self.rows {
                    x.cells.remove(c);
                }
                self.align.remove(c);
                self.shape_changed();
                Some((r, c.min(nc - 2)))
            }
            "align-none" | "align-left" | "align-center" | "align-right" => {
                let a = match op {
                    "align-left" => Align::Left,
                    "align-center" => Align::Center,
                    "align-right" => Align::Right,
                    _ => Align::None,
                };
                if self.align[c] == a {
                    return None;
                }
                self.align[c] = a;
                if !self.head {
                    // выравнивание живёт в строке-разделителе: без шапки первая строка становится шапкой
                    self.head = true;
                }
                self.sep_raw = None;
                Some((r, c))
            }
            "sort-asc" | "sort-desc" => {
                let mut body: Vec<Row> = self.rows.drain(b0..).collect();
                let before: Vec<Vec<String>> = body.iter().map(|x| x.cells.clone()).collect();
                body.sort_by(|a, b| {
                    let o = sort_key(&a.cells[c], &b.cells[c]);
                    if op == "sort-desc" { o.reverse() } else { o }
                });
                let same = body.iter().map(|x| &x.cells).eq(before.iter());
                self.rows.extend(body);
                if same {
                    return None;
                }
                Some((r, c))
            }
            "table-del" => {
                self.rows.clear();
                Some((0, 0))
            }
            _ => None,
        }
    }

    fn swap_cols(&mut self, a: usize, b: usize) {
        for x in &mut self.rows {
            x.cells.swap(a, b);
        }
        self.align.swap(a, b);
        self.shape_changed();
    }

    /// Ширина колонок по содержимому — в долях размера шрифта (em). Узкая колонка не уже 4 em,
    /// широкая не шире 24 em: длинный текст переносится. Окно умножает на размер шрифта
    /// и, если вся таблица не влезает, сжимает колонки поровну.
    pub fn widths(&self) -> Vec<f32> {
        (0..self.cols())
            .map(|c| {
                let w = self
                    .rows
                    .iter()
                    .enumerate()
                    .map(|(k, x)| {
                        let t = edit_text(&x.cells[c]);
                        let longest = t.split('\n').map(|p| crate::mdline::plain(p.trim()).text.chars().count()).max().unwrap_or(0);
                        // шапка жирная — чуть шире
                        longest as f32 * if k == 0 && self.head { 0.7 } else { 0.64 }
                    })
                    .fold(0.0, f32::max);
                (w + 1.9).clamp(4.0, 24.0)
            })
            .collect()
    }
}
