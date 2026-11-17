import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_

# Холст в «Знаниях»: все состояния элементов
def card(x, y, w, title, body, c=VIO, kind='DND', sel=False, hover=False, edit=False, h=0):
    bord = f'; outline: 1.5px solid {OR}; outline-offset: 2px' if sel else ''
    if edit: bord = f'; border-color: {OR}'
    ex = ''
    if hover or sel:
        ex += sock('l', 38, c) + sock('r', 38, c) + f'<span style="position: absolute; left: 50%; top: -6px; margin-left: -5px; width: 10px; height: 10px; border-radius: 3px; box-sizing: border-box; background: {c}; border: 1.5px solid {GROUND}"></span>' + f'<span style="position: absolute; left: 50%; bottom: -6px; margin-left: -5px; width: 10px; height: 10px; border-radius: 3px; box-sizing: border-box; background: {c}; border: 1.5px solid {GROUND}"></span>'
    if sel:
        ex += ''.join(f'<span style="position: absolute; {v}: -8px; {hh}: -8px; width: 8px; height: 8px; background: {GROUND}; border: 1.5px solid {OR}"></span>' for v in ('top', 'bottom') for hh in ('left', 'right'))
    b = f'<div style="padding: 10px 12px; font-size: 12.5px; color: #C9CAD0; line-height: 1.45">{body}</div>'
    return node(x, y, w, h, nhead('', title, kind, c) + b, extra=ex, style=bord)
def tag(t): return f'<div style="font: 500 10px {MONO}; letter-spacing: .16em; color: {MUT}; margin-bottom: 10px">{t}</div>'
def cap(x, y, n, t, w=380): return ab(x, y, f'<div style="display: flex; gap: 8px; align-items: baseline"><span style="font: 500 10.5px {MONO}; color: {OR}">{n}</span><span style="font: 500 10px {MONO}; letter-spacing: .16em; color: {MUT}">{t}</span></div>', w=w)
def bar(items):
    return f'<div style="display: inline-flex; align-items: center; gap: 2px; padding: 4px; border-radius: 9px; background: {NODE}; border: 1px solid {LINE}{SH}">{items}</div>'
def bi(t, on=False, danger=False):
    c = RED if danger else (DARK if on else INK)
    bg = f'background: {OR};' if on else ''
    return f'<span style="height: 28px; padding: 0 10px; border-radius: 6px; {bg} display: inline-flex; align-items: center; gap: 6px; white-space: nowrap; font-size: 12.5px; color: {c}">{t}</span>'
SEP = f'<span style="width: 1px; height: 18px; background: {LINE}; margin: 0 4px"></span>'
def sw(c, on=False): return f'<span style="width: 16px; height: 16px; border-radius: 4px; background: {c}; margin: 0 2px; {"outline: 1.5px solid " + INK + "; outline-offset: 2px" if on else ""}"></span>'

st = ''; paths = ''
# 1. карточка: обычная, наведение, выбрана, правка
st += cap(0, 0, '1', 'КАРТОЧКА · ОБЫЧНАЯ / НАВЕДЕНИЕ / ВЫБРАНА / ПРАВКА', 1248)
st += card(0, 24, 220, 'НПС: МИРА ТЁРН', 'Информатор фракции.')
st += card(250, 24, 220, 'НПС: МИРА ТЁРН', 'Информатор фракции.', hover=True)
st += card(500, 24, 220, 'НПС: МИРА ТЁРН', 'Информатор фракции.', sel=True)
st += node(750, 24, 220, 0, f'<div style="padding: 10px 12px; font-size: 12.5px; line-height: 1.45">Игроки ещё не знают, что Мира<span style="display: inline-block; width: 1.5px; height: 14px; background: {OR}; vertical-align: -2px; margin-left: 1px"></span></div>', style=f'; border-color: {OR}; background: {WASH}')
st += ab(750, 92, f'<span style="font: 400 10px {MONO}; letter-spacing: .1em; color: {MUT}">ESC ИЛИ КЛИК МИМО — ГОТОВО</span>')
st += ab(1000, 30, f'<div style="font-size: 12px; color: {MUT}; line-height: 1.5">Наведение — гнёзда со всех четырёх сторон, как в JSON Canvas.<br>Выбор — рамка {OR} 1.5 с отступом 2 и уголки размера.<br>Двойной клик — правка прямо в карточке.</div>', w=248)

