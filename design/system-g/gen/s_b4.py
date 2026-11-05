import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board, s_cal
habs = [('Зарядка', 'З', GOLD, 'КАЖДЫЙ ДЕНЬ · УТРО', '21', 'ДН ПОДРЯД', 'ddddddd', '→ 50 · ЧЕРЕЗ 29 ДН', True, True),
        ('Вода', 'В', BLUE, '8 СТАКАНОВ', '12', 'ДН ПОДРЯД', 'ddddddp', '5 / 8 СЕГОДНЯ', False, False),
        ('Скетч 15 минут', 'С', OR, '3 В НЕД · ВЕЧЕР', '3', 'НЕД ПОДРЯД', 'dodoodf', '1 / 3 НА НЕДЕЛЕ', False, False),
        ('Английский', 'А', VIO, 'ПО БУДНЯМ', '7', 'ДН ПОДРЯД', 'ddddkkd', '→ 21 · ЧЕРЕЗ 14 ДН', True, False),
        ('Без сладкого', 'Б', GREEN, 'КАЖДЫЙ ДЕНЬ', '0', 'СЕРИЯ НА ПАУЗЕ', 'ddmdddf', 'ВЧЕРА ПРОПУСК', False, False),
        ('Прогулка', 'П', GREY, 'КАЖДЫЙ ДЕНЬ · ДЕНЬ', '4', 'ДН ПОДРЯД', 'oddddof', 'ОКНО 12:00—14:00', False, False)]
DIMK = f'<div style="position: absolute; inset: 0; opacity: .25; pointer-events: none">{s_board.KANBAN}</div>'
DIMW = f'<div style="position: absolute; inset: 0; opacity: .25; pointer-events: none">{s_cal.WEEK}</div>'

def inp(t, w='100%', on=False, h=36):
    return f'<span style="width: {w}; height: {h}px; box-sizing: border-box; border-radius: 8px; border: {"1.5px solid " + OR if on else "1px solid " + STRONG}; background: {BG}; display: inline-flex; align-items: center; padding: 0 12px">{t}</span>'

# ---------------- HABITS · MONTH ----------------
top = f'''<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{coon(30, "ФЛАГ")}{lbl("ПРИВЫЧКИ", INK)}{micro("НОЯБРЬ 2026 · 6 ПРИВЫЧЕК", MUT)}
  <span style="width: 1px; height: 20px; background: {LINE}"></span>{btn("‹", "ghost", True)}{lbl("НОЯБРЬ", INK)}{btn("›", "ghost", True)}<span style="flex: 1"></span>{seg(["СЕГОДНЯ", "МЕСЯЦ"], "МЕСЯЦ")}{btn("＋ Привычка", "acc", True)}</div>'''
