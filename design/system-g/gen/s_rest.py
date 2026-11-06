import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board
DIMK = f'<div style="position: absolute; inset: 0; opacity: .28; pointer-events: none">{s_board.KANBAN}</div>'

def prow(label, inner, top=False):
    return f'<div style="display: grid; grid-template-columns: 96px minmax(0, 1fr); gap: 10px; align-items: center; min-height: 30px">{lbl(label, MUT, 10)}<div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center">{inner}</div></div>'

# ---------------- HABITS ----------------
habs = [('Зарядка', 'З', GOLD, 'КАЖДЫЙ ДЕНЬ · УТРО', '21', 'ДН ПОДРЯД', 'ddddddd', '→ 50 · ЧЕРЕЗ 29 ДН', True, True),
        ('Вода', 'В', BLUE, '8 СТАКАНОВ', '12', 'ДН ПОДРЯД', 'ddddddp', '5 / 8 СЕГОДНЯ', False, False),
        ('Скетч 15 минут', 'С', OR, '3 В НЕД · ВЕЧЕР', '3', 'НЕД ПОДРЯД', 'dodoodf', '1 / 3 НА НЕДЕЛЕ', False, False),
        ('Английский', 'А', VIO, 'ПО БУДНЯМ', '7', 'ДН ПОДРЯД', 'ddddkkd', '→ 21 · ЧЕРЕЗ 14 ДН', True, False),
        ('Без сладкого', 'Б', GREEN, 'КАЖДЫЙ ДЕНЬ', '0', 'СЕРИЯ НА ПАУЗЕ', 'ddmdddf', 'ВЧЕРА ПРОПУСК', False, False),
        ('Прогулка', 'П', GREY, 'КАЖДЫЙ ДЕНЬ · ДЕНЬ', '4', 'ДН ПОДРЯД', 'oddddof', 'ОКНО 12:00—14:00', False, False)]
