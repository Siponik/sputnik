# Правки по комментариям 06.11: конвейер, стикеры, одно окно «Создать», сферы, поиск, анимации.
# Запуск последним: python3 s_fix.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
import s_board, s_cal, s_b4
from s_board import sidebar, titlebar

K = dim(s_board.KANBAN); W = dim(s_cal.WEEK)

# ======================= КОНВЕЙЕР =======================
STN = ['Модель', 'Ретопо', 'UV', 'Покраска', 'Рендер', 'Сдача']


def art(kind, c, w, h, r=8):
    # превью ассета: силуэт предмета на тёплом фоне
    shapes = {
        'shield': '<path d="M50 14 L80 24 L76 58 Q70 78 50 88 Q30 78 24 58 L20 24 Z" fill="#B7793C" stroke="#E8B77A" stroke-width="3"/><path d="M50 22 V80 M28 44 H72" stroke="#6B4320" stroke-width="5"/>',
        'sword': '<path d="M50 8 L56 16 L56 64 L44 64 L44 16 Z" fill="#C9CFD8"/><rect x="34" y="64" width="32" height="7" rx="2" fill="#B7793C"/><rect x="46" y="71" width="8" height="16" fill="#6B4320"/><circle cx="50" cy="91" r="5" fill="#E8B77A"/>',
        'helmet': '<path d="M22 60 Q22 18 50 16 Q78 18 78 60 L78 80 L22 80 Z" fill="#9AA3AF" stroke="#D5DBE2" stroke-width="3"/><rect x="30" y="46" width="40" height="7" rx="2" fill="#2B2E33"/><path d="M50 16 V80" stroke="#7A828C" stroke-width="3"/>',
        'chest': '<rect x="16" y="40" width="68" height="42" rx="4" fill="#8A5A2E"/><path d="M16 42 Q16 20 50 20 Q84 20 84 42 Z" fill="#A8703B"/><rect x="16" y="38" width="68" height="6" fill="#C9A15A"/><rect x="44" y="44" width="12" height="14" rx="2" fill="#E8C65A"/>',
        'torch': '<path d="M50 14 Q64 30 58 44 Q54 50 50 50 Q46 50 42 44 Q36 30 50 14 Z" fill="#F0A04B"/><path d="M50 26 Q56 36 52 44 Q50 46 48 44 Q44 36 50 26 Z" fill="#FFD29C"/><path d="M42 52 L58 52 L54 88 L46 88 Z" fill="#6B4320"/>',
    }
    return (f'<span style="flex: none; display: block; width: {w}px; height: {h}px; border-radius: {r}px; overflow: hidden; border: 1px solid #4A3B2C; '
            f'background: radial-gradient(90% 80% at 30% 20%, {c}40, transparent 70%), linear-gradient(160deg, #33291F, #1F1B17)">'
            f'<svg viewBox="0 0 100 100" width="100%" height="100%" preserveAspectRatio="xMidYMid meet" aria-hidden="true">{shapes[kind]}</svg></span>')


def pills(done, cur, days=''):
    out = ''
    for i, n in enumerate(STN):
        if i < done:
            s = f'background: rgba(127,209,140,.14); color: {GREEN}; border: 1px solid rgba(127,209,140,.35)'; t = f'✓ {n}'
        elif i == cur:
            s = f'background: {OR}; color: {DARK}; border: 1px solid {OR}; font-weight: 600'; t = n
        else:
            s = f'background: transparent; color: {DIM}; border: 1px dashed #4A4B52'; t = n
        out += f'<span style="flex: {1.5 if i == cur else 1}; min-width: 0; height: 28px; border-radius: 6px; box-sizing: border-box; {s}; display: flex; align-items: center; justify-content: center; font-size: 12px; white-space: nowrap; overflow: hidden">{t}</span>'
    return f'<div style="display: flex; gap: 3px; flex: 1; min-width: 0">{out}</div>'


def due(t, c=MUT):
    return f'<span style="flex: none; width: 64px; text-align: right"><span style="display: block; font-size: 13px; color: {c}">{t}</span></span>'


def nextbtn(t, on=False):
    s = f'background: {OR}; color: {DARK}; border: 0' if on else f'background: transparent; color: {INK}; border: 1px solid {LINE}'
    return f'<button type="button" style="flex: none; width: 104px; height: 32px; border-radius: 8px; {s}; font: 500 12.5px {SANS}">{t}</button>'


rows = [  # name, project, kind, color, done, cur, days, due, due color, next
    ('Шлем рыцаря', 'Кузня', 'helmet', OR, 1, 1, '1 дн', '19 ноя', MUT, 'UV →'),
    ('Сундук', 'Кузня', 'chest', OR, 0, 0, '3 дн', '25 ноя', MUT, 'Ретопо →'),
    ('Меч героя', 'Таверна', 'sword', OR, 4, 4, '4 дн', 'вт 10', RED, 'Сдача →'),
    ('Факел', 'Без проекта', 'torch', OR, 5, 5, '', 'готов', GREEN, 'Сдать ✓'),
]
st = sidebar('3D-ассеты', 'Меч ждёт рендера 4 дня. Поставить рендер на вечер?')
st += titlebar('3D-ассеты', OR, 'КОНВЕЙЕР', f'<span style="font-size: 12.5px; color: {MUT}">5 ассетов · 2 проекта</span><span style="width: 1px; height: 20px; background: {LINE}"></span>{seg(["ПО ПРОЕКТАМ", "ПО ЭТАПАМ"], "ПО ПРОЕКТАМ")}')
# раскрытая строка
X = 236; Wd = 1012
exp_top = f'''<div style="display: flex; align-items: center; gap: 14px; padding: 12px 14px">
  <span style="color: {MUT}; font-size: 12px">▾</span>{art("shield", OR, 64, 64)}
  <span style="width: 170px; flex: none"><span style="display: block; font: 600 15px {SANS}">Щит «Таверны»</span><span style="font-size: 12.5px; color: {MUT}">Таверна · покраска 2 дн · !!!</span></span>
  {pills(3, 3, "2 дн")}{due("пт 06", OR)}{nextbtn("Рендер →", True)}
</div>'''
chk = ''.join(f'<div style="display: flex; gap: 10px; align-items: center; height: 30px">{check(d, GREEN if d else STRONG)}<span style="{"text-decoration: line-through; color: " + DIM if d else ""}">{t}</span></div>' for t, d in [('Базовые цвета', True), ('Потёртости и сколы', True), ('Металл на окантовке', False), ('Запечь AO', False)])
col1 = f'''<div style="flex: 1.1; min-width: 0">
  <div style="display: flex; align-items: center; gap: 10px"><span style="font: 600 13px {SANS}">Этап «Покраска»</span><span style="font-size: 12px; color: {MUT}">2 из 4</span><span style="flex: 1; height: 4px; border-radius: 2px; background: {SOFT}; overflow: hidden"><span style="display: block; width: 50%; height: 100%; background: {OR}"></span></span></div>
  <div style="margin-top: 6px">{chk}</div>
  <div style="margin-top: 4px; height: 32px; border-radius: 8px; border: 1px dashed {STRONG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}; font-size: 12.5px">＋ Подзадача этапа… Enter — добавить</div>
</div>'''
col2 = f'''<div style="flex: none; width: 300px">
  <div style="display: flex; align-items: center; gap: 8px"><span style="font: 600 13px {SANS}">Превью</span><span style="font-size: 12px; color: {MUT}">2048 × 2048 · вчера</span></div>
  <div style="margin-top: 8px; position: relative">{art("shield", OR, 300, 150)}
    <span style="position: absolute; right: 8px; bottom: 8px; display: flex; gap: 6px">{btn("⤢ Крупно", sm=True, extra="; background: rgba(0,0,0,.55); border-color: transparent")}{btn("Заменить", sm=True, extra="; background: rgba(0,0,0,.55); border-color: transparent")}</span></div>
  <div style="margin-top: 6px; font-size: 12px; color: {MUT}">Перетащи картинку сюда или Ctrl+V</div>
</div>'''
det = lambda k, v: f'<div style="display: flex; align-items: center; gap: 10px; min-height: 30px"><span style="width: 92px; flex: none; font-size: 12.5px; color: {MUT}">{k}</span><span style="display: flex; gap: 6px; align-items: center; flex-wrap: wrap">{v}</span></div>'
col3 = f'''<div style="flex: 1; min-width: 0">
  <div style="font: 600 13px {SANS}">Детали</div>
  <div style="margin-top: 6px">{det("Срок", sc("Пт 6 ноября", True, OR))}{det("Клиент", sc("Таверна «Ёж»"))}{det("Приоритет", sc("!!!", True, RED) + sc("!!") + sc("!"))}{det("Напомнить", sc("За день", True, OR))}</div>
  <div style="margin-top: 8px; padding: 8px 10px; border-radius: 8px; background: {HOVER}; font-size: 12.5px; color: #C9CAD0">Клиент просит потёртости посильнее по краю.</div>
</div>'''
exp_body = f'''<div style="display: flex; gap: 22px; padding: 4px 18px 0 110px">{col1}{col2}{col3}</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 40px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 14px; padding: 0 18px 0 110px; font-size: 12px; color: {MUT}">
  <span>← Покраска назад к UV</span><span style="flex: 1"></span><span>{kbd("ESC")} свернуть</span><span>{kbd("SPACE")} следующий</span><span>{kbd("ENTER")} окно задачи</span><a href="#" style="font-size: 12.5px">Открыть полностью ↗</a></div>'''

