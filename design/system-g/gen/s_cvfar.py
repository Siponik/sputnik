import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_

# Холст издалека (масштаб < 60 %): карточки остаются своего размера и места, но упрощаются
PRESET = {'red': '#E5484D', 'or': '#F0A04B', 'yel': '#E8C547', 'grn': '#5BB98B', 'cyan': '#4FB3D9', 'vio': '#A78BFA', None: '#8A8C96'}
def rgba(h, a):
    h = h.lstrip('#'); return f'rgba({int(h[0:2],16)},{int(h[2:4],16)},{int(h[4:6],16)},{a})'
GF = {'red': (RED, '#8A3A2E'), 'or': (OR, '#8A5320'), 'yel': (GOLD, '#7A6620'), 'grn': (GREEN, '#2E6B3E'), 'cyan': (BLUE, '#2F4F86'), 'vio': (VIO, '#5E3F92'), None: (GREY, '#3D3E45')}
def plate(x, y, w, h, t, c=None, kind='note', img=False):
    col, fill = GF[c]
    band = f'<span style="position: absolute; left: 0; right: 0; top: 0; height: 6px; background: {fill}; border-radius: 5px 5px 0 0"></span>'
    inner = band
    if img:
        inner += (f'<div style="position: absolute; left: 5px; right: 5px; top: 11px; bottom: 5px; background-color: #2B2520; background-image: linear-gradient(rgba(240,160,75,.08) 1px, transparent 1px), linear-gradient(90deg, rgba(240,160,75,.08) 1px, transparent 1px); background-size: 8px 8px; border: 1px solid #3F352B; border-radius: 3px; display: grid; place-items: center; color: {MUT}">{svg_("image", 13)}'
                  f'<span style="position: absolute; left: 3px; top: 3px; width: 5px; height: 5px; border-left: 1px solid {OR}; border-top: 1px solid {OR}"></span><span style="position: absolute; right: 3px; bottom: 3px; width: 5px; height: 5px; border-right: 1px solid {OR}; border-bottom: 1px solid {OR}"></span></div>')
    elif w >= 44 and h >= 26:
        inner += (f'<div style="position: absolute; left: 0; right: 0; top: 6px; bottom: 0; padding: 3px 8px; display: flex; align-items: center; justify-content: center; text-align: center">'
                  f'<span style="font: 600 11px {SANS}; color: {INK}; line-height: 1.3; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden">{t}</span></div>')
    return ab(x, y, f'<div style="position: relative; width: {w}px; height: {h}px; box-sizing: border-box; border-radius: 6px; background: {NODE}; border: 1px solid {LINE}">{inner}</div>')
def e(x1, y1, x2, y2, c='#6E7079'):
    return f'<path d="M{x1} {y1} C {x1+30} {y1}, {x2-30} {y2}, {x2} {y2}" stroke="{c}" stroke-width="1" fill="none"></path><path d="M{x2-5} {y2-3} L{x2} {y2} L{x2-5} {y2+3}" stroke="{c}" stroke-width="1" fill="none"></path>'
def lab(x, y, t): return ab(x, y, f'<span style="font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}; background: {GROUND}; padding: 0 3px">{t.upper()}</span>')

st = colhead(0, 0, 860, 'ХОЛСТ ИЗДАЛЕКА · 30 % · СИСТЕМА G')
ox, oy = 0, 30
st += ab(ox, oy, f'<div style="width: 860px; height: 540px; border-radius: 10px; border: 1px solid {LINE}; {GRID}"></div>')
P = []
P += [plate(20, 250, 70, 46, 'Деревня Ольховый ручей', 'vio'), plate(110, 140, 50, 34, '', img=True), plate(110, 190, 60, 34, 'Первая жертва', 'yel')]
P += [plate(200, 200, 96, 60, '1. Корчма', 'vio'), plate(320, 160, 96, 46, 'Разговор с корчмарём', 'vio'), plate(320, 240, 110, 70, '1.2. Разговор с сотником Яном Ивером', 'vio')]
P += [plate(470, 110, 90, 46, '2. Путь через лес', 'vio'), plate(470, 180, 70, 50, '2.1. Разграбленная телега', 'vio'), plate(470, 290, 110, 130, '2.1. Расследование у телеги', 'grn'), plate(560, 170, 54, 40, '', img=True)]
P += [plate(610, 300, 96, 76, '2.2. Путь в глубь леса', 'vio'), plate(730, 310, 70, 40, 'Бой', 'red'), plate(730, 380, 110, 100, '2.3. Обыск убитых гоблинов', 'yel'), plate(740, 490, 80, 30, 'Проброс на историю (10)', 'yel')]
P += [plate(560, 450, 30, 16, 'мелкая', 'cyan')]
paths = e(90, 273, 200, 230) + e(170, 207, 200, 220, '#E8C547') + e(296, 230, 320, 183) + e(368, 206, 375, 240) + e(430, 275, 470, 133) + e(505, 156, 505, 180) + e(540, 205, 470, 300) + e(580, 355, 610, 338, '#5BB98B') + e(706, 338, 730, 330, '#E5484D') + e(800, 330, 760, 380, '#E5484D')
st += svg(paths, 1248, 760).replace('style="position: absolute; left: 0; top: 0"', f'style="position: absolute; left: {ox}px; top: {oy}px"')
st += ''.join(P).replace('left: ', 'left: calc(0px + ').replace('px; top: ', 'px); top: ') if False else ''
for p in P: st += p.replace('position: absolute; left: ', f'position: absolute; margin-left: {ox}px; margin-top: {oy}px; left: ', 1)
st += lab(ox + 425, oy + 196, 'Тракт')

