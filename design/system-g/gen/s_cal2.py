import kit
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
def rgba(h, a):
    h = h.lstrip('#'); return f'rgba({int(h[0:2],16)},{int(h[2:4],16)},{int(h[4:6],16)},{a})'
PINK = '#F08CC0'
def cap(x, y, n, t, w=600): return ab(x, y, f'<div style="display: flex; gap: 8px; align-items: baseline"><span style="font: 500 10.5px {MONO}; color: {OR}">{n}</span><span style="font: 500 10px {MONO}; letter-spacing: .16em; color: {MUT}">{t}</span></div>', w=w)
def note(x, y, w, t): return ab(x, y, f'<div style="font-size: 12px; color: #C9CAD0; line-height: 1.5">{t}</div>', w=w)
# блок события в сетке
def blk(x, y, w, h, t, tm, c, kind='task', done=False, ghost=False):
    col = c
    bg = rgba(col, .10) if not done else '#25262B'
    bd = f'1px solid {rgba(col, .55)}' if not done else f'1px solid {LINE}'
    if ghost: bd = f'1px dashed {OR}'; bg = rgba(OR, .10)
    tc = DIM if done else INK
    mark = (f'<span style="width: 8px; height: 8px; border-radius: 50%; box-sizing: border-box; flex: none; border: 1.5px solid {col}"></span>' if kind == 'task' else f'<span style="width: 3px; align-self: stretch; border-radius: 2px; background: {col}; flex: none"></span>')
    if done: mark = f'<span style="flex: none; width: 10px; height: 10px; border-radius: 3px; background: #45464D; display: grid; place-items: center; color: {INK}; font-size: 8px">✓</span>'
    if h < 34:  # короткое: одна строка, время и название рядом
        inner = f'<div style="display: flex; align-items: center; gap: 6px; height: 100%; padding: 0 6px; white-space: nowrap; overflow: hidden">{mark}<span style="font: 400 10px {MONO}; color: {MUT}">{tm}</span><span style="font-size: 12px; color: {tc}; overflow: hidden; text-overflow: ellipsis">{t}</span></div>'
    else:
        inner = f'<div style="display: flex; gap: 6px; padding: 5px 7px; height: 100%; box-sizing: border-box">{mark}<div style="min-width: 0"><div style="font: 400 10px {MONO}; color: {MUT}">{tm}</div><div style="font-size: 12px; color: {tc}; line-height: 1.3; overflow: hidden; display: -webkit-box; -webkit-line-clamp: {max(1, (h - 22) // 16)}; -webkit-box-orient: vertical">{t}</div></div></div>'
    return ab(x, y, f'<div style="width: {w}px; height: {h}px; box-sizing: border-box; border-radius: 5px; background: {bg}; border: {bd}; overflow: hidden">{inner}</div>')
def grid(x, y, w, h, rows, r0=8, rh=30, cols=1, colw=None):
    s = ''
    for i in range(rows):
        s += f'<div style="position: absolute; left: 0; right: 0; top: {i * rh}px; height: {rh}px; border-top: 1px solid {SOFT}"><span style="position: absolute; left: 4px; top: 2px; font: 400 9.5px {MONO}; color: {DIM}">{(r0 + i) % 24:02d}</span></div>'
    for j in range(1, cols):
        s += f'<div style="position: absolute; top: 0; bottom: 0; left: {36 + j * colw}px; border-left: 1px solid {SOFT}"></div>'
    return ab(x, y, f'<div style="position: relative; width: {w}px; height: {h}px; border-radius: 6px; border: 1px solid {LINE}; background: {NODE}; overflow: hidden">{s}</div>')

