#!/usr/bin/env python3
"""Сводит i18n/parts/*.po в en/LC_MESSAGES/sputnik.po (без повторов msgid, первая запись главнее).
Запуск: python3 rust/i18n/merge.py"""
import pathlib, re
here = pathlib.Path(__file__).parent
main = here / "en/LC_MESSAGES/sputnik.po"
def entries(text):
    out = []
    for block in re.split(r"\n\s*\n", text):
        lines = [l for l in block.strip().splitlines() if l.strip()]
        if not any(l.startswith("msgid ") for l in lines):
            continue
        m = re.search(r'^msgid "(.*)"$', "\n".join(lines), re.M)
        out.append((m.group(1) if m else "", "\n".join(lines)))
    return out
src = main.read_text(encoding="utf-8")
seen, blocks = set(), []
header, *_ = src.split("\n\n", 1)
for mid, b in entries(src):
    if mid == "" or mid in seen: continue
    seen.add(mid); blocks.append(b)
for p in sorted((here / "parts").glob("*.po")):
    for mid, b in entries(p.read_text(encoding="utf-8")):
        if mid == "" or mid in seen: continue
        seen.add(mid); blocks.append(b)
head = '# Спутник — английский перевод. Исходный текст — русский (msgid), перевод — msgstr.\n# Один файл на Slint (@tr) и Rust (t!). Без msgctxt. Правила — docs/i18n.md.\nmsgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Language: en\\n"\n'
main.write_text(head + "\n" + "\n\n".join(blocks) + "\n", encoding="utf-8")
print(len(blocks), "строк")
