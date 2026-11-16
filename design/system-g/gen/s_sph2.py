import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_board import sidebar

# Сферы: как попасть в правку и как отправить сферу в архив
sph = [('3D и заказы', OR, [('3D-ассеты', 'К', 7), ('Иконки для клиента', 'К', 4), ('Заказы клиентов', 'К', 3)], 'ВМЕСТЕ · 3'),
       ('Работа', BLUE, [('Работа · клиенты', 'К', 9)], ''),
       ('Дом', GREEN, [('Дела по дому', 'С', 11), ('Покупки', 'Л', 5)], ''),
       ('Учёба', VIO, [('Учёба', 'Л', 4)], '')]
def sbody(ls):
    return '<div style="padding: 8px">' + ''.join(f'<div style="height: 32px; display: flex; align-items: center; gap: 8px; padding: 0 6px"><span style="width: 16px; height: 16px; border-radius: 4px; border: 1px solid {LINE}; display: grid; place-items: center; font: 500 9px {MONO}; color: {MUT}">{v}</span><span style="flex: 1">{t}</span><span style="font: 400 10.5px {MONO}; color: {DIM}">{n}</span></div>' for t, v, n in ls) + f'<div style="height: 32px; display: flex; align-items: center; padding: 0 6px; color: {MUT}">＋ Список</div></div>'
def badge(n, x, y):
    return ab(x, y, f'<span style="width: 18px; height: 18px; border-radius: 50%; background: {OR}; color: {DARK}; display: grid; place-items: center; font: 600 10.5px {MONO}">{n}</span>')

st = sidebar('', 'Нажми на название сферы — откроется её правка.')
# наведение на название сферы в колонке: подсветка, шестерёнка и ⋯
st += ab(8, 84, f'<div style="width: 204px; height: 26px; box-sizing: border-box; border-radius: 6px; background: {WASH}; border: 1px solid {OR}; display: flex; align-items: center; gap: 8px; padding: 0 6px 0 8px">{dot(OR)}<span style="font: 500 10px {MONO}; letter-spacing: .14em; color: {INK}">3D И ЗАКАЗЫ</span><span style="margin-left: auto; color: {MUT}">⚙</span><span style="color: {INK}">⋯</span></div>')
st += badge('1', 196, 62)
menu = '<div style="padding: 6px">' + mrow('Править сферу', kbd('ENTER'), True, icon='⚙') + mrow('Новый список в сфере', icon='＋') + mrow('Поделиться', icon='↗') + f'<div style="height: 1px; background: {LINE}; margin: 4px 6px"></div>' + mrow('В архив', kbd('CTRL E'), icon='▣') + mrow('Удалить сферу', danger=True, icon='✕') + '</div>'