# ======== ДОСКА 1: БЛОКИ + МЕСЯЦ ========
st = cap(0, 0, '1', 'ПРАВИЛА НЕДЕЛИ · КОРОТКИЕ, СДЕЛАННЫЕ, ДЛИННЫЕ, ПЕРЕСЕКАЮЩИЕСЯ', 760)
st += note(0, 24, 1000, f'''<b>Вид — неделя Б с панелью дня</b> (G_CalWeekBP): видны часы от первой до последней задачи недели, остальное — чипы «↑ раньше / ↓ позже».<br><br><b>Короче 45 мин</b> — одна строка: значок и название (время — только если не ровно по часу). Высота не меньше 22 px, даже если событие 10 минут.<br><br>
<b>Сделанное</b> — серый фон, галочка вместо кружка, текст DIM без зачёркивания. Не пропадает, чтобы день читался целиком.<br><br>
<b>Длинное фоновое</b> (привычка «Работа 08–17», отпуск): часы чуть тонированы золотом (6 %), тонкие золотые линии на начале и конце, подпись «РАБОТА 08–17» сверху. Дела лежат поверх на всю ширину.<br><br><b>Короткая привычка со временем</b> — блок в золотой пунктирной рамке с квадратным значком.<br><br><b>Время в блоке</b> не пишем, если начало ровно по часу — оно видно по сетке. <b>Наведение</b> — всплывашка: полное название, дата, время и длительность, список, заметка.<br><br>
<b>Пересечения</b> — ширину не делим: один блок «2 ДЕЛА · 11–13», внутри дела строками. Часы этого отрезка растут во всех днях (до ×2), не влезло — «+N ещё». Строки внутри — без времени.<br><br>
<b>Задача</b> — кружок; <b>событие календаря</b> — вертикальная черта слева. Название переносится на столько строк, сколько влезает, дальше «…».''')

st += cap(0, 380, '2', 'МЕСЯЦ · БЕЗ ВРЕМЕНИ, ДНИ РОЖДЕНИЯ ОТДЕЛЬНО', 760)
def mcell(x, y, d, items, bday=None, today=False, more=0, dim=False):
    head = f'<div style="display: flex; align-items: center; gap: 6px; height: 22px; padding: 0 8px; font: 500 11px {MONO}; color: {OR if today else (DIM if dim else INK)}">{d}{"<span style=\"font-size: 9px; letter-spacing: .12em\">СЕГОДНЯ</span>" if today else ""}</div>'
    b = ''
    if bday:
        b = f'<div style="margin: 0 4px 3px; height: 20px; border-radius: 4px; background: {rgba(PINK, .16)}; display: flex; align-items: center; gap: 5px; padding: 0 6px; font-size: 11.5px; color: {PINK}; white-space: nowrap; overflow: hidden">{svg_("birthday", 11)}<span style="overflow: hidden; text-overflow: ellipsis">{bday}</span></div>'
    li = ''.join(f'<div style="display: flex; align-items: center; gap: 6px; height: 18px; padding: 0 8px; font-size: 11.5px; color: {DIM if dn else "#C9CAD0"}; white-space: nowrap; overflow: hidden">{dot(c, 6)}<span style="overflow: hidden; text-overflow: ellipsis">{t}</span></div>' for t, c, dn in items)
    m = f'<div style="padding: 0 8px; font: 400 10px {MONO}; color: {MUT}">+{more} ещё</div>' if more else ''
    bd = f'1.5px solid {OR}' if today else f'1px solid {SOFT}'
    return ab(x, y, f'<div style="width: 140px; height: 112px; box-sizing: border-box; background: {NODE}; border: {bd}; overflow: hidden">{head}{b}{li}{m}</div>')
cells = [('09', [('Ретопология меча', OR, True), ('Созвон: бриф', BLUE, False)], None, False, 0),
         ('10', [('Просроченный отчёт за октябрь', VIO, False)], 'Алексей', False, 0),
         ('11', [('UV щита', OR, False), ('Курс Substance', VIO, False), ('Обед с Олей', GREY, False)], None, False, 2),
         ('12', [('Текстуры для щита, 2K', OR, False)], None, True, 0),
         ('13', [], 'Аня · 30 лет', False, 0)]
for i, (d, it, bd, td, mo) in enumerate(cells):
    st += mcell(i * 140, 404, d, it, bd, td, mo)
