import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

def toolbar(mode):
    inner = f'''<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px; flex-wrap: wrap">
  {lbl('НОЯБРЬ 2026', INK)}{lbl('НЕДЕЛЯ 45' if mode=='НЕДЕЛЯ' else '5 ИЗ 30', DIM)}
  <span style="display: flex; gap: 4px">{btn('‹', sm=True)}{btn('›', sm=True)}</span>{btn('Сегодня', sm=True)}
  <span style="width: 1px; height: 20px; background: {LINE}"></span>
  {chip(dot(GREY)+'СОБЫТИЯ', True, GREY)}{chip(dot(OR)+'ЗАДАЧИ', True)}{chip(dot(GOLD)+'ПРИВЫЧКИ', True, GOLD)}{chip(dot(VIO)+'ДНИ РОЖДЕНИЯ', False)}
  <span style="flex: 1"></span>{seg(['НЕДЕЛЯ','МЕСЯЦ'], mode)}
</div>'''
    return node(0, 0, 1248, 48, inner)

def daypanel(y, h, title):
    rows = [('10:00', 'Ретопология меча', OR, True), ('12:30', 'Созвон «Таверна»', GREY, False), ('15:00', 'Текстуры для щита, 2K', OR, False, True), ('19:00', 'Глава 4 · Substance', VIO, False), ('ДЕНЬ', 'Купить корм коту', GREEN, False)]
    rh = ''
    for r in rows:
        t, x, c, done = r[0], r[1], r[2], r[3]; now = len(r) > 4
        st = 'text-decoration: line-through; color: ' + DIM if done else ''
        bgc = hatch() + f'; border: 1px solid {OR}; border-radius: 8px' if now else f'border-bottom: 1px solid {SOFT}'
        rh += f'<div style="height: 36px; box-sizing: border-box; display: flex; align-items: center; gap: 10px; padding: 0 10px; {bgc}">{check(done, OR if now else STRONG)}<span style="font: 400 11.5px {MONO}; width: 40px; color: {ORI if now else MUT}">{t}</span><span style="flex: 1; {st}">{x}</span>{dot(c)}</div>'
    hab = ''.join(f'<span style="display: flex; align-items: center; justify-content: space-between; height: 28px"><span>{n}</span><span style="font: 400 11px {MONO}; color: {c}">{v}</span></span>' for n, v, c in [('✓ Зарядка', '21 ДН', GOLD), ('Вода', '5/8', MUT), ('Скетч · вечер', '3 НЕД', MUT)])
    inner = nhead('', title, '5 ДЕЛ', OR, MUT, 34, OR, OR) + f'''<div style="padding: 10px 12px; display: flex; flex-direction: column; gap: 4px">{rh}</div>
  <div style="margin: 0 12px; padding: 8px 0; border-top: 1px solid #8A7424">{lbl('ПРИВЫЧКИ · 1 / 3', GOLD)}{hab}</div>
  <div style="margin: 6px 12px 0">{btn('＋ Добавить на этот день', extra='; width: 100%; border-style: dashed')}</div>
  <div style="margin: 12px; padding: 10px; border-radius: 8px; border: 1px dashed #8A7424; display: flex; gap: 10px; align-items: center">{coon(44)}<span style="font-size: 12.5px; color: #C9CAD0">Свободно 17:00—19:00. Поставить туда «Рендер щита»? <a href="#">Поставить</a></span></div>'''
    return node(924, y, 324, h, inner)

# ---------- WEEK ----------
days = ['ПН 02', 'ВТ 03', 'СР 04', 'ЧТ 05', 'ПТ 06', 'СБ 07', 'ВС 08']
GX = 50; CW = 120; HT = 146
def hy(h): return HT + (h - 9) * 30
ev = [(0, 10, 12, 'Ретопология меча', 'task', OR, True), (0, 14, 15, 'Созвон: бриф', 'ev', GREY, False),
      (1, 11, 13, 'UV щита', 'task', OR, False), (1, 19, 20.5, 'Курс Substance', 'task', VIO, False),
      (2, 12, 13, 'Обед с Олей', 'ev', GREY, False), (2, 15, 17, 'Скульпт шлема', 'task', OR, False),
      (3, 10, 11, 'Ретопология меча', 'task', OR, True), (3, 12.5, 13.5, 'Созвон «Таверна»', 'ev', GREY, False),
      (3, 15, 17, 'Текстуры для щита', 'now', OR, False), (3, 19, 20, 'Глава 4 · Substance', 'task', VIO, False),
      (4, 11, 12, 'Сдача «Таверне»', 'task', BLUE, False), (4, 16, 18, 'Рендер щита', 'task', OR, False),
      (5, 12, 14, 'Рынок', 'task', GREEN, False)]
