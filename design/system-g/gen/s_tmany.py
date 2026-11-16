import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

# «Сегодня», когда задач и списков много: один провод на список, сделанное свёрнуто, группы по сроку
lists = [('Работа · клиенты', BLUE, 4, 9), ('3D-ассеты', OR, 3, 7), ('Тест · канбан', VIO, 2, 7), ('Учёба', VIO, 1, 4),
         ('Дела по дому', GREEN, 1, 5), ('Покупки', GREEN, 0, 3)]
SX, SW = 0, 236
rows = ''
for i, (n, c, left, tot) in enumerate(lists):
    rows += (f'<div style="position: relative; height: 30px; padding: 0 14px 0 12px; display: flex; align-items: center; gap: 8px; border-bottom: 1px solid {SOFT}">'
             f'{dot(c)}<span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{n}</span>'
             f'<span style="font: 400 11px {MONO}; color: {INK if left else DIM}">{left}</span><span style="font: 400 11px {MONO}; color: {DIM}">/ {tot}</span>{sock("r", 10, c)}</div>')
rows += f'<div style="height: 30px; padding: 0 12px; display: flex; align-items: center; gap: 8px; color: {MUT}"><span style="font: 400 11px {MONO}; color: {DIM}">▸</span>Ещё 7 списков · сегодня пусто</div>'
st = colhead(SX, 0, SW, '01 · ИСТОЧНИКИ')
st += node(SX, 22, SW, 0, nhead('', 'СПИСКИ', 'ОСТАЛОСЬ / ВСЕГО', GREY) + rows)
st += node(SX, 290, SW, 0, nhead('', 'ОТ CLAUDE', 'ЖДУТ 13', GREY) + f'<div style="height: 30px; padding: 0 12px; display: flex; align-items: center; color: {MUT}">13 задач без дня</div>', wait=True, extra=sock('r', 39, GREY, True))
st += node(SX, 370, SW, 0, nhead('', 'ПРИВЫЧКИ', '1 / 3', GOLD) + f'<div style="height: 30px; padding: 0 12px; display: flex; align-items: center; color: {MUT}">Зарядка, Вода, Скетч</div>', extra=sock('r', 39, GOLD))

HX, HW = 300, 600
N = [0]
def tr(time, title, lst, c, tc=MUT):
    N[0] += 1
    return (f'<div style="height: 45px; padding: 0 10px; display: flex; align-items: center; gap: 12px; border-bottom: 1px solid {SOFT}">'
            f'<span style="font: 400 10.5px {MONO}; color: {DIM}; width: 16px">{N[0] + 1:02d}</span>{check()}<span style="font: 400 11.5px {MONO}; width: 42px; color: {tc}">{time}</span><span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{title}</span>{dot(c)}</div>')
def more(t, n=''):
    return f'<div style="height: 40px; padding: 0 10px; display: flex; align-items: center; gap: 12px; border-bottom: 1px solid {SOFT}; color: {MUT}"><span style="font: 400 10.5px {MONO}; color: {DIM}; width: 16px; white-space: nowrap">{n}</span><span style="font: 400 11px {MONO}; color: {DIM}; width: 14px">▸</span><span>{t}</span></div>'
