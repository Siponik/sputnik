import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board, s_cal
K = dim(s_board.KANBAN); W = dim(s_cal.WEEK)

# ---------- DATE & TIME ----------
import datetime
cal = ''.join(f'<span style="text-align: center">{micro(d)}</span>' for d in ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'])
for k in range(35):
    d = datetime.date(2026, 10, 26) + datetime.timedelta(days=k)
    inm = d.month == 11
    if d.day == 6 and inm: st_ = f'background: {OR}; color: {DARK}; font-weight: 600'
    elif d.day == 5 and inm: st_ = f'border: 1px solid {OR}; color: {ORI}'
    else: st_ = f'color: {INK if inm else "#4E5058"}'
    cal += f'<span style="height: 32px; border-radius: 8px; box-sizing: border-box; display: grid; place-items: center; font-size: 13px; {st_}">{d.day}</span>'
busy = {10, 12, 15, 16, 19}
hours = ''
for row, name in enumerate(['Ночь', 'Утро', 'День', 'Вечер']):
    cells = ''
    for h in range(row * 6, row * 6 + 6):
        on = h == 17
        st_ = f'background: {OR}; color: {DARK}; font-weight: 600' if on else f'border: 1px solid {LINE}; color: {INK if h >= 6 else MUT}'
        bar = f'<span style="position: absolute; left: 6px; right: 6px; bottom: 3px; height: 2px; border-radius: 1px; background: {GREY}"></span>' if h in busy else ''
        cells += f'<span style="position: relative; height: 32px; border-radius: 8px; box-sizing: border-box; display: grid; place-items: center; font: 400 12px {MONO}; {st_}">{h:02d}{bar}</span>'
    hours += f'<div style="display: grid; grid-template-columns: 52px repeat(6, minmax(0, 1fr)); gap: 4px; align-items: center"><span style="font-size: 12px; color: {MUT}">{name}</span>{cells}</div>'
body = f'''<div style="padding: 16px 18px; display: grid; grid-template-columns: 260px minmax(0, 1fr); gap: 22px">
 <div style="display: flex; flex-direction: column; gap: 12px">
  <div style="height: 40px; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 12px; font-size: 14px">в пятницу 17:00<span style="display: inline-block; width: 1.5px; height: 18px; background: {OR}; margin-left: 2px"></span></div>
  <div style="font-size: 12px; color: {MUT}">Понял: пятница, 6 ноября, 17:00</div>
  <div style="display: flex; gap: 6px; flex-wrap: wrap">{sc("Сегодня")}{sc("Завтра", True)}{sc("В выходные")}{sc("Через неделю")}{sc("Без срока")}</div>
  <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px"><span style="font-weight: 600">Ноябрь 2026</span><span style="display: flex; gap: 4px">{btn("‹", sm=True)}{btn("›", sm=True)}</span></div>
  <div style="display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 3px">{cal}</div>
 </div>
 <div style="display: flex; flex-direction: column; gap: 10px">
  <span style="font: 500 12.5px {SANS}; color: {MUT}">Время · серая полоска — час уже занят</span>
  {hours}
  <span style="font: 500 12.5px {SANS}; color: {MUT}; margin-top: 6px">Минуты</span>
  <div style="display: flex; gap: 6px; align-items: center">{sc(":00", True)}{sc(":15")}{sc(":30")}{sc(":45")}<span style="margin-left: 10px; font-size: 12px; color: {MUT}">или точно</span><span style="height: 30px; padding: 0 10px; border-radius: 8px; border: 1px solid {STRONG}; display: flex; align-items: center; font: 400 13px {MONO}">17:00</span></div>
  <span style="font: 500 12.5px {SANS}; color: {MUT}; margin-top: 6px">До</span>
  <div style="display: flex; gap: 6px">{sc("Без конца")}{sc("30 мин")}{sc("1 час")}{sc("2 часа · до 19:00", True)}</div>
 </div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 56px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 18px"><span style="font-size: 12.5px; color: {MUT}">Пт, 6 ноября · 17:00—19:00</span><span style="flex: 1"></span>{btn("Отмена")}{btn("Готово", "acc")}</div>'''
st = K + pop(254, 40, 740, 500, 'СРОК · ВЫБОР ДАТЫ И ВРЕМЕНИ', body, OR, 'ПРО «ТЕКСТУРЫ ДЛЯ ЩИТА»', hub=True)
save2('G_DateTime.dc.html', page('Дата и время', 'ДОСКА', st), 'Выбор даты и времени')

# ---------- PICKERS ----------
lp = f'<div style="padding: 8px"><div style="height: 34px; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}">Найти список…</div></div>'
n = 1
for g, c, ls in [('3D и заказы', OR, ['3D-ассеты', 'Иконки для клиента', 'Заказы клиентов']), ('Работа', BLUE, ['Работа · клиенты']), ('Дом', GREEN, ['Дела по дому', 'Покупки']), ('Учёба', VIO, ['Учёба'])]:
    lp += f'<div style="padding: 6px 18px 2px; font-size: 12px; color: {MUT}">{g}</div><div style="padding: 0 8px">'
    for l in ls:
        lp += mrow(l, kbd(str(n)), on=(l == '3D-ассеты'), c=c); n += 1
    lp += '</div>'
lp += f'<div style="margin: 6px 8px 8px; border-top: 1px solid {LINE}; padding-top: 6px">{mrow("＋ Новый список", kbd("N"))}</div>'
cm = '<div style="padding: 6px">' + ''.join(mrow(t, kbd(k), on=(i == 0), icon=ic) for i, (t, k, ic) in enumerate([('Открыть', 'ENTER', '↗'), ('Переименовать', 'F2', '✎'), ('Следующий этап', 'ALT →', '→'), ('Приоритет', 'ALT 1–3', '!'), ('Срок…', 'D', '◷'), ('В другой список…', 'M', '⇄'), ('Дублировать', 'CTRL D', '⧉')])) + f'<div style="border-top: 1px solid {LINE}; margin-top: 4px; padding-top: 4px">{mrow("Удалить", kbd("DEL"), danger=True, icon="✕")}</div></div>'
dd = f'<div style="padding: 8px"><div style="height: 32px; border-radius: 8px; border: 1px solid {STRONG}; background: {BG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}">Поиск</div></div><div style="padding: 0 8px 8px">'
for g, items in [('Сегодня', [('Сегодня', MUT)]), ('Скоро', [('Завтра', MUT), ('Пятница', MUT), ('Выходные', MUT)]), ('Позже', [('Через неделю', MUT), ('Без срока', MUT)])]:
    dd += f'<div style="padding: 6px 10px 2px; font-size: 12px; color: {MUT}">{g}</div>' + ''.join(mrow(t, on=(t == 'Пятница'), right=('✓' if t == 'Пятница' else '')) for t, _ in items)
dd += '</div>'
dd2 = '<div style="padding: 6px">' + ''.join(mrow(t, f'<span style="font: 400 11px {MONO}; color: {DIM}">{cnt}</span>', on=(t == 'В работе'), c=c) for t, cnt, c in [('Входящие', '4', GREY), ('В работе', '2/3', OR), ('На проверке', '1', VIO), ('Готово', '6', GREEN)]) + '</div>'
trig = lambda x, y, w, t, c=OR: f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; height: 34px; box-sizing: border-box; border-radius: 8px; border: 1px solid {c}; background: {NODE}; display: flex; align-items: center; gap: 8px; padding: 0 10px">{t}<span style="margin-left: auto; color: {MUT}">▾</span></div>'
st = K
st += colhead(0, 0, 300, 'ВЫБОР СПИСКА · ALT L')
st += pop(0, 24, 300, 0, 'КУДА ПОЛОЖИТЬ', lp, OR, '7 СПИСКОВ')
st += colhead(330, 0, 260, 'МЕНЮ ЗАДАЧИ · ⋯ ИЛИ ПРАВЫЙ КЛИК')
st += pop(330, 24, 260, 0, 'СОЗВОН «ТАВЕРНА»', cm, BLUE)
st += colhead(620, 0, 300, 'ВЫПАДАЮЩИЙ СПИСОК С ПОИСКОМ')
st += trig(620, 24, 300, 'Срок: пятница')
st += node(620, 64, 300, 0, dd, style=SH)
st += colhead(950, 0, 298, 'ВЫПАДАЮЩИЙ СПИСОК · ЭТАП')
st += trig(950, 24, 298, f'{dot(OR)}В работе')
st += node(950, 64, 298, 0, dd2, style=SH)
st += ab(950, 260, f'<div style="font-size: 12.5px; color: {MUT}; line-height: 19px">Все выпадающие списки одинаковые: точка цвета, счётчик справа, ✓ у выбранного, Esc закрывает только меню. Системных «select» нет.</div>', w=298)
save2('G_Pickers.dc.html', page('Выборы и меню', 'ДОСКА', st), 'Выбор списка, меню задачи, выпадающие списки')

# ---------- SEARCH ----------
hl = lambda a, b, c_: f'{a}<span style="background: rgba(240,160,75,.22); color: {ORI}; border-radius: 3px; padding: 0 2px">{b}</span>{c_}'
res = ''
def grp(t): return f'<div style="padding: 10px 18px 4px; font-size: 12px; color: {MUT}">{t}</div>'
res += grp('Задачи · 3')
for i, (t, l, c, d) in enumerate([(hl('Текстуры для ', 'щит', 'а, 2K'), '3D-ассеты', OR, 'Сегодня 15:00'), (hl('Рендер ', 'щит', 'а'), '3D-ассеты', OR, 'Пт 17:00'), (hl('', 'Щит', ' «Таверны» · сдача'), 'Работа · клиенты', BLUE, '12.11')]):
    bg = f'background: {HOVER};' if i == 0 else ''
    res += f'<div style="margin: 0 8px; height: 40px; border-radius: 8px; {bg} display: flex; align-items: center; gap: 12px; padding: 0 10px">{check()}<span style="flex: 1">{t}</span><span style="display: flex; align-items: center; gap: 6px; font-size: 12px; color: {MUT}">{dot(c)}{l}</span><span style="width: 90px; text-align: right; font: 400 11px {MONO}; color: {MUT}">{d}</span></div>'
res += grp('В заметках · 1')
res += f'<div style="margin: 0 8px; height: 40px; display: flex; align-items: center; gap: 12px; padding: 0 10px; color: #C9CAD0">{check()}<span style="flex: 1">Созвон с клиентом «Таверна» — <span style="color: {MUT}">«…концепты {hl("", "щит", "а")} и меча…»</span></span></div>'
res += grp('Разделы и списки')
res += f'<div style="padding: 0 8px">{mrow("Доска · 3D-ассеты", kbd("ENTER"), c=OR)}{mrow("Календарь", kbd("2"))}</div>'
body = f'''<div style="padding: 14px"><div style="height: 48px; border-radius: 10px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; gap: 10px; padding: 0 14px; font-size: 16px"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="{MUT}" stroke-width="1.8" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4"></path></svg>щит<span style="display: inline-block; width: 1.5px; height: 20px; background: {OR}"></span><span style="margin-left: auto">{kbd("ESC")}</span></div></div>{res}
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 44px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 16px; padding: 0 18px; font-size: 12px; color: {MUT}"><span>{kbd("↑ ↓")} выбрать</span><span>{kbd("ENTER")} открыть</span><span style="margin-left: auto">Ищу в названиях и заметках, ё = е</span></div>'''
st = K + pop(264, 30, 720, 520, 'ПОИСК · CTRL K', body, OR, '4 НАЙДЕНО', hub=True)
save2('G_Search.dc.html', page('Поиск', 'ДОСКА', st), 'Поиск')

# ---------- STATUS & UPDATE ----------
hx = (f'<span style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px; border-radius: 8px; background: {WASH}; border: 1px solid {OR}; color: {ORI}">⏱ 00:42<span style="color: {OR}">■</span></span>'
      f'<span style="display: flex; align-items: center; gap: 6px; height: 32px; padding: 0 10px; border-radius: 8px; border: 1px solid {GOLD}; color: {GOLD}">✦ 0.9.1</span>')
rows = ''
for c, t, s_ in [(GREEN, 'Google Задачи и Календарь', 'Синхронизировано в 14:50'), (GREEN, 'Слой Спутника на Drive', 'Сохранено в 14:51 · второй компьютер видит'), (GREEN, 'Бот в Telegram', 'Работает · сводка завтра в 8:00'), (GOLD, 'Входящие от Claude', 'Две задачи ждут ответа')]:
    rows += f'<div style="display: flex; gap: 12px; padding: 10px 0; border-bottom: 1px solid {SOFT}">{dot(c, 8)}<span><span style="display: block">{t}</span><span style="font-size: 12px; color: {MUT}">{s_}</span></span></div>'
stp = f'<div style="padding: 4px 14px 14px">{rows}<div style="display: flex; gap: 8px; margin-top: 12px">{btn("Синхронизировать сейчас", sm=True)}{btn("Открыть входящие", "ghost", True, "; color: " + OR)}</div></div>'
upd = f'''<div style="padding: 18px 20px; display: flex; flex-direction: column; gap: 14px">
  <div style="display: flex; gap: 14px; align-items: center">{coon(48, "УРА")}<span><span style="display: block; font: 500 20px {SANS}">Вышла версия 0.9.1</span><span style="font-size: 12.5px; color: {MUT}">Сейчас стоит 0.9.0 · бета</span></span></div>
  <div style="font-weight: 600">Что нового</div>
  <ul style="margin: 0; padding-left: 18px; display: flex; flex-direction: column; gap: 8px; color: #DADBE0; line-height: 19px"><li>Новый вид: экран собирается как схема из нод, провода показывают, откуда пришла задача.</li><li>Окно «Создать» стало проще: пишешь как в заметке, остальное подставляется само.</li><li>Привычки со временем видны блоками в календаре.</li></ul>
  <div style="display: flex; gap: 8px; margin-top: 6px">{btn("Обновить сейчас", "acc")}{btn("Вечером")}{btn("Пропустить", "ghost")}</div>
  <div style="font-size: 12px; color: {MUT}">Обновление займёт около минуты, задачи никуда не денутся.</div>
</div>'''
st = K
st += pop(868, 0, 380, 0, 'СОСТОЯНИЕ', stp, GREEN, 'ВСЁ В ПОРЯДКЕ')
st += pop(200, 40, 540, 0, 'ОБНОВЛЕНИЕ', upd, GOLD, '0.9.0 → 0.9.1', hub=True)
st += toast(200, 600, 540, 'Таймер идёт: «Текстуры для щита» · 42 мин', 'Остановить', OR)
save2('G_Status.dc.html', page('Состояние и обновление', 'ДОСКА', st, right='14:52', hx=hx), 'Состояние, обновление, таймер в шапке')

# ---------- FEEDBACK ----------
conf = f'''<div style="padding: 18px 20px; display: flex; flex-direction: column; gap: 12px">
  <div style="font: 500 18px {SANS}">Удалить список «Покупки»?</div>
  <div style="color: #C9CAD0; line-height: 20px">Список и 5 задач в нём удалятся из Google Задач насовсем. Вернуть не получится.</div>
  <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 6px">{btn("Отмена", extra="; outline: 2px solid " + ORI + "; outline-offset: 2px")}<button type="button" style="height: 32px; padding: 0 14px; border-radius: 6px; border: 0; background: {RED}; color: {DARK}; font: 600 13px {SANS}">Удалить список</button></div>
</div>'''
st = W
st += node(0, 0, 1248, 40, f'<div style="height: 100%; display: flex; align-items: center; gap: 10px; padding: 0 14px">{dot(RED, 8)}<span>Нет связи с Google. Работаю без сети, всё отправлю, когда связь вернётся.</span><span style="flex: 1"></span><span style="font-size: 12px; color: {MUT}">повтор через 0:48</span>{btn("Повторить", sm=True)}</div>', wait=True, style=SH)
st += pop(364, 160, 520, 0, 'УДАЛЕНИЕ', conf, RED, 'НАСОВСЕМ')
st += colhead(364, 420, 520, 'ПЛАШКИ ВНИЗУ ЭКРАНА · ИСЧЕЗАЮТ ЧЕРЕЗ 6 С')
st += toast(364, 446, 520, 'Готово · «Ретопология меча»', 'Отменить', GREEN)
st += toast(364, 500, 520, 'Создано в «3D-ассеты»', 'Открыть', OR)
st += toast(364, 554, 520, 'Оля сделала «Купить корм коту»', 'Вернуть', VIO)
st += toast(364, 608, 520, 'Тебе отдали задачу «Бриф: броня»', 'Открыть', BLUE)
st += ab(920, 446, f'<div style="display: flex; gap: 12px; align-items: flex-start; padding: 12px; border-radius: 10px; border: 1px dashed #55575F; background: {NODE}">{coon(44, "ОЙ")}<span style="font-size: 12.5px; line-height: 19px; color: #C9CAD0">Знак спутника краснеет, когда пропала связь с Google. Колонки и задачи остаются на месте.</span></div>', w=300)
save2('G_Feedback.dc.html', page('Плашки и подтверждения', 'КАЛЕНДАРЬ', st), 'Удаление, плашки, «нет связи»')
print('ok')
