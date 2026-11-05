import sys, os, re; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board, s_cal
DIMK = dim(s_board.KANBAN, .25)

def inp(t, w='100%', on=False, h=36):
    return f'<span style="width: {w}; height: {h}px; box-sizing: border-box; border-radius: 8px; border: {"1.5px solid " + OR if on else "1px solid " + STRONG}; background: {BG}; display: inline-flex; align-items: center; padding: 0 12px">{t}</span>'

# ---------------- SETTINGS: shared sidebar ----------------
TABS = ['Вид', 'Что показывать', 'Напоминания', 'Синхронизация', 'Обновления', 'Клавиши']
def sside(active):
    th = f'<div style="margin: 10px; height: 32px; border-radius: 8px; border: 1px solid {STRONG}; display: flex; align-items: center; padding: 0 10px; color: {MUT}; font-size: 12.5px">Найти настройку</div>'
    for i, t in enumerate(TABS):
        on = i == active
        th += f'<div style="margin: 0 8px 2px; height: 36px; border-radius: 8px; {"background:" + WASH + "; border: 1px solid " + OR if on else "border: 1px solid transparent"}; display: flex; align-items: center; gap: 10px; padding: 0 10px"><span style="font: 400 10px {MONO}; color: {DIM}">0{i + 1}</span><span style="color: {INK if on else "#C9CAD0"}; font-weight: {600 if on else 400}">{t}</span></div>'
    return node(0, 0, 240, 700, nhead('', 'НАСТРОЙКИ', 'CTRL ,', None) + th + f'<div style="position: absolute; left: 12px; bottom: 12px">{micro("СПУТНИК 0.9.0 · БЕТА", DIM)}</div>')

def sect(x, y, w, h, num, title, kind, color, rows, hub=False):
    return node(x, y, w, h, nhead(num, title, kind, color, None, 34, INK, OR if hub else LINE) + f'<div style="padding: 4px 20px 10px">{rows}</div>', hub=hub)

# Reminders
sel = lambda opts, on: ''.join(sc(o, o == on) for o in opts)
rem = (srow('Задачи', 'Если у задачи не выбрано своё', sel(['В момент', 'За 15 мин', 'За час', 'За день'], 'За час'))
       + srow('События', '', sel(['За 15 мин', 'За час', 'За день'], 'За 15 мин'))
       + srow('Дни рождения', '', sel(['В день', 'За день', 'За неделю'], 'За день'))
       + srow('Задачи без времени', 'Во сколько напоминать, если есть только дата', inp('10:00', '84px') + sc('Не напоминать')))
tg = (srow('Telegram · @SputnikTasksBot', 'Привязан · пишет в чат «Siponik»', f'{btn("Проверить", sm=True)}{toggle(True)}')
      + srow('Свой бот (Apps Script)', 'Видно только тебе как владельцу', toggle(False))
      + srow('Уведомления Windows', 'Задачи, привычки в своё окно, «тебе отдали задачу»', toggle(True))
      + f'<div style="display: flex; gap: 10px; align-items: center; padding: 12px 0 2px; font-size: 12.5px; color: {MUT}">Не привязан? Напиши боту /start и введи код из 6 цифр {inp("_ _ _ _ _ _", "130px", h=32)}</div>')
