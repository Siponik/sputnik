# Знания: граф вблизи (переделан), уровни приближения, состояния, окна. Запуск после s_notes.py: python3 s_notes2.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from s_notes import *

def nn(x, y, w, title, folder, body, sl=(), sr=(), hub=False, h=0, wait=False):
    c = FC[folder]
    inner = nhead('', title.upper(), folder.upper(), c, None, 28, INK, OR if hub else LINE)
    inner += f'<div style="padding: 8px 12px 10px; font-size: 12px; line-height: 18px; color: #C9CAD0">{body}</div>'
    ex = ''.join(sock('l', t, c) for t in sl) + ''.join(sock('r', t, c) for t in sr)
    return node(x, y, w, h, inner, hub=hub, extra=ex, wait=wait)

def wlab(x, y, t, c=MUT):
    return ab(x, y, f'<span style="font: 400 10px {MONO}; letter-spacing: .08em; color: {c}; background: {GROUND}; padding: 1px 5px; border-radius: 3px">{t}</span>')

def fdot(x, y, c, r=5, o=.45, label=''):
    l = f'<span style="position: absolute; left: -30px; top: 24px; white-space: nowrap; font-size: 11px; color: {MUT}">{label}</span>' if label else ''
    return f'<span style="position: absolute; left: {x - r}px; top: {y - r}px; width: {r * 2}px; height: {r * 2}px; border-radius: 50%; background: {c}; opacity: {o}">{l}</span>'

ZSEG = lambda a: seg(['×1 ТОЧКИ', '×2 НАЗВАНИЯ', '×3 НОДЫ'], a)

# =================== 3. ГРАФ ВБЛИЗИ ===================
top = f'''<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{lbl("ГРАФ ЗНАНИЙ · ВБЛИЗИ", INK)}{micro("ТОЧКИ РАСКРЫЛИСЬ В НОДЫ · ССЫЛКИ [[…]] — ПРОВОДА", MUT)}
<span style="flex: 1"></span>{micro("МАСШТАБ", DIM)}{ZSEG("×3 НОДЫ")}<span style="width: 1px; height: 20px; background: {LINE}"></span>{btn("Свернуть в точки", "ghost", True)}{btn("Весь граф", sm=True)}</div>'''
st = node(0, 0, 1248, 48, top)
# дальние точки — ещё не раскрыты
far = [(330, 92, OR), (372, 120, OR), (816, 80, OR), (1214, 250, GREEN), (1226, 286, GREEN), (1196, 318, GREEN), (1238, 470, BLUE), (1226, 430, BLUE)]
fl = ''.join(f'<path d="M{a[0]} {a[1]} L{b[0]} {b[1]}" stroke="#45464D" stroke-width="1" opacity=".6"></path>' for a, b in [(far[0], far[1]), (far[3], far[4]), (far[4], far[5]), (far[6], far[7])])
w = fl
w += wire(270, 149, 439, 275, OR, 2) + wire(270, 349, 439, 295, OR, 2) + wire(270, 509, 439, 315, OR, 2)
w += wire(761, 275, 929, 139, OR, 2) + wire(761, 295, 929, 309, GREEN, 2) + wire(761, 315, 929, 447, OR, 1.5, True) + wire(761, 335, 929, 587, GREY, 1.5, True)
w += wire(1171, 309, 1214, 286, GREEN, 1.5, True, k=20)
w += vwire(560, 430, 520, 520, '#55575F', 1.2) + vwire(640, 430, 690, 520, '#55575F', 1.2)
st += svg(w)
for x, y, c in far:
    st += fdot(x, y, c)