# 2. панель над выделенным — как в приложении: значки с подсказками, цвета отдельной полоской
def ib(ic, on=False, danger=False):
    c = RED if danger else (OR if on else MUT)
    bg = f'background: {WASH}; border: 1px solid {ORL};' if on else 'border: 1px solid transparent;'
    return f'<span style="width: 28px; height: 28px; box-sizing: border-box; border-radius: 6px; {bg} display: inline-grid; place-items: center; color: {c}">{svg_(ic, 14)}</span>'
PRESET = ['#E5484D', '#F0A04B', '#E8C547', '#5BB98B', '#4FB3D9', '#A78BFA']
pal = bar(f'<span style="width: 18px; height: 18px; box-sizing: border-box; border-radius: 50%; border: 1.5px solid {STRONG}; margin: 0 4px"></span>' + ''.join(f'<span style="width: 18px; height: 18px; border-radius: 50%; background: {c}; margin: 0 4px"></span>' for c in PRESET))
st += cap(0, 140, '2', 'ПАНЕЛЬ НАД ВЫДЕЛЕННЫМ · КАК В ПРИЛОЖЕНИИ')
st += ab(0, 164, pal)
st += ab(0, 206, bar(ib('trash', danger=True) + ib('accent', True) + ib('focus') + ib('edit') + ib('open') + ib('canvas') + ib('copy')))
st += ab(250, 206, f'<span style="padding: 4px 8px; border-radius: 5px; background: {DARK}; border: 1px solid {LINE}; font-size: 11.5px; color: {INK}; white-space: nowrap">Цвет</span>')
st += card(40, 262, 180, 'ТАВЕРНА', 'Хозяин — гном Борн.', sel=True)
st += ab(250, 250, f'''<div style="font-size: 12px; color: {MUT}; line-height: 1.55">Уже есть в коде, оставляем. Значки слева направо: удалить, цвет, приблизить, править, открыть, в группу, дублировать. У провода ещё «стрелка».<br>Цвет — полоска над панелью: «без цвета» и 6 цветов холстов Obsidian (тот же файл открывается там).<br>Наведение — подсказка с названием.</div>''', w=440)

# 3. меню по правому клику
st += cap(720, 140, '3', 'МЕНЮ ПО ПРАВОМУ КЛИКУ')
menu = '<div style="padding: 6px">' + mrow('Править', kbd('ENTER'), True, icon='✎') + mrow('Открыть заметку', icon='↗') + mrow('Цвет', f'<span style="color: {MUT}">▸</span>', icon='●') + f'<div style="height: 1px; background: {LINE}; margin: 4px 6px"></div>' + mrow('Копировать', kbd('CTRL C'), icon='⧉') + mrow('Вырезать', kbd('CTRL X'), icon='✂') + mrow('Дублировать', kbd('CTRL D'), icon='⧉') + mrow('В группу', kbd('CTRL G'), icon='▢') + f'<div style="height: 1px; background: {LINE}; margin: 4px 6px"></div>' + mrow('Удалить', kbd('DEL'), danger=True, icon='✕') + '</div>'
st += pop(720, 166, 260, 0, 'КАРТОЧКА', menu, GREY)
menu2 = '<div style="padding: 6px">' + mrow('Карточка здесь', icon='＋', on=True) + mrow('Заметка…', icon='¶') + mrow('Картинка…', icon='▣') + f'<div style="height: 1px; background: {LINE}; margin: 4px 6px"></div>' + mrow('Вставить', kbd('CTRL V'), icon='⎘') + mrow('Выделить всё', kbd('CTRL A'), icon='⬚') + '</div>'
st += pop(1000, 166, 248, 0, 'ПУСТОЕ МЕСТО', menu2, GREY)

# 4. рамка выделения
st += cap(0, 380, '4', 'РАМКА ВЫДЕЛЕНИЯ · ТЯНУТЬ ПО ПУСТОМУ')
st += ab(0, 406, f'<div style="width: 400px; height: 170px; box-sizing: border-box; border: 1px dashed {OR}; background: rgba(240,160,75,.06); border-radius: 2px"></div>')
st += card(20, 426, 170, 'СЕССИЯ 11', 'Порт и склад.', OR, sel=True)
st += card(210, 480, 170, 'СЕССИЯ 12', 'Пожар в доках.', OR, sel=True)
st += ab(0, 582, f'<span style="font: 400 10px {MONO}; letter-spacing: .1em; color: {MUT}">SHIFT / CTRL + КЛИК — ДОБАВИТЬ К ВЫДЕЛЕНИЮ · ALT + ТЯНУТЬ — ДУБЛИКАТ</span>')