st += note(0, 528, 700, f'Время в месяце не показываем — только точка цвета списка и название. Порядок: день рождения, весь день, по времени, сделанное (DIM) в конце. Не влезло — «+N ещё», клик открывает день справа. <b>День рождения</b> — отдельная розовая плашка {PINK} с тортиком над всем остальным, имя и возраст, если известен. В неделе ДР — такая же плашка в строке «ДЕНЬ».')
save2('G_CalRules.dc.html', page('Календарь · блоки и месяц', 'КАЛЕНДАРЬ', st, right='ЧТ 19.11 · 09:30', stage_h=620), 'Календарь · блоки и месяц')

# ======== ДОСКА 2: ДОБАВЛЕНИЕ КЛИКОМ ========
st = cap(0, 0, '', 'ДОБАВЛЕНИЕ КЛИКОМ · КАК РАБОТАЕТ', 1248)
steps = [('1', 'Наведение на пустое место', 'Под курсором — пунктирная рамка на 1 час, привязка к 15 минутам, сверху время «17:00». Курсор — плюс.'),
         ('2', 'Клик или протянуть', 'Клик — черновик на 1 час. Протянул вниз — черновик нужной длины (шаг 15 мин). Черновик — пунктир OR с заливкой 10 %.'),
         ('3', 'Затемнение', 'Всё, кроме черновика и окна, затемняется до 35 % за 120 мс. Сетка не двигается. Клик по затемнению = «Отмена».'),
         ('4', 'Окно рядом', 'Окно «Добавить» открывается сбоку от черновика (справа, если места нет — слева), соединено с ним проводом OR. Поле «Что» уже в фокусе.'),
         ('5', 'Ввод', 'Пишешь название. Дата и время уже стоят из черновика; их можно поправить, черновик двигается вслед. Можно тянуть края черновика.'),
         ('6', 'Готово', 'Enter — создать: затемнение уходит, черновик становится блоком. Esc или «Отмена» — всё как было. Тип «Задача/Событие» помнится с прошлого раза.')]
for i, (n, t, d) in enumerate(steps):
    x = (i % 3) * 416; y = 24 + (i // 3) * 120
    st += node(x, y, 400, 104, nhead(n, t.upper(), '', OR if i in (2, 3) else GREY) + f'<div style="padding: 10px 12px; font-size: 12.5px; color: #C9CAD0; line-height: 1.5">{d}</div>')
# мини-сцена: затемнение
gr = grid(0, 0, 520, 300, 10, 9, 30)
dimmed = f'<div style="position: absolute; inset: 0; background: rgba(15,16,19,.65); border-radius: 6px"></div>'
scene = (f'<div style="position: relative; width: 820px; height: 300px">{gr}'
         + blk(48, 60, 200, 58, 'Созвон «Таверна»', '11:00', BLUE, 'event') + blk(260, 30, 200, 88, 'Текстуры для щита', '10:00', OR)
         + dimmed + blk(260, 240, 200, 58, 'Ретопология шлема', '+ 17:00 – 18:00', OR, ghost=True)
         + f'<svg width="820" height="300" style="position: absolute; left: 0; top: 0" fill="none"><path d="M460 268 C 500 268, 520 150, 560 150" stroke="{OR}" stroke-width="1.5"></path></svg>'
         + ab(560, 60, node(0, 0, 260, 0, nhead('', 'ДОБАВИТЬ · ЧТ 19', 'ENTER', OR, under=OR) + f'<div style="padding: 12px; display: flex; flex-direction: column; gap: 10px"><span style="height: 32px; box-sizing: border-box; border-radius: 7px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 10px">Ретопология шлема</span><div style="display: flex; gap: 6px">{kit.sc("Задача", True)}{kit.sc("Событие")}</div><div style="display: flex; justify-content: flex-end; gap: 6px">{btn("Отмена", "ghost", True)}{btn("Добавить", "acc", True)}</div></div>', hub=True)) + '</div>')
st += cap(0, 280, '', 'ЭКРАН В МОМЕНТ ВВОДА', 1248)
st += ab(0, 310, scene)
save2('G_CalAddFlow.dc.html', page('Календарь · добавление', 'КАЛЕНДАРЬ', st, right='ЧТ 19.11 · 09:30', stage_h=620), 'Календарь · добавление кликом')