st += fdot(1214, 286, GREEN, 7, .9, '+5 заметок')
st += nn(40, 90, 230, 'Пайплайн ассета', '3D', '1. Блокинг<br>2. Хай-поли<br>3. Ретопология, UV<br>4. ' + wl('Запекание') + ' →', sr=[54])
st += nn(40, 290, 230, 'UV без растяжений', '3D', 'Швы по естественным краям. Плотность одна на весь ассет.', sr=[54])
st += nn(40, 450, 230, 'Щит паладина', '3D', f'<div style="display: flex; gap: 10px; align-items: center">{thumb("64px", 48, OR)}<span>Ассет · этап «Рендер»<br><span style="color: {MUT}">задача в Спутнике</span></span></div>', sr=[54])
hub = f'''<div style="display: flex; gap: 8px; align-items: center; margin-bottom: 8px">{chip("ТЕХНИКА", True)}{micro("3D / ТЕХНИКИ", DIM)}</div>
Кейдж чуть больше модели, сглаживание одной группой, сначала низкий полигонаж.
<div style="margin-top: 8px; display: flex; gap: 6px">{tag("baking")}{tag("substance")}</div>
<div style="margin-top: 12px; padding-top: 8px; border-top: 1px solid {SOFT}; display: flex; align-items: center; gap: 10px">{micro("↔ 11 СВЯЗЕЙ", OR)}<span style="flex: 1"></span>{kbd("ENTER")}<span style="font-size: 11.5px; color: {MUT}">открыть</span>{kbd("L")}<span style="font-size: 11.5px; color: {MUT}">локальный</span></div>'''
st += nn(440, 230, 320, 'Запекание нормалей', '3D', hub, sl=[40, 60, 80], sr=[40, 60, 80, 100], hub=True, h=200)
st += dimline(440, 200, 320, 'ВЫБРАНА · ГЛАВНАЯ НОДА')
st += nn(930, 80, 240, 'Умные маски Substance', '3D', 'Грязь по кривизне, края по AO.', sl=[54])
st += nn(930, 250, 240, 'Курс: текстуры', 'Учёба', 'Урок 6 — запекание. Домашка: щит.', sl=[54], sr=[54])
st += ab(930, 420, f'<div style="width: 240px; box-sizing: border-box; border-radius: 8px; border: 1.5px dashed #55575F; padding: 10px 12px; color: {MUT}"><div style="font: 500 10.5px {MONO}; letter-spacing: .14em">СПРАВОЧНИК ПО КЕЙДЖАМ</div><div style="font-size: 12px; margin-top: 4px">Заметки ещё нет · <span style="color: {OR}">Создать</span></div></div>')
st += ab(930, 560, f'<div style="width: 240px; box-sizing: border-box; border-radius: 8px; border: 1px dashed {GREY}; background: {NODE}; padding: 10px 12px"><div style="font: 500 10.5px {MONO}; letter-spacing: .14em; color: {INK}">ПРАЙС НА АССЕТЫ</div><div style="font-size: 12px; margin-top: 4px; color: {MUT}">Упомянута без ссылки · <span style="color: {OR}">Связать</span></div></div>')
st += wlab(830, 292, '#КЕЙДЖ', GREEN)
st += wlab(830, 470, 'НЕТ ФАЙЛА')
st += wlab(830, 548, 'БЕЗ ССЫЛКИ')
for x, t in [(470, 'baking'), (640, 'substance')]:
    st += ab(x, 520, f'<span style="display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 10px; border-radius: 999px; border: 1px solid #55575F; background: {NODE}; font: 400 11px {MONO}; color: {MUT}">#{t}</span>')
st += ab(300, 600, f'<div style="display: flex; gap: 12px; align-items: center; padding: 10px 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 560px; box-sizing: border-box">{coon(40, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Колёсико — ближе или дальше: ноды снова станут точками. Перетащи ноду — граф подстроится. Провод из сокета в пустоту — новая ссылка.</span></div>')
st += stamp(968, 640, 'ГРАФ · ВБЛИЗИ', '×3', '9 НОД')
save3('G_NotesGraphNear.dc.html', page('Граф вблизи', 'ЗНАНИЯ', st, R), 'Знания · граф вблизи: ноды и провода', 2)

