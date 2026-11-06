import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

def sidebar(active, tip='В «В работе» уже 2 из 3. Закончи одну до новой.'):
    groups = [('3D И ЗАКАЗЫ', OR, [('3D-ассеты', 'К', 7), ('Иконки для клиента', 'К', 4), ('Заказы клиентов', 'К', 3)]),
              ('РАБОТА', BLUE, [('Работа · клиенты', 'К', 9)]),
              ('ДОМ', GREEN, [('Дела по дому', 'С', 11), ('Покупки', 'Л', 5)]),
              ('УЧЁБА', VIO, [('Учёба', 'Л', 4)])]
    h = f'<div style="margin: 10px 10px 4px; height: 30px; border-radius: 8px; border: 1px solid {STRONG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}; font-size: 12.5px">Список…<span style="margin-left: auto; font: 400 9.5px {MONO}; color: {DIM}">CTRL ⇧ L</span></div>'
    for name, c, lists in groups:
        h += f'<div style="padding: 10px 12px 4px; display: flex; align-items: center; gap: 8px">{dot(c)}{lbl(name, MUT, 10)}</div>'
        for t, v, n in lists:
            on = t == active
            st = f'background: {WASH}; border: 1px solid {OR}' if on else 'border: 1px solid transparent'
            h += f'<div style="margin: 0 8px; height: 30px; box-sizing: border-box; border-radius: 6px; {st}; display: flex; align-items: center; gap: 8px; padding: 0 8px"><span style="width: 16px; height: 16px; border-radius: 4px; border: 1px solid {LINE}; display: grid; place-items: center; font: 500 9px {MONO}; color: {MUT}">{v}</span><span style="flex: 1; {"color: " + INK if on else "color: #C9CAD0"}">{t}</span><span style="font: 400 10.5px {MONO}; color: {DIM}">{n}</span></div>'
    h += f'<div style="position: absolute; left: 10px; right: 10px; bottom: 52px; padding: 10px; border-radius: 8px; border: 1px dashed #55575F; display: flex; gap: 10px; align-items: center">{coon(36)}<span style="font-size: 12px; color: #C9CAD0">{tip}</span></div>'
    h += f'<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 40px; border-top: 1px solid {LINE}; display: flex; align-items: center; justify-content: space-around">{lbl("ШАБЛОНЫ", MUT, 10)}{lbl("АРХИВ", MUT, 10)}{lbl("ПОКАЗЫВАТЬ", MUT, 10)}</div>'
    return node(0, 0, 220, 700, nhead('', 'СФЕРЫ', '4', None) + h)

def titlebar(name, color, view, extra=''):
    inner = f'''<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{dot(color, 8)}<span style="font-weight: 600; font-size: 15px">{name}</span><span style="color: {DIM}; font-size: 16px">⋯</span>{extra}<span style="flex: 1"></span>{seg(["КАНБАН", "КОНВЕЙЕР", "СТИКЕРЫ"], view)}</div>'''
    return node(236, 0, 1012, 48, inner)

def card(t, meta, prio='', bar=None, now=False, done=False, client=''):
    st = hatch() + f'; border: 1px solid {OR}' if now else f'background: {HOVER}; border: 1px solid {LINE}'
    tt = f'text-decoration: line-through; color: {DIM}' if done else ''
    p = f'<span style="font: 600 11px {MONO}; color: {OR if prio == "!!!" else MUT}">{prio}</span>' if prio else ''
    cl = f'<span style="font: 400 10px {MONO}; letter-spacing: .08em; color: {BLUE}">{client}</span>' if client else ''
    b = f'<div style="margin-top: 8px">{stages(*bar)}</div>' if bar else ''
    return f'<div style="border-radius: 8px; {st}; padding: 10px 10px 9px"><div style="display: flex; gap: 8px; align-items: flex-start"><span style="flex: 1; {tt}">{t}</span>{p}</div><div style="display: flex; gap: 10px; align-items: center; margin-top: 6px">{micro(meta, ORI if now else MUT)}{cl}<span style="flex: 1"></span><span style="color: {DIM}">→</span></div>{b}</div>'

