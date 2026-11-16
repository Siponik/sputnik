import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
from s_board import sidebar, titlebar, card

# Мало колонок: колонки не растягиваются, ширина общая и меняется в пределах 200–360
W = 288; gap = 28; x0 = 236
wctl = (f'<span title="Ширина колонок" style="height: 28px; padding: 0 10px; border-radius: 7px; border: 1px solid {LINE}; display: inline-flex; align-items: center; gap: 8px; font-size: 12.5px; color: #C9CAD0">'
        f'<span style="color: {MUT}; font: 500 11px {MONO}">⟷</span>'
        f'<span style="position: relative; width: 84px; height: 3px; border-radius: 2px; background: {LINE}"><span style="position: absolute; left: 0; top: 0; width: 46px; height: 3px; border-radius: 2px; background: {OR}"></span><span style="position: absolute; left: 40px; top: -5px; width: 12px; height: 12px; border-radius: 50%; background: {INK}"></span></span>'
        f'<span style="font: 500 10.5px {MONO}; color: {MUT}">{W}</span></span>')
st = sidebar('Покупки') + titlebar('Покупки', GREEN, 'КАНБАН', wctl)
cols = [('КУПИТЬ', '3', GREY, [card('Молоко, хлеб', 'СЕГОДНЯ', ''), card('Лампочки E27', 'БЕЗ СРОКА', ''), card('Подарок маме', 'ДО ПТ 20', '!!')]),
        ('КУПЛЕНО', '2', GREEN, [card('Батарейки АА', 'ВЧЕРА', done=True), card('Корм коту', 'ПН 09', done=True)])]
paths = ''
for i, (n, cnt, c, cards) in enumerate(cols):
    x = x0 + i * (W + gap)
    body = f'<div style="padding: 10px; display: flex; flex-direction: column; gap: 8px">{"".join(cards)}'
    if i == 0:
        body += f'<div style="height: 34px; border-radius: 8px; border: 1px dashed {STRONG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}">＋ Добавить задачу<span style="margin-left: auto; font: 400 9.5px {MONO}; color: {DIM}">N</span></div>'
    body += '</div>'
    ex = sock('r', 10, c) if i == 0 else sock('l', 10, cols[0][2])
    if i == 1:  # ручка изменения ширины на правом крае
        ex += f'<span style="position: absolute; right: -3px; top: 40%; width: 4px; height: 44px; border-radius: 2px; background: {OR}"></span>'
    st += node(x, 64, W, 0, nhead(f'0{i + 1}', n, cnt, c, MUT) + body, extra=ex)
paths += wire(x0 + W + 1, 79, x0 + W + gap - 1, 79, GREY, 1.5, k=10)
xr = x0 + 2 * W + gap
# подсказка у ручки
st += ab(xr + 12, 160, f'<div style="padding: 6px 10px; border-radius: 6px; background: {NODE}; border: 1px solid {OR}; font: 500 10.5px {MONO}; color: {ORI}; white-space: nowrap">⟷ {W} PX · ВСЕ КОЛОНКИ · 200–360</div>')
# место справа остаётся пустым полем, плюс кнопка новой колонки
st += ab(xr + gap, 64, f'<div style="width: 180px; height: 40px; border-radius: 8px; border: 1px dashed {STRONG}; display: flex; align-items: center; justify-content: center; color: {MUT}; font-size: 12.5px">＋ Колонка</div>')
st = svg(paths) + st
st += dimline(236, 684, 2 * W + gap, f'КОЛОНКИ НЕ РАСТЯГИВАЮТСЯ НА ВСЮ ШИРИНУ · {W} PX · ТЯНИ ЗА КРАЙ ИЛИ ПОЛЗУНОК')
save2('G_KanbanFew.dc.html', page('Доска · мало колонок', 'ДОСКА', st), 'Доска · мало колонок')