# =================== 3б. УРОВНИ ПРИБЛИЖЕНИЯ ===================
st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ГРАФ · КАК ТОЧКИ СТАНОВЯТСЯ НОДАМИ", INK)}{micro("ОДНИ И ТЕ ЖЕ 6 ЗАМЕТОК НА ТРЁХ МАСШТАБАХ · ПЕРЕХОД ПЛАВНЫЙ, 220 МС", MUT)}</div>', w=1248)
PW = 396; PG = 30
pts = [(0.5, 0.45, OR, 'Запекание нормалей', True), (0.2, 0.22, OR, 'Пайплайн ассета', False), (0.18, 0.72, OR, 'UV без растяжений', False), (0.8, 0.2, OR, 'Умные маски', False), (0.82, 0.7, GREEN, 'Курс: текстуры', False), (0.52, 0.86, GREY, 'Справочник', False)]
for i, (lv, cap, sub) in enumerate([('×1 ТОЧКИ', 'Вся база', 'Размер — число связей, цвет — папка. Подписи только у крупных.'),
                                    ('×2 НАЗВАНИЯ', 'Район графа', 'Точка вырастает в шапку ноды цвета папки с названием.'),
                                    ('×3 НОДЫ', 'Рядом', 'Шапка + первые строки + теги, ссылки — провода с сокетами.')]):
    x0 = i * (PW + PG); y0 = 40; H = 486
    inner = ''
    W2, H2 = PW - 2, H - 92
    lines = ''
    for j in range(1, 6):
        a, b = pts[0], pts[j]
        c = b[2] if b[2] != GREY else '#55575F'
        if i < 2:
            lines += f'<path d="M{a[0]*W2:.0f} {a[1]*H2:.0f} L{b[0]*W2:.0f} {b[1]*H2:.0f}" stroke="{c}" stroke-width="{1 + i * .5}" {"stroke-dasharray=\"4 4\"" if b[2] == GREY else ""} opacity=".8"></path>'
        else:
            x1, y1, x2, y2 = a[0]*W2, a[1]*H2, b[0]*W2, b[1]*H2
            k = 40
            if x2 < x1: x1, x2, y1, y2 = x2, x1, y2, y1
            lines += f'<path d="M{x1:.0f} {y1:.0f} C {x1+k:.0f} {y1:.0f}, {x2-k:.0f} {y2:.0f}, {x2:.0f} {y2:.0f}" stroke="{c}" stroke-width="1.8" fill="none" {"stroke-dasharray=\"4 4\"" if b[2] == GREY else ""}></path>'
    if i == 0:
        extra = ''.join(f'<path d="M{x*W2:.0f} {y*H2:.0f} L{x2*W2:.0f} {y2*H2:.0f}" stroke="#3A3B42" stroke-width="1"></path>' for x, y, x2, y2 in [(.05,.1,.2,.22),(.9,.45,.8,.2),(.95,.9,.82,.7),(.35,.95,.52,.86)])
        lines = extra + lines
    inner += f'<svg width="{W2}" height="{H2}" style="position: absolute; left: 0; top: 0" fill="none" aria-hidden="true">{lines}</svg>'
    for (px, py, c, name, main) in pts:
        cx, cy = px * W2, py * H2
        if i == 0:
            r = 9 if main else 5
            inner += f'<span style="position: absolute; left: {cx - r:.0f}px; top: {cy - r:.0f}px; width: {r*2}px; height: {r*2}px; border-radius: 50%; background: {c if c != GREY else "transparent"}; {"border: 1.5px dashed " + DIM + ";" if c == GREY else ""} box-sizing: border-box{"; box-shadow: 0 0 0 3px " + GROUND + ", 0 0 0 4.5px " + OR if main else ""}"></span>'
            if main:
                inner += f'<span style="position: absolute; left: {cx + 14:.0f}px; top: {cy - 8:.0f}px; font-size: 11.5px; color: {INK}">{name}</span>'
            for (fx, fy) in [(.05,.1),(.9,.45),(.95,.9),(.35,.95)]:
                inner += f'<span style="position: absolute; left: {fx*W2-3:.0f}px; top: {fy*H2-3:.0f}px; width: 6px; height: 6px; border-radius: 50%; background: #55575F"></span>'
        elif i == 1:
            fill = FILL.get(c, FILL[GREY]) if c != GREY else 'transparent'
            wdt = 150 if main else 118
            bd = f'border: 1px dashed {DIM}; color: {MUT}' if c == GREY else f'background: {HUBFILL if main else fill}; color: #FFFFFF'
            inner += f'<span style="position: absolute; left: {min(max(cx - wdt/2, 8), W2 - wdt - 8):.0f}px; top: {cy - 12:.0f}px; width: {wdt}px; height: 24px; box-sizing: border-box; border-radius: 6px; {bd}; display: flex; align-items: center; padding: 0 8px; font: 500 9.5px {MONO}; letter-spacing: .1em; white-space: nowrap; overflow: hidden{"; box-shadow: 0 0 0 2px " + GROUND + ", 0 0 0 3.5px " + OR if main else ""}">{name.upper()}</span>'
        else:
            wdt = 170 if main else 128
            hh = 78 if main else 54
            if c == GREY:
                inner += f'<span style="position: absolute; left: {min(max(cx - wdt/2, 8), W2 - wdt - 8):.0f}px; top: {cy - 20:.0f}px; width: {wdt}px; box-sizing: border-box; border-radius: 8px; border: 1.5px dashed #55575F; background: {GROUND}; padding: 6px 8px; font: 500 9px {MONO}; letter-spacing: .1em; color: {MUT}">СПРАВОЧНИК<br><span style="font: 400 11px {SANS}; letter-spacing: 0; color: {OR}">Создать</span></span>'
                continue
            fill = HUBFILL if main else FILL[c]
            body = 'Кейдж, сглаживание…<br>' + tag('baking') if main else 'Первые строки…'
            inner += (f'<span style="position: absolute; left: {min(max(cx - wdt/2, 8), W2 - wdt - 8):.0f}px; top: {cy - hh/2:.0f}px; width: {wdt}px; height: {hh}px; box-sizing: border-box; border-radius: {12 if main else 8}px; background: {NODE}; border: 1px solid {ORL if main else LINE}; overflow: hidden{"; box-shadow: 0 10px 24px rgba(0,0,0,.4)" if main else ""}">'
                      f'<span style="display: block; height: 22px; background: {fill}; padding: 0 8px; font: 500 9px/22px {MONO}; letter-spacing: .1em; color: #FFFFFF; white-space: nowrap; overflow: hidden">{name.upper()}</span>'
                      f'<span style="display: block; padding: 5px 8px; font-size: 10.5px; line-height: 15px; color: #C9CAD0">{body}</span></span>')
    panel = (nhead(f'0{i + 1}', lv, cap.upper(), OR if i == 2 else GREY, None, 32, INK, OR if i == 2 else LINE)
             + f'<div style="position: relative; height: {H2}px; margin: 0; {GRID}; border-bottom: 1px solid {LINE}">{inner}</div>'
             + f'<div style="padding: 10px 14px; font-size: 12.5px; line-height: 18px; color: #C9CAD0">{sub}</div>')
    st += node(x0, y0, PW, H, panel, hub=(i == 2))
    if i < 2:
        st += ab(x0 + PW + 2, y0 + 230, f'<span style="font: 500 14px {MONO}; color: {OR}">→</span>')