# ---------------- KANBAN ----------------
cols = [('ВХОДЯЩИЕ', '4', GREY, [card('Счёт за октябрь', 'ДО ПТ 06', '!!!', client='ТАВЕРНА'), card('Бриф: броня для «Кузни»', 'ПН 09', '!!', client='КУЗНЯ'), card('Правки иконок v2', 'БЕЗ СРОКА', '!'), card('Ответить про сроки', 'СЕГОДНЯ', '', client='ТАВЕРНА')]),
        ('В РАБОТЕ', '2 / 3', OR, [card('Созвон с клиентом «Таверна»', 'СЕГОДНЯ 12:30', '!!', now=True, client='ТАВЕРНА'), card('Смета на логотип', 'СР 11', '!', bar=(1, 1, 3))]),
        ('НА ПРОВЕРКЕ', '1', VIO, [card('Презентация концептов', 'ЖДЁТ ОТВЕТА', '', client='КУЗНЯ', bar=(3, 9, 3))]),
        ('ГОТОВО', '6', GREEN, [card('Иконки v1', 'ВЧЕРА', done=True), card('Договор', 'ПН 02', done=True)])]
st = sidebar('Работа · клиенты') + titlebar('Работа · клиенты', BLUE, 'КАНБАН', micro('ПО ШАБЛОНУ «РАБОТА»', DIM))
CWk = 232; gap = 28; x0 = 236
paths = ''
for i, (n, cnt, c, cards) in enumerate(cols):
    x = x0 + i * (CWk + gap)
    body = f'<div style="padding: 10px; display: flex; flex-direction: column; gap: 8px">{"".join(cards)}'
    if n == 'ВХОДЯЩИЕ':
        body += f'<div style="height: 34px; border-radius: 8px; border: 1px dashed {STRONG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}">＋ Добавить задачу<span style="margin-left: auto; font: 400 9.5px {MONO}; color: {DIM}">N</span></div>'
    if n == 'В РАБОТЕ':
        body += f'<div style="padding: 8px 10px; border-radius: 8px; border: 1px solid #6A5238; font-size: 12px; color: {ORI}">Лимит 3. Можно взять ещё одну.</div>'
    if n == 'ГОТОВО':
        body += f'<div style="text-align: center; padding: 4px">{micro("＋ ЕЩЁ 4 · СВЕРНУТО", MUT)}</div>'
    if n == 'НА ПРОВЕРКЕ':
        body += f'<div style="margin-top: 20px; display: flex; flex-direction: column; align-items: center; gap: 6px; opacity: .8">{coon(40, "ВЫГЛ.")}{micro("ТУТ ПОКА ПУСТОВАТО")}</div>'
    body += '</div>'
    kc = OR if n == 'В РАБОТЕ' else MUT
    ex = ''
    if i < 3: ex += sock('r', 10, c)
    if i > 0: ex += sock('l', 10, cols[i - 1][2])
    st += node(x, 64, CWk, 616 if n != 'ГОТОВО' else 0, nhead(f'0{i + 1}', n, cnt, c, kc) + body, hub=(n == 'В РАБОТЕ'), extra=ex, style='' if n != 'ГОТОВО' else '')
    if i < 3:
        paths += wire(x + CWk + 1, 79, x + CWk + gap - 1, 79, cols[i][2], 1.5, k=10)
st = svg(paths) + st
st += dimline(236, 690 - 6, 1012, 'ВХОДЯЩИЕ → В РАБОТЕ → НА ПРОВЕРКЕ → ГОТОВО · СТРЕЛКА НА КАРТОЧКЕ — СЛЕДУЮЩИЙ ЭТАП')
KANBAN = st
save('G_Kanban.dc.html', page('Доска · канбан', 'ДОСКА', st), 'Доска · канбан', 1360, 940, 'r4')

# ---------------- CONVEYOR ----------------
STN = ['МОДЕЛЬ', 'РЕТОПО', 'UV', 'ПОКРАСКА', 'РЕНДЕР', 'СДАЧА']
SX0 = 560 - 236; SW = 92   # stage x inside row (relative to row left)
def track(done, cur, wait=None):
    h = ''; xs = [SX0 + i * SW for i in range(6)]
    for i in range(5):
        c = GREEN if i < done else ('#45464D')
        h += f'<span style="position: absolute; left: {xs[i] + 10}px; top: 37px; width: {SW - 10}px; height: 2px; background: {c}"></span>'
    for i, x in enumerate(xs):
        if i < done: s = f'background: {GREEN}; border: 1.5px solid {GREEN}'; m = '✓'
        elif i == cur: s = f'background: {OR}; border: 1.5px solid {OR}'; m = ''
        else: s = f'background: {NODE}; border: 1.5px solid {STRONG}'; m = ''
        h += f'<span style="position: absolute; left: {x}px; top: 32px; width: 12px; height: 12px; border-radius: 3px; box-sizing: border-box; {s}; font-size: 8px; color: {DARK}; display: grid; place-items: center">{m}</span>'
    return h
