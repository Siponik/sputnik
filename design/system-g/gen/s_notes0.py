# Знания: «Как это работает» — объяснение для пользователя. Запуск: python3 s_notes0.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from s_notes import *

T = lambda t: f'<div style="font: 600 14px {SANS}; color: {INK}">{t}</div>'
D = lambda t: f'<div style="margin-top: 4px; font-size: 12.5px; line-height: 18px; color: #C9CAD0">{t}</div>'

def step(x, y, w, h, n, title, color, head, text, hub=False, sl=False, sr=False):
    ex = (sock('l', 40, color) if sl else '') + (sock('r', 40, color) if sr else '')
    return node(x, y, w, h, nhead(n, title, '', color, None, 30, INK, OR if hub else LINE) + f'<div style="padding: 10px 14px">{T(head)}{D(text)}</div>', hub=hub, extra=ex)

st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ЗНАНИЯ · КАК ЭТО РАБОТАЕТ", INK)}{micro("ПРОЧИТАЙ ЭТО ПЕРВЫМ · ДАЛЬШЕ ЭКРАНЫ ПО ПОРЯДКУ", MUT)}</div>', w=1248)
# ряд 1: путь данных
Y = 34; H = 150; W = 290; G = 29
xs = [i * (W + G) for i in range(4)]
st += svg(''.join(wire(xs[i] + W + 1, Y + 45, xs[i + 1] - 1, Y + 45, c, 2, k=14) for i, c in enumerate([OR, OR, BLUE])))
st += step(xs[0], Y, W, H, '01', 'ТВОИ ФАЙЛЫ', GREY, 'Папка с заметками .md', 'Одна заметка — один текстовый файл на компьютере. Это и есть база: её откроет и Obsidian, ничего не пропадёт.', sr=True)
st += step(xs[1], Y, W, H, '02', 'СПУТНИК ЧИТАЕТ', GREY, 'Находит связи сам', 'В тексте ищет [[ссылки]] на другие заметки, #теги и свойства из шапки. Из них строит карту базы.', sl=True, sr=True)
st += step(xs[2], Y, W, H, '03', 'ТЫ РАБОТАЕШЬ', OR, 'Вкладка «Знания»', 'Пишешь, ищешь, смотришь связи — в пяти видах ниже. Всё сохраняется в те же файлы сразу.', hub=True, sl=True, sr=True)
st += step(xs[3], Y, W, H, '04', 'ВТОРОЙ КОМПЬЮТЕР', BLUE, 'Копия на твоём Drive', 'Спутник сам кладёт заметки в «Спутник / Знания» на Google Drive и забирает их на другом компьютере.', sl=True)

# ряд 2: как появляется связь
Y2 = 214
st += colhead(0, Y2, 1248, 'ГЛАВНОЕ: КАК ЗАМЕТКИ СВЯЗЫВАЮТСЯ')
ex = f'''<div style="padding: 14px 16px; display: grid; grid-template-columns: 1fr 24px 1fr 24px 1fr 24px 1fr; gap: 0; align-items: center">
 <div><div style="font-size: 12px; color: {MUT}">1. Пишешь в заметке «Пайплайн ассета»</div><div style="margin-top: 6px; padding: 8px 10px; border-radius: 8px; background: {BG}; border: 1px solid {LINE}; font-size: 13px">4. Пеку по {wl("[[Запекание нормалей]]")}</div></div>
 <span style="text-align: center; color: {OR}">→</span>
 <div><div style="font-size: 12px; color: {MUT}">2. Это ссылка — клик открывает ту заметку</div><div style="margin-top: 6px; font-size: 13px">Нет такой заметки — ссылка пунктиром, {wl("клик создаст её", False)}</div></div>
 <span style="text-align: center; color: {OR}">→</span>
 <div><div style="font-size: 12px; color: {MUT}">3. У «Запекания» в «Связях»</div><div style="margin-top: 6px; font-size: 13px">«Ссылаются сюда: <b style="font-weight: 600">Пайплайн ассета</b>» — с куском текста</div></div>
 <span style="text-align: center; color: {OR}">→</span>
 <div><div style="font-size: 12px; color: {MUT}">4. На графе</div><div style="margin-top: 6px; display: flex; align-items: center; gap: 6px; font-size: 12px"><span style="width: 10px; height: 10px; border-radius: 50%; background: {OR}"></span><span style="flex: 0 0 50px; height: 1.5px; background: {OR}"></span><span style="width: 14px; height: 14px; border-radius: 50%; background: {OR}"></span><span style="color: {MUT}">две точки и линия</span></div></div>
</div>'''
st += node(0, Y2 + 22, 1248, 112, ex)

# ряд 3: какой вид для чего
Y3 = 372
st += colhead(0, Y3, 1248, 'КАКОЙ ЭКРАН ДЛЯ ЧЕГО · ПЕРЕКЛЮЧАТЕЛЬ «СПИСОК | КАРТОЧКИ | ТАБЛИЦА | ГРАФ» ВВЕРХУ')
views = [
    ('ЗНАНИЯ', OR, 'Написать и читать', 'Слева папки → список заметок → в центре заметка → справа её связи и маленький граф.'),
    ('ГРАФ', VIO, 'Увидеть всю базу', 'Точка — заметка, линия — ссылка. Крутишь колёсико ближе — точки становятся карточками с проводами.'),
    ('ХОЛСТ', VIO, 'Собрать схему руками', 'Свободная доска: кладёшь заметки, картинки и текст, соединяешь сам. Для кампании DND или пайплайна.'),
    ('КАРТОЧКИ', GOLD, 'Референсы', 'Те же заметки папки, но крупно с картинками — удобно для подборок.'),
    ('ТАБЛИЦА', BLUE, 'Сравнить по полям', 'Каждая заметка — строка, поля из шапки — колонки: «где», «фракция», «статус». Можно править прямо в ячейке.'),
    ('CTRL K · ЗАДАЧИ', GREEN, 'Найти и связать', 'Поиск находит заметки вместе с задачами. В окне задачи — блок «Заметки», а пункты «- [ ]» превращаются в задачи.'),
]
CW = 196; CG = (1248 - 6 * CW) // 5
for i, (t, c, h, d) in enumerate(views):
    st += node(i * (CW + CG), Y3 + 22, CW, 196, nhead('', t, '', c, None, 30, INK, LINE) + f'<div style="padding: 10px 12px">{T(h)}<div style="margin-top: 4px; font-size: 12px; line-height: 17px; color: #C9CAD0">{d}</div></div>')
st += ab(0, 612, f'<div style="display: flex; gap: 12px; align-items: center; padding: 10px 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 900px; box-sizing: border-box">{coon(40, "ПРИВЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Коротко: ты просто пишешь заметки и ставишь [[ссылки]]. Всё остальное — граф, связи, таблицы — Спутник строит сам из этих ссылок и полей. Файлы остаются твоими.</span></div>')
st += stamp(968, 640, 'ЗНАНИЯ · СХЕМА', '5 ВИДОВ', 'ЛИСТ 00')
save3('G_NotesHow.dc.html', page('Знания · как это работает', 'ЗНАНИЯ', st, R), 'Знания · как это работает (читать первым)', -1)
print('ok0')