st += dimline(0, 546, 1248, 'КОЛЁСИКО ИЛИ CTRL ＋ / −  ·  ДВОЙНОЙ КЛИК ПО ТОЧКЕ — СРАЗУ ×3 ВОКРУГ НЕЁ')
st += ab(0, 584, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 700px; box-sizing: border-box">{coon(44, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Ноды раскрываются только там, куда смотришь: дальше от центра экрана остаются точки, поэтому граф из тысяч заметок не тормозит.</span></div>')
st += stamp(968, 610, 'ГРАФ · МАСШТАБЫ', '×1 ×2 ×3', '6 ЗАМЕТОК')
save3('G_NotesZoom.dc.html', page('Граф · масштабы', 'ЗНАНИЯ', st, R), 'Знания · граф: точки → названия → ноды', 7)

# =================== 8. СОСТОЯНИЯ ===================
def card(x, y, w, h, num, title, kind, color, body, wait=False):
    return node(x, y, w, h, nhead(num, title, kind, color, None, 32, INK, LINE) + f'<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 12px">{body}</div>', wait=wait)
t2 = lambda a, b: f'<div><div style="font: 500 16px {SANS}">{a}</div><div style="margin-top: 4px; font-size: 12.5px; line-height: 18px; color: {MUT}">{b}</div></div>'
CW, CH = 400, 330
s1 = (f'<div style="display: flex; gap: 14px; align-items: center">{coon(56, "ПРИВЕТ")}{t2("Где лежат твои заметки?", "Подключи папку с файлами .md — например, хранилище Obsidian. Файлы останутся твоими и на месте.")}</div>'
      + f'<div style="display: flex; gap: 8px">{btn("Выбрать папку…", "acc")}{btn("Создать новую")}</div>'
      + f'<div style="padding: 10px 12px; border-radius: 8px; background: {WASH}; border: 1px solid {ORL}; font-size: 12.5px; line-height: 18px">Нашёл «Obsidian-Vault» в Документах: 152 заметки. <span style="color: {OR}; font-weight: 600">Подключить</span></div>')
s2 = (f'<div style="display: flex; gap: 14px; align-items: center">{coon(56, "СОН")}{t2("В «Работе» пока пусто", "Новая заметка ляжет сюда. Можно взять заготовку из папки «Шаблоны».")}</div>'
      + f'<div style="display: flex; gap: 8px">{btn("＋ Заметка", "acc")}{btn("Из шаблона…")}</div>'
      + f'<div style="font-size: 12px; color: {MUT}">Или перетащи сюда файлы .md из проводника.</div>')
s3 = (t2('«Запекание нормалей» изменили в другой программе', 'Пока она была открыта здесь. Твои правки за последние 2 минуты не сохранены в файл.')
      + f'<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 12px"><div style="padding: 8px 10px; border-radius: 8px; border: 1px solid {LINE}"><div style="color: {MUT}">В файле · 22:31</div>+ 2 строки, − 1</div><div style="padding: 8px 10px; border-radius: 8px; border: 1px solid {OR}"><div style="color: {MUT}">Здесь · 22:33</div>+ 1 абзац</div></div>'
      + f'<div style="display: flex; gap: 8px; flex-wrap: wrap">{btn("Сравнить", "acc", True)}{btn("Взять из файла", sm=True)}{btn("Оставить мою", sm=True)}</div>')
s4 = (t2('Заметка «UV без растяжений» уже есть', 'В папке 3D / Техники. Два файла с одним именем в одной папке быть не может.')
      + f'<div style="display: flex; flex-direction: column; gap: 6px">{btn("Открыть ту заметку", "acc", True)}{btn("Назвать «UV без растяжений 2»", sm=True)}{btn("Положить в другую папку…", "ghost", True)}</div>')
s5 = (f'<div style="display: flex; gap: 14px; align-items: center">{coon(56, "ОЙ")}{t2("Не вижу папку «Obsidian-Vault»", "Диск отключён или папку переименовали. Заметки не пропали — я просто их не нахожу.")}</div>'
      + f'<div style="display: flex; gap: 8px">{btn("Найти заново…", "acc")}{btn("Убрать из списка", "ghost")}</div>'
      + f'<div style="font-size: 12px; color: {MUT}">Поиск и граф пока работают по последнему индексу · 22:10</div>')
s6 = (t2('Читаю 152 заметки…', 'Первый раз — около минуты. Дальше только изменённые файлы, за секунды.')
      + f'<div><div style="height: 8px; border-radius: 4px; background: {SOFT}; overflow: hidden"><div style="width: 63%; height: 100%; background: {OR}; border-radius: 4px"></div></div><div style="margin-top: 6px; display: flex; justify-content: space-between">{micro("96 / 152", OR)}{micro("DND / СЕССИИ", DIM)}</div></div>'
      + f'<div style="font-size: 12.5px; color: #C9CAD0">Уже можно писать — поиск и граф догонят.</div>')
st = card(0, 0, CW, CH, '01', 'ПЕРВЫЙ ЗАПУСК', 'ПАПКИ НЕТ', OR, s1)
st += card(424, 0, CW, CH, '02', 'ПУСТАЯ ПАПКА', 'РАБОТА · 0', BLUE, s2)
st += card(848, 0, CW, CH, '03', 'ФАЙЛ ИЗМЕНЁН СНАРУЖИ', 'НЕ ЗАТИРАЮ', GOLD, s3)
st += card(0, 354, CW, CH, '04', 'КОНФЛИКТ ИМЁН', 'ИМЯ ЗАНЯТО', GOLD, s4)
st += card(424, 354, CW, CH, '05', 'ПАПКА НЕДОСТУПНА', 'НЕТ ДОСТУПА', RED, s5, wait=True)
st += card(848, 354, CW, CH, '06', 'ИДЁТ ИНДЕКСАЦИЯ', '63%', GREY, s6)
save3('G_NotesStates.dc.html', page('Знания · состояния', 'ЗНАНИЯ', st, R), 'Знания · состояния: первый запуск, пусто, конфликты, индексация', 8)

# =================== 9. ОКНА ===================
inp = lambda t, w='100%', on=False: f'<span style="width: {w}; height: 36px; box-sizing: border-box; border-radius: 8px; border: {"1.5px solid " + OR if on else "1px solid " + STRONG}; background: {BG}; display: inline-flex; align-items: center; padding: 0 12px">{t}</span>'
fold_rows = ''.join(f'<div style="display: flex; align-items: center; gap: 10px; height: 32px; border-bottom: 1px solid {SOFT}"><span style="flex: 1">{n}</span><span style="font-size: 12px; color: {MUT}">→</span><span style="display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 8px; border-radius: 6px; border: 1px solid {LINE}; font-size: 12px">{dot(c)}{s}<span style="color: {MUT}">▾</span></span></div>' for n, c, s in [('3D', OR, '3D и заказы'), ('DND', VIO, 'Учёба'), ('Работа', BLUE, 'Работа'), ('Личное', GOLD, 'Дом')])
w1 = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 14px">
 {field("Папка", inp("Документы / Obsidian-Vault", on=True) + btn("Обзор…", sm=True))}
 <div style="font-size: 12.5px; color: {GREEN}">{dot(GREEN, 6)} 152 заметки, 46 картинок, 2 холста</div>
 <div><span style="font: 500 12.5px {SANS}; color: {MUT}">Цвет папок — по сферам</span>{fold_rows}</div>
 {field("Картинки класть в", inp("Вложения/", "160px"))}
 {srow("Следить за изменениями", "Правки в Obsidian видны сразу", toggle(True))}
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 58px; border-top: 1px solid {LINE}; display: flex; align-items: center; justify-content: flex-end; gap: 8px; padding: 0 18px">{btn("Отмена", "ghost")}{btn("Подключить", "acc")}</div>'''
files = ''.join(f'<div style="display: flex; align-items: center; gap: 10px; height: 30px">{check(True, OR)}<span style="flex: 1">{n}</span>{micro(str(k) + " ССЫЛ.", DIM)}</div>' for n, k in [('Пайплайн ассета', 2), ('Щит паладина', 1), ('Курс: текстуры', 1), ('UV без растяжений', 1), ('Умные маски Substance', 1)])
w2 = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 12px">
 {field("Было", inp(f'<span style="color: {MUT}">Запекание нормалей</span>'))}
 {field("Стало", inp("Запекание карт нормалей", on=True))}
 <div style="padding: 10px 12px; border-radius: 8px; background: {HOVER}"><div style="font-weight: 600; margin-bottom: 4px">Обновить ссылки в 5 заметках</div>{files}</div>
 <div style="font-size: 12px; color: {MUT}">Меняю только [[ссылки]], остальной текст не трогаю.</div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 58px; border-top: 1px solid {LINE}; display: flex; align-items: center; justify-content: flex-end; gap: 8px; padding: 0 18px">{btn("Только имя", "ghost")}{btn("Переименовать и обновить", "acc")}</div>'''
tpls = [('Пустая', 'Только название', GREY, False), ('Техника', 'тип, теги, «Порядок», «Ошибки»', OR, True), ('Референс', 'картинки, источник', OR, False), ('НПС', 'где, фракция, статус', VIO, False), ('Сессия DND', 'дата, игроки, итоги', VIO, False), ('Конспект', 'курс, урок, вопросы', GREEN, False)]
tl = ''.join(f'<div style="display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 8px; {"background: " + WASH + "; border: 1px solid " + OR if on else "border: 1px solid transparent"}">{dot(c, 8)}<span style="flex: 1"><span style="display: block">{n}</span><span style="font-size: 12px; color: {MUT}">{d}</span></span>{kbd(str(i + 1))}</div>' for i, (n, d, c, on) in enumerate(tpls))
yaml = f'''<div style="padding: 12px; border-radius: 8px; background: {BG}; border: 1px solid {LINE}; font: 400 11.5px/19px {MONO}; color: #C9CAD0"><span style="color: {DIM}">---</span><br>type: <span style="color: {ORI}">техника</span><br>tags: [<span style="color: {ORI}">3d</span>]<br>created: 2026-11-05<br><span style="color: {DIM}">---</span><br><span style="color: {INK}"># Новая техника</span><br>## Порядок<br>1.<br>## Частые ошибки<br>—</div>'''
w3 = f'''<div style="padding: 16px 18px; display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 16px">
 <div style="display: flex; flex-direction: column; gap: 4px">{tl}</div>
 <div style="display: flex; flex-direction: column; gap: 10px">{field("Название", inp("Новая техника", on=True))}{field("Папка", inp(dot(OR) + "&nbsp; 3D / Техники"))}{yaml}</div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 58px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 8px; padding: 0 18px"><span style="font-size: 12px; color: {MUT}">Шаблоны — заметки из папки «Шаблоны»</span><span style="flex: 1"></span>{btn("Создать", "acc")}</div>'''
st = dim(NOTES, .2)
st += pop(0, 10, 400, 560, 'ПОДКЛЮЧИТЬ ПАПКУ', w1, OR, 'ОКНО 01', hub=True)
st += pop(420, 10, 380, 560, 'ПЕРЕИМЕНОВАТЬ ЗАМЕТКУ', w2, GOLD, 'ОКНО 02')
st += pop(820, 10, 428, 560, 'НОВАЯ ЗАМЕТКА ИЗ ШАБЛОНА', w3, GREY, 'ОКНО 03')
st += ab(0, 596, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 700px; box-sizing: border-box">{coon(44, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Файлы — главное: удаляю только в корзину, а переименование всегда показывает, какие заметки поменяются.</span></div>')
save3('G_NotesWindows.dc.html', page('Знания · окна', 'ЗНАНИЯ', st, R), 'Знания · окна: папка, переименование, шаблон', 9)

# страница «Знания» — сразу после «Система G»
P_ = P + 'canvas.json'
c = json.load(open(P_))
pg = [p for p in c['pages'] if p['id'] == 'kb'] + [p for p in c['pages'] if p['id'] != 'kb']
r4 = [p for p in pg if p['id'] == 'r4']
c['pages'] = r4 + [p for p in pg if p['id'] != 'r4']
c['pages'] = [c['pages'][0]] + [p for p in c['pages'] if p['id'] == 'kb'] + [p for p in c['pages'][1:] if p['id'] != 'kb']
json.dump(c, open(P_, 'w'), ensure_ascii=False, indent=1)
print('ok2')