y = 64
st += ab(X, y, f'<div style="display: flex; align-items: center; gap: 8px">{dot(OR, 7)}<span style="font: 600 13px {SANS}">Таверна</span><span style="font-size: 12px; color: {MUT}">2 ассета · сдача в пятницу</span></div>', w=600)
y += 26
st += node(X, y, Wd, 350, exp_top + exp_body, hub=True)
y += 350 + 8


def row(t, pr, kind, c, done, cur, days, d, dc, nx, on=False):
    sub = f'{pr} · {STN[cur].lower()} {days}' if days else f'{pr} · все этапы готовы'
    return (f'<div style="display: flex; align-items: center; gap: 14px; padding: 0 14px; height: 100%">'
            f'<span style="color: {DIM}; font-size: 12px">▸</span>{art(kind, c, 48, 48, 6)}'
            f'<span style="width: 170px; flex: none"><span style="display: block; font: 600 14px {SANS}">{t}</span><span style="font-size: 12px; color: {MUT}">{sub}</span></span>'
            f'{pills(done, cur, days)}{due(d, dc)}{nextbtn(nx, nx.startswith("Сдать"))}</div>')


t_, pr, kd, c, dn, cu, dy, dd, dc, nx = rows[2]
st += node(X, y, Wd, 64, row(t_, pr, kd, c, dn, cu, dy, dd, dc, nx)); y += 64 + 12
st += ab(X, y, f'<div style="display: flex; align-items: center; gap: 8px">{dot(OR, 7)}<span style="font: 600 13px {SANS}">Кузня</span><span style="font-size: 12px; color: {MUT}">2 ассета</span><span style="flex: 1"></span><span style="font-size: 12.5px; color: {OR}">＋ Ассет в «Кузню»</span>{kbd("N")}</div>', w=Wd); y += 24
for r_ in rows[:2]:
    st += node(X, y, Wd, 64, row(*r_)); y += 64 + 6
save('G_Conveyor.dc.html', page('Доска · конвейер', 'ДОСКА', st), 'Доска · конвейер', 0, 1880, 'r4')

# ======================= СТИКЕРЫ =======================
TINT = {OR: ('#3A2E22', '#F0C08A'), GREEN: ('#24342A', '#A8E2B2'), GOLD: ('#38331F', '#F0DC8E'), BLUE: ('#22304A', '#A9C6F6')}


def note(t, when, c, rot, pin=False, now=False, h=112):
    bg, ink = TINT[c]
    pinh = f'<span style="position: absolute; left: 50%; top: -6px; width: 12px; height: 12px; margin-left: -6px; border-radius: 50%; background: {RED}; box-shadow: 0 2px 3px rgba(0,0,0,.5)"></span>' if pin else ''
    tape = '' if pin else f'<span style="position: absolute; left: 50%; top: -7px; width: 54px; height: 14px; margin-left: -27px; transform: rotate({-rot * 2}deg); background: rgba(255,255,255,.12); border-radius: 2px"></span>'
    ring = f'; outline: 2px solid {OR}; outline-offset: 3px' if now else ''
    return (f'<div style="position: relative; height: {h}px; box-sizing: border-box; padding: 14px 14px 10px; border-radius: 3px 3px 14px 3px; background: {bg}; '
            f'transform: rotate({rot}deg); box-shadow: 0 6px 14px rgba(0,0,0,.35), inset 0 -18px 18px -18px rgba(0,0,0,.4){ring}; display: flex; flex-direction: column">'
            f'{pinh}{tape}<span style="flex: 1; font: 500 14.5px/20px {SANS}; color: {ink}">{t}</span>'
            f'<span style="display: flex; align-items: center; gap: 8px"><span style="width: 18px; height: 18px; border-radius: 50%; box-sizing: border-box; border: 1.5px solid {ink}; opacity: .7"></span>'
            f'<span style="font-size: 12px; color: {ink}; opacity: .75">{when}</span></span></div>')


lanes = [('Покупки', OR, [('Купить корм коту', 'сегодня', False, True), ('Лампочки E27 × 3', 'до сб', False, False), ('Губки и средство для посуды', 'без срока', False, False)]),
         ('Дом', GREEN, [('Вызвать мастера на кран', 'пт 06', True, False), ('Повесить полку', 'выходные', False, False), ('Разобрать балкон', 'без срока', False, False)]),
         ('Кот', GOLD, [('Прививка в ветклинике', '12.11 · 18:00', False, False), ('Подстричь когти', 'каждые 2 нед', False, False)]),
         ('Документы', BLUE, [('Квитанция за свет', 'до 10.11', True, False), ('Продлить ОСАГО', '28.11', False, False)])]
st = sidebar('Дела по дому', 'Сделанное уходит в баночку сразу.') + titlebar('Дела по дому', GREEN, 'СТИКЕРЫ', seg(['ПО ТЕМАМ', 'ПО СРОКАМ'], 'ПО ТЕМАМ'))
LW = 236; LG = 22
rots = [-1.6, 1.2, -0.6, 1.8, -1.2, 0.8]
for i, (n, c, ss) in enumerate(lanes):
    x = 236 + i * (LW + LG)
    inner = f'<div style="display: flex; align-items: center; gap: 8px; padding: 0 2px">{dot(c, 8)}<span style="font: 600 13.5px {SANS}">{n}</span><span style="font-size: 12px; color: {DIM}">{len(ss)}</span></div><div style="margin-top: 18px; display: flex; flex-direction: column; gap: 18px">'
    for j, (t, w_, pin, now) in enumerate(ss):
        inner += note(t, w_, c, rots[(i * 2 + j) % 6], pin, now)
    inner += f'<div style="height: 44px; border-radius: 4px; border: 1.5px dashed #4A4B52; display: flex; align-items: center; padding: 0 12px; color: {MUT}">＋ Стикер</div></div>'
    st += ab(x, 64, inner, w=LW)
jar = ''.join(f'<span style="width: 14px; height: 14px; border-radius: 3px; background: {c}; transform: rotate({r}deg)"></span>' for c, r in [('#F0C08A', -8), ('#A8E2B2', 6), ('#F0DC8E', -3), ('#A9C6F6', 10), ('#F0C08A', 4), ('#A8E2B2', -6), ('#F0DC8E', 8), ('#A8E2B2', -2)])
st += node(236 + 2 * (LW + LG), 556, 2 * LW + LG, 124, f'''<div style="padding: 14px 16px; display: flex; gap: 16px; align-items: center">
  <span style="flex: none; width: 70px; height: 92px; border-radius: 10px 10px 14px 14px; border: 2px solid #55575F; border-top-width: 6px; display: flex; flex-wrap: wrap-reverse; align-content: flex-start; gap: 3px; padding: 6px; box-sizing: border-box">{jar}</span>
  <span style="flex: 1"><span style="display: block; font: 600 14px {SANS}">Баночка · 12 за неделю</span><span style="display: block; margin-top: 4px; font-size: 12.5px; color: #C9CAD0">Последнее: «Вынести коробки» · вчера. Сделанный стикер падает сюда.</span><a href="#" style="display: inline-block; margin-top: 6px; font-size: 12.5px">Открыть баночку</a></span></div>''')
save('G_Stickers.dc.html', page('Доска · стикеры', 'ДОСКА', st), 'Доска · стикеры', 1360, 1880, 'r4')

# ======================= ОДНО ОКНО «СОЗДАТЬ» =======================
KINDS = [('Задача', OR, '✓'), ('Событие', BLUE, '◷'), ('Привычка', GOLD, '↻'), ('День рождения', VIO, '✦')]


def crhead(k, mode='all', title=''):
    c = KINDS[k][1]
    if mode == 'locked':
        inner = f'<span style="padding-left: 10px; font: 600 14px {SANS}; color: #FFFFFF">{title}</span><span style="flex: 1"></span>'
    else:
        tabs = ''
        allowed = range(4) if mode == 'all' else mode
        for i in allowed:
            n, cc, ic = KINDS[i]
            if i == k:
                s = f'background: rgba(255,255,255,.94); color: {FILL[c]}; font-weight: 600'
            else:
                s = 'color: rgba(255,255,255,.86)'
            tabs += f'<span style="flex: 1; height: 32px; border-radius: 7px; {s}; display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 13.5px"><span style="opacity: .8">{ic}</span>{n}<span style="font: 400 10px {MONO}; opacity: .55">ALT {i + 1}</span></span>'
        inner = f'<div style="flex: 1; display: flex; gap: 4px; padding: 3px; border-radius: 9px; background: rgba(0,0,0,.18)">{tabs}</div>'
    return (f'<div style="height: 46px; box-sizing: border-box; padding: 0 8px 0 8px; border-radius: 11px 11px 0 0; background: {FILL[c]}; display: flex; align-items: center; gap: 8px">'
            f'{inner}<button type="button" aria-label="Закрыть" style="width: 32px; height: 32px; border-radius: 8px; border: 0; background: transparent; color: #FFFFFF; font-size: 16px">✕</button></div>')


