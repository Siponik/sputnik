import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board
from s_board import sidebar, titlebar
K = dim(s_board.KANBAN)

# ---------- SPHERES ----------
sph = [('Р', '3D и заказы', OR, [('3D-ассеты', 'К', 7), ('Иконки для клиента', 'К', 4), ('Заказы клиентов', 'К', 3)], 'ВМЕСТЕ · 3'),
       ('Р', 'Работа', BLUE, [('Работа · клиенты', 'К', 9)], ''),
       ('Д', 'Дом', GREEN, [('Дела по дому', 'С', 11), ('Покупки', 'Л', 5)], ''),
       ('У', 'Учёба', VIO, [('Учёба', 'Л', 4)], '')]
def sbody(ls):
    return '<div style="padding: 8px">' + ''.join(f'<div style="height: 32px; display: flex; align-items: center; gap: 8px; padding: 0 6px; border-bottom: 1px solid transparent"><span style="width: 16px; height: 16px; border-radius: 4px; border: 1px solid {LINE}; display: grid; place-items: center; font: 500 9px {MONO}; color: {MUT}">{v}</span><span style="flex: 1">{t}</span><span style="font: 400 10.5px {MONO}; color: {DIM}">{n}</span></div>' for t, v, n in ls) + f'<div style="height: 32px; display: flex; align-items: center; padding: 0 6px; color: {MUT}">＋ Список</div></div>'