rows = [('Щит «Таверны»', 'ТАВЕРНА', 3, 3, 'ПТ 06', True), ('Меч героя', 'ТАВЕРНА', 4, 4, 'ВТ 10', False), ('Шлем рыцаря', 'КУЗНЯ', 1, 1, '19.11', False),
        ('Сундук', 'КУЗНЯ', 0, 0, '25.11', False), ('Факел', 'ЛИЧНОЕ', 5, 5, 'ГОТОВ К СДАЧЕ', False)]
st = sidebar('3D-ассеты', 'Меч ждёт рендера 4 дня. Поставить рендер на вечер?') + titlebar('3D-ассеты', OR, 'КОНВЕЙЕР', micro('7 АССЕТОВ · 2 ПРОЕКТА', DIM))
# stage header
hdr = ''.join(f'<span style="position: absolute; left: {236 + SX0 + i * SW - 20}px; width: 52px; text-align: center; top: 62px">{micro(n, OR if n == "ПОКРАСКА" else DIM)}</span>' for i, n in enumerate(STN))
st += hdr + colhead(236, 64, 300, 'ПРОЕКТ · ТАВЕРНА')
y = 86
for t, pr, done, cur, due, exp in rows:
    if pr == 'КУЗНЯ' and t == 'Шлем рыцаря':
        st += colhead(236, y + 6, 300, 'ПРОЕКТ · КУЗНЯ'); y += 26
    if pr == 'ЛИЧНОЕ':
        st += colhead(236, y + 6, 300, 'БЕЗ ПРОЕКТА'); y += 26
    h = 214 if exp else 70
    thumb = f'<span style="position: absolute; left: 12px; top: 12px; width: 52px; height: 52px; border-radius: 6px; border: 1px solid #3F352B; background-color: #2B2520; background-image: linear-gradient(rgba(240,160,75,.1) 1px, transparent 1px), linear-gradient(90deg, rgba(240,160,75,.1) 1px, transparent 1px); background-size: 8px 8px; display: grid; place-items: center; font: 500 13px {MONO}; color: {ORI}">{t[0]}</span>'
    info = f'<span style="position: absolute; left: 78px; top: 16px; font-weight: 600; font-size: 14px">{t}</span><span style="position: absolute; left: 78px; top: 40px">{micro(pr + " · " + (STN[cur] if cur < 6 else "") + (" · 2 ДН В ЭТАПЕ" if exp else ""), MUT)}</span>'
    right = f'<span style="position: absolute; right: 16px; top: 20px; text-align: right">{lbl(due, OR if exp else MUT)}</span><span style="position: absolute; right: 16px; top: 42px">{micro("ЭТАП →", DIM)}</span>'
    body = thumb + info + track(done, cur) + right
    if exp:
        sub = ''.join(f'<div style="display: flex; gap: 10px; align-items: center; height: 26px">{check(d)}<span style="{"text-decoration: line-through; color: " + DIM if d else ""}">{x}</span></div>' for x, d in [('Базовые цвета', True), ('Потёртости и сколы', False), ('Металл на окантовке', False), ('Запечь AO', False)])
        body += f'''<div style="position: absolute; left: 78px; top: 76px; width: 340px">{lbl("ПОКРАСКА · ЧЕК-ЛИСТ 1 / 4", OR)}<div style="margin-top: 6px">{sub}</div></div>
  <div style="position: absolute; left: 470px; top: 80px; width: 220px; height: 100px; border-radius: 6px; border: 1px solid #3F352B; background-color: #2B2520; background-image: linear-gradient(rgba(240,160,75,.08) 1px, transparent 1px), linear-gradient(90deg, rgba(240,160,75,.08) 1px, transparent 1px); background-size: 14px 14px; display: grid; place-items: center">{micro("ПРЕВЬЮ · 2048 × 2048", MUT)}</div>
  <div style="position: absolute; left: 720px; top: 84px; display: flex; flex-direction: column; gap: 8px; width: 250px">{btn("Этап → Рендер", "acc", True)}{btn("▶ Засечь время", sm=True)}<span style="font-size: 12px; color: {MUT}">Сдача клиенту в пятницу. До рендера осталось 2 дня.</span></div>'''
    st += node(236, y, 1012, h, body, hub=exp)
    y += h + 10
st += dimline(236 + SX0 - 20, y + 4, SW * 5 + 52, 'МОДЕЛЬ → СДАЧА · 6 ЭТАПОВ ИЗ ШАБЛОНА «3D-АССЕТЫ»')
save('G_Conveyor.dc.html', page('Доска · конвейер', 'ДОСКА', st), 'Доска · конвейер', 0, 1880, 'r4')