mark = lambda t, c: f'<span style="padding: 2px 8px; border-radius: 6px; background: {c}29; color: {INK}; margin: 0 2px">{t}</span>'
caret = lambda c: f'<span style="display: inline-block; width: 1.5px; height: 20px; background: {c}; vertical-align: -4px; margin-left: 3px"></span>'
help_ = f'<span title="Подсказка" style="margin-left: auto; flex: none; width: 24px; height: 24px; border-radius: 50%; border: 1px solid {LINE}; color: {MUT}; display: grid; place-items: center; font-size: 12px">?</span>'


def frow(label, inner):
    return f'<div style="display: flex; align-items: center; gap: 12px; min-height: 34px"><span style="width: 104px; flex: none; font-size: 13px; color: {MUT}">{label}</span><span style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center; min-width: 0">{inner}</span></div>'


def cwin(k, line, rows_, right, primary, mode='all', title='', x=204, y=14, w=840, h=672, foot_left='Enter — добавить · Esc — закрыть', ctx=''):
    c = KINDS[k][1]
    ctxh = f'<div style="padding: 10px 22px 0; font-size: 12.5px; color: {MUT}">{ctx}</div>' if ctx else ''
    body = f'''{ctxh}<div style="padding: {"10px" if ctx else "18px"} 22px 0">
  <div style="height: 52px; box-sizing: border-box; border-radius: 10px; border: 1.5px solid {c}; background: {BG}; display: flex; align-items: center; gap: 8px; padding: 0 10px 0 16px; font-size: 17px">{line}{caret(c)}{help_}</div>
</div>
<div style="padding: 16px 22px 0; display: grid; grid-template-columns: minmax(0, 1fr) 248px; gap: 22px">
  <div style="display: flex; flex-direction: column; gap: 8px">{rows_}</div>
  <div style="display: flex; flex-direction: column; gap: 12px">{right}</div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 60px; box-sizing: border-box; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 22px">
  <span style="font-size: 12.5px; color: {MUT}">{foot_left}</span><span style="flex: 1"></span>
  {btn("Добавить и ещё" if mode != "locked" else "Отмена", extra="; height: 38px; padding: 0 16px; border-radius: 8px")}<button type="button" style="height: 38px; padding: 0 18px; border-radius: 8px; border: 0; background: {c}; color: {DARK}; font: 600 14px {SANS}">{primary}</button>
</div>'''
    return node(x, y, w, h, crhead(k, mode, title) + body, hub=True, style=SH)


s_ = lambda c: (lambda t, on=False, x=False: sc(t, on, c, x))
o = s_(OR)
where = f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}">{dot(OR, 8)}<span style="font-weight: 600">3D-ассеты</span><span style="color: {GOLD}; font-size: 12px">по слову «рендер»</span><span style="color: {MUT}">▾</span></span>'
more = f'''<div style="margin-top: 6px; border-radius: 10px; border: 1px solid {LINE}; background: {BG}">
  <div style="height: 38px; display: flex; align-items: center; gap: 10px; padding: 0 12px; border-bottom: 1px solid {SOFT}"><span style="font: 600 13px {SANS}">▾ Ещё параметры</span><span style="font-size: 12px; color: {MUT}">открыто 2 из 8 · запомню, какие ты открываешь</span></div>
  <div style="padding: 8px 12px 10px; display: flex; flex-direction: column; gap: 6px">
    {frow("Приоритет", o("!!! Высокий", True) + o("!! Средний") + o("! Низкий") + o("Нет"))}
    {frow("Подзадачи", f'<span style="display: flex; flex-direction: column; gap: 4px"><span style="display: flex; gap: 8px; align-items: center">{check()}Свет и камера</span><span style="display: flex; gap: 8px; align-items: center">{check()}Рендер 4K</span><span style="color: {MUT}; font-size: 12.5px">＋ подзадача</span></span>')}
    <div style="display: flex; gap: 6px; flex-wrap: wrap; padding-top: 4px; border-top: 1px solid {SOFT}">{"".join(f'<span style="height: 26px; padding: 0 10px; border-radius: 13px; border: 1px dashed #55575F; display: inline-flex; align-items: center; font-size: 12.5px; color: #C9CAD0">＋ {t}</span>' for t in ["Повтор", "Заметка", "Цвет", "Картинка", "Исполнитель"])}</div>
  </div>
</div>'''
chip_ = lambda t, on=False: f'<span style="height: 28px; padding: 0 11px; border-radius: 7px; display: inline-flex; align-items: center; font-size: 12.5px; {"background: "+OR+"29; border: 1px solid "+OR+"; color: "+INK+"; font-weight: 600" if on else "border: 1px solid "+LINE+"; color: #C9CAD0"}">{t}</span>'
more_c = f'<div style="margin-top: 6px; height: 38px; border-radius: 10px; border: 1px solid {LINE}; background: {BG}; display: flex; align-items: center; gap: 10px; padding: 0 12px"><span style="font: 600 13px {SANS}">▸ Ещё параметры</span><span style="font-size: 12px; color: {MUT}">приоритет, подзадачи, повтор…</span></div>'
when_chips = chip_("Сегодня") + chip_("Завтра", True) + chip_("Пн") + chip_("След. неделя") + chip_("Без срока") + f'<span style="height: 28px; padding: 0 10px; border-radius: 7px; border: 1px solid {LINE}; display: inline-flex; align-items: center; gap: 6px; font: 500 12px {MONO}; color: {INK}">◷ 17:00</span><span style="font-size: 12.5px; color: {MUT}">📅 дата…</span>'
_days = [("ЧТ", "5", "сегодня"), ("ПТ", "6", ""), ("СБ", "7", ""), ("ВС", "8", ""), ("ПН", "9", ""), ("ВТ", "10", ""), ("СР", "11", "")]
def _day(d, n, note, on):
    st_ = f"background: {OR}29; border: 1.5px solid {OR}" if on else f"border: 1px solid {SOFT}"
    pin = f'<span style="position: absolute; left: 50%; bottom: -7px; transform: translateX(-50%); width: 6px; height: 6px; border-radius: 50%; background: {OR}"></span>' if on else ''
    return f'<span style="position: relative; flex: 1; height: 40px; border-radius: 7px; {st_}; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1px"><span style="font: 500 9.5px {MONO}; letter-spacing: .1em; color: {OR if on else MUT}">{d}</span><span style="font-size: 13px; font-weight: {600 if on else 400}; color: {INK if on else "#C9CAD0"}">{n}</span>{pin}</span>'
when_land = f'''<div style="margin: 2px 0 4px 116px; padding: 10px 12px; border-radius: 10px; border: 1px solid {LINE}; background: {BG}; display: flex; flex-direction: column; gap: 10px">
  <div style="display: flex; gap: 4px">{"".join(_day(d, n, t, i == 1) for i, (d, n, t) in enumerate(_days))}</div>
  <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap; font-size: 12.5px; color: #DADBE0"><span style="color: {OR}; font-weight: 600">→ Попадёт</span><span style="padding: 2px 8px; border-radius: 6px; background: {HOVER}">Доска · колонка «Завтра»</span><span style="padding: 2px 8px; border-radius: 6px; background: {HOVER}">«Сегодня» в пт 6 · 17:00</span><span style="padding: 2px 8px; border-radius: 6px; background: {HOVER}">Календарь · неделя 2–8 ноя</span></div>
</div>'''
_set = lambda k, v, c=OR: f'<span style="height: 30px; padding: 0 6px 0 10px; border-radius: 8px; background: {c}1F; border: 1px solid {c}66; display: inline-flex; align-items: center; gap: 7px; font-size: 12.5px"><span style="color: {MUT}">{k}</span><span style="font-weight: 600; color: {INK}">{v}</span><span style="color: {MUT}; font-size: 11px; padding: 0 3px">✕</span></span>'
_add = lambda t: f'<span style="height: 30px; padding: 0 10px; border-radius: 8px; border: 1px dashed #55575F; display: inline-flex; align-items: center; font-size: 12.5px; color: #C9CAD0">＋ {t}</span>'
props_bar = f'''<div style="margin-top: 4px; padding-top: 12px; border-top: 1px solid {SOFT}; display: flex; flex-direction: column; gap: 10px">
  <div style="display: flex; gap: 6px; flex-wrap: wrap">{_set("Этап", "Рендер")}{_set("Приоритет", "!!!", RED)}{_set("Напомнить", "за час")}{_set("Подзадачи", "2")}</div>
  <div style="display: flex; gap: 6px; flex-wrap: wrap">{"".join(_add(t) for t in ["Повтор", "Заметка", "Цвет", "Картинка", "Исполнитель"])}</div>
  <div style="font-size: 12px; color: {MUT}">Клик по свойству — маленькое всплывающее окно рядом. Или «/» в строке: <span style="font: 500 11.5px {MONO}; color: {INK}">/этап</span>, <span style="font: 500 11.5px {MONO}; color: {INK}">/повтор</span>. Заданное фразой («!!!», «в пятницу») сразу становится чипом.</div>
</div>'''
_fld = lambda ic, t, w, mono=False: f'<span style="width: {w}px; height: 34px; box-sizing: border-box; padding: 0 10px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}; display: inline-flex; align-items: center; gap: 8px; font: {"500 13px "+MONO if mono else "600 13px "+SANS}; color: {INK}"><span style="color: {MUT}; display: grid">{svg_(ic[1:], 16) if ic.startswith("@") else ic}</span><span style="flex: 1">{t}</span><span style="color: {MUT}; font-size: 11px">▾</span></span>'
when_block = (frow("Когда", _fld("@clock", "17:00", 104, True) + _fld("@calendar", "Пт, 6 ноября", 200))
              + f'<div style="margin: -2px 0 0 116px; display: flex; gap: 6px; flex-wrap: wrap">{chip_("Сегодня") + chip_("Завтра", True) + chip_("Пн") + chip_("След. неделя") + chip_("Без срока")}</div>')