st = node(0, 0, 1248, 48, top)
DAYS = 30; CW = 30
pat = {'Зарядка': 'ddddd', 'Вода': 'ddpdd', 'Скетч 15 минут': 'dookd', 'Английский': 'kdddd', 'Без сладкого': 'ddmdd', 'Прогулка': 'ddodd'}
wd = ['ВС', 'ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ']
hdr = ''.join(f'<span style="width: {CW}px; text-align: center; flex: none; display: flex; flex-direction: column; gap: 2px; align-items: center">{micro(wd[(d - 1) % 7], OR if d == 5 else (GOLD if (d - 1) % 7 in (0, 6) else DIM))}<span style="font: {"600" if d == 5 else "400"} 11px {MONO}; color: {OR if d == 5 else MUT}">{d}</span></span>' for d in range(1, DAYS + 1))
rows = f'<div style="display: flex; align-items: center; height: 44px; border-bottom: 1px solid {LINE}"><span style="width: 210px; flex: none; padding-left: 14px">{lbl("ПРИВЫЧКА", MUT, 10)}</span>{hdr}<span style="width: 70px; text-align: right; padding-right: 14px">{lbl("%", MUT, 10)}</span></div>'
import random; random.seed(4)
for h in habs:
    n, ic, c = h[0], h[1], h[2]
    cells = ''
    for d in range(1, DAYS + 1):
        if d < 5:
            k = 'dddmdkdd'[(d + len(n)) % 8] if n != 'Зарядка' else 'd'
        elif d == 5: k = 'f' if n not in ('Зарядка',) else 'd'
        else: k = 'e'
        stl = {'d': f'background: {c}', 'p': f'background: linear-gradient(0deg, {c} 55%, transparent 55%); border: 1px solid {c}', 'm': f'border: 1px solid {RED}', 'k': f'border: 1px dashed {DIM}', 'f': f'border: 1.5px solid {OR}', 'e': f'border: 1px solid {SOFT}'}[k]
        if n == 'Вода' and d == 3: stl = f'background: linear-gradient(0deg, {c} 55%, transparent 55%); border: 1px solid {c}'
        if n == 'Скетч 15 минут' and k == 'e' and d % 7 not in (2, 4, 6): stl = f'border: 1px dashed #3A3B42'
        sel = n == 'Скетч 15 минут' and d == 3
        cells += f'<span style="width: {CW}px; flex: none; display: grid; place-items: center"><span style="width: 20px; height: 20px; border-radius: 5px; box-sizing: border-box; {stl}{"; box-shadow: 0 0 0 2px " + NODE + ", 0 0 0 3.5px " + INK if sel else ""}"></span></span>'
    pc = {'Зарядка': '100', 'Вода': '88', 'Скетч 15 минут': '67', 'Английский': '100', 'Без сладкого': '80', 'Прогулка': '75'}[n]
    rows += f'<div style="display: flex; align-items: center; height: 46px; border-bottom: 1px solid {SOFT}"><span style="width: 210px; flex: none; padding-left: 14px; display: flex; align-items: center; gap: 8px"><span style="width: 20px; height: 20px; border-radius: 5px; background: {c}; color: {DARK}; display: grid; place-items: center; font: 600 11px {MONO}">{ic}</span><span style="font-weight: 600; white-space: nowrap">{n}</span></span>{cells}<span style="width: 70px; text-align: right; padding-right: 14px; font: 400 12px {MONO}; color: {GOLD if pc == "100" else MUT}">{pc}</span></div>'
leg = ''.join(f'<span style="display: inline-flex; align-items: center; gap: 6px"><span style="width: 14px; height: 14px; border-radius: 4px; box-sizing: border-box; {s}"></span><span style="font-size: 12px; color: {MUT}">{t}</span></span>' for s, t in [(f'background: {GOLD}', 'сделано'), (f'background: linear-gradient(0deg, {BLUE} 55%, transparent 55%); border: 1px solid {BLUE}', 'не всё (5 из 8)'), (f'border: 1px solid {RED}', 'пропуск'), (f'border: 1px dashed {DIM}', 'не считать'), (f'border: 1px dashed #3A3B42', 'не по расписанию'), (f'border: 1.5px solid {OR}', 'сегодня')])
tbl = rows + f'<div style="display: flex; gap: 18px; padding: 14px; flex-wrap: wrap">{leg}</div>'
st += node(0, 64, 1248, 400, nhead('', 'ПРИВЫЧКА × ДЕНЬ', 'SPACE — ОТМЕТИТЬ · X — ПРОПУСК · O — НЕ СЧИТАТЬ', GOLD, MUT, 34, INK) + tbl, hub=True)
# day menu
menu = f'''<div style="padding: 6px">{mrow("Сделано", kbd("SPACE"), True, GOLD)}{mrow("Пропуск", kbd("X"), c=RED)}{mrow("Не считать этот день", kbd("O"), c=DIM)}<div style="height: 1px; background: {LINE}; margin: 6px 4px"></div>{mrow("Очистить", kbd("DEL"))}</div>'''
st += pop(318, 260, 240, 196, 'СКЕТЧ · ВТ 3 НОЯБРЯ', menu, OR)
# summary cards
sums = [('Лучший месяц', 'Зарядка и английский — без пропусков', GOLD), ('Средний процент', '85% · на 6% лучше октября', GREEN), ('Сорвалось', 'Без сладкого — 3 ноября', RED)]
for i, (t, s, c) in enumerate(sums):
    st += node(i * 300, 484, 284, 84, f'<div style="padding: 14px 16px; display: flex; gap: 12px; align-items: center">{dot(c, 10)}<span><span style="display: block; font-weight: 600">{t}</span><span style="font-size: 12.5px; color: {MUT}">{s}</span></span></div>')