# ---------------- STICKERS ----------------
def stk(t, when, pin=False, done=False, now=False):
    st_ = hatch() + f'; border: 1px solid {OR}' if now else f'background: {NODE}; border: 1px solid {LINE}'
    pinh = micro('⦿ ЗАКРЕП', OR) if pin else ''
    tt = f'text-decoration: line-through; color: {DIM}' if done else ''
    return f'<div style="border-radius: 8px; {st_}; padding: 10px 12px; display: flex; flex-direction: column; gap: 8px; min-height: 64px; box-sizing: border-box"><div style="display: flex; gap: 10px; align-items: flex-start"><span style="width: 16px; height: 16px; flex: none; border-radius: 50%; box-sizing: border-box; border: 1.5px solid {GREEN if not done else GREEN}; {"background:" + GREEN if done else ""}"></span><span style="flex: 1; {tt}">{t}</span></div><div style="display: flex; gap: 10px">{micro(when, ORI if now else MUT)}{pinh}</div></div>'
lanes = [('ПОКУПКИ', OR, [stk('Купить корм коту', 'СЕГОДНЯ', now=True), stk('Лампочки E27 × 3', 'ДО СБ'), stk('Губки и средство для посуды', 'БЕЗ СРОКА')]),
         ('ДОМ', GREEN, [stk('Вызвать мастера на кран', 'ПТ 06', pin=True), stk('Повесить полку', 'ВЫХОДНЫЕ'), stk('Разобрать балкон', 'БЕЗ СРОКА')]),
         ('КОТ', GOLD, [stk('Прививка · ветклиника', '12.11 · 18:00'), stk('Подстричь когти', 'КАЖДЫЕ 2 НЕД')]),
         ('ДОКУМЕНТЫ', BLUE, [stk('Квитанция за свет', 'ДО 10.11', pin=True), stk('Продлить ОСАГО', '28.11')])]
st = sidebar('Дела по дому', 'Сделанное уходит в баночку сразу.') + titlebar('Дела по дому', GREEN, 'СТИКЕРЫ', seg(['ПО ТЕМАМ', 'ПО СРОКАМ'], 'ПО ТЕМАМ'))
LW = 212; LG = 14
for i, (n, c, ss) in enumerate(lanes):
    x = 236 + i * (LW + LG)
    st += ab(x, 64, f'<div style="display: flex; align-items: center; gap: 8px">{dot(c)}{lbl(n, INK)}{micro(str(len(ss)), DIM)}<span style="flex: 1; height: 1px; background: {LINE}"></span></div><div style="margin-top: 12px; display: flex; flex-direction: column; gap: 10px">{"".join(ss)}<div style="height: 40px; border-radius: 8px; border: 1px dashed {STRONG}; display: flex; align-items: center; padding: 0 12px; color: {MUT}">＋ Стикер</div></div>', w=LW)
st += ab(236 + 4 * (LW + LG) - 4, 64, f'<div style="height: 120px; border-radius: 8px; border: 1px dashed #55575F; display: grid; place-items: center; color: {MUT}; font: 500 10px {MONO}; letter-spacing: .14em">＋ ТЕМА</div>', w=1248 - (236 + 4 * (LW + LG) - 4))
jar = ''.join(f'<span style="flex: 1; height: {h}px; border-radius: 2px; background: {GREEN if h > 14 else "#45464D"}"></span>' for h in [12, 22, 30, 18, 26, 34, 10])
st += node(236, 540, 380, 120, nhead('', 'БАНОЧКА · СДЕЛАНО', '12 ЗА НЕДЕЛЮ', GREEN, GREEN) + f'<div style="padding: 12px; display: flex; gap: 14px; align-items: flex-end"><span style="display: flex; gap: 4px; align-items: flex-end; height: 40px; width: 160px">{jar}</span><span style="font-size: 12.5px; color: #C9CAD0">Последнее: «Вынести коробки» · вчера. <a href="#">Открыть баночку</a></span></div><div style="padding: 0 12px">{micro("ПН ВТ СР ЧТ ПТ СБ ВС", DIM)}</div>')
st += node(632, 540, 380, 120, f'<div style="padding: 14px; display: flex; gap: 12px; align-items: center">{coon(50)}<span style="font-size: 12.5px; color: #C9CAD0">Два закреплённых стикера висят больше недели. Сделаем «Вызвать мастера» в пятницу? <a href="#">Поставить на ПТ</a></span></div>', wait=True)
st += stamp(1028, 620, 'ДОСКА · СТИКЕРЫ', 'ТЕМ 04', 'ДЕЛ 10', w=220)
save('G_Stickers.dc.html', page('Доска · стикеры', 'ДОСКА', st), 'Доска · стикеры', 1360, 1880, 'r4')
print('ok')