task_rows = (frow("Куда", where + f'<span style="font-size: 12.5px; color: {OR}">Alt L</span>') + when_block + when_land
             + props_bar)
prev = f'''<span style="font-size: 12.5px; color: {MUT}">Так появится на доске</span>
<div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; overflow: hidden">
  <div style="height: 28px; padding: 0 10px; background: {FILL[OR]}; display: flex; align-items: center; justify-content: space-between; font: 500 10px {MONO}; letter-spacing: .14em; color: #FFFFFF">3D-АССЕТЫ<span style="color: rgba(255,255,255,.72)">РЕНДЕР</span></div>
  <div style="padding: 12px; display: flex; gap: 10px; align-items: center">{art("shield", OR, 40, 40, 6)}<span style="flex: 1"><span style="display: block; font-weight: 600">Рендер щита</span><span style="font-size: 12px; color: {MUT}">Завтра 17:00 · !!! · 0 / 2</span></span></div>
</div>
<div style="display: flex; gap: 10px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(232,198,90,.07); border: 1px solid #5C4F22">{coon(40, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #DADBE0">В пятницу с 17:00 свободно. Рендер обычно занимает часа два.</span></div>
<div style="padding: 10px 12px; border-radius: 10px; border: 1px solid {LINE}; font-size: 12px; line-height: 18px; color: {MUT}"><b style="font-weight: 600; color: {INK}">?</b> Пиши как в заметке: «в пятницу», «каждую неделю», «@работа», «!!!». Подсказка открывается по «?» и видна, пока строка пустая.</div>'''
line = f'Рендер щита {mark("завтра в 17:00", OR)} {mark("!!!", RED)}'
st = K + cwin(0, line, task_rows, prev, 'Добавить задачу')
save('G_Create.dc.html', page('Создать', 'ДОСКА', st), 'Окно «Создать» · задача и «Ещё параметры»', 0, 3760, 'r4')

# пустая строка — подсказка в поле
bv = s_(BLUE)
ev_rows = (frow("Календарь", f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}">{dot(BLUE, 8)}<span style="font-weight: 600">Основной</span><span style="color: {MUT}">▾</span></span>')
           + frow("Когда", bv("Пятница, 6 ноября · 15:00", True, True)) + frow("Длится", bv("30 мин") + bv("1 час", True) + bv("2 часа") + bv("Весь день"))
           + f'<div style="padding-left: 116px; display: flex; align-items: center; gap: 8px; font-size: 12.5px; color: {GREEN}">{dot(GREEN, 6)}Свободно до 17:00</div>'
           + frow("Место", f'<span style="width: 300px; height: 32px; box-sizing: border-box; border-radius: 8px; border: 1px solid {STRONG}; display: inline-flex; align-items: center; padding: 0 12px; color: {MUT}">Адрес или ссылка</span>')
           + frow("Напомнить", bv("За 15 мин", True, True) + bv("За час") + bv("＋"))
           + f'<div style="margin-top: 6px; height: 38px; border-radius: 10px; border: 1px solid {LINE}; background: {BG}; display: flex; align-items: center; gap: 10px; padding: 0 12px"><span style="font: 600 13px {SANS}">▸ Ещё параметры</span><span style="font-size: 12px; color: {MUT}">повтор, заметка, участники</span></div>')
hrs = ''.join(f'<div style="height: 38px; border-top: 1px solid {SOFT}; position: relative"><span style="position: absolute; left: 8px; top: 4px; font: 400 10px {MONO}; color: {DIM}">{hh}</span></div>' for hh in ['13:00', '14:00', '15:00', '16:00', '17:00'])
ev_r = f'''<span style="font-size: 12.5px; color: {MUT}">Пятница, 6 ноября</span>
<div style="position: relative; border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; overflow: hidden">{hrs}
 <div style="position: absolute; left: 52px; right: 8px; top: 4px; height: 30px; border-radius: 6px; background: #2C2D33; border-left: 3px solid {GREY}; padding: 4px 8px; box-sizing: border-box; font-size: 12px">Созвон с Олей</div>
 <div style="position: absolute; left: 52px; right: 8px; top: 78px; height: 38px; border-radius: 6px; background: rgba(111,162,242,.18); border: 1.5px dashed {BLUE}; padding: 4px 8px; box-sizing: border-box; font-size: 12px"><b style="font-weight: 600">Встреча с заказчиком</b><br><span style="color: {MUT}">15:00 – 16:00</span></div></div>'''
line = f'Встреча с заказчиком {mark("в пятницу 15:00", BLUE)} {mark("час", BLUE)}'
st = W + cwin(1, line, ev_rows, ev_r, 'Добавить событие')
save2('G_CreateEvent.dc.html', page('Создать · событие', 'КАЛЕНДАРЬ', st), 'Создать · событие')

gd = s_(GOLD)
icons = ''.join(f'<span style="width: 32px; height: 32px; border-radius: 8px; border: 1px solid {GOLD if i == 0 else LINE}; background: {"rgba(232,198,90,.12)" if i == 0 else "transparent"}; display: grid; place-items: center; font-size: 15px">{e}</span>' for i, e in enumerate([svg_('fire', 16), svg_('timer', 16), svg_('edit', 16), svg_('read', 16), svg_('focus', 16), svg_('star', 16), svg_('theme', 16)]))


def hab_rows(edit=False):
    return (frow("Значок", icons) + frow("Как часто", gd("Каждый день", True) + gd("По будням") + gd("Свои дни") + gd("N раз в неделю"))
            + frow("Цель на день", gd("Просто сделать", True) + gd("Количество…"))
            + frow("Часть дня", gd("Утро", True) + gd("День") + gd("Вечер") + gd("Любое"))
            + frow("Окно", f'<span style="font: 400 13px {MONO}; padding: 6px 10px; border-radius: 8px; border: 1px solid {STRONG}">07:00</span><span style="color: {MUT}">до</span><span style="font: 400 13px {MONO}; padding: 6px 10px; border-radius: 8px; border: 1px solid {STRONG}">09:00</span><span style="font-size: 12px; color: {MUT}">утро 6–12, можно сузить</span>')
            + frow("Напомнить", gd("Telegram в 07:00", True, True) + gd("Windows, пока идёт окно", True, True))
            + f'<div style="margin-top: 6px; height: 38px; border-radius: 10px; border: 1px solid {LINE}; background: {BG}; display: flex; align-items: center; gap: 10px; padding: 0 12px"><span style="font: 600 13px {SANS}">▸ Ещё параметры</span><span style="font-size: 12px; color: {MUT}">цвет, до какого дня{", удалить" if edit else ""}</span></div>')


hprev = f'''<span style="font-size: 12.5px; color: {MUT}">Так появится в «Привычках»</span>
<div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; padding-bottom: 12px">
 <div style="height: 34px; padding: 0 12px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 8px"><span style="width: 20px; height: 20px; border-radius: 5px; background: {GOLD}; display: grid; place-items: center; font-size: 11px">{svg_("fire", 13)}</span><span style="font-weight: 600">Зарядка</span><span style="margin-left: auto">{micro("УТРО")}</span></div>
 <div style="padding: 12px 14px 0; display: flex; align-items: flex-end; gap: 10px"><span style="font: 200 50px/46px {SANS}">21</span><span style="padding-bottom: 6px">{micro("ДН ПОДРЯД", MUT)}</span></div>
</div>'''
line = f'Зарядка {mark("каждый день", GOLD)} {mark("утром", GOLD)}'
st = dim(s_b4.HM, .2) + cwin(2, line, hab_rows(), hprev + f'<div style="display: flex; gap: 10px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(232,198,90,.07); border: 1px solid #5C4F22">{coon(40, "ФЛАГ")}<span style="font-size: 12.5px; line-height: 18px; color: #DADBE0">Первая веха — 7 дней.</span></div>', 'Добавить привычку')
save2('G_CreateHabit.dc.html', page('Создать · привычка', 'ПРИВЫЧКИ', st), 'Создать · привычка')

