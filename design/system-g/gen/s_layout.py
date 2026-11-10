# Раскладка: ноды тянутся на всё окно, отступы 8 px. Запуск после s_win.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

def win(x, y, w, h, gut, gap, side, right, label, bad=False):
    o = f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; height: {h}px; border: 1px solid {LINE}; border-radius: 10px; background: {GROUND}; overflow: hidden">'
    o += f'<div style="height: 22px; background: {BG}; border-bottom: 1px solid {LINE}"></div>'
    ih = h - 22 - 2 * gut
    cx = gut; o2 = ''
    cols = [side, None, right] if right else [side, None]
    fixed = sum(c for c in cols if c) + gap * (len(cols) - 1)
    mid = w - 2 * gut - fixed
    if bad:
        mid = min(mid, 300)
    for c in cols:
        cw = c or mid
        col = OR if c is None else GREY
        o2 += f'<div style="position: absolute; left: {cx}px; top: {22 + gut}px; width: {cw}px; height: {ih}px; border-radius: 6px; background: {NODE}; border: 1px solid {LINE}; box-sizing: border-box"><div style="height: 10px; border-radius: 6px 6px 0 0; background: {col}; opacity: .7"></div></div>'
        cx += cw + gap
    o += o2 + '</div>'
    o += f'<div style="position: absolute; left: {x}px; top: {y + h + 8}px; width: {w}px">{micro(label, RED if bad else GREEN)}</div>'
    return o

st = ab(0, 0, f'<div style="display: flex; gap: 12px; align-items: center">{lbl("РАСКЛАДКА ОКНА", INK)}{micro("НОДЫ ЗАНИМАЮТ ВСЁ ОКНО · ОТСТУПЫ 8 PX · СЕРЕДИНА ТЯНЕТСЯ", MUT)}</div>', w=1248)
st += win(0, 40, 600, 300, 16, 16, 120, 0, 'СЕЙЧАС В ПРИЛОЖЕНИИ: ПОЛЯ 16-24, СЕРЕДИНА ФИКСИРОВАНА, СБОКУ ПУСТО', bad=True)
st += win(648, 40, 600, 300, 8, 8, 120, 110, 'НАДО: ПОЛЯ 8, ЗАЗОРЫ 8, СЕРЕДИНА ЗАНИМАЕТ ВСЁ ОСТАЛЬНОЕ')
rules = [('Поля окна', '8 px от шапки и от краёв окна до нод. Точечная сетка видна только в этих 8 px и в зазорах.'),
         ('Зазор между нодами', '8 px. Провода между соседними нодами — короткие, внутри зазора, или их нет.'),
         ('Ширина', 'Боковые ноды фиксированы (левая колонка 264, панели справа 300–360). Главная нода тянется на всю оставшуюся ширину. Никаких max-width у главной ноды, кроме текста заметки (колонка 640–720 по центру ноды).'),
         ('Высота', 'Ноды тянутся до низа окна, прокручивается содержимое ноды, а не страница.'),
         ('Внутри ноды', 'Отступы как в макетах: шапка ноды 30–34, поля 12–16. Сжимать содержимое нельзя: при узком окне сначала прячется правая панель, потом левая колонка уходит в полосу 64 px.'),
         ('Макеты', 'Холст рисует экран 1280×820 с полями 16 — это картинка, а не правило. Правило — эта страница.')]
rw = ''.join(f'<div style="display: flex; gap: 14px; padding: 9px 0; border-bottom: 1px solid {SOFT}"><span style="width: 170px; flex: none; font-weight: 600">{a}</span><span style="color: #C9CAD0; line-height: 19px">{b}</span></div>' for a, b in rules)
st += node(0, 380, 1248, 0, nhead('', 'ПРАВИЛА', '', OR, None, 30) + f'<div style="padding: 4px 16px 8px">{rw}</div>')
save2('G_Layout.dc.html', page('Раскладка окна', 'СЕГОДНЯ', st), 'Раскладка: ноды на всё окно, отступы 8 px')
print('ok layout')