g = ''
# day headers
for i, d in enumerate(days):
    x = GX + i * CW; today = i == 3
    c = OR if today else MUT
    bgc = f'background: {WASH};' if today else ''
    g += f'<div style="position: absolute; left: {x}px; top: 34px; width: {CW}px; height: 40px; box-sizing: border-box; border-left: 1px solid {SOFT}; {bgc} display: flex; align-items: center; justify-content: center; gap: 6px">{lbl(d, c)}{"" if not today else micro("СЕГОДНЯ", OR)}</div>'
    # habits dots
    pat = [('d','d','m'),('d','d','d'),('d','m','m'),('d','t','t'),('o','o','o'),('o','o','x'),('o','o','x')][i]
    ds = ''
    for p in pat:
        st = {'d': f'background: {GOLD}', 'm': f'border: 1px solid {DIM}', 't': f'border: 1.5px solid {OR}', 'o': f'border: 1px solid #45464D', 'x': f'border: 1px dashed #55575F'}[p]
        ds += f'<span style="width: 7px; height: 7px; border-radius: 2px; box-sizing: border-box; {st}"></span>'
    cnt = sum(1 for p in pat if p == 'd')
    g += f'<div style="position: absolute; left: {x}px; top: 74px; width: {CW}px; height: 22px; box-sizing: border-box; border-left: 1px solid {SOFT}; display: flex; align-items: center; justify-content: center; gap: 4px">{ds}{micro(f"{cnt}/3", DIM, "; margin-left: 4px")}</div>'
    # column body line
    g += f'<div style="position: absolute; left: {x}px; top: 96px; width: {CW}px; height: 428px; border-left: 1px solid {SOFT}; {"background: rgba(240,160,75,.035)" if today else ""}"></div>'
g += f'<div style="position: absolute; left: 8px; top: 78px">{micro("ПРИВЫЧКИ")}</div><div style="position: absolute; left: 8px; top: 104px">{micro("ДЕНЬ")}</div>'
# all-day
alld = [(0, 'Счёт за октябрь', BLUE), (3, 'Купить корм коту', GREEN), (4, '★ ДР Ани', VIO)]
for i, t, c in alld:
    g += f'<div style="position: absolute; left: {GX + i * CW + 4}px; top: 100px; width: {CW - 8}px; height: 22px; box-sizing: border-box; border-radius: 6px; border: 1px solid {LINE}; background: {BG}; display: flex; align-items: center; gap: 6px; padding: 0 6px; font-size: 11.5px; overflow: hidden; white-space: nowrap">{dot(c)}{t}</div>'
g += f'<div style="position: absolute; left: 0; right: 0; top: 126px; height: 20px; border-top: 1px solid {LINE}; border-bottom: 1px solid {SOFT}; background: repeating-linear-gradient(90deg, rgba(255,255,255,.025) 0 6px, transparent 6px 12px); display: flex; align-items: center; padding-left: 8px">{micro("00—09")}</div>'
for h in range(9, 21):
    y = hy(h)
    g += f'<div style="position: absolute; left: 0; right: 0; top: {y}px; border-top: 1px solid {SOFT}"></div><div style="position: absolute; left: 8px; top: {y + 3}px">{micro(f"{h:02d}:00")}</div>'