# правка привычки = то же окно, вид закреплён
line = 'Зарядка'
st = dim(s_b4.HM, .2) + cwin(2, line, hab_rows(True), hprev + f'<div style="display: flex; gap: 10px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(232,198,90,.07); border: 1px solid #5C4F22">{coon(40, "ФЛАГ")}<span style="font-size: 12.5px; line-height: 18px; color: #DADBE0">Серия 21 день. Изменения не сбросят её.</span></div>',
                                    'Сохранить', mode='locked', title='Привычка · Зарядка', foot_left='Ctrl+Enter — сохранить · Esc — закрыть',
                                    ctx='То же окно «Создать», открыто из карточки привычки: вид закреплён, поля уже заполнены.')
save2('G_HabitEdit.dc.html', page('Окно привычки', 'ПРИВЫЧКИ', st), 'Привычка · правка в том же окне «Создать»')

vv = s_(VIO)
bd_rows = (frow("Когда", vv("12 ноября", True, True) + f'<span style="font-size: 12px; color: {MUT}">каждый год</span>')
           + frow("Год", f'<span style="font: 400 13px {MONO}; padding: 6px 10px; border-radius: 8px; border: 1px solid {STRONG}">1994</span><span style="font-size: 12px; color: {MUT}">необязательно</span>')
           + frow("Напомнить", vv("В день", True, True) + vv("За день", True, True) + vv("＋"))
           + frow("Подарок", vv("Не надо") + vv("За неделю", True) + vv("За 2 недели") + vv("За месяц"))
           + frow("Календарь", f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}">{dot(VIO, 8)}<span style="font-weight: 600">Основной</span><span style="color: {MUT}">▾</span></span>'))
bd_r = f'''<span style="font-size: 12.5px; color: {MUT}">В календаре</span>
<div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; padding: 14px; display: flex; gap: 12px; align-items: center">
 <span style="width: 44px; height: 48px; border-radius: 8px; background: {FILL[VIO]}; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #FFFFFF"><span style="font: 600 18px {SANS}">12</span><span style="font: 500 9px {MONO}; letter-spacing: .1em">НОЯ</span></span>
 <span><span style="display: block; font-weight: 600">День рождения Оли</span><span style="font-size: 12.5px; color: {MUT}">Исполнится 32 · через 7 дней</span></span></div>'''
line = f'Оля {mark("12 ноября", VIO)} {mark("1994", VIO)}'
st = K + cwin(3, line, bd_rows, bd_r, 'Добавить день рождения')
save2('G_CreateBday.dc.html', page('Создать · день рождения', 'КАЛЕНДАРЬ', st), 'Создать · день рождения')

# ---- откуда вызвали → что заранее выбрано ----
def mini(k, mode, title, line, chips):
    c = KINDS[k][1]
    if mode == 'locked':
        hd = f'<div style="height: 34px; padding: 0 12px; border-radius: 9px 9px 0 0; background: {FILL[c]}; display: flex; align-items: center; color: #FFFFFF; font: 600 12.5px {SANS}">{title}</div>'
    else:
        ks = range(4) if mode == 'all' else mode
        tabs = ''.join(f'<span style="flex: 1; height: 24px; border-radius: 5px; display: grid; place-items: center; font-size: 11.5px; {"background: rgba(255,255,255,.94); color: " + FILL[c] + "; font-weight: 600" if i == k else "color: rgba(255,255,255,.85)"}">{["Задача", "Событие", "Привычка", "Д. р."][i]}</span>' for i in ks)
        hd = f'<div style="height: 34px; padding: 0 5px; border-radius: 9px 9px 0 0; background: {FILL[c]}; display: flex; align-items: center; gap: 3px">{tabs}</div>'
    ch = ''.join(f'<span style="height: 24px; padding: 0 8px; border-radius: 6px; border: 1px solid {c}; background: {c}1F; display: inline-flex; align-items: center; font-size: 12px">{t}</span>' for t in chips)
    return (f'<div style="border-radius: 10px; border: 1px solid {LINE}; background: {NODE}; overflow: hidden">{hd}'
            f'<div style="padding: 10px 12px"><div style="height: 32px; border-radius: 7px; border: 1.5px solid {c}; background: {BG}; display: flex; align-items: center; padding: 0 10px; font-size: 13px; color: {MUT if not line else INK}">{line or "Что нужно сделать?"}</div>'
            f'<div style="margin-top: 8px; display: flex; gap: 6px; flex-wrap: wrap">{ch}</div></div></div>')


cases = [
    ('Кнопка «Создать», Ctrl+N', 'Все четыре вида. «Куда» угадывается по тексту.', mini(0, 'all', '', '', ['Куда: угадаю'])),
    ('«＋» в колонке доски', 'Только задача. Список и колонка уже выбраны.', mini(0, 'locked', 'Задача · 3D-ассеты · В работе', '', ['3D-ассеты', 'В работе'])),
    ('Клик по часу в календаре', 'Задача или событие. День и время уже стоят.', mini(1, [0, 1], '', '', ['Пт 6 ноября', '15:00–16:00'])),
    ('«＋ Привычка» на «Привычках»', 'Только привычка. Часть дня — из выбранного фильтра.', mini(2, 'locked', 'Новая привычка', '', ['Утро'])),
    ('Клик по привычке → «Изменить»', 'Та же форма с заполненными полями, кнопка «Сохранить».', mini(2, 'locked', 'Привычка · Зарядка', 'Зарядка', ['Каждый день', 'Утро'])),
    ('Строка «Сегодня», Shift+Enter', 'Задача, текст из строки переносится.', mini(0, 'all', '', 'Позвонить в банк в 15:00', ['Сегодня 15:00'])),
    ('Стикеры: «＋ Стикер» в теме', 'Только задача. Список и тема выбраны.', mini(0, 'locked', 'Стикер · Дела по дому · Кот', '', ['Дела по дому', 'Кот'])),
    ('Окно задачи → подзадача «↗»', 'Задача в тот же список, родитель указан.', mini(0, 'locked', 'Подзадача · Щит «Таверны»', '', ['3D-ассеты', 'Этап «Покраска»'])),
]
st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ОДНО ОКНО «СОЗДАТЬ» · ОТКУДА ВЫЗВАЛИ — ЧТО УЖЕ ВЫБРАНО", INK)}{micro("ВЕЗДЕ ТОТ ЖЕ КОМПОНЕНТ, МЕНЯЮТСЯ ТОЛЬКО ВИДЫ В ШАПКЕ И ЗАПОЛНЕННЫЕ ПОЛЯ", MUT)}</div>', w=1248)
CWc = 297; CGc = 20
for i, (t, d, m) in enumerate(cases):
    r, c = divmod(i, 4)
    st += node(c * (CWc + CGc), 34 + r * 262, CWc, 246,
               f'<div style="padding: 12px 14px"><div style="font: 400 10px {MONO}; letter-spacing: .14em; color: {DIM}">0{i + 1}</div><div style="font: 600 14px {SANS}">{t}</div><div style="margin-top: 4px; font-size: 12.5px; line-height: 18px; color: #C9CAD0; min-height: 36px">{d}</div><div style="margin-top: 12px">{m}</div></div>')
st += ab(0, 566, f'<span style="font-size: 12.5px; color: {MUT}">Правило: шапка с видами показывается, только если видов больше одного. Закреплённый вид — заголовок вместо переключателя. Поля, выбранные местом вызова, можно поменять, кроме вида.</span>', w=1248)
props = [('kinds', 'какие виды можно выбрать: все четыре, [задача, событие] или один'), ('kind', 'вид при открытии'), ('preset', 'заранее выбранные поля: список, колонка, тема, этап, день, время, часть дня, родитель'),
         ('edit', 'id записи — та же форма в режиме правки, кнопка «Сохранить», в «Ещё» — «Удалить»'), ('text', 'текст строки, если пришёл из «Сегодня»')]
pt = ''.join(f'<div style="display: flex; gap: 14px; padding: 5px 0; border-bottom: 1px solid {SOFT}"><span style="width: 70px; flex: none; font: 500 12px {MONO}; color: {OR}">{a}</span><span style="font-size: 12.5px; color: #C9CAD0">{b}</span></div>' for a, b in props)
st += node(0, 596, 1248, 0, nhead('', 'КОМПОНЕНТ · ОКНО «СОЗДАТЬ»', 'ОДИН НА ВСЁ ПРИЛОЖЕНИЕ', OR, None, 30) + f'<div style="padding: 4px 14px 8px">{pt}</div>')
save2('G_CreateFrom.dc.html', page('Создать · откуда вызвали', 'ДОСКА', st, stage_h=790), 'Создать · одно окно для всех мест')

# ======================= ПОИСК ИЗ ПОЛЯ В ШАПКЕ =======================
hl = lambda a, b, c_: f'{a}<span style="background: rgba(240,160,75,.22); color: {ORI}; border-radius: 3px; padding: 0 2px">{b}</span>{c_}'
grp = lambda t: f'<div style="padding: 10px 14px 4px; font: 500 12px {SANS}; letter-spacing: 0; color: {MUT}">{t}</div>'
res = grp('Задачи · 3')
for i, (t, l, c, d) in enumerate([(hl('Текстуры для ', 'щит', 'а, 2K'), '3D-ассеты', OR, 'сегодня 15:00'), (hl('Рендер ', 'щит', 'а'), '3D-ассеты', OR, 'пт 17:00'), (hl('', 'Щит', ' «Таверны» · сдача'), 'Работа · клиенты', BLUE, '12.11')]):
    bg = f'background: {HOVER};' if i == 0 else ''
    res += f'<div style="margin: 0 6px; height: 38px; border-radius: 8px; {bg} display: flex; align-items: center; gap: 10px; padding: 0 10px; font: 400 13px {SANS}; letter-spacing: 0; color: {INK}">{check()}<span style="flex: 1">{t}</span><span style="display: flex; align-items: center; gap: 6px; font-size: 12px; color: {MUT}">{dot(c)}{l}</span><span style="width: 84px; text-align: right; font-size: 12px; color: {MUT}">{d}</span></div>'
res += grp('В заметках · 1')
res += f'<div style="margin: 0 6px; height: 38px; display: flex; align-items: center; gap: 10px; padding: 0 10px; font: 400 13px {SANS}; letter-spacing: 0; color: #C9CAD0">{check()}<span style="flex: 1">Созвон с «Таверной» — <span style="color: {MUT}">«…концепты {hl("", "щит", "а")} и меча…»</span></span></div>'
res += grp('Разделы и списки')
res += f'<div style="margin: 0 6px 8px; height: 34px; display: flex; align-items: center; gap: 10px; padding: 0 10px; font: 400 13px {SANS}; letter-spacing: 0; color: {INK}">{dot(OR)}<span style="flex: 1">Доска · 3D-ассеты</span></div>'
res += f'<div style="height: 38px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 14px; padding: 0 14px; font: 400 12px {SANS}; letter-spacing: 0; color: {MUT}"><span>{kbd("↑ ↓")} выбрать</span><span>{kbd("ENTER")} открыть</span><span>{kbd("ESC")} закрыть</span><span style="margin-left: auto">ё = е</span></div>'
drop = f'<div style="position: absolute; right: 0; top: calc(100% + 6px); width: 560px; border-radius: 10px; border: 1px solid {OR}; background: {NODE}; box-shadow: 0 18px 40px rgba(0,0,0,.5); z-index: 5; text-transform: none">{res}</div>'
html = page('Поиск', 'ДОСКА', K, right='')
old_field = html[html.index('<span style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px; border-radius: 8px; border: 1px solid ' + LINE + '; color: ' + MUT + '; min-width: 150px">'):]
old_field = old_field[:old_field.index('CTRL K</span></span>') + len('CTRL K</span></span>')]
new_field = (f'<span style="position: relative; display: flex; align-items: center; gap: 8px; height: 32px; width: 400px; box-sizing: border-box; padding: 0 10px; border-radius: 8px; border: 1.5px solid {OR}; background: {NODE}; color: {INK}; font: 400 13.5px {SANS}; letter-spacing: 0">'
             f'<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="{MUT}" stroke-width="1.6" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4"></path></svg>щит<span style="display: inline-block; width: 1.5px; height: 16px; background: {OR}"></span>'
             f'<span style="margin-left: auto; font: 400 10px {MONO}; color: {DIM}">4 найдено</span>{drop}</span>')
html = html.replace(old_field, new_field)
open(P + 'G_Search.dc.html', 'w').write(html)
save2('G_Search.dc.html', open(P + 'G_Search.dc.html').read(), 'Поиск · раскрывается из поля в шапке')

# ======================= АНИМАЦИИ =======================
mot = [
    ('Смена раздела', '1–4, Q/E, клик по вкладке', 'старый гаснет 120 мс, новый въезжает на 12 px со стороны направления, 220 мс; подчёркивание вкладки переезжает', 'out'),
    ('Окно «Создать», окно задачи', 'Ctrl+N, клик по задаче', 'фон темнеет 180 мс; окно scale .96 → 1 + fade 220 мс; закрытие 160 мс', 'out'),
    ('Меню, выпадающие списки, выбор даты', 'клик, Alt+L', 'от кнопки: scale .96 → 1 + fade 160 мс, закрытие 100 мс', 'out'),
    ('Поиск', 'Ctrl+K, /', 'поле в шапке растёт до 400 px 180 мс, список выпадает вниз на 6 px + fade 160 мс', 'out'),
    ('Наведение на карточку, ноду', 'мышь', 'подъём на 1 px и тень 120 мс; кнопки на карточке проявляются 120 мс', 'out'),
    ('Перетаскивание карточки', 'мышь', 'захват scale 1.02 и наклон −2° 140 мс; место вставки растёт 150 мс; соседи съезжают FLIP 220 мс', 'out'),
    ('Следующий этап', '→ на карточке, Alt+→', 'канбан — карточка перелетает в колонку 260 мс; конвейер — заливка бежит по этапам 220 мс', 'out'),
    ('Выполнено', 'галочка, «Готово»', 'галочка рисуется 200 мс, зачёркивание растёт 200 мс, через 600 мс строка схлопывается 220 мс', 'pop'),
    ('Плашки «Готово · Отменить»', 'после действия', 'въезд снизу на 12 px + fade 180 мс, полоска-таймер 6 с, на наведении пауза', 'out'),
    ('Раскрытие строки конвейера', 'клик, →', 'высота 0 → авто 240 мс, три колонки по очереди с шагом 60 мс, стрелка ▸ поворачивается', 'out'),
    ('Новая задача', 'Enter в «Создать», форма в колонке', 'появляется сверху на 8 px + fade, подсветка акцентом 8 % гаснет за 1,2 с', 'out'),
    ('Числа и счётчики', 'серии, «2 / 3»', 'старое уходит вверх, новое приходит снизу, 180 мс', 'out'),
    ('Привычки', 'отметка, веха', 'квадрат заливается от центра 200 мс, число серии подпрыгивает 1 → 1.15 → 1; веха — искры у знака спутника 600 мс', 'pop'),
    ('Стикеры', 'сделано, новый, раскладка', 'кружок заливается 160 мс, через 2 с стикер летит в баночку 420 мс; новый — поворот от 0° к наклону 220 мс; смена раскладки FLIP 260 мс', 'pop'),
    ('Календарь ← →', 'стрелки, T', 'сетка уезжает на 24 px по направлению + fade 200 мс; неделя ↔ месяц — crossfade', 'out'),
    ('Граф знаний', 'колёсико', 'точки → подписи → ноды: crossfade 160 мс на каждом пороге масштаба', 'out'),
]
cv = {'out': 'cubic-bezier(.2,.8,.2,1)', 'pop': 'cubic-bezier(.3,1.4,.5,1)'}
st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("АНИМАЦИИ · ВСЕ МЕСТА", INK)}{micro("ТОЛЬКО TRANSFORM И OPACITY · УХОД БЫСТРЕЕ ПОЯВЛЕНИЯ · НЕ БЛОКИРУЮТ ВВОД", MUT)}</div>', w=1248)
tok = ''.join(f'<span style="display: flex; flex-direction: column; gap: 2px; padding: 8px 12px; border-radius: 8px; border: 1px solid {LINE}; background: {NODE}"><span style="font: 500 12px {MONO}; color: {OR}">{a}</span><span style="font-size: 12px; color: {MUT}">{b}</span></span>'
              for a, b in [('dur-1 120 мс', 'наведение, нажатие'), ('dur-2 180 мс', 'меню, чипы, плашки'), ('dur-3 260 мс', 'окна, смена экрана'), ('dur-4 420 мс', 'праздник, вехи'), ('ease-out', '(.2,.8,.2,1) появление'), ('ease-in', '(.4,0,1,1) уход'), ('ease-pop', '(.3,1.4,.5,1) галочки, числа')])