# 5. провод: тянем и подпись
st += cap(440, 380, '5', 'ПРОВОД · ТЯНЕМ НА ПУСТОЕ / ПОДПИСЬ')
st += card(440, 406, 180, 'ФРАКЦИЯ', 'Цель — порт.', hover=True)
paths += f'<path d="M626 450 C 680 450, 660 520, 720 520" stroke="{OR}" stroke-width="1.5" stroke-dasharray="4 4" fill="none"></path>'
st += ab(720, 496, f'<div style="width: 150px; height: 50px; box-sizing: border-box; border-radius: 8px; border: 1px dashed {OR}; display: grid; place-items: center; color: {ORI}; font-size: 12px">＋ новая карточка</div>')
st += ab(440, 526, f'<div style="font-size: 12px; color: {MUT}; line-height: 1.5; width: 260px">Отпустил на пустом — карточка с проводом, сразу в правке. На гнезде — обычная связь.</div>')
paths += f'<path d="M1010 450 C 1070 450, 1110 520, 1170 520" stroke="{VIO}" stroke-width="1.5" fill="none"></path>'
st += ab(1035, 470, f'<span style="padding: 2px 8px; border-radius: 4px; background: {WASH}; border: 1px solid {OR}; font: 500 10px {MONO}; letter-spacing: .14em; color: {INK}">ВРАГИ<span style="display: inline-block; width: 1.5px; height: 10px; background: {OR}; margin-left: 2px; vertical-align: -1px"></span></span>')
st += ab(1010, 526, f'<div style="font-size: 12px; color: {MUT}; line-height: 1.5; width: 238px">Двойной клик по проводу — подпись. Выбранный провод толще (2.5) и с ⨯ посередине.</div>')
st += ab(1006, 445, dot(VIO, 10)) + ab(1166, 515, dot(VIO, 10))

# 6. группа
st += cap(0, 622, '6', 'ГРУППА · ВЫБРАНА')
st += ab(0, 648, f'<div style="position: relative; width: 400px; height: 120px; box-sizing: border-box; border: 1px dashed {VIO}; border-radius: 10px; background: rgba(180,140,240,.05); outline: 1.5px solid {OR}; outline-offset: 2px"><span style="position: absolute; left: 12px; top: 10px; font: 500 10px {MONO}; letter-spacing: .16em; color: {VIO}">ГОРОД ВЕЛЬСК</span>' + ''.join(f'<span style="position: absolute; {v}: -8px; {hh}: -8px; width: 8px; height: 8px; background: {GROUND}; border: 1.5px solid {OR}"></span>' for v in ('top', 'bottom') for hh in ('left', 'right')) + '</div>')
st += ab(16, 682, f'<span style="font-size: 12px; color: {MUT}">Тянешь группу — едет всё, что внутри.</span>')

# 7. издалека
st += cap(440, 622, '7', 'МАСШТАБ МЕНЬШЕ 35 % — ПЛАШКИ')
for i, (t, c) in enumerate([('Таверна', VIO), ('Сессия 12', OR), ('Карта', GREY), ('Фракция', VIO)]):
    st += ab(440 + (i % 2) * 120, 650 + (i // 2) * 44, f'<span style="display: inline-flex; align-items: center; height: 30px; padding: 0 10px; border-radius: 6px; background: {FILL.get(c)}; font: 500 11px {MONO}; letter-spacing: .1em; color: #FFFFFF">{t.upper()}</span>')

# 8. нижняя панель и уведомление
st += cap(720, 622, '8', 'НИЖНЯЯ ПАНЕЛЬ · ИЗМЕНЁН СНАРУЖИ')
st += ab(720, 648, bar(bi('＋ Карточка') + bi('¶ Заметка') + bi('▣ Картинка') + bi('▢ Группа') + SEP + bi('−') + f'<span style="font: 500 11px {MONO}; color: {MUT}; padding: 0 4px">100%</span>' + bi('＋') + SEP + bi('⤢') + bi('?')))
st += ab(720, 700, f'<div style="width: 528px; height: 40px; box-sizing: border-box; border-radius: 8px; border: 1px solid {GOLD}; background: #2A2718; display: flex; align-items: center; gap: 10px; padding: 0 6px 0 12px; font-size: 12.5px">{dot(GOLD, 8)}<span style="flex: 1">Холст изменили в Obsidian. Твоя версия сохранена копией рядом.</span>{btn("Открыть копию", "ghost", True)}</div>')

st = svg(paths, 1248, 820) + st
st = st.replace('rgba(255,255,255,.72)', 'rgba(255,255,255,.9)')
save2('G_NotesCanvasKit.dc.html', page('Холст · элементы', 'ЗНАНИЯ', st, right='22:40', stage_h=770), 'Знания · холст: все элементы и состояния')