g += f'<div style="position: absolute; left: 0; right: 0; top: {hy(21)}px; height: 18px; border-top: 1px solid {SOFT}; background: repeating-linear-gradient(90deg, rgba(255,255,255,.025) 0 6px, transparent 6px 12px); display: flex; align-items: center; padding-left: 8px">{micro("21—24")}</div>'
# free window
g += f'<div style="position: absolute; left: {GX + 3 * CW + 4}px; top: {hy(17) + 2}px; width: {CW - 8}px; height: {60 - 4}px; box-sizing: border-box; border-radius: 6px; border: 1px dashed {GOLD}; display: flex; align-items: center; justify-content: center">{micro("СВОБОДНО", GOLD)}</div>'
for d, s, e, t, k, c, done in ev:
    x = GX + d * CW + 4; y = hy(s) + 1; hh = (e - s) * 30 - 2
    if k == 'ev':
        st = f'background: #2F3036; border: 1px solid {LINE}'
    elif k == 'now':
        st = hatch() + f'; border: 1px solid {OR}'
    else:
        st = f'background: {NODE}; border: 1px solid {LINE}; border-left: 3px solid {c}' if False else f'background: rgba(255,255,255,.03); border: 1px solid {c}55'
    tt = f'text-decoration: line-through; color: {DIM}' if done else ''
    tm = f'{int(s):02d}:{int((s % 1) * 60):02d}'
    ck = '' if k == 'ev' else f'<span style="width: 9px; height: 9px; border-radius: 50%; box-sizing: border-box; border: 1.5px solid {c}; {"background:" + c if done else ""}; flex: none"></span>'
    if e - s <= 1:
        g += f'<div style="position: absolute; left: {x}px; top: {y}px; width: {CW - 8}px; height: {hh}px; box-sizing: border-box; border-radius: 6px; {st}; padding: 0 6px; overflow: hidden; display: flex; gap: 5px; align-items: center; white-space: nowrap">{ck}<span style="font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; {tt}">{t}</span></div>'
    else:
        g += f'<div style="position: absolute; left: {x}px; top: {y}px; width: {CW - 8}px; height: {hh}px; box-sizing: border-box; border-radius: 6px; {st}; padding: 4px 6px; overflow: hidden"><div style="display: flex; gap: 5px; align-items: center">{ck}{micro(tm, ORI if k == "now" else MUT)}</div><div style="font-size: 11.5px; line-height: 15px; margin-top: 2px; {tt}">{t}</div></div>'
# now line
ny = hy(14 + 52 / 60)
g += f'<div style="position: absolute; left: {GX + 3 * CW}px; top: {ny}px; width: {CW}px; height: 0; border-top: 1.5px solid {OR}"></div><span style="position: absolute; left: {GX + 3 * CW - 4}px; top: {ny - 4}px; width: 8px; height: 8px; border-radius: 2px; background: {OR}"></span>'
# sleeping coon on Sunday
g += f'<div style="position: absolute; left: {GX + 6 * CW + 34}px; top: {hy(13)}px; display: flex; flex-direction: column; align-items: center; gap: 6px">{coon(46, "СОН")}{micro("СВОБОДНЫЙ")}</div>'
hubinner = nhead('', 'НЕДЕЛЯ · 02—08 НОЯБРЯ', 'ЗАНЯТО 31 Ч', OR, MUT, 34, OR, OR) + g
st = toolbar('НЕДЕЛЯ')
st += node(0, 64, 900, 556, hubinner, hub=True, style='; overflow: visible')
st += daypanel(64, 556, 'ЧТ 05 · СЕГОДНЯ')
st += ab(0, 636, f'<span style="display: flex; align-items: center; gap: 14px">{lbl("ОБЗОР НЕДЕЛИ ▾", INK)}{micro("ЗАГРУЗКА 31 Ч", MUT)}{micro("СРОКИ 3", MUT)}{micro("СВОБОДНЕЕ ВСЕГО · ЧТ 17—19", GOLD)}</span>', w=900)
st += dimline(0, 664, 900, 'ПН — ВС · 7 ДНЕЙ · ЧАСЫ 09—21 КРУПНО, ОСТАЛЬНОЕ СЖАТО')
st += stamp(968, 636, 'КАЛЕНДАРЬ · НЕДЕЛЯ', 'СОБЫТИЙ 05', 'ЗАДАЧ 09')
WEEK = st
save('G_CalWeek.dc.html', page('Календарь · неделя', 'КАЛЕНДАРЬ', st), 'Календарь · неделя', 1360, 0, 'r4')