st += ab(0, 30, f'<div style="display: flex; gap: 8px; flex-wrap: wrap">{tok}</div>', w=1248)
tbl = f'<div style="display: grid; grid-template-columns: 230px 190px 1fr 90px; font-size: 12.5px">'
for hh in ['ГДЕ', 'КОГДА', 'ЧТО ДВИЖЕТСЯ', 'КРИВАЯ']:
    tbl += f'<span style="padding: 8px 12px; border-bottom: 1px solid {LINE}">{lbl(hh, MUT, 10)}</span>'
for a, b, c_, e in mot:
    tbl += f'<span style="padding: 6px 12px; border-bottom: 1px solid {SOFT}; font-weight: 600">{a}</span><span style="padding: 6px 12px; border-bottom: 1px solid {SOFT}; color: {MUT}">{b}</span><span style="padding: 6px 12px; border-bottom: 1px solid {SOFT}; color: #C9CAD0">{c_}</span><span style="padding: 6px 12px; border-bottom: 1px solid {SOFT}; font: 400 11px {MONO}; color: {OR if e == "pop" else MUT}">{e}</span>'
tbl += '</div>'
st += node(0, 96, 1248, 0, nhead('', 'КАТАЛОГ', '16 МЕСТ', OR, None, 32) + tbl)
st += ab(0, 704, f'<span style="font-size: 12.5px; color: {MUT}">Настройки → Вид → «Анимации: полные / минимум / выкл». «Минимум» и системное «уменьшить движение» — только затухания до 120 мс, без сдвигов. Рамка фокуса — всегда сразу.</span>', w=1248)
save2('G_Motion.dc.html', page('Анимации', '', st, stage_h=730), 'Анимации · каталог')
print('fix ok')