# правила справа
R = [('≥ 60 %', 'Карточка целиком: шапка, текст, гнёзда.'),
     ('35–60 %', 'Шапка и первые строки; текст мельче не делаем, лишнее обрезаем.'),
     ('< 35 %', 'Плашка (как слева). Размер и место карточки на холсте не меняются.'),
     ('Плашка', 'Это свёрнутая нода: тело NODE, рамка LINE, скругление 6. Шапка сжимается в полоску 6 px тёмным цветом шапки (FILL). Без цвета — серая.'),
     ('Название', 'Onest 600, 11 px на экране при любом масштабе (не растёт и не сжимается вместе с холстом). Обычный регистр, по центру, не больше 2 строк, дальше «…». Название — первый заголовок или первая строка.'),
     ('Мелкая', 'Меньше 44×22 px на экране — только цветная плашка, без текста.'),
     ('Картинка', 'Превью в рамке «чертежа»: сетка и уголки OR, как «Превью рендера» в «Сегодня». Не имя файла.'),
     ('Провода', '1 px, цветом ноды-источника, со стрелкой. Подписи — JetBrains Mono 10 px капсом на фоне холста; меньше 20 % прячем.'),
     ('Группа', 'Пунктир 1 px цветом группы, название капсом JetBrains Mono 10 px сверху слева — как группы на «Сферах».'),
     ('Выбор', 'Уголки-скобки OR по углам, как у главной ноды «Сегодня».')]
rh = ''.join(f'<div style="display: flex; gap: 10px; padding: 7px 0; border-bottom: 1px solid {SOFT}"><span style="width: 74px; flex: none; font: 500 10.5px {MONO}; letter-spacing: .06em; color: {OR}">{a}</span><span style="font-size: 12px; color: #C9CAD0; line-height: 1.45">{b}</span></div>' for a, b in R)
st += node(888, 30, 360, 0, nhead('', 'ПРАВИЛА', 'ИЗДАЛЕКА', GREY) + f'<div style="padding: 4px 14px 10px">{rh}</div>')

# было / надо
st += colhead(0, 590, 860, 'СЕЙЧАС → НАДО')
st += ab(0, 616, f'<div style="display: flex; align-items: center; gap: 24px">'
         f'<div style="width: 150px; height: 90px; box-sizing: border-box; background: #A78BFA; display: grid; place-items: center; text-align: center; padding: 6px; font: 600 15px {MONO}; letter-spacing: .08em; color: #FFFFFF; line-height: 1.2">2.1. РАЗГРАБЛЕННА Я ТЕЛЕГА</div>'
         f'<span style="font: 500 18px {MONO}; color: {MUT}">→</span>'
         f'<div style="position: relative; width: 150px; height: 90px">{plate(0, 0, 150, 90, "2.1. Разграбленная телега", "vio").replace("position: absolute; left: 0px; top: 0px;", "")}</div>'
         f'<div style="width: 420px; font-size: 12px; color: {MUT}; line-height: 1.5">Сейчас: яркая заливка, капс моноширинным, текст растёт под размер карточки и рвёт слова. Вместо картинок — «Pasted image 2026…».<br>Надо: нода в свёрнутом виде — цветная полоска-шапка, тело ноды, ровное небольшое название, картинка — превью в рамке чертежа.</div></div>')
save2('G_NotesCanvasFar.dc.html', page('Холст издалека', 'ЗНАНИЯ', st, right='22:40', stage_h=720), 'Знания · холст издалека')