st = sside(2) + sect(264, 0, 984, 310, '03', 'НАПОМИНАНИЯ · ПО УМОЛЧАНИЮ', 'МОЖНО ПОМЕНЯТЬ В «СОЗДАТЬ»', OR, rem, hub=True)
st += sect(264, 330, 984, 290, '', 'КУДА ПРИСЫЛАТЬ', '', BLUE, tg)
st += ab(264, 636, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 560px; box-sizing: border-box">{coon(44, "ПРИВЕТ")}<span style="font-size: 12.5px; color: #C9CAD0">Под напоминанием в Telegram есть «✓ Готово», «На завтра» и «Через час» — отвечать можно прямо там.</span></div>')
save2('G_SetRemind.dc.html', page('Настройки · напоминания', '', st), 'Настройки · напоминания и бот')

# Sync
bk = ''.join(f'<div style="display: flex; align-items: center; gap: 10px; height: 34px; border-bottom: 1px solid {SOFT}"><span style="font: 400 12px {MONO}; color: {MUT}">{d}</span><span style="flex: 1">{t}</span><span style="font-size: 12px; color: {DIM}">{s}</span></div>' for d, t, s in [('05.11', 'layer-2026-11-05.json', '142 КБ'), ('04.11', 'layer-2026-11-04.json', '140 КБ'), ('03.11', 'layer-2026-11-03.json', '139 КБ')])
syn = (srow('Google · siponik…', 'Задачи и календари · синхронизация раз в 2 минуты', f'<span style="display: inline-flex; align-items: center; gap: 6px; color: {GREEN}">{dot(GREEN, 8)}на связи · 14:51</span>{btn("Обновить сейчас", sm=True)}')
       + srow('Слой Спутника между компьютерами', 'Статусы, типы, привычки — через скрытую папку Google Drive', f'<span style="color: {GREEN}">2 компьютера</span>{toggle(True)}')
       + srow('Доступы Google', 'Если что-то перестало сохраняться', btn('Войти заново', sm=True)))
dup = f'''<div style="padding: 12px 0; display: flex; flex-direction: column; gap: 8px">
 <span style="color: #C9CAD0">Нашёл 2 одинаковые задачи с одним сроком. Оставлю копию, где больше полей.</span>
 <div style="display: flex; gap: 10px; align-items: center; padding: 8px 10px; border-radius: 8px; background: {HOVER}">{check(True, OR)}<span style="flex: 1">Полить цветы · пт 06</span><span style="font-size: 12px; color: {MUT}">Дела по дому · копия 2</span></div>
 <div style="display: flex; gap: 10px; align-items: center; padding: 8px 10px; border-radius: 8px; background: {HOVER}">{check(True, OR)}<span style="flex: 1">Зарядка · чт 05</span><span style="font-size: 12px; color: {MUT}">Привычки · копия 2</span></div>
 <div style="display: flex; gap: 8px; margin-top: 4px">{btn("Удалить отмеченные · 2", "acc", True)}{btn("Не сейчас", "ghost", True)}</div></div>'''
st = sside(3) + sect(264, 0, 984, 230, '04', 'СИНХРОНИЗАЦИЯ', 'ИСТОЧНИК ПРАВДЫ — GOOGLE', OR, syn, hub=True)
st += sect(264, 250, 480, 250, '', 'РЕЗЕРВНЫЕ КОПИИ', 'РАЗ В ДЕНЬ · 14 ШТ', GREEN, f'<div style="padding-top: 8px">{bk}</div><div style="display: flex; gap: 8px; margin-top: 14px">{btn("Открыть папку", sm=True)}{btn("Вернуть из копии…", "ghost", True)}</div>')
st += sect(768, 250, 480, 250, '', 'ДУБЛИ ЗАДАЧ', '2 НАЙДЕНО', GOLD, dup)
save2('G_SetSync.dc.html', page('Настройки · синхронизация', '', st), 'Настройки · синхронизация, копии, дубли')

# Updates + keys
upd = (srow('Версия 0.9.0', 'Последняя проверка сегодня в 14:30', btn('Проверить', sm=True))
       + srow('Ставить обновления', '', sel(['Сразу', 'Ночью', 'Спрашивать'], 'Ночью'))
       + srow('Бета-версии', 'Новые функции раньше. Обычный релиз встанет поверх сам', toggle(True)))
notes = f'''<div style="margin-top: 12px; padding: 12px 14px; border-radius: 10px; background: {WASH}; border: 1px solid {ORL}">
 <div style="display: flex; align-items: center; gap: 8px"><span style="font-weight: 600">Вышла 0.9.1</span><span style="font-size: 12px; color: {MUT}">· что нового</span></div>
 <ul style="margin: 8px 0 10px; padding-left: 18px; color: #C9CAD0; line-height: 20px"><li>Ноды и провода на всех экранах</li><li>Цветные заголовки по сферам</li></ul>
 <div style="display: flex; gap: 8px">{btn("Обновить сейчас", "acc", True)}{btn("Вечером", sm=True)}{btn("Пропустить", "ghost", True)}</div></div>'''
KEYS = [('Создать', 'N  ·  CTRL N'), ('Найти', 'CTRL K  ·  /'), ('Разделы', '1—4  ·  Q / E'), ('Списки', '[  ]'), ('Архив', 'F'), ('Колонка слева', 'CTRL B'), ('Этап задачи', 'ALT ← →'), ('Приоритет', 'ALT 1 2 3 0'), ('Исполнитель', 'I'), ('Привычки', 'SHIFT 1…9'), ('Календарь', 'T  W  M  ← →'), ('Настройки', 'CTRL ,')]
kh = ''.join(f'<div style="display: flex; align-items: center; height: 32px; border-bottom: 1px solid {SOFT}"><span style="flex: 1">{t}</span>{kbd(k)}</div>' for t, k in KEYS)
st = sside(4) + sect(264, 0, 560, 420, '05', 'ОБНОВЛЕНИЯ', 'БЕТА-КАНАЛ', OR, upd + notes, hub=True)
st += sect(848, 0, 400, 470, '06', 'КЛАВИШИ', 'РАБОТАЮТ В РУССКОЙ РАСКЛАДКЕ', GREY, kh)
st += ab(264, 440, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 560px; box-sizing: border-box">{coon(44, "УРА")}<span style="font-size: 12.5px; color: #C9CAD0">Вниз по версии не откатываюсь: выключишь бету — вернёшься на обычную со следующим релизом.</span></div>')
save2('G_SetUpdate.dc.html', page('Настройки · обновления', '', st), 'Настройки · обновления и клавиши')

# ---------------- TASK WINDOW · MORE ----------------
def prow(label, inner):
    return f'<div style="display: grid; grid-template-columns: 96px minmax(0, 1fr); gap: 10px; align-items: center; min-height: 30px"><span style="font-size: 12.5px; color: {MUT}">{label}</span><div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center">{inner}</div></div>'
cols = ''.join(f'<span style="width: 24px; height: 24px; border-radius: 6px; background: {c}{"; box-shadow: 0 0 0 2px " + NODE + ", 0 0 0 3.5px " + INK if i == 1 else ""}"></span>' for i, c in enumerate([GREY, OR, BLUE, VIO, GREEN, GOLD]))
chg = ''.join(f'<div style="display: flex; gap: 10px; align-items: center; height: 30px">{av(*w, 18)}<span style="flex: 1; font-size: 12.5px; color: #C9CAD0">{t}</span><span style="font: 400 10.5px {MONO}; color: {DIM}">{d}</span></div>' for w, t, d in [(('А', GREEN), 'Аня отдала задачу тебе', '14:20'), (('С', OR), 'Ты создал задачу', '02.11')])
tp = f'''<div style="height: 46px; box-sizing: border-box; padding: 0 12px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; border-radius: 11px 11px 0 0; background: {FILL[VIO]}">
  <span style="font-size: 12.5px; color: rgba(255,255,255,.7)">Куда</span><span style="display: inline-flex; align-items: center; gap: 8px; height: 28px; padding: 0 10px; border-radius: 6px; background: rgba(255,255,255,.14); color: #FFFFFF">Таверна · заказ<span>▾</span></span>
  <span style="flex: 1"></span><span style="color: #FFFFFF; font-size: 16px">⋯</span><span style="color: #FFFFFF; font-size: 15px; margin-left: 8px">✕</span></div>
<div style="padding: 14px 18px; display: flex; flex-direction: column; gap: 12px">
  <div style="font: 500 22px/28px {SANS}">Логотип «Таверна»</div>
  <div style="padding: 12px; border-radius: 10px; background: {HOVER}; display: flex; flex-direction: column; gap: 8px">
    {prow("Кто делает", f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px 0 4px; border-radius: 999px; border: 1px solid {OR}">{av("С", OR, 22)}Я<span style="color: {MUT}">▾</span></span>{kbd("I")}')}
    {prow("Колонка", sc("Входящие") + sc("В работе 2/3", True) + sc("Проверка") + sc("✓"))}
    {prow("Приоритет", sc("Высокий", True, RED) + sc("Обычный") + sc("Низкий"))}
    {prow("Срок", sc("Сегодня · 16:00", True) + sc("За час", True, OR, True) + sc("＋"))}
  </div>
  <div style="border-top: 1px solid {LINE}; padding-top: 12px; display: flex; flex-direction: column; gap: 12px">
    <span style="font-weight: 600">▾ Ещё</span>
    {prow("Повтор", sc("Нет") + sc("Каждый день") + sc("Каждую неделю", True) + sc("Месяц"))}
    {prow("Цвет", cols + f'<span style="font-size: 12px; color: {MUT}; margin-left: 6px">Творческое</span>')}
    {prow("Картинка", f'<span style="width: 110px; height: 56px; border-radius: 8px; background: linear-gradient(135deg, #3B2E24, #5A3F28); border: 1px solid {ORL}; display: grid; place-items: end start; padding: 6px; box-sizing: border-box; font-size: 11px; color: {ORI}">logo_v2.png</span><span style="display: flex; flex-direction: column; gap: 6px">{btn("Заменить", sm=True)}{btn("Убрать", "ghost", True)}</span>')}
  </div>
  <div style="border-top: 1px solid {LINE}; padding-top: 12px"><span style="font-size: 12.5px; color: {MUT}">Изменения</span>{chg}</div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 40px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 8px; padding: 0 14px; font-size: 12.5px; color: {MUT}">{dot(GREEN)}Сохранено · общая сфера</div>'''
st = dim(s_board.KANBAN, .25) + node(744, 0, 504, 700, tp, hub=True)
save2('G_TaskMore.dc.html', page('Окно задачи · ещё', 'ДОСКА', st), 'Окно задачи · «Ещё», исполнитель, изменения')

# ---------------- CALENDAR · ADD TO DAY ----------------
form = f'''<div style="padding: 16px; display: flex; flex-direction: column; gap: 14px">
 {field("Что добавить", inp("Ретопология шлема", on=True, h=40))}
 {field("Это", sc("Задача", True) + sc("Событие"))}
 {field("Когда", sc("Чт 5 ноября · 17:00 – 18:00", True, OR, True) + sc("Весь день"))}
 {field("Список", f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}">{dot(OR, 8)}3D-ассеты<span style="color: {MUT}">▾</span></span>')}
 <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 4px">{btn("Отмена", "ghost", True)}{btn("Добавить", "acc", True)}</div>
</div>'''
W = s_cal.WEEK
st = dim(W, .35)
# draft block in grid (thursday column, 17:00)
st += f'<div style="position: absolute; left: 416px; top: 452px; width: 112px; height: 58px; box-sizing: border-box; border-radius: 6px; border: 1.5px dashed {OR}; background: rgba(240,160,75,.14); padding: 4px 8px; font-size: 12px; color: {ORI}"><b style="font-weight: 600">+ 17:00</b><br>Ретопология шлема</div>'
st += svg(wire(528, 481, 900, 300, OR, 1.5, True, k=80))
st += pop(900, 150, 348, 400, 'ЧТ 05 · ДОБАВИТЬ НА ЭТОТ ДЕНЬ', form, OR, 'ENTER', hub=True)
st += ab(900, 570, f'<div style="display: flex; gap: 10px; align-items: center; padding: 10px; border-radius: 8px; border: 1px dashed #8A7424; width: 348px; box-sizing: border-box">{coon(40, "ДУМАЕТ")}<span style="font-size: 12.5px; color: #C9CAD0">Клик по пустому часу открывает эту форму. Esc — убрать черновик.</span></div>')
save2('G_CalAdd.dc.html', page('Календарь · добавить', 'КАЛЕНДАРЬ', st), 'Календарь · клик по часу и форма дня')

# ---------------- LIGHT THEME ----------------
LIGHT = {'#191A1E': '#EEECE7', '#1C1D21': '#F6F4F0', '#25262B': '#FFFFFF', '#2C2D33': '#F1EFEA', '#3A3B42': '#DCD9D2', '#303137': '#E8E5DF',
         '#6E7079': '#A7A49D', '#E2E3E8': '#1F2024', '#9A9CA6': '#5F616A', '#7A7C86': '#7E8089', '#F0A04B': '#C96F1C', '#FFD29C': '#8A4A10',
         '#2E2722': '#FBEBDC', '#6A5238': '#E6C7A3', '#6FA2F2': '#3C74D2', '#B48CF0': '#8457D0', '#7FD18C': '#3C9A4D', '#E8C65A': '#B08A17',
         '#A3A5AE': '#6E707A', '#F0785F': '#CF5139', '#62646E': '#8A8C95', '#8A8C96': '#6A6C75', '#55575F': '#B6B3AC', '#45464D': '#CBC8C1',
         '#36373D': '#E2DFD8', '#7C7E88': '#7C7E88', '#8A7424': '#C9AE5A', '#C9CAD0': '#3E4048', '#B5B7C0': '#4A4C54', '#D8C2A5': '#7A5A36',
         '#2B2520': '#FBEFE3', '#3F352B': '#E9D3B8', '#DADBE0': '#33353C'}
def lighten(h):
    h = re.sub(r'#[0-9A-Fa-f]{6}\b', lambda m: LIGHT.get(m.group(0).upper(), m.group(0)), h)
    return h.replace('rgba(255,255,255,.07)', 'rgba(0,0,0,.09)').replace('rgba(0,0,0,.45)', 'rgba(60,50,40,.16)')
src = open(P + 'G_Today.dc.html').read()
lt = lighten(src)
save2('G_TodayLight.dc.html', lt, 'Сегодня · светлая тема')
print('ok')