# вариант B: панель свойств справа
PI = {'Список': 'board', 'Этап': 'stage', 'Приоритет': 'priority', 'Напомнить': 'bell', 'Повтор': 'repeat', 'Цвет': 'accent', 'Картинка': 'image', 'Исполнитель': 'share', 'Календарь': 'calendar', 'Участники': 'share', 'Цель': 'done', 'Telegram': 'telegram', 'Windows': 'bell', 'До какого дня': 'calendar', 'Удалить': 'trash', 'Контакт': 'link'}
_pr = lambda k, v='', c=None: f'<div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-top: 1px solid {SOFT}; font-size: 12.5px"><span style="display: grid; color: {MUT}">{svg_(PI.get(k, "circle"), 15)}</span><span style="width: 84px; flex: none; color: {MUT}; white-space: nowrap">{k}</span>' + (f'<span style="flex: 1; min-width: 0; font-weight: 600; color: {c or INK}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{v}</span><span style="color: {MUT}">▾</span>' if v else f'<span style="flex: 1; color: #55575F">—</span>') + '</div>'
insp = f'''<div style="border-radius: 10px; border: 1px solid {LINE}; background: {BG}; overflow: hidden">
  <div style="height: 30px; display: flex; align-items: center; padding: 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">СВОЙСТВА</div>
  {_pr("Список", "● 3D-ассеты", OR)}{_pr("Этап", "Рендер")}{_pr("Приоритет", "!!! Высокий", RED)}{_pr("Напомнить", "за час")}{_pr("Повтор")}{_pr("Цвет")}{_pr("Картинка")}{_pr("Исполнитель")}
</div>'''
_sub = lambda t, done=False: f'<div style="height: 30px; display: flex; align-items: center; gap: 10px; padding: 0 10px; border-top: 1px solid {SOFT}; font-size: 13px; color: {MUT if done else INK}">{check(done) if done else check()}<span style="{"text-decoration: line-through" if done else ""}">{t}</span></div>'
main_b = f'''<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 6px">
  <div style="border-radius: 10px; border: 1px solid {LINE}; background: {BG}; overflow: hidden">
    <div style="height: 30px; display: flex; align-items: center; padding: 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">ПОДЗАДАЧИ<span style="margin-left: auto; font: 400 11px {MONO}">0 / 2</span></div>
    {_sub("Свет и камера")}{_sub("Рендер 4K")}<div style="height: 30px; display: flex; align-items: center; padding: 0 10px; border-top: 1px solid {SOFT}; font-size: 12.5px; color: {MUT}">＋ подзадача · Enter</div>
  </div>
  <div style="border-radius: 10px; border: 1px solid {LINE}; background: {BG}; display: flex; flex-direction: column">
    <div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 6px 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">ЗАМЕТКА<span style="margin-left: auto; height: 22px; padding: 0 8px; border-radius: 6px; border: 1px solid {LINE}; display: inline-flex; align-items: center; font: 400 11.5px {SANS}; letter-spacing: 0; color: #C9CAD0">↗ из Знаний</span><span title="Развернуть" style="width: 22px; height: 22px; border-radius: 6px; border: 1px solid {LINE}; display: inline-grid; place-items: center; font-size: 12px; letter-spacing: 0; color: #C9CAD0">⤢</span></div>
    <div style="flex: 1; padding: 2px 10px 10px; font-size: 12.5px; line-height: 18px; color: #55575F">Ракурс как на референсе, фон нейтральный… Markdown, ссылки на «Знания» через [[</div>
  </div>
</div>'''
_hdr = lambda t: f'<div style="font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">{t}</div>'
rows_b = (_hdr("КОГДА") + f'<div style="display: flex; gap: 6px">{_fld("@clock", "17:00", 110, True)}{_fld("@calendar", "Пт, 6 ноября", 0).replace("width: 0px", "flex: 1")}</div>'
          + f'<div style="display: flex; gap: 6px; flex-wrap: wrap">{chip_("Сегодня") + chip_("Завтра", True) + chip_("Пн") + chip_("След. неделя") + chip_("Без срока")}</div>'
          + when_land.replace("margin: 2px 0 4px 116px", "margin: 0") + main_b)
prev_node = node(1022, 150, 230, 112, f'<div style="padding: 8px 10px 6px; font: 500 9.5px {MONO}; letter-spacing: .14em; color: {MUT}">ПОЯВИТСЯ НА ДОСКЕ</div><div style="padding: 0 8px 8px">'+f'''<div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; overflow: hidden">
  <div style="height: 26px; padding: 0 10px; background: {FILL[OR]}; display: flex; align-items: center; justify-content: space-between; font: 500 10px {MONO}; letter-spacing: .14em; color: #FFFFFF">3D-АССЕТЫ<span style="color: rgba(255,255,255,.72)">РЕНДЕР</span></div>
  <div style="padding: 10px; display: flex; gap: 10px; align-items: center">{art("shield", OR, 32, 32, 6)}<span style="flex: 1"><span style="display: block; font-weight: 600; font-size: 13px">Рендер щита</span><span style="font-size: 11.5px; color: {MUT}">Завтра 17:00 · !!! · 0 / 2</span></span></div>
</div>
'''+'</div>', style=SH)
st = K + cwin(0, f'Рендер щита {mark("завтра в 17:00", OR)} {mark("!!!", RED)}', rows_b, insp, 'Добавить задачу', x=150, h=620) + svg(wire(990, 190, 1022, 190, OR, 1.5, k=12) + f'<circle cx="990" cy="190" r="3.5" fill="{OR}"></circle><circle cx="1022" cy="190" r="3.5" fill="{OR}"></circle>') + prev_node
stB = st
save('G_CreateB.dc.html', page('Создать', 'ДОСКА', st), 'Создать · вариант B: панель свойств справа', 2720, 0, 'task')

# ==== все окна «Создать» по схеме варианта B ====
def chipc(t, c, on=False):
    st_ = f"background: {c}29; border: 1px solid {c}; color: {INK}; font-weight: 600" if on else f"border: 1px solid {LINE}; color: #C9CAD0"
    return f'<span style="height: 28px; padding: 0 11px; border-radius: 7px; display: inline-flex; align-items: center; font-size: 12.5px; {st_}">{t}</span>'
chips = lambda c, items, on: f'<div style="display: flex; gap: 6px; flex-wrap: wrap">{"".join(chipc(t, c, t in on) for t in items)}</div>'
fflex = lambda ic, t: _fld(ic, t, 0).replace("width: 0px", "flex: 1")
frow2 = lambda *a: f'<div style="display: flex; gap: 6px">{"".join(a)}</div>'


def notebox(ph, h=96):
    return (f'<div style="border-radius: 10px; border: 1px solid {LINE}; background: {BG}; min-height: {h}px; display: flex; flex-direction: column">'
            f'<div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 6px 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">ЗАМЕТКА'
            f'<span style="margin-left: auto; height: 22px; padding: 0 8px; border-radius: 6px; border: 1px solid {LINE}; display: inline-flex; align-items: center; font: 400 11.5px {SANS}; letter-spacing: 0; color: #C9CAD0">↗ из Знаний</span>'
            f'<span style="width: 22px; height: 22px; border-radius: 6px; border: 1px solid {LINE}; display: inline-grid; place-items: center; font-size: 12px; letter-spacing: 0; color: #C9CAD0">⤢</span></div>'
            f'<div style="flex: 1; padding: 2px 10px 10px; font-size: 12.5px; line-height: 18px; color: #55575F">{ph}</div></div>')


def props(rows):
    return (f'<div style="border-radius: 10px; border: 1px solid {LINE}; background: {BG}; overflow: hidden"><div style="height: 30px; display: flex; align-items: center; padding: 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">СВОЙСТВА</div>'
            + ''.join(_pr(*r) for r in rows) + '</div>')


def bwin(k, line, left, right, preview, label, primary, h, wire_y=190, ph=112, **kw):
    c = KINDS[k][1]
    pn = node(1022, 150, 230, ph, f'<div style="padding: 8px 10px 6px; font: 500 9.5px {MONO}; letter-spacing: .14em; color: {MUT}">{label}</div><div style="padding: 0 8px 8px">{preview}</div>', style=SH)
    return (cwin(k, line, left, right, primary, x=150, h=h, **kw)
            + svg(wire(990, wire_y, 1022, wire_y, c, 1.5, k=12) + f'<circle cx="990" cy="{wire_y}" r="3.5" fill="{c}"></circle><circle cx="1022" cy="{wire_y}" r="3.5" fill="{c}"></circle>') + pn)


# событие
ev_left = (_hdr("КОГДА") + frow2(_fld("@clock", "15:00", 110, True), fflex("@calendar", "Пт, 6 ноября"))
           + chips(BLUE, ["Сегодня", "Завтра", "Пн", "След. неделя"], ["Завтра"])
           + _hdr("ДЛИТСЯ") + chips(BLUE, ["30 мин", "1 час", "2 часа", "Весь день"], ["1 час"])
           + f'<div style="display: flex; align-items: center; gap: 8px; font-size: 12.5px; color: {GREEN}">{dot(GREEN, 6)}Свободно до 17:00 · в календаре 15:00–16:00</div>'
           + _hdr("МЕСТО") + f'<span style="height: 34px; box-sizing: border-box; border-radius: 8px; border: 1px solid {STRONG}; display: flex; align-items: center; padding: 0 12px; color: {MUT}">Адрес или ссылка на созвон</span>'
           + notebox("Повестка, ссылки… Markdown, «Знания» через [[", 88))
