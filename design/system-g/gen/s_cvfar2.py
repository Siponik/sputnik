import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
GF = {'r': (RED, '#8A3A2E'), 'o': (OR, '#8A5320'), 'y': (GOLD, '#7A6620'), 'g': (GREEN, '#2E6B3E'), 'v': (VIO, '#5E3F92'), None: (GREY, '#3D3E45')}
def rgba(h, a):
    h = h.lstrip('#'); return f'rgba({int(h[0:2],16)},{int(h[2:4],16)},{int(h[4:6],16)},{a})'
CL = 'display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden'
def A(w, h, t, c):  # шапка-нода: верх — цветная шапка с названием, низ — тело
    col, fill = GF[c]; hh = min(22, h)
    return (f'<div style="width: {w}px; height: {h}px; box-sizing: border-box; border-radius: 6px; background: {NODE}; border: 1px solid {LINE}; overflow: hidden">'
            f'<div style="height: {hh}px; background: {fill}; display: flex; align-items: center; padding: 0 7px; font: 500 9px {MONO}; letter-spacing: .1em; color: #FFFFFF; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{t.upper()}</div></div>')
def B(w, h, t, c):  # чертёж: контур цветом, название цветом
    col, fill = GF[c]
    return (f'<div style="width: {w}px; height: {h}px; box-sizing: border-box; border-radius: 4px; background: {rgba(col, .06)}; border: 1.5px solid {col}; display: flex; align-items: center; justify-content: center; text-align: center; padding: 4px 6px">'
            f'<span style="font: 500 9.5px {MONO}; letter-spacing: .08em; color: {col}; line-height: 1.3; {CL}">{t.upper()}</span></div>')
def C(w, h, t, c):  # приглушённая заливка цветом шапки
    col, fill = GF[c]
    return (f'<div style="width: {w}px; height: {h}px; box-sizing: border-box; border-radius: 6px; background: {fill}; border: 1px solid {rgba(col, .5)}; display: flex; align-items: center; justify-content: center; text-align: center; padding: 4px 8px">'
            f'<span style="font: 600 11px {SANS}; color: #FFFFFF; line-height: 1.3; {CL}">{t}</span></div>')
scene = [(10, 120, 60, 40, 'Деревня Ольховый ручей', 'v'), (90, 80, 56, 30, 'Первая жертва', 'y'), (166, 100, 84, 52, '1. Корчма', 'v'),
         (270, 60, 84, 40, 'Разговор с корчмарём', 'v'), (270, 130, 96, 60, '1.2. Сотник Ян Ивер', 'v'), (60, 210, 96, 110, '2.1. Разграбленная телега', 'g'),
         (180, 230, 84, 64, '2.2. Путь в глубь леса', 'v'), (290, 230, 60, 34, 'Бой', 'r'), (290, 280, 96, 84, '2.3. Обыск гоблинов', 'y')]
edges = [(70, 140, 166, 126), (146, 95, 166, 115), (250, 126, 270, 80), (250, 126, 270, 160), (156, 265, 180, 262), (264, 262, 290, 247), (350, 247, 338, 280)]
st = ''
for i, (fn, name, note) in enumerate([(A, 'А · ШАПКА', 'Нода, сжатая до шапки: цветная шапка с названием капсом, под ней тело. Ближе всего к виду нод вблизи.'),
                                       (B, 'Б · ЧЕРТЁЖ', 'Только контур цветом сферы и название тем же цветом. Лёгкий вид в духе строгого чертежа.'),
                                       (C, 'В · ЗАЛИВКА', 'Плашка залита тёмным цветом шапки, название белым. Как сейчас, только спокойнее и без растущего капса.')]):
    x0 = i * 416
    st += colhead(x0, 0, 400, name)
    paths = ''.join(f'<path d="M{x1} {y1} C {x1+20} {y1}, {x2-20} {y2}, {x2} {y2}" stroke="#6E7079" stroke-width="1" fill="none"></path>' for x1, y1, x2, y2 in edges)
    inner = f'<svg width="400" height="390" style="position: absolute; left: 0; top: 0" fill="none">{paths}</svg>' + ''.join(f'<div style="position: absolute; left: {x}px; top: {y}px">{fn(w, h, t, c)}</div>' for x, y, w, h, t, c in scene)
    st += ab(x0, 24, f'<div style="position: relative; width: 400px; height: 390px; border-radius: 10px; border: 1px solid {LINE}; {GRID}; overflow: hidden">{inner}</div>')
    st += ab(x0, 426, f'<div style="font-size: 12.5px; color: #C9CAD0; line-height: 1.5">{note}</div>', w=400)
st += ab(0, 500, f'<div style="font-size: 12.5px; color: {MUT}; line-height: 1.5">Во всех вариантах: размер и место карточки не меняются, название всегда одного размера на экране и не рвёт слова, картинка — превью.</div>', w=1248)
save2('G_NotesCanvasFar2.dc.html', page('Холст издалека · варианты', 'ЗНАНИЯ', st, right='22:40', stage_h=560), 'Знания · холст издалека: 3 варианта')