body = f'''<div style="padding: 12px 12px 0">
<div style="height: 36px; box-sizing: border-box; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 8px; background: {BG}; border: 1px solid {LINE}; color: {DIM}"><span style="color: {OR}">＋</span><span style="flex: 1">Добавить: «завтра 17:00 рендер щита»</span><span style="font: 400 10px {MONO}; letter-spacing: .1em">SHIFT A</span></div>
<div style="margin-top: 8px; padding: 12px 10px; border-radius: 8px; {hatch()}; border: 1px solid {OR}; display: flex; flex-direction: column; gap: 10px"><div style="display: flex; align-items: center; gap: 12px"><span style="font: 400 10.5px {MONO}; color: {OR}; width: 16px">01</span>{check(c=OR)}<span style="font: 400 11.5px {MONO}; width: 42px; color: {RED}">10.11</span><span style="flex: 1; font-weight: 600; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">Просроченный отчёт за октябрь с очень длинным названием</span><span style="font: 500 10px {MONO}; letter-spacing: .14em; color: {OR}">ДАЛЬШЕ</span></div><div style="padding-left: 96px; display: flex; gap: 6px">{btn("Открыть", "acc", True)}{btn("На завтра", "sec", True)}</div></div>
{tr("12.11", "Сдать показания счётчиков", "ДОМ", GREEN, RED)}
{tr("14.11", "Пропс «Бочка»", "3D", OR, RED)}
{tr("15:00", "Текстуры для щита, 2K", "3D", OR)}
{tr("19:00", "Созвон с клиентом «Таверна»", "РАБОТА", BLUE)}
{tr("ДЕНЬ", "Ответить про сроки", "РАБОТА", BLUE)}
{tr("ДЕНЬ", "Оплатить интернет", "ДОМ", GREEN)}
{more("Ещё 6 задач на день", "＋6")}
{more("Сделано · 8", "✓")}
<div style="margin-top: 10px; height: 38px; box-sizing: border-box; padding: 0 10px; border-radius: 8px; border: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; color: {GREY}"><span style="font: 400 10.5px {MONO}; color: {DIM}">＋13</span><span style="flex: 1">От Claude ждут 13 задач: взять в день?</span>{btn("Принять", "sec", True)}</div>
<div style="margin-top: 12px; padding: 12px 10px 14px; border-top: 1px solid #8A7424; display: flex; flex-direction: column; gap: 10px"><span style="display: flex; justify-content: space-between; font: 500 10.5px {MONO}; letter-spacing: .14em"><span style="color: {GOLD}">ПРИВЫЧКИ</span><span style="color: {DIM}">1 / 3</span></span><div style="display: flex; gap: 6px"><button type="button" style="height: 32px; padding: 0 12px; border-radius: 999px; border: 0; background: {GOLD}; color: {DARK}; font: 600 12.5px {SANS}">✓ Зарядка</button><button type="button" style="height: 32px; padding: 0 12px; border-radius: 999px; border: 1px solid #8A7424; background: transparent; color: {INK}; font: 500 12.5px {SANS}">Вода 5/8</button><button type="button" style="height: 32px; padding: 0 12px; border-radius: 999px; border: 1px solid #8A7424; background: transparent; color: {INK}; font: 500 12.5px {SANS}">Скетч</button></div></div>
</div>'''
hub = nhead('', 'СЕГОДНЯ', '13 ЗАДАЧ · 3 ПРИВЫЧКИ', OR, under=OR, h=34).replace('СЕГОДНЯ</span>', 'СЕГОДНЯ</span><span style="color: rgba(255,255,255,.72)">ПН 16.11</span>', 1)
st += colhead(HX, 0, HW, '02 · СБОРКА ДНЯ')
st += node(HX, 22, HW, 0, hub + body, hub=True, extra=sock('l', 44, INK) + sock('l', 555, GREY, True) + sock('l', 606, GOLD) + sock('r', 74, OR) + sock('r', 606, INK))

paths = ''
for i, (n, c, l, t) in enumerate(lists):
    paths += wire(SW, 22 + 30 + i * 30 + 15, HX, 71, c, 1.5, k=40)
paths += wire(SW, 334, HX, 582, GREY, 1.5, True, 30) + wire(SW, 414, HX, 633, GOLD, 1.5, False, 30)

OX, OW = 960, 288
st += colhead(OX, 0, OW, '03 · ВЫВОД')
st += node(OX, 22, OW, 0, nhead('В1', 'ДАЛЬШЕ', '10.11', OR) + f'<div style="padding: 10px 12px 12px"><div style="font-weight: 600; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">Просроченный отчёт за октябрь…</div><div style="margin-top: 6px; font: 400 10.5px {MONO}; letter-spacing: .08em; color: {MUT}">10.11 · ТЕСТ · КАНБАН</div></div>', extra=sock('l', 10, OR))
st += node(OX, 140, OW, 0, nhead('В2', 'ИТОГ ДНЯ', '', GREY) + f'<div style="padding: 10px 12px 12px; display: flex; flex-direction: column; gap: 8px; font-size: 12.5px"><span style="display: flex; justify-content: space-between"><span>Задачи</span><span style="font-family: {MONO}">8 / 21</span></span><span style="display: flex; justify-content: space-between"><span>Привычки</span><span style="font-family: {MONO}">1 / 3</span></span></div>', extra=sock('l', 10, INK))
paths += wire(HX + HW, 101, OX, 37, OR, 2, k=30) + wire(HX + HW, 633, OX, 155, INK, 1.5, k=30)

notes = [('1', 'Слева не задачи, а списки: строка на список, «осталось / всего». Один провод на список, все в один вход.'),
         ('2', 'Списки, где на сегодня ничего, свёрнуты в одну строку «Ещё N списков».'),
         ('3', 'Середина — как раньше. Видно до 6 задач, остальные под «Ещё N». Сделанное свёрнуто в одну строку.'),
         ('4', 'От Claude — одна строка, без перечня задач.')]
nh = ''.join(f'<div style="display: flex; gap: 8px; margin-bottom: 8px"><span style="font: 500 10.5px {MONO}; color: {OR}">{a}</span><span style="color: {MUT}; font-size: 12px; line-height: 1.45">{b}</span></div>' for a, b in notes)
st += ab(OX, 270, f'<div style="font: 500 10px {MONO}; letter-spacing: .16em; color: {DIM}; margin-bottom: 10px">ЧТО ПОМЕНЯЛОСЬ</div>{nh}', w=OW)
st = svg(paths) + st
save2('G_TodayMany.dc.html', page('Сегодня · много задач', 'СЕГОДНЯ', st, right='ПН 16.11 · 18:30'), 'Сегодня · много задач и списков')