# ---------- MONTH ----------
import datetime
start = datetime.date(2026, 10, 26)
CWm = 900 // 7; RH = 82
m = ''
for i, d in enumerate(['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС']):
    m += f'<div style="position: absolute; left: {i * CWm}px; top: 34px; width: {CWm}px; height: 24px; display: flex; align-items: center; padding-left: 10px; box-sizing: border-box">{lbl(d, DIM)}</div>'
items = {5: [('15:00', 'Текстуры щита', OR), ('12:30', 'Созвон', GREY)], 2: [('10:00', 'Ретопология', OR)], 3: [('11:00', 'UV щита', OR)], 6: [('★', 'ДР Ани', VIO), ('11:00', 'Сдача', BLUE)],
         10: [('', 'Рендер щита', OR)], 12: [('19:00', 'Курс', VIO)], 14: [('', 'Рынок', GREEN)], 17: [('12:00', 'Счёт «Таверне»', BLUE)], 19: [('', 'Шлем · сдача', OR), ('18:00', 'Кино', GREY)],
         23: [('★', 'ДР мамы', VIO)], 25: [('10:00', 'Бриф: броня', BLUE)], 28: [('', 'Сб · дача', GREEN)], 4: [('12:00', 'Обед с Олей', GREY)], 1: [('', 'Отдых', GREEN)]}
for k in range(42):
    d = start + datetime.timedelta(days=k); r, c = divmod(k, 7)
    x = c * CWm; y = 58 + r * RH
    inm = d.month == 11; today = d == datetime.date(2026, 11, 5)
    bgc = hatch(a=.05) + ';' if today else ''
    brd = f'border: 1px solid {OR}; border-radius: 8px;' if today else f'border-top: 1px solid {SOFT}; border-left: 1px solid {SOFT};'
    numc = OR if today else (INK if inm else '#4E5058')
    cell = f'<div style="display: flex; justify-content: space-between; align-items: center">{lbl(f"{d.day:02d}", numc, 11)}{micro("СЕГОДНЯ", OR) if today else ""}</div>'
    if inm:
        for t, x2, cc in items.get(d.day, [])[:2]:
            cell += f'<div style="display: flex; gap: 5px; align-items: center; margin-top: 4px; font-size: 11px; white-space: nowrap; overflow: hidden">{dot(cc)}<span style="font: 400 9.5px {MONO}; color: {MUT}">{t}</span>{x2}</div>'
        if d.day <= 5:
            fill = 3 if d.day < 5 else 1
            segs = ''.join(f'<span style="flex: 1; height: 3px; border-radius: 2px; background: {GOLD if j < fill else "#45464D"}"></span>' for j in range(3))
            cell += f'<div style="position: absolute; left: 8px; right: 8px; bottom: 6px; display: flex; gap: 2px">{segs}</div>'
        elif d.day > 5:
            cell += f'<div style="position: absolute; left: 8px; right: 8px; bottom: 6px; height: 0; border-top: 1px dashed #45464D"></div>'
    m += f'<div style="position: absolute; left: {x}px; top: {y}px; width: {CWm}px; height: {RH}px; box-sizing: border-box; padding: 6px 8px; {brd} {bgc} overflow: hidden">{cell}</div>'
hub = nhead('', 'НОЯБРЬ 2026', '30 ДНЕЙ · 18 ДЕЛ', OR, MUT, 34, OR, OR) + m
st = toolbar('МЕСЯЦ')
st += node(0, 64, 900, 556, hub, hub=True)
st += daypanel(64, 556, 'ЧТ 05 · СЕГОДНЯ')
st += ab(0, 636, f'<span style="display: flex; align-items: center; gap: 14px">{lbl("ПОЛОСКА ВНИЗУ КЛЕТКИ", DIM)}{micro("ЗОЛОТО — ПРИВЫЧКИ СДЕЛАНЫ", GOLD)}{micro("ПУНКТИР — ЕЩЁ ВПЕРЕДИ", MUT)}</span>', w=900)
st += dimline(0, 664, 900, '26.10 — 06.12 · 6 НЕДЕЛЬ')
st += stamp(968, 636, 'КАЛЕНДАРЬ · МЕСЯЦ', 'ДЕЛ 18', 'ДР 02')
save('G_CalMonth.dc.html', page('Календарь · месяц', 'КАЛЕНДАРЬ', st), 'Календарь · месяц', 0, 940, 'r4')
print('ok')