st += node(236, 0, 668, 48, f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px"><span style="font-weight: 600; font-size: 15px">Сферы</span>{micro("4 СФЕРЫ · 8 СПИСКОВ · 1 В АРХИВЕ", DIM)}<span style="flex: 1"></span>{btn("＋ Сфера", "acc", True)}</div>')
for i, (n, c, ls, tag) in enumerate(sph):
    r, cc = divmod(i, 2)
    x = 236 + cc * 344; y = 64 + r * 240
    if i == 0: continue  # первая сфера закрыта меню, рисуем её ниже
    st += node(x, y, 324, 0, nhead('', n.upper(), (tag or f'{len(ls)} СП.') + ' &nbsp;⋯', c) + sbody(ls))
n, c, ls, tag = sph[0]
st += node(236, 64, 324, 0, nhead('', n.upper(), tag + ' &nbsp;⋯', c) + sbody(ls), hub=True)
st += node(236, 540, 668, 0, nhead('', 'В АРХИВЕ', '1', GREY) + f'<div style="padding: 10px 12px; display: flex; gap: 10px; align-items: center">{dot(GOLD, 8)}<span style="flex: 1; color: #C9CAD0">Фриланс 2025</span><span style="font: 400 10.5px {MONO}; color: {DIM}">2 СП. · С 02.11</span>{btn("Вернуть", sm=True)}{btn("Весь архив", "ghost", True)}</div>', wait=True)

cols = ''.join(f'<span style="width: 28px; height: 28px; border-radius: 8px; background: {c}; {"outline: 2px solid " + ORI + "; outline-offset: 2px" if j == 0 else ""}"></span>' for j, c in enumerate([OR, BLUE, GREEN, VIO, GOLD, RED, GREY]))
ed = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 18px">
 {field("Название", f'<span style="width: 100%; height: 38px; box-sizing: border-box; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 12px; font-size: 14px">3D и заказы</span>')}
 {field("Цвет шапки", cols)}
 {field("Списки в сфере", sc("3D-ассеты", True) + sc("Иконки для клиента", True) + sc("Заказы клиентов", True) + sc("＋ Добавить"))}
 {field("Вместе с другими", f'<span style="font-size: 12.5px; color: {MUT}">С тобой работают Оля и Аня.</span>{btn("Участники", sm=True)}')}
 <div style="margin-top: 4px; padding-top: 14px; border-top: 1px solid {LINE}; display: flex; flex-direction: column; gap: 10px">
   <div style="display: flex; gap: 8px">{btn("Сохранить", "acc")}{btn("В архив")}<span style="flex: 1"></span>{btn("Удалить", "ghost", extra="; color: " + RED)}</div>
   <span style="font-size: 12px; color: {DIM}; line-height: 1.45">В архиве сфера со всеми списками пропадает из колонки, «Сегодня», доски и календаря. Задачи остаются в Google, вернуть можно в любой момент.</span>
 </div>
</div>'''
st += node(928, 64, 320, 0, nhead('', 'СФЕРА · ПРАВКА', 'ESC', OR, None, 32) + ed)
st += badge('3', 1238, 54)
notes = [('1', 'Клик по названию сферы в колонке слева открывает правку. Справа от названия при наведении ⚙ и ⋯.'),
         ('2', 'То же меню — по ⋯ в шапке сферы и правой кнопкой мыши.'),
         ('3', 'В правке: «В архив» рядом с «Сохранить».')]
st += ab(236, 640, ''.join(f'<div style="display: flex; gap: 8px; margin-bottom: 6px"><span style="font: 500 10.5px {MONO}; color: {OR}">{a}</span><span style="color: {MUT}; font-size: 12px">{b}</span></div>' for a, b in notes), w=668)
st += pop(196, 112, 240, 0, '3D И ЗАКАЗЫ', menu, OR, '⋯') + badge('2', 426, 102)
save2('G_Spheres.dc.html', page('Сферы', 'ДОСКА', st), 'Сферы')

# ---------- АРХИВ: задачи / сферы и списки ----------
def arow(c, t, meta, date, kind):
    return (f'<div style="margin: 0 8px; height: 48px; display: flex; align-items: center; gap: 12px; padding: 0 10px; border-bottom: 1px solid {SOFT}">'
            f'<span style="width: 22px; height: 22px; border-radius: 6px; background: {FILL.get(c, "#3D3E45")}; display: grid; place-items: center; font: 500 9px {MONO}; color: #FFFFFF">{kind}</span>'
            f'<span style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span>{t}</span><span style="font-size: 12px; color: {MUT}">{meta}</span></span>'
            f'<span style="width: 90px; font: 400 11px {MONO}; color: {DIM}">{date}</span>{btn("Вернуть", sm=True)}{btn("⋯", "ghost", True)}</div>')
rows = f'<div style="padding: 14px 16px 6px; font-size: 12.5px; color: {MUT}">Сферы</div>'
rows += arow(GOLD, 'Фриланс 2025', '2 списка · 31 задач · все внутри вернутся вместе со сферой', 'С 02.11', 'СФ')
rows += arow(RED, 'Ремонт', '3 списка · 48 задач', 'С 14.10', 'СФ')
rows += f'<div style="padding: 14px 16px 6px; font-size: 12.5px; color: {MUT}">Списки</div>'
rows += arow(VIO, 'Курс Blender 2024', 'был в сфере «Учёба» · 12 задач', 'С 01.11', 'Л')
rows += arow(GREEN, 'Переезд', 'был в сфере «Дом» · 20 задач', 'С 20.09', 'С')
top = (f'<div style="padding: 12px 16px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; border-bottom: 1px solid {LINE}">{seg(["ЗАДАЧИ · 7", "СФЕРЫ И СПИСКИ · 4"], "СФЕРЫ И СПИСКИ · 4")}'
       f'<span style="width: 260px; height: 34px; box-sizing: border-box; border-radius: 8px; border: 1px solid {STRONG}; background: {BG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}">Найти в архиве</span></div>')
foot = f'<div style="margin: 16px; padding: 12px; border-radius: 8px; border: 1px dashed #55575F; display: flex; gap: 10px; align-items: center">{coon(36, "СПИТ")}<span style="font-size: 12.5px; color: #C9CAD0">Сфера в архиве не видна нигде, кроме этой вкладки. Задачи из неё не удаляются из Google. «Удалить навсегда» — в меню ⋯.</span></div>'
st = sidebar('', 'Сделанное больше 3 дней назад уходит сюда само.')
st += node(236, 0, 1012, 700, nhead('', 'АРХИВ', '7 ЗАДАЧ · 2 СФЕРЫ · 2 СПИСКА', GREY, None, 34, INK, OR) + top + rows + foot, hub=True)
save2('G_Archive.dc.html', page('Архив', 'ДОСКА', st), 'Архив · сферы и списки')