def hcard(x, y, w, h, d, sel=False):
    n, ic, c, kind, num, unit, l7, foot, done_today, _ = d
    sq = ''
    for ch, dl in zip(l7[3:] + 'xxx', ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС']):
        stl = {'x': f'border: 1px dashed #3A3B42; opacity: .6', 'd': f'background: {c}', 'p': f'background: linear-gradient(0deg, {c} 60%, transparent 60%); border: 1px solid {c}', 'm': f'border: 1px solid {RED}', 'o': f'border: 1px solid #45464D', 'k': f'border: 1px dashed {DIM}', 'f': f'border: 1.5px solid {OR}'}[ch]
        sq += f'<span style="display: flex; flex-direction: column; align-items: center; gap: 4px"><span style="width: 22px; height: 22px; border-radius: 5px; box-sizing: border-box; {stl}"></span>{micro(dl, OR if dl == "ЧТ" else DIM)}</span>'
    numc = DIM if num == '0' else INK
    btnh = (f'<button type="button" style="height: 30px; padding: 0 12px; border-radius: 999px; border: 0; background: {c}; color: {DARK}; font: 600 12px {SANS}">✓ Сделано</button>' if done_today
            else f'<button type="button" style="height: 30px; padding: 0 12px; border-radius: 999px; border: 1px solid {c}; background: transparent; color: {INK}; font: 500 12px {SANS}">{"＋1" if n == "Вода" else "Отметить"}</button>')
    inner = (f'<div style="height: 34px; box-sizing: border-box; padding: 0 12px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 8px"><span style="width: 20px; height: 20px; border-radius: 5px; background: {c}; color: {DARK}; display: grid; place-items: center; font: 600 11px {MONO}">{ic}</span><span style="font-weight: 600; white-space: nowrap">{n}</span><span style="margin-left: auto; white-space: nowrap">{micro(kind, DIM)}</span></div>'
             f'<div style="padding: 12px 14px 0; display: flex; align-items: flex-end; gap: 10px"><span style="font: 200 54px/48px {SANS}; letter-spacing: -.03em; color: {numc}">{num}</span><span style="padding-bottom: 6px">{micro(unit, MUT)}</span></div>'
             f'<div style="padding: 12px 14px 0; display: flex; justify-content: space-between">{sq}</div>'
             f'<div style="position: absolute; left: 14px; right: 14px; bottom: 12px; display: flex; align-items: center; justify-content: space-between">{micro(foot, GOLD if "→" in foot else MUT)}{btnh}</div>')
    return node(x, y, w, h, inner, hub=sel, extra='')
top = f'''<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px; flex-wrap: wrap">{coon(30, "ФЛАГ")}{lbl("ПРИВЫЧКИ", INK)}{micro("6 ПРИВЫЧЕК · СЕГОДНЯ 1 / 5", MUT)}
  <span style="width: 1px; height: 20px; background: {LINE}"></span>{chip("ВСЕ", True)}{chip("УТРО")}{chip("ДЕНЬ")}{chip("ВЕЧЕР")}<span style="flex: 1"></span>{seg(["СЕГОДНЯ", "МЕСЯЦ"], "СЕГОДНЯ")}{btn("＋ Привычка", "acc", True)}</div>'''
st = node(0, 0, 1248, 48, top)
pills = ''.join((f'<button type="button" style="height: 30px; padding: 0 12px; border-radius: 999px; border: 0; background: {d[2]}; color: {DARK}; font: 600 12px {SANS}">✓ {d[0]}</button>' if d[8] and d[0] == 'Зарядка'
                 else f'<button type="button" style="height: 30px; padding: 0 12px; border-radius: 999px; border: 1px solid {d[2]}; background: transparent; color: {INK}; font: 500 12px {SANS}">{d[0]}</button>') for d in habs if d[0] != 'Без сладкого')
st += ab(0, 64, f'<div style="display: flex; align-items: center; gap: 10px">{lbl("СЕГОДНЯ", GOLD)}{pills}<span style="flex: 1"></span>{btn("Отметить все", sm=True)}</div>', w=844)
CW3 = 270; GAP3 = 17
for i, d in enumerate(habs):
    r, c = divmod(i, 3)
    st += hcard(c * (CW3 + GAP3), 110 + r * 222, CW3, 206, d, sel=(i == 0))
# panel
ms = ''
pts = [7, 21, 50, 100]; px = [20, 110, 220, 330]
for i, (p, x) in enumerate(zip(pts, px)):
    ok = p <= 21
    ms += f'<span style="position: absolute; left: {x}px; top: 0; width: 12px; height: 12px; border-radius: 3px; box-sizing: border-box; {"background:" + GOLD if ok else "border: 1.5px solid " + STRONG}"></span><span style="position: absolute; left: {x - 6}px; top: 18px">{micro(str(p), GOLD if ok else DIM)}</span>'
msvg = f'<svg width="360" height="14" style="position: absolute; left: 0; top: 0" aria-hidden="true"><path d="M32 6 H110" stroke="{GOLD}" stroke-width="2"></path><path d="M122 6 H200" stroke="{GOLD}" stroke-width="2" stroke-dasharray="0"></path><path d="M122 6 H136" stroke="{GOLD}" stroke-width="2"></path><path d="M136 6 H220" stroke="{STRONG}" stroke-width="1.5" stroke-dasharray="4 4"></path><path d="M232 6 H330" stroke="{STRONG}" stroke-width="1.5" stroke-dasharray="4 4"></path></svg>'
cal = ''
import datetime
for k in range(35):
    dday = k - 6 + 1
    if dday < 1 or dday > 30: cal += '<span></span>'; continue
    stl = f'background: {GOLD}' if dday < 5 else (f'border: 1.5px solid {OR}' if dday == 5 else f'border: 1px solid #3A3B42')
    cal += f'<span style="height: 26px; border-radius: 5px; box-sizing: border-box; {stl}; display: grid; place-items: center; font: 400 9.5px {MONO}; color: {DARK if dday < 5 else MUT}">{dday}</span>'
pin = (nhead('', 'ЗАРЯДКА · ПАНЕЛЬ', 'КАЖДЫЙ ДЕНЬ', GOLD, MUT, 34, INK) +
       f'''<div style="padding: 14px 16px; display: flex; flex-direction: column; gap: 16px">
  <div style="display: flex; align-items: flex-end; gap: 12px"><span style="font: 200 64px/56px {SANS}; letter-spacing: -.03em">21</span><span style="padding-bottom: 8px">{micro("ДЕНЬ ПОДРЯД · ВЕХА ПРОЙДЕНА", GOLD)}</span></div>
  <div>{lbl("ВЕХИ", MUT, 10)}<div style="position: relative; height: 34px; margin-top: 8px">{msvg}{ms}</div></div>
  <div>{lbl("НОЯБРЬ", MUT, 10)}<div style="display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 4px; margin-top: 8px">{''.join(f'<span style="text-align: center">{micro(w_, DIM)}</span>' for w_ in ['ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС'])}{cal}</div></div>
  <div style="display: grid; grid-template-columns: repeat(3, 1fr); border: 1px solid {LINE}; border-radius: 8px">{"".join(f'<span style="padding: 8px 10px; {"border-right: 1px solid " + LINE if i < 2 else ""}"><span style="display: block; font: 300 20px {SANS}">{v}</span>{micro(t)}</span>' for i, (v, t) in enumerate([("34", "ЛУЧШАЯ"), ("112", "ВСЕГО"), ("86%", "ЗА МЕСЯЦ")]))}</div>
  {prow("ОКНО", f'<span style="font: 400 12px {MONO}">07:00 — 09:00</span>{micro("УТРО", DIM)}')}
  {prow("НАПОМНИТЬ", chip("TELEGRAM", True, GOLD) + chip("WINDOWS", True, GOLD))}
</div>''')
st += node(868, 110, 380, 590, pin)
st += ab(0, 562, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 560px; box-sizing: border-box">{coon(44, "УРА")}<span style="font-size: 12.5px; color: #C9CAD0">21 день зарядки подряд. Следующая веха — 50. «Без сладкого» вчера сорвалось — начнём заново сегодня?</span></div>')
st += stamp(588, 640, 'ПРИВЫЧКИ', 'ВЕХ 02', 'СЕРИЙ 05', w=256)
save('G_Habits.dc.html', page('Привычки', 'ПРИВЫЧКИ', st), 'Привычки · карточки и панель', 0, 2820, 'r4')

# ---------------- TASK PANEL ----------------
sub = ''.join(f'<div style="display: flex; gap: 10px; align-items: center; height: 30px; border-bottom: 1px solid {SOFT}">{check(d)}<span style="{"text-decoration: line-through; color: " + DIM if d else ""}">{t}</span></div>' for t, d in [('Подготовить три варианта щита', True), ('Уточнить бюджет', False), ('Договориться о сроке сдачи', False)])
tp = f'''<div style="height: 44px; box-sizing: border-box; padding: 0 12px; border-bottom: 1px solid {OR}; display: flex; align-items: center; gap: 10px">
  {lbl("КУДА", DIM, 10)}<span style="display: inline-flex; align-items: center; gap: 8px; height: 28px; padding: 0 10px; border-radius: 6px; border: 1px solid {LINE}">{dot(BLUE)}Работа · клиенты<span style="color: {DIM}">▾</span></span>
  <span style="flex: 1"></span>{btn("⋯", "ghost", True)}{btn("✕", "ghost", True)}</div>
<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 16px">
  <div style="font: 500 22px/28px {SANS}; text-wrap: balance">Созвон с клиентом «Таверна»</div>
  <div style="padding: 12px; border-radius: 8px; background: {HOVER}; display: flex; flex-direction: column; gap: 8px">
    {prow("КОЛОНКА", chip("ВХОДЯЩИЕ") + chip("В РАБОТЕ · 2/3", True) + chip("ПРОВЕРКА") + chip("ГОТОВО"))}
    {prow("ПРИОРИТЕТ", chip("!!!") + chip("!!", True) + chip("!") + chip("—"))}
    {prow("КЛИЕНТ", f'<span>Таверна «Под дубом»</span><span style="margin-left: 12px">{lbl("СУММА", DIM, 10)}</span><span style="font: 400 12px {MONO}">25 000 ₽</span>')}
    {prow("СРОК", f'<span style="display: inline-flex; align-items: center; height: 28px; padding: 0 10px; border-radius: 6px; border: 1px solid {OR}; color: {ORI}; font: 400 11.5px {MONO}">СЕГОДНЯ · 12:30—13:30</span>' + chip("ЗА 15 МИН ×", True) + chip("ЗА ЧАС ×", True) + chip("＋"))}
  </div>
  <div>{lbl("ПОДЗАДАЧИ · 1 / 3", MUT, 10)}<div style="margin-top: 6px">{sub}</div><div style="height: 30px; display: flex; align-items: center; color: {MUT}">＋ Подзадача</div></div>
  <div>{lbl("ЗАМЕТКА", MUT, 10)}<div style="margin-top: 6px; padding: 10px 12px; border-radius: 8px; border: 1px solid {STRONG}; background: {BG}; line-height: 20px; color: #C9CAD0">Показать концепты щита и меча. Спросить, нужен ли вариант без герба.</div></div>
  <div style="display: flex; gap: 14px; align-items: center">{lbl("▸ ЕЩЁ", INK, 10)}{micro("ПОВТОР · ЦВЕТ · КАРТИНКА")}</div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 40px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 8px; padding: 0 14px">{dot(GREEN)}{micro("СОХРАНЕНО В GOOGLE TASKS", MUT)}<span style="flex: 1"></span>{micro("ИЗМЕНЕНО 14:40", DIM)}</div>'''
st = DIMK
st += f'<span style="position: absolute; left: 496px; top: 107px; width: 236px; height: 80px; border-radius: 10px; border: 1.5px solid {OR}"></span>'
st += svg(wire(729, 136, 784, 141, OR, 2, k=24))
st += node(784, 0, 464, 700, tp, hub=True, extra=sock('l', 136, OR))
save('G_TaskPanel.dc.html', page('Окно задачи', 'ДОСКА', st), 'Окно задачи', 1360, 2820, 'r4')

# ---------------- CREATE ----------------
smart = (f'<span>Рендер щита </span><span style="padding: 1px 6px; border-radius: 4px; background: rgba(240,160,75,.18); color: {ORI}">завтра 17:00</span> '
         f'<span style="padding: 1px 6px; border-radius: 4px; background: rgba(240,120,95,.18); color: {RED}">!!!</span> '
         f'<span style="padding: 1px 6px; border-radius: 4px; background: rgba(240,160,75,.12); color: {OR}">@3d</span><span style="display: inline-block; width: 1.5px; height: 18px; background: {OR}; vertical-align: -3px; margin-left: 2px"></span>')
kinds = ''.join((f'<span style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; border-radius: 6px; background: {WASH}; border: 1px solid {OR}; color: {INK}">{dot(OR)}{t}<span style="color: {DIM}">ALT {i + 1}</span></span>' if i == 0
                 else f'<span style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; border-radius: 6px; border: 1px solid {LINE}; color: {MUT}">{t}<span style="color: {DIM}">ALT {i + 1}</span></span>') for i, t in enumerate(['ЗАДАЧА', 'СОБЫТИЕ', 'ПРИВЫЧКА', 'ДЕНЬ РОЖДЕНИЯ']))
cr = f'''<div style="height: 52px; box-sizing: border-box; padding: 0 14px; border-bottom: 1px solid {OR}; display: flex; align-items: center; gap: 8px; font: 500 10.5px {MONO}; letter-spacing: .12em">{kinds}<span style="flex: 1"></span>{btn("✕", "ghost", True)}</div>
<div style="padding: 16px 18px 0">
  <div style="height: 52px; box-sizing: border-box; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 14px; font-size: 17px">{smart}</div>
  <div style="display: flex; gap: 10px; align-items: center; margin-top: 10px">{lbl("ПОНЯЛ", DIM, 10)}{chip("ПТ 06 · 17:00 ×", True)}{chip("ВЫСОКИЙ ×", True, RED)}{chip("3D-АССЕТЫ ×", True)}<span style="flex: 1"></span>{micro("СЛОВАМИ: «ЗАВТРА», «В ПЯТНИЦУ 17:00», #ТИП, @СПИСОК")}</div>
</div>'''
fields = (f'<div style="padding: 12px; display: flex; flex-direction: column; gap: 8px">'
          f'{prow("ПРОЕКТ", chip("ТАВЕРНА", True) + chip("КУЗНЯ") + chip("＋"))}'
          f'{prow("ЭТАП", chip("МОДЕЛЬ") + chip("UV") + chip("ПОКРАСКА") + chip("РЕНДЕР", True) + chip("СДАЧА"))}'
          f'{prow("НАПОМНИТЬ", chip("ЗА ЧАС", True) + chip("ЗА ДЕНЬ") + chip("В МОМЕНТ"))}'
          f'{prow("ЧЕК-ЛИСТ", micro("ВЗЯТ ИЗ «МЕЧ ГЕРОЯ» · 4 ПУНКТА", MUT))}</div>')
kuda = f'<div style="padding: 12px; display: flex; flex-direction: column; gap: 6px"><span style="display: flex; align-items: center; gap: 8px; font-weight: 600">{dot(OR, 8)}3D-ассеты<span style="margin-left: auto">{btn("Сменить · ALT L", sm=True)}</span></span><span style="font-size: 12px; color: {GOLD}">✦ по «@3d» и слову «рендер»</span></div>'
prev = f'''<div style="padding: 12px"><div style="position: relative; height: 64px; border-radius: 8px; border: 1px solid {LINE}; background: {HOVER}">
  <span style="position: absolute; left: 10px; top: 10px; width: 42px; height: 42px; border-radius: 6px; border: 1px solid #3F352B; background: #2B2520; display: grid; place-items: center; font: 500 12px {MONO}; color: {ORI}">Р</span>
  <span style="position: absolute; left: 62px; top: 12px; font-weight: 600">Рендер щита</span><span style="position: absolute; left: 62px; top: 36px">{micro("ТАВЕРНА · РЕНДЕР · ПТ 17:00", MUT)}</span>
  <span style="position: absolute; right: 10px; top: 12px; font: 600 11px {MONO}; color: {OR}">!!!</span></div>
  <div style="margin-top: 10px">{stages(4, 4, 6)}</div></div>'''
cin = cr + node(18, 150, 420, 196, nhead('01', 'КУДА', 'УГАДАНО', OR, GOLD) + kuda + f'<div style="border-top: 1px solid {LINE}">{lbl("&nbsp;", DIM)}</div>', extra='') 
# fields node and preview inside modal
cin = cr
cin += node(18, 166, 400, 96, nhead('01', 'КУДА', 'УГАДАНО', OR, GOLD) + kuda, extra=sock('r', 40, OR))
cin += node(18, 276, 400, 218, nhead('02', 'ПОЛЯ КОНВЕЙЕРА', '', OR) + fields, extra=sock('r', 40, OR))
cin += node(462, 166, 380, 140, nhead('03', 'ТАК БУДЕТ', 'ПРЕВЬЮ', OR) + prev, extra=sock('l', 40, OR) + sock('l', 110, OR))
cin += node(462, 322, 380, 80, f'<div style="padding: 12px; display: flex; gap: 10px; align-items: center">{coon(40, "ДУМАЕТ")}<span style="font-size: 12.5px; color: #C9CAD0">В пятницу с 17:00 свободно. Рендер займёт около двух часов.</span></div>', wait=True)
cin = f'<svg width="860" height="560" style="position: absolute; left: 0; top: 0" aria-hidden="true" fill="none">{wire(419, 211, 461, 211, OR, 2, k=20)}{wire(419, 321, 461, 281, OR, 1.5, k=20)}</svg>' + cin
cin += f'<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 56px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 12px; padding: 0 18px">{micro("ENTER — ДОБАВИТЬ · CTRL ENTER — СОЗДАТЬ И ЕЩЁ · ESC — ЗАКРЫТЬ")}<span style="flex: 1"></span>{btn("Создать и ещё")}{btn("Добавить в 3D-ассеты", "acc")}</div>'
st = DIMK + node(194, 40, 860, 560, cin, hub=True, style='; overflow: visible')
save('G_Create.dc.html', page('Создать', 'ДОСКА', st), 'Окно «Создать»', 0, 3760, 'r4')

# ---------------- SETTINGS ----------------
tabs = ['ВИД', 'ЧТО ПОКАЗЫВАТЬ', 'НАПОМИНАНИЯ', 'СИНХРОНИЗАЦИЯ', 'ОБНОВЛЕНИЯ', 'КЛАВИШИ']
th = f'<div style="margin: 10px; height: 30px; border-radius: 8px; border: 1px solid {STRONG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}; font-size: 12.5px">Найти настройку</div>'
for i, t in enumerate(tabs):
    on = i == 0
    th += f'<div style="margin: 0 8px; height: 34px; border-radius: 6px; {"background:" + WASH + "; border: 1px solid " + OR if on else "border: 1px solid transparent"}; display: flex; align-items: center; gap: 10px; padding: 0 10px"><span style="font: 400 10px {MONO}; color: {DIM}">0{i + 1}</span>{lbl(t, INK if on else MUT, 10)}</div>'
st = node(0, 0, 240, 700, nhead('', 'НАСТРОЙКИ', 'CTRL ,', None) + th + f'<div style="position: absolute; left: 12px; bottom: 12px">{micro("СПУТНИК 0.9.0 · БЕТА", DIM)}</div>')
accs = ''.join(f'<span style="width: 30px; height: 30px; border-radius: 8px; background: {c}; {"outline: 2px solid " + ORI + "; outline-offset: 2px" if i == 0 else ""}"></span>' for i, c in enumerate([OR, '#E07A5F', '#E8C65A', '#7FD18C', '#6FA2F2', '#B48CF0']))
order = ['СЕГОДНЯ', 'КАЛЕНДАРЬ', 'ДОСКА', 'ПРИВЫЧКИ']
oh = ''
for i, t in enumerate(order):
    x = 20 + i * 168
    oh += f'<div style="position: absolute; left: {x}px; top: 0; width: 140px; height: 40px; box-sizing: border-box; border-radius: 8px; border: 1px solid {OR if i == 0 else LINE}; background: {HOVER}; display: flex; align-items: center; gap: 8px; padding: 0 10px"><span style="color: {DIM}">⠿</span>{lbl(t, INK, 10)}<span style="margin-left: auto; font: 400 10px {MONO}; color: {DIM}">{i + 1}</span>{sock("r", 14, OR) if i < 3 else ""}{sock("l", 14, OR) if i > 0 else ""}</div>'
ow = ''.join(wire(20 + i * 168 + 141, 19, 20 + (i + 1) * 168 - 1, 19, OR, 1.5, k=10) for i in range(3))
vid = nhead('01', 'ВИД', '', OR, None, 34, OR, OR) + f'''<div style="padding: 18px 20px; display: flex; flex-direction: column; gap: 22px">
  {prow("ТЕМА", seg(["ТЁМНАЯ", "СВЕТЛАЯ", "КАК В СИСТЕМЕ"], "ТЁМНАЯ"))}
  {prow("АКЦЕНТ", accs + f'<span style="margin-left: 8px">{btn("Свой цвет…", sm=True)}</span>')}
  {prow("АНИМАЦИИ", seg(["ПОЛНЫЕ", "МИНИМУМ", "ВЫКЛ"], "ПОЛНЫЕ") + f'<span style="margin-left: 8px; font-size: 12px; color: {MUT}">Провода рисуются при открытии экрана</span>')}
  {prow("ПРИ ЗАПУСКЕ", seg(["СЕГОДНЯ", "ПОСЛЕДНИЙ РАЗДЕЛ"], "СЕГОДНЯ"))}
  <div>{lbl("ПОРЯДОК ВКЛАДОК · ПЕРЕТАЩИ", MUT, 10)}<div style="position: relative; height: 40px; margin-top: 12px"><svg width="700" height="40" style="position: absolute; left: 0; top: 0" aria-hidden="true" fill="none">{ow}</svg>{oh}</div><div style="margin-top: 8px">{micro("ПО ЭТОМУ ПОРЯДКУ РАБОТАЮТ КЛАВИШИ 1—4 И Q / E")}</div></div>
</div>'''
st += node(264, 0, 700, 470, vid, hub=True, extra=sock('r', 60, OR))
pv = f'''<div style="padding: 14px"><div style="border-radius: 8px; border: 1px solid {LINE}; overflow: hidden">
  <div style="height: 34px; background: {BG}; display: flex; align-items: center; gap: 12px; padding: 0 10px; border-bottom: 1px solid {LINE}">{LOGO}<span style="font: 500 9px {MONO}; letter-spacing: .12em; padding-bottom: 2px; border-bottom: 1px solid {OR}">СЕГОДНЯ</span><span style="font: 500 9px {MONO}; letter-spacing: .12em; color: {MUT}">КАЛЕНДАРЬ</span></div>
  <div style="height: 120px; {GRID}; position: relative">
    <span style="position: absolute; left: 14px; top: 20px; width: 70px; height: 34px; border-radius: 6px; background: {NODE}; border: 1px solid {LINE}"></span>
    <span style="position: absolute; left: 130px; top: 14px; width: 90px; height: 90px; border-radius: 8px; background: {NODE}; border: 1px solid {OR}"></span>
    <svg width="240" height="120" style="position: absolute; left: 0; top: 0" aria-hidden="true" fill="none">{wire(84, 37, 130, 50, OR, 1.5, k=20)}</svg>
  </div></div><div style="margin-top: 10px; font-size: 12px; color: {MUT}">Так будет выглядеть шапка и ноды с выбранным акцентом.</div></div>'''
st += svg(wire(964, 65, 990, 65, OR, 1.5, k=10))
st += node(988, 0, 260, 250, nhead('', 'ПРЕДПРОСМОТР', '', OR) + pv, extra=sock('l', 60, OR))
st += node(264, 494, 700, 150, nhead('02', 'ЧТО ПОКАЗЫВАТЬ', '4 СПИСКА · 1 КАЛЕНДАРЬ', GREY) + f'<div style="padding: 12px 16px; display: flex; gap: 8px; flex-wrap: wrap">{chip(dot(OR) + "3D-АССЕТЫ", True)}{chip(dot(BLUE) + "РАБОТА · КЛИЕНТЫ", True)}{chip(dot(GREEN) + "ДЕЛА ПО ДОМУ", True)}{chip(dot(VIO) + "УЧЁБА", True)}{chip("ПРАЗДНИКИ РОССИИ", True, GREY)}{chip("ДНИ РОЖДЕНИЯ")}{chip("РАБОЧИЙ КАЛЕНДАРЬ")}</div><div style="padding: 0 16px">{micro("СКРЫТЫЕ СПИСКИ НЕ ПОПАДАЮТ В «СЕГОДНЯ», КАЛЕНДАРЬ И НАПОМИНАНИЯ")}</div>')
st += stamp(988, 640, 'НАСТРОЙКИ', 'РАЗДЕЛОВ 06', 'ВИД', w=260)
save('G_Settings.dc.html', page('Настройки', '', st), 'Настройки', 1360, 3760, 'r4')

# ---------------- FIRST RUN ----------------
W4 = 280; G4 = 42
steps = [('01', 'ВХОД В GOOGLE', 'done'), ('02', 'ДОСТУПЫ', 'now'), ('03', 'ЧТО ПОКАЗЫВАТЬ', 'next'), ('04', 'ГОТОВО', 'next')]
bodies = {
 '01': f'<div style="padding: 14px; display: flex; flex-direction: column; gap: 10px"><span style="display: flex; gap: 10px; align-items: center">{coon(40, "ПРИВЕТ")}<span>Привет! Я Спутник. Работаю поверх твоих Google Задач и Календаря.</span></span><span style="display: flex; align-items: center; gap: 8px; height: 34px; padding: 0 10px; border-radius: 8px; border: 1px solid {GREEN}">{dot(GREEN)}<span style="font-size: 12.5px">siponik · вход выполнен</span></span></div>',
 '02': f'''<div style="padding: 14px; display: flex; flex-direction: column; gap: 10px">
   <span style="font-size: 12.5px; color: #C9CAD0">Google спросит четыре разрешения. Своего сервера у Спутника нет: всё остаётся в твоём аккаунте.</span>
   {"".join(f'<div style="display: flex; gap: 10px; align-items: flex-start; padding: 8px 0; border-bottom: 1px solid {SOFT}">{check(True, OR)}<span><span style="display: block; font-weight: 600">{a}</span><span style="font-size: 12px; color: {MUT}">{b}</span></span></div>' for a, b in [("Задачи", "читать и менять списки и задачи"), ("Календарь", "показывать события и создавать новые"), ("Контакты", "дни рождения, только чтение"), ("Скрытая папка Drive", "слой Спутника для второго компьютера")])}
   {btn("Продолжить в Google", "acc", extra="; width: 100%")}
   {micro("GOOGLE ДАЁТ СНЯТЬ ГАЛОЧКИ · БЕЗ ВСЕХ ЧЕТЫРЁХ ВХОД НЕ ЗАСЧИТАЕТСЯ")}</div>''',
 '03': f'<div style="padding: 14px; display: flex; flex-direction: column; gap: 8px">{"".join(f"<div style=\"display: flex; gap: 10px; align-items: center; height: 28px\">{check(on)}<span>{t}</span></div>" for t, on in [("Мои задачи", True), ("Основной календарь", True), ("Праздники России", True), ("Дни рождения", False), ("Рабочий календарь", False)])}</div>',
 '04': f'<div style="padding: 14px; display: flex; flex-direction: column; gap: 10px">{"".join(f"<div style=\"display: flex; gap: 10px\"><span style=\"font: 500 10px {MONO}; color: {DIM}; padding-top: 3px\">{n}</span><span>{t}</span></div>" for n, t in [("А", "Ctrl N — создать из любого места"), ("Б", "«Запиши в Спутник» в чате с Claude"), ("В", "Сводка дня в Telegram в 7:45")])}</div>',
}
st = ab(0, 0, f'<div style="font: 200 64px/60px {SANS}; letter-spacing: -.03em">Первый запуск</div><div style="margin-top: 8px">{micro("ЧЕТЫРЕ ШАГА · ОКОЛО МИНУТЫ · ВСЁ МОЖНО ПОМЕНЯТЬ В НАСТРОЙКАХ", MUT)}</div>', w=900)
paths = ''
for i, (n, t, s_) in enumerate(steps):
    x = i * (W4 + G4); y = 130
    kc = GREEN if s_ == 'done' else (OR if s_ == 'now' else DIM)
    kind = {'done': 'ГОТОВО ✓', 'now': 'СЕЙЧАС', 'next': 'ДАЛЬШЕ'}[s_]
    h = 470 if s_ == 'now' else 0
    ex = (sock('r', 15, kc) if i < 3 else '') + (sock('l', 15, steps[i - 1][2] == 'done' and GREEN or OR) if i > 0 else '')
    st += node(x, y, W4, h, nhead(n, t, kind, kc, kc) + bodies[n], hub=(s_ == 'now'), wait=(s_ == 'next'), extra=ex, style='; opacity: .75' if s_ == 'next' else '')
    if i < 3:
        c = GREEN if s_ == 'done' else (OR if s_ == 'now' else STRONG)
        paths += wire(x + W4 + 1, y + 20, x + W4 + G4 - 1, y + 20, c, 2 if s_ == 'now' else 1.5, dash=(s_ == 'next'), k=14)
st = svg(paths) + st
st += dimline(0, 640, 1248, 'ВХОД → ДОСТУПЫ → ЧТО ПОКАЗЫВАТЬ → ГОТОВО')
st += node(0, 660, 520, 40, f'<div style="height: 100%; display: flex; align-items: center; gap: 10px; padding: 0 12px">{dot(RED)}{micro("НЕТ СВЯЗИ С GOOGLE · ПОВТОРЮ ЧЕРЕЗ МИНУТУ", RED)}<span style="flex: 1"></span>{btn("Повторить", sm=True)}</div>', wait=True)
save('G_Setup.dc.html', page('Первый запуск', '', st, right='0.9.0'), 'Первый запуск', 0, 4700, 'r4')
print('ok')