st = sidebar('', 'Перетащи список в другую сферу прямо в колонке слева.')
st += node(236, 0, 668, 48, f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px"><span style="font-weight: 600; font-size: 15px">Сферы</span>{micro("4 СФЕРЫ · 8 СПИСКОВ", DIM)}<span style="flex: 1"></span>{btn("＋ Сфера", "acc", True)}</div>')
for i, (ic, n, c, ls, tag) in enumerate(sph):
    r, cc = divmod(i, 2)
    x = 236 + cc * 344; y = 64 + r * 240
    ex = ''
    st += node(x, y, 324, 0, nhead('', n.upper(), tag or f'{len(ls)} СП.', c) + sbody(ls), hub=(i == 0), extra=ex)
st += node(236, 560, 668, 0, nhead('', 'БЕЗ СФЕРЫ', '1', GREY) + f'<div style="padding: 12px; display: flex; gap: 10px; align-items: center">{coon(36, "СОН")}<span style="color: {MUT}">«Старые заметки» пока ни в какой сфере. Перетащи в нужную.</span></div>', wait=True)
icons = ''.join(f'<span style="width: 32px; height: 32px; border-radius: 8px; box-sizing: border-box; display: grid; place-items: center; {"background: " + WASH + "; border: 1px solid " + OR if j == 0 else "border: 1px solid " + LINE}; color: {INK}; font-size: 14px">{g}</span>' for j, g in enumerate(['◆', '✎', '▲', '●', '☕', '♫', '⚑', '✦', '⌂', '✈', '☀', '♥']))
cols = ''.join(f'<span style="width: 28px; height: 28px; border-radius: 8px; background: {c}; {"outline: 2px solid " + ORI + "; outline-offset: 2px" if j == 0 else ""}"></span>' for j, c in enumerate([OR, BLUE, GREEN, VIO, GOLD, RED, GREY]))
ed = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 18px">
 {field("Название", f'<span style="width: 100%; height: 38px; box-sizing: border-box; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 12px; font-size: 14px">3D и заказы</span>')}
 {field("Цвет", cols)}
 {field("Значок", icons)}
 {field("Списки в сфере", sc("3D-ассеты", True) + sc("Иконки для клиента", True) + sc("Заказы клиентов", True) + sc("＋ Добавить"))}
 {field("Вместе с другими", f'<span style="font-size: 12.5px; color: {MUT}">С тобой работают Оля и Аня.</span>{btn("Участники", sm=True)}')}
 <div style="display: flex; gap: 8px; margin-top: 4px">{btn("Сохранить", "acc")}{btn("Удалить сферу", "ghost", extra="; color: " + RED)}</div>
</div>'''
st += node(928, 64, 320, 636, nhead('', 'СФЕРА · ПРАВКА', 'ENTER', OR, None, 32) + ed)
save2('G_Spheres.dc.html', page('Сферы', 'ДОСКА', st), 'Сферы')

# ---------- TEMPLATES ----------
tl = [('Работа', 'ВСТРОЕННЫЙ · 2 СПИСКА', BLUE, True), ('3D-ассеты', 'ВСТРОЕННЫЙ · 1', OR, False), ('Личное', 'ВСТРОЕННЫЙ · 1', GREEN, False), ('Учёба', 'ВСТРОЕННЫЙ · 1', VIO, False), ('Заказы клиентов', 'ВСТРОЕННЫЙ · 1', GOLD, False), ('Скетчи', 'СВОЙ · 0', GREY, False)]
tlh = '<div style="padding: 8px">' + ''.join(f'<div style="margin-bottom: 4px; padding: 8px 10px; border-radius: 8px; {"background: " + WASH + "; border: 1px solid " + OR if on else "border: 1px solid transparent"}"><span style="display: flex; align-items: center; gap: 8px">{dot(c)}<span style="font-weight: 600">{t}</span></span><span style="display: block; margin-top: 2px">{micro(k)}</span></div>' for t, k, c, on in tl) + f'<div style="padding: 8px 10px; color: {MUT}">＋ Новый шаблон</div></div>'
st = sidebar('', 'Правка шаблона меняет все списки, которые идут за ним.')
st += node(236, 0, 220, 700, nhead('', 'ШАБЛОНЫ ДОСОК', '6', None) + tlh)
colsd = [('Входящие', GREY, '—', False), ('В работе', OR, '3', False), ('Проверка', VIO, '—', False), ('Готово', GREEN, '—', True)]
cw = 132; cg = 22; cx0 = 6
chain = ''; cw_ = ''
for i, (n, c, lim, lock) in enumerate(colsd):
    x = cx0 + i * (cw + cg)
    ex = (sock('r', 14, c) if i < 3 else '') + (sock('l', 14, colsd[i - 1][1]) if i > 0 else '')
    chain += node(x, 0, cw, 120, nhead(f'0{i + 1}', n.upper(), '🔒' if lock else '⠿', c) + f'<div style="padding: 10px; display: flex; flex-direction: column; gap: 8px; font-size: 12.5px"><span style="display: flex; justify-content: space-between; color: {MUT}">Лимит<span style="font: 400 12px {MONO}; color: {INK}">{lim}</span></span><span style="display: flex; justify-content: space-between; color: {MUT}">Цвет{dot(c, 10)}</span>{"" if not lock else micro("ПОСЛЕДНЯЯ, НЕ УДАЛЯЕТСЯ")}</div>', extra=ex)
    if i < 3: cw_ += wire(x + cw + 1, 19, x + cw + cg - 1, 19, c, 1.5, k=8)
chain += f'<div style="position: absolute; left: {cx0 + 4 * (cw + cg)}px; top: 0; width: 80px; height: 120px; border-radius: 8px; border: 1px dashed {STRONG}; display: grid; place-items: center; color: {MUT}; font-size: 12.5px">＋ Колонка</div>'
ed = f'''<div style="padding: 18px 20px; display: flex; flex-direction: column; gap: 20px">
 <div style="display: flex; gap: 20px; align-items: flex-end">{field("Название шаблона", f'<span style="width: 300px; height: 38px; box-sizing: border-box; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 12px; font-size: 14px">Работа</span>')}{field("Вид доски", seg(["КАНБАН", "КОНВЕЙЕР", "СТИКЕРЫ", "СПИСОК"], "КАНБАН"))}</div>
 <div><span style="font: 500 12.5px {SANS}; color: {MUT}">Колонки · перетащи, чтобы поменять порядок</span><div style="position: relative; height: 120px; margin-top: 10px"><svg width="760" height="120" style="position: absolute; left: 0; top: 0" aria-hidden="true" fill="none">{cw_}</svg>{chain}</div></div>
 {field("Поля карточки", sc("Срок", True) + sc("Приоритет", True) + sc("Подзадачи", True) + sc("Клиент", True) + sc("Сумма") + sc("Картинка"))}
 {field("Используется", f'<span style="display: inline-flex; align-items: center; gap: 6px">{dot(BLUE)}Работа · клиенты</span><span style="color: {MUT}">и ещё 1 список</span>')}
 <div style="display: flex; gap: 8px">{btn("Сохранить шаблон", "acc")}{btn("Дублировать")}{btn("Вернуть как было", "ghost")}</div>
 <div style="font-size: 12.5px; color: {MUT}">Если колонку убрать, её задачи переедут в колонку с тем же названием, а если такой нет — в соседнюю.</div>
</div>'''
st += node(472, 0, 776, 700, nhead('', 'ШАБЛОН · РАБОТА', 'ВСТРОЕННЫЙ', BLUE, None, 34, INK, OR) + ed, hub=True)
save2('G_Templates.dc.html', page('Шаблоны досок', 'ДОСКА', st), 'Шаблоны досок и редактор')

# ---------- LIST SETTINGS ----------
ls = f'''<div style="padding: 16px 22px; display: flex; flex-direction: column">
 {field("Название", f'<span style="width: 100%; height: 38px; box-sizing: border-box; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 12px; font-size: 14px">Работа · клиенты</span>')}
 <div style="height: 10px"></div>
 {srow("Сфера", "", ddtrig(dot(BLUE) + "Работа"))}
 {srow("Порядок задач", "Как сортировать карточки в колонках", seg(["СВОЙ", "ПО СРОКУ", "ПО ПРИОРИТЕТУ"], "ПО ПРИОРИТЕТУ"))}
 {srow("Показывать в «Сегодня»", "Задачи с датой попадают на главный экран", toggle(True))}
 {srow("В сводке и боте", "Выключи, если список тихий: доска и напоминания останутся", toggle(True))}
 {srow("Сделанное в архив через", "", seg(["СРАЗУ", "3 ДНЯ", "7 ДНЕЙ"], "3 ДНЯ"))}
 {srow("Колонки", "Сейчас по шаблону «Работа»", btn("Колонки из другого шаблона…", sm=True))}
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 60px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 8px; padding: 0 22px">{btn("Вернуть как в шаблоне", "ghost")}<span style="flex: 1"></span>{btn("Сохранить как новый шаблон…")}{btn("Сохранить", "acc")}</div>'''
st = K + pop(304, 40, 640, 560, 'НАСТРОЙКИ СПИСКА · CTRL .', ls, BLUE, 'ПО ШАБЛОНУ', hub=True)
save2('G_ListSettings.dc.html', page('Настройки списка', 'ДОСКА', st), 'Настройки списка')

# ---------- ARCHIVE ----------
rows = ''
for g, items in [('Вчера', [('Иконки v1', 'Работа · клиенты', BLUE, '04.11'), ('Вынести коробки', 'Дела по дому', GREEN, '04.11')]), ('На этой неделе', [('Ретопология меча', '3D-ассеты', OR, '03.11'), ('Договор', 'Работа · клиенты', BLUE, '02.11'), ('Глава 3 · Substance', 'Учёба', VIO, '02.11')]), ('Октябрь', [('Факел · сдача', '3D-ассеты', OR, '28.10'), ('Квитанция за газ', 'Дела по дому', GREEN, '20.10')])]:
    rows += f'<div style="padding: 14px 16px 6px; font-size: 12.5px; color: {MUT}">{g}</div>'
    for t, l, c, d in items:
        rows += f'<div style="margin: 0 8px; height: 42px; display: flex; align-items: center; gap: 12px; padding: 0 10px; border-bottom: 1px solid {SOFT}">{check(True)}<span style="flex: 1; color: #C9CAD0">{t}</span><span style="display: flex; align-items: center; gap: 6px; width: 170px; font-size: 12px; color: {MUT}">{dot(c)}{l}</span><span style="width: 60px; font: 400 11px {MONO}; color: {DIM}">{d}</span>{btn("Вернуть", sm=True)}</div>'
top = f'<div style="padding: 12px 16px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap; border-bottom: 1px solid {LINE}"><span style="width: 260px; height: 34px; box-sizing: border-box; border-radius: 8px; border: 1px solid {STRONG}; background: {BG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}">Найти в архиве</span>{sc("Все списки", True)}{sc(dot(OR) + "3D-ассеты")}{sc(dot(BLUE) + "Работа")}{sc(dot(GREEN) + "Дом")}{sc(dot(VIO) + "Учёба")}</div>'
st = sidebar('', 'Сделанное больше 3 дней назад уходит сюда само.')
st += node(236, 0, 1012, 700, nhead('', 'АРХИВ', '7 ЗАДАЧ · ЗА МЕСЯЦ', GREY, None, 34, INK, OR) + top + rows, hub=True)
save2('G_Archive.dc.html', page('Архив', 'ДОСКА', st), 'Архив')

# ---------- LIST VIEW ----------
def lrow(t, meta, date, lessons=None, prio='', done=False, over=False):
    pr = f'<span style="font: 600 11px {MONO}; color: {OR}">{prio}</span>' if prio else ''
    ls_ = ''
    if lessons:
        a, b = lessons
        ls_ = f'<span style="display: flex; align-items: center; gap: 8px; width: 160px"><span style="flex: 1; height: 4px; border-radius: 2px; background: #45464D; overflow: hidden"><span style="display: block; width: {int(a / b * 100)}%; height: 100%; background: {VIO}"></span></span>{micro(f"УРОК {a}/{b}", MUT)}</span>'
    else:
        ls_ = '<span style="width: 160px"></span>'
    tt = f'text-decoration: line-through; color: {DIM}' if done else ''
    return f'<div style="height: 44px; display: flex; align-items: center; gap: 12px; padding: 0 12px; border-bottom: 1px solid {SOFT}">{check(done)}<span style="flex: 1; {tt}">{t}<span style="margin-left: 10px; font-size: 12px; color: {MUT}">{meta}</span></span>{pr}{ls_}<span style="width: 80px; text-align: right; font: 400 11px {MONO}; color: {RED if over else MUT}">{date}</span></div>'
body = ''
for g, c, rs in [('Просрочено', RED, [lrow('Домашка по топологии', 'Курс по Blender', 'ВТ 03', prio='!!', over=True)]),
                 ('Сегодня', OR, [lrow('Глава 4 курса по Substance', 'Курс по Substance', '19:00', (4, 12))]),
                 ('На неделе', MUT, [lrow('Разобрать запекание нормалей', 'Курс по Substance', 'СБ 07', (5, 12)), lrow('Посмотреть разбор от Пола', '', 'ВС 08')]),
                 ('Без срока', MUT, [lrow('Книга «Анатомия для художников»', 'гл. 2 из 9', '—', (2, 9)), lrow('Записаться на курс по ZBrush', '', '—')])]:
    body += f'<div style="padding: 14px 14px 4px; display: flex; align-items: center; gap: 8px">{dot(c)}<span style="font-size: 12.5px; color: {MUT}">{g}</span></div>' + ''.join(rs)
body += f'<div style="height: 44px; display: flex; align-items: center; padding: 0 14px; color: {MUT}">＋ Добавить задачу <span style="margin-left: 10px">{kbd("N")}</span></div>'
st = sidebar('Учёба', 'Вид «Список» удобен для учёбы: видно, сколько уроков пройдено.')
st += node(236, 0, 1012, 48, f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{dot(VIO, 8)}<span style="font-weight: 600; font-size: 15px">Учёба</span><span style="color: {DIM}; font-size: 16px">⋯</span>{micro("ПО ШАБЛОНУ «УЧЁБА»")}<span style="flex: 1"></span>{seg(["КАНБАН", "СТИКЕРЫ", "СПИСОК"], "СПИСОК")}</div>')
st += node(236, 64, 1012, 0, nhead('', 'УЧЁБА · ВСЕ ЗАДАЧИ', '6 ОТКРЫТО', VIO, None, 34, INK, OR) + body, hub=True)
save2('G_ListView.dc.html', page('Вид «Список»', 'ДОСКА', st), 'Доска · вид «Список»')

# ---------- GALLERY ----------
items = [('Щит «Таверны»', 'ПОКРАСКА', 3, OR, True), ('Меч героя', 'РЕНДЕР', 4, OR, False), ('Шлем рыцаря', 'РЕТОПО', 1, OR, False), ('Сундук', 'МОДЕЛЬ', 0, OR, False), ('Факел', 'СДАЧА', 5, OR, False), ('Бочка', 'UV', 2, OR, False), ('Фонарь', 'МОДЕЛЬ', 0, OR, False), ('Кружка', 'ПОКРАСКА', 3, OR, False)]
GW = 236; GG = 14
st = sidebar('3D-ассеты', 'Перетащи картинку на ассет, чтобы поставить превью.')
st += titlebar('3D-ассеты', OR, 'КОНВЕЙЕР', seg(['СТРОКИ', 'ГАЛЕРЕЯ'], 'ГАЛЕРЕЯ'))
st += ab(236, 62, f'<div style="display: flex; gap: 6px">{sc("Все этапы", True)}{sc("Модель")}{sc("UV")}{sc("Покраска")}{sc("Рендер")}{sc("Сдача")}</div>')
for i, (t, sname, cur, c, sel) in enumerate(items):
    r, cc = divmod(i, 4)
    x = 236 + cc * (GW + GG); y = 108 + r * 262
    has = i in (0, 1, 4)
    pv = (f'<div style="height: 180px; border-radius: 7px 7px 0 0; background: radial-gradient(circle at 50% 45%, #5A4632 0, #2B2520 60%); position: relative; display: grid; place-items: center">'
          f'<span style="width: 90px; height: 110px; border-radius: 45% 45% 40% 40%; background: linear-gradient(160deg, #A8763F, #5C3B1E); box-shadow: inset 0 0 0 6px #7A5530"></span><span style="position: absolute; right: 8px; bottom: 8px">{micro("2048 × 2048", "#D8C2A5")}</span></div>') if has else \
         (f'<div style="height: 180px; border-radius: 7px 7px 0 0; background-color: #2B2520; background-image: linear-gradient(rgba(240,160,75,.08) 1px, transparent 1px), linear-gradient(90deg, rgba(240,160,75,.08) 1px, transparent 1px); background-size: 14px 14px; display: grid; place-items: center"><span style="text-align: center; font-size: 12px; color: {MUT}">Перетащи или вставь<br>картинку · Ctrl V</span></div>')
    st += node(x, y, GW, 250, pv + f'<div style="padding: 10px 12px; display: flex; flex-direction: column; gap: 8px"><span style="display: flex; justify-content: space-between"><span style="font-weight: 600">{t}</span>{micro(sname, OR if sel else MUT)}</span>{stages(cur, cur, 6)}</div>', hub=sel)
save2('G_Gallery.dc.html', page('Галерея', 'ДОСКА', st), 'Конвейер · галерея')
print('ok')