ev_right = props([("Календарь", "● Основной", BLUE), ("Напомнить", "за 15 мин"), ("Повтор",), ("Участники",), ("Цвет",)])
ev_prev = ev_r.split('</span>', 1)[1]
st = W + bwin(1, f'Встреча с заказчиком {mark("в пятницу 15:00", BLUE)} {mark("час", BLUE)}', ev_left, ev_right, ev_prev, 'ПОЯВИТСЯ В КАЛЕНДАРЕ', 'Добавить событие', 620, ph=232)
save('G_CreateEvent.dc.html', page('Создать · событие', 'КАЛЕНДАРЬ', st), 'Создать · событие', 1360, 1120, 'task')

# привычка
def hab_left():
    return (_hdr("ЗНАЧОК") + f'<div style="display: flex; gap: 6px">{icons}</div>'
            + _hdr("КАК ЧАСТО") + chips(GOLD, ["Каждый день", "По будням", "Свои дни", "N раз в неделю"], ["Каждый день"])
            + _hdr("КОГДА") + frow2(_fld("@clock", "07:00", 104, True), f'<span style="align-self: center; color: {MUT}">до</span>', _fld("@clock", "09:00", 104, True))
            + chips(GOLD, ["Утро", "День", "Вечер", "Любое"], ["Утро"])
            + notebox("Зачем и как… Markdown, «Знания» через [[", 80))
hab_right = lambda edit: props([("Цель", "Сделать"), ("Telegram", "в 07:00"), ("Windows", "в окне"), ("До какого дня",), ("Цвет",)] + ([("Удалить", "…", RED)] if edit else []))
hcard = hprev.split('</span>', 1)[1]
st = dim(s_b4.HM, .2) + bwin(2, f'Зарядка {mark("каждый день", GOLD)} {mark("утром", GOLD)}', hab_left(), hab_right(False), hcard, 'ПОЯВИТСЯ В «ПРИВЫЧКАХ»', 'Добавить привычку', 620, ph=150)
save('G_CreateHabit.dc.html', page('Создать · привычка', 'ПРИВЫЧКИ', st), 'Создать · привычка', 2720, 1120, 'task')
st = dim(s_b4.HM, .2) + bwin(2, 'Зарядка', hab_left(), hab_right(True), hcard, 'КАРТОЧКА ПРИВЫЧКИ', 'Сохранить', 620, ph=150, mode='locked', title='Привычка · Зарядка',
                             foot_left='Ctrl+Enter — сохранить · Esc — закрыть', ctx='То же окно «Создать», открыто из карточки привычки: поля заполнены, серия 21 день не сбросится.')
c_ = json.load(open(P + 'canvas.json')); hb = c_['boards'].get('G_HabitEdit.dc.html', {})
save('G_HabitEdit.dc.html', page('Окно привычки', 'ПРИВЫЧКИ', st), 'Привычка · правка в том же окне «Создать»', hb.get('x', 0), hb.get('y', 0), hb.get('page', 'habits'))

# день рождения
bd_left = (_hdr("КОГДА") + frow2(fflex("@calendar", "12 ноября"), _fld("", "1994", 110, True).replace('<span style="color: #8A8C94"></span>', ''))
           + f'<div style="font-size: 12px; color: {MUT}">Повторяется каждый год · год можно не указывать, он нужен, чтобы показать возраст («исполнится 32»)</div>'
           + _hdr("ПОДАРОК, НАПОМНИТЬ ЗАРАНЕЕ") + chips(VIO, ["Не надо", "За неделю", "За 2 недели", "За месяц"], ["За неделю"])
           + notebox("Идеи подарков, размеры, что любит… Markdown, «Знания» через [[", 120))
bd_right = props([("Календарь", "● Основной", VIO), ("Напомнить", "в день, за день"), ("Контакт",), ("Цвет",)])
bcard = bd_r.split('</span>', 1)[1]
st = K + bwin(3, f'Оля {mark("12 ноября", VIO)} {mark("1994", VIO)}', bd_left, bd_right, bcard, 'ПОЯВИТСЯ В КАЛЕНДАРЕ', 'Добавить день рождения', 620, ph=112)
save('G_CreateBday.dc.html', page('Создать · день рождения', 'КАЛЕНДАРЬ', st), 'Создать · день рождения', 4080, 1120, 'task')


# ==== выпадашки времени и даты — у своих полей ====
def _tpop():
    cell = lambda t, on=False, mono=True: f'<span style="height: 28px; border-radius: 6px; display: grid; place-items: center; font: {"600" if on else "400"} 12.5px {MONO if mono else SANS}; {"background: "+OR+"; color: #1B1206" if on else "color: #C9CAD0"}">{t}</span>'
    hours = ''.join(cell(f"{h:02d}", h == 17) for h in range(24))
    mins = ''.join(cell(m, m == "00") for m in ["00", "15", "30", "45"])
    quick = ''.join(f'<span style="height: 26px; padding: 0 9px; border-radius: 6px; border: 1px solid {LINE}; display: inline-flex; align-items: center; font-size: 12px; color: #C9CAD0">{t}</span>' for t in ["Через час", "Утром 9:00", "Вечером 19:00", "Без времени"])
    return (f'<div style="position: absolute; left: 174px; top: 206px; width: 300px; padding: 10px; box-sizing: border-box; border-radius: 10px; background: {NODE}; border: 1px solid {STRONG}; box-shadow: 0 18px 40px rgba(0,0,0,.5)">'
            f'<div style="height: 32px; border-radius: 7px; border: 1px solid {OR}; display: flex; align-items: center; padding: 0 10px; font: 400 14px {MONO}">17:00<span style="margin-left: auto; font: 400 11px {SANS}; color: {MUT}">«1730», «5pm» · Enter</span></div>'
            f'<div style="display: flex; gap: 4px; flex-wrap: wrap; margin: 8px 0">{quick}</div>'
            f'<div style="display: grid; grid-template-columns: 1fr 52px; gap: 10px; padding-top: 8px; border-top: 1px solid {LINE}">'
            f'<div><div style="font: 500 9.5px {MONO}; letter-spacing: .12em; color: {MUT}; margin-bottom: 4px">ЧАС</div><div style="display: grid; grid-template-columns: repeat(6, 1fr); gap: 3px">{hours}</div></div>'
            f'<div><div style="font: 500 9.5px {MONO}; letter-spacing: .12em; color: {MUT}; margin-bottom: 4px">МИН</div><div style="display: grid; gap: 3px">{mins}</div></div></div>'
            f'<div style="font-size: 11px; color: {MUT}; margin-top: 8px">Колесо над полем времени — ±15 мин без открытия</div></div>')
def _dpop():
    days = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
    head = ''.join(f'<span style="font: 500 9.5px {MONO}; color: {MUT}; text-align: center">{d}</span>' for d in days)
    cells = ''
    for i in range(36):
        n = i - 5
        if n < 1 or n > 30: cells += '<span></span>'; continue
        on, today = n == 6, n == 5
        st_ = f"background: {OR}; color: #1B1206; font-weight: 600" if on else (f"border: 1px solid {OR}; color: {INK}" if today else "color: #C9CAD0")
        cells += f'<span style="height: 30px; border-radius: 7px; display: grid; place-items: center; font-size: 12.5px; {st_}">{n}</span>'
    quick = ''.join(f'<span style="height: 26px; padding: 0 9px; border-radius: 6px; border: 1px solid {LINE}; display: inline-flex; align-items: center; font-size: 12px; color: #C9CAD0">{t}</span>' for t in ["Сегодня", "Завтра", "Пн", "+1 нед"])
    return (f'<div style="position: absolute; left: 290px; top: 206px; width: 268px; padding: 10px; box-sizing: border-box; border-radius: 10px; background: {NODE}; border: 1px solid {STRONG}; box-shadow: 0 18px 40px rgba(0,0,0,.5)">'
            f'<div style="display: flex; align-items: center; margin-bottom: 8px"><span style="color: {MUT}">‹</span><span style="flex: 1; text-align: center; font-weight: 600; font-size: 13px">Ноябрь 2026</span><span style="color: {MUT}">›</span></div>'
            f'<div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 3px">{head}{cells}</div>'
            f'<div style="display: flex; gap: 4px; flex-wrap: wrap; margin-top: 8px; padding-top: 8px; border-top: 1px solid {LINE}">{quick}</div></div>')
save('G_CreateTime.dc.html', page('Создать · время', 'ДОСКА', stB + _tpop()), 'Создать · выбор времени у поля', 0, 2240, 'task')
save('G_CreateDate.dc.html', page('Создать · дата', 'ДОСКА', stB + _dpop()), 'Создать · выбор даты у поля', 1360, 2240, 'task')
