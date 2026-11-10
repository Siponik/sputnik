//! Чистая логика Спутника: без окна, файлов и сети. Поведение берётся у старого кода (tracker/src/lib/*.js);
//! совпадение проверяют золотые тесты (tests/*.rs читают app/test/golden/*.json — ответы настоящего JS).
pub mod accent;
pub mod boardedit;
pub mod authcheck;
pub mod dates;
pub mod dropdown;
pub mod j;
pub mod layer;
pub mod repeat;
pub mod rx;
pub mod search;
pub mod small;
pub mod spheres;
pub mod stickers;
pub mod templates;
pub mod today;
pub mod when;