st += ab(900, 484, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 348px; box-sizing: border-box">{coon(44, "ФЛАГ")}<span style="font-size: 12.5px; color: #C9CAD0">Клик по клетке — меню дня. Задним числом можно отметить любой день месяца.</span></div>')
HM = st
save2('G_HabitsMonth.dc.html', page('Привычки · месяц', 'ПРИВЫЧКИ', st), 'Привычки · месяц (привычка × день)')

# ---------------- HABIT EDIT ----------------
cols = ''.join(f'<span style="width: 26px; height: 26px; border-radius: 50%; background: {c}; box-sizing: border-box{"; box-shadow: 0 0 0 2px " + NODE + ", 0 0 0 4px " + INK if c == GOLD else ""}"></span>' for c in [GOLD, OR, BLUE, VIO, GREEN, RED, GREY])
icons = ''.join(f'<span style="width: 34px; height: 34px; border-radius: 8px; border: 1px solid {GOLD if i == 0 else LINE}; background: {"rgba(232,198,90,.12)" if i == 0 else "transparent"}; display: grid; place-items: center; font-size: 16px">{e}</span>' for i, e in enumerate(['🏃', '💧', '✏️', '📖', '🧘', '🍎', '🌙', '🎸']))
winbar = f'''<div style="position: relative; height: 40px; margin-top: 2px">
 <div style="position: absolute; left: 0; right: 0; top: 14px; height: 10px; border-radius: 5px; background: {SOFT}"></div>
 <div style="position: absolute; left: 0; width: 25%; top: 14px; height: 10px; border-radius: 5px 0 0 5px; background: rgba(232,198,90,.18)"></div>
 <div style="position: absolute; left: 4%; width: 8%; top: 12px; height: 14px; border-radius: 4px; background: {GOLD}"></div>
 {"".join(f'<span style="position: absolute; left: {p}%; top: 28px; font: 400 9.5px {MONO}; color: {DIM}">{t}</span>' for p, t in [(0, "06"), (25, "12"), (50, "18"), (75, "24")])}
</div>'''
form = f'''<div style="padding: 22px 24px; display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 28px">
 <div style="display: flex; flex-direction: column; gap: 18px">
  {field("Как называется", inp("Зарядка", on=True, h=42))}
  {field("Значок", icons)}
  {field("Цвет", cols)}
  {field("Как часто", sc("Каждый день", True, GOLD) + sc("По будням") + sc("Свои дни") + sc("3 раза в неделю"))}
  {field("Цель на день", sc("Просто сделать", True, GOLD) + sc("Количество: 8 стаканов"))}
 </div>
 <div style="display: flex; flex-direction: column; gap: 18px">
  {field("Часть дня", sc("Утро", True, GOLD) + sc("День") + sc("Вечер") + sc("Любое"))}
  {field("Окно", f'{inp("07:00", "84px")}<span style="color: {MUT}">до</span>{inp("09:00", "84px")}<span style="font-size: 12px; color: {MUT}">утро — 6–12, можно сузить</span>')}
  <div style="margin-top: -8px">{winbar}</div>
  {field("Напомнить", sc("Telegram в 07:00", True, GOLD, True) + sc("Windows, пока идёт окно", True, GOLD, True))}
  {field("До какого дня", sc("Без конца", True, GOLD) + sc("Выбрать дату…"))}
  <div style="display: flex; gap: 10px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(232,198,90,.07); border: 1px solid #5C4F22">{coon(40, "ФЛАГ")}<span style="font-size: 12.5px; line-height: 18px; color: #DADBE0">Серия 21 день. Изменения не сбросят её.</span></div>
 </div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 64px; box-sizing: border-box; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 24px">
 {btn("Удалить привычку", "ghost", extra="; color: " + RED)}<span style="flex: 1"></span><span style="font-size: 12.5px; color: {MUT}">Ctrl+Enter — сохранить</span>{btn("Отмена", extra="; height: 38px; padding: 0 16px; border-radius: 8px")}{btn("Сохранить", "acc", extra="; height: 38px; padding: 0 18px; border-radius: 8px; font-size: 14px")}
</div>'''
st = dim(HM, .22) + node(194, 30, 860, 620, nhead('', 'ПРИВЫЧКА · ЗАРЯДКА', 'ИЗМЕНИТЬ', GOLD, None, 38, INK, GOLD) + form, hub=True, style=SH)
save2('G_HabitEdit.dc.html', page('Окно привычки', 'ПРИВЫЧКИ', st), 'Окно привычки · окно «с — до», цель, напоминания')

# ---------------- CREATE · other kinds ----------------
KC = [OR, BLUE, GOLD, VIO]
def cr_head(k):
    kinds = ''
    for i, t in enumerate(['Задача', 'Событие', 'Привычка', 'День рождения']):
        if i == k:
            kinds += f'<span style="height: 30px; padding: 0 14px; border-radius: 8px; background: rgba(255,255,255,.92); color: {FILL[KC[k]]}; display: flex; align-items: center; font: 600 13px {SANS}">{t}</span>'
        else:
            kinds += f'<span style="height: 30px; padding: 0 14px; border-radius: 8px; color: rgba(255,255,255,.85); display: flex; align-items: center; font: 500 13px {SANS}">{t}</span>'
    return f'<div style="height: 50px; box-sizing: border-box; padding: 0 10px 0 12px; border-radius: 11px 11px 0 0; background: {FILL[KC[k]]}; display: flex; align-items: center; gap: 4px">{kinds}<span style="flex: 1"></span><span style="font: 400 10px {MONO}; color: rgba(255,255,255,.6); margin-right: 8px">ALT 1…4</span><button type="button" aria-label="Закрыть" style="width: 30px; height: 30px; border-radius: 8px; border: 0; background: transparent; color: #FFFFFF; font-size: 16px">✕</button></div>'

mark = lambda t, c: f'<span style="padding: 2px 8px; border-radius: 6px; background: {c}29; color: {INK}; margin: 0 2px">{t}</span>'
caret = lambda c: f'<span style="display: inline-block; width: 1.5px; height: 20px; background: {c}; vertical-align: -4px; margin-left: 3px"></span>'

def cr(k, q, line, hint, left, right, primary, more=''):
    c = KC[k]
    sc_ = lambda t, on=False, x=False: sc(t, on, c, x)
    body = f'''<div style="padding: 22px 24px 0; display: flex; flex-direction: column; gap: 10px">
  <span style="font: 500 15px {SANS}">{q}</span>
  <div style="height: 54px; box-sizing: border-box; border-radius: 10px; border: 1.5px solid {c}; background: {BG}; display: flex; align-items: center; padding: 0 16px; font-size: 17px">{line}{caret(c)}</div>
  <div style="font-size: 12.5px; color: {MUT}">{hint}</div>
</div>
<div style="padding: 20px 24px 0; display: grid; grid-template-columns: minmax(0, 1fr) 280px; gap: 24px">
  <div style="display: flex; flex-direction: column; gap: 16px">{left(sc_)}</div>
  <div style="display: flex; flex-direction: column; gap: 14px">{right}</div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 64px; box-sizing: border-box; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 24px">
  <span style="font-size: 12.5px; color: {MUT}">Enter — добавить, Esc — закрыть</span><span style="flex: 1"></span>{more}
  {btn("Добавить и ещё", extra="; height: 38px; padding: 0 16px; border-radius: 8px")}<button type="button" style="height: 38px; padding: 0 18px; border-radius: 8px; border: 0; background: {c}; color: {DARK}; font: 600 14px {SANS}">{primary}</button>
</div>'''
    return node(214, 14, 820, 672, cr_head(k) + body, hub=True)

# event
def ev_left(s):
    return f'''{field("В какой календарь", f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 34px; padding: 0 12px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}">{dot(BLUE, 8)}<span style="font-weight: 600">Основной</span><span style="color: {MUT}">▾</span></span><span style="font-size: 12px; color: {MUT}">только те, куда можно писать</span>')}
    {field("Когда", s("Пятница, 6 ноября · 15:00", True, True))}
    {field("Длится", s("15 мин") + s("30 мин") + s("1 час", True) + s("2 часа") + s("Весь день"))}
    <div style="display: flex; align-items: center; gap: 8px; font-size: 12.5px; color: {GREEN}; margin-top: -8px">{dot(GREEN, 6)}Свободно до 17:00</div>
    {field("Напомнить", s("Нет") + s("За 15 мин", True) + s("За час") + s("За день"))}
    <span style="color: {BLUE}; font-size: 13px">▸ Ещё: заметка и повтор</span>'''
hrs = ''
for i, hh in enumerate(['13:00', '14:00', '15:00', '16:00', '17:00']):
    hrs += f'<div style="height: 40px; border-top: 1px solid {SOFT}; position: relative"><span style="position: absolute; left: 8px; top: 4px; font: 400 10px {MONO}; color: {DIM}">{hh}</span></div>'
dayc = f'''<span style="font: 500 12.5px {SANS}; color: {MUT}">Пятница, 6 ноября</span>
<div style="position: relative; border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; overflow: hidden">{hrs}
 <div style="position: absolute; left: 52px; right: 8px; top: 4px; height: 30px; border-radius: 6px; background: #2C2D33; border-left: 3px solid {GREY}; padding: 4px 8px; box-sizing: border-box; font-size: 12px">Созвон с Олей</div>
 <div style="position: absolute; left: 52px; right: 8px; top: 82px; height: 38px; border-radius: 6px; background: rgba(111,162,242,.18); border: 1.5px dashed {BLUE}; padding: 4px 8px; box-sizing: border-box; font-size: 12px"><b style="font-weight: 600">Встреча с заказчиком</b><br><span style="color: {MUT}">15:00 – 16:00</span></div>
</div>
{field("Место", inp(f'<span style="color: {MUT}">Адрес или ссылка</span>', "100%"))}'''
line = f'Встреча с заказчиком {mark("в пятницу 15:00", BLUE)} {mark("час", BLUE)}'
st = DIMW + cr(1, 'Что за событие?', line, 'Событие попадёт в Google Календарь. «час», «до 17», «в офисе» — тоже понимаю.', ev_left, dayc, 'Добавить событие')
save2('G_CreateEvent.dc.html', page('Создать · событие', 'КАЛЕНДАРЬ', st), 'Создать · событие')

# habit
def hb_left(s):
    return f'''{field("Значок", ''.join(f'<span style="width: 34px; height: 34px; border-radius: 8px; border: 1px solid {GOLD if i == 1 else LINE}; background: {"rgba(232,198,90,.12)" if i == 1 else "transparent"}; display: grid; place-items: center; font-size: 16px">{e}</span>' for i, e in enumerate(["🏃", "💧", "✏️", "📖", "🧘", "🍎"])) + f'<span style="font-size: 12px; color: {GOLD}">угадал по слову «вода»</span>')}
    {field("Как часто", s("Каждый день", True) + s("По будням") + s("Свои дни") + s("N раз в неделю"))}
    {field("Цель на день", s("Просто сделать") + s("8 стаканов", True, True))}
    {field("Часть дня", s("Утро") + s("День") + s("Вечер") + s("Весь день", True))}
    {field("Напомнить", s("Telegram", True) + s("Windows", True) + s("Не надо"))}'''
prev = f'''<span style="font: 500 12.5px {SANS}; color: {MUT}">Так появится в «Привычках»</span>
<div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; padding-bottom: 12px">
 <div style="height: 34px; padding: 0 12px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 8px"><span style="width: 20px; height: 20px; border-radius: 5px; background: {BLUE}; display: grid; place-items: center; font-size: 11px">💧</span><span style="font-weight: 600">Пить воду</span><span style="margin-left: auto">{micro("8 СТАКАНОВ")}</span></div>
 <div style="padding: 12px 14px 0; display: flex; align-items: flex-end; gap: 10px"><span style="font: 200 54px/48px {SANS}; color: {DIM}">0</span><span style="padding-bottom: 6px">{micro("ДН ПОДРЯД", MUT)}</span></div>
 <div style="padding: 12px 14px 0; display: flex; justify-content: space-between">{"".join(f'<span style="width: 22px; height: 22px; border-radius: 5px; box-sizing: border-box; border: {"1.5px solid " + OR if i == 6 else "1px solid #45464D"}"></span>' for i in range(7))}</div>
</div>
<div style="display: flex; gap: 12px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(232,198,90,.07); border: 1px solid #5C4F22">{coon(44, "ФЛАГ")}<span style="font-size: 13px; line-height: 19px; color: #DADBE0">Первая веха — 7 дней. Отмечать можно по стакану: «＋1».</span></div>'''
line = f'Пить воду {mark("8 стаканов", GOLD)} {mark("каждый день", GOLD)}'
st = dim(HM, .22) + cr(2, 'Какую привычку заведём?', line, 'Можно сразу цель и частоту: «8 стаканов», «3 раза в неделю», «по утрам».', hb_left, prev, 'Добавить привычку')
save2('G_CreateHabit.dc.html', page('Создать · привычка', 'ПРИВЫЧКИ', st), 'Создать · привычка')

# birthday
def bd_left(s):
    return f'''{field("Когда", s("12 ноября", True, True) + f'<span style="font-size: 12px; color: {MUT}">каждый год</span>')}
    {field("Год рождения", inp("1994", "100px") + f'<span style="font-size: 12px; color: {MUT}">необязательно — тогда покажу, сколько исполнится</span>')}
    {field("Напомнить", s("В день", True) + s("За день", True) + s("За 3 дня") + s("За неделю") + s("За месяц"))}
    {field("Задача «Подарок Оле»", s("Не надо") + s("За 3 дня") + s("За неделю", True) + s("За 2 недели") + s("За месяц"))}'''
prev = f'''<span style="font: 500 12.5px {SANS}; color: {MUT}">В календаре</span>
<div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; padding: 14px; display: flex; gap: 12px; align-items: center">
 <span style="width: 44px; height: 48px; border-radius: 8px; background: {FILL[VIO]}; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #FFFFFF"><span style="font: 600 18px {SANS}">12</span><span style="font: 500 9px {MONO}; letter-spacing: .1em">НОЯ</span></span>
 <span><span style="display: block; font-weight: 600">День рождения Оли</span><span style="font-size: 12.5px; color: {MUT}">Исполнится 32 · через 7 дней</span></span>
</div>
<div style="border-radius: 8px; background: {NODE}; border: 1px dashed {LINE}; padding: 12px 14px; display: flex; gap: 10px; align-items: center">{check()}<span style="flex: 1"><span style="display: block">Подарок Оле</span><span style="font-size: 12px; color: {MUT}">появится 5 ноября</span></span><span style="display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 10px; border-radius: 6px; background: {HOVER}; border: 1px solid {LINE}; font-size: 12px">{dot(GREEN, 6)}Дела по дому<span style="color: {MUT}">▾</span></span></div>
<div style="display: flex; gap: 12px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(180,140,240,.08); border: 1px solid #4D3D6B">{coon(44, "УРА")}<span style="font-size: 13px; line-height: 19px; color: #DADBE0">Неделя до праздника уже идёт — задачу про подарок заведу сразу.</span></div>'''
line = f'Оля {mark("12 ноября", VIO)} {mark("1994", VIO)}'
st = DIMK + cr(3, 'Чей день рождения?', line, 'Имя и дата: «Оля 12 ноября». Год — если знаешь.', bd_left, prev, 'Добавить день рождения')
save2('G_CreateBday.dc.html', page('Создать · день рождения', 'КАЛЕНДАРЬ', st), 'Создать · день рождения')
print('ok')
