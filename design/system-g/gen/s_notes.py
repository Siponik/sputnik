# Макеты раздела «Знания» (база знаний), система G. Запуск: python3 s_notes.py
import sys, os, json, math, random; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *

TABS = ['СЕГОДНЯ', 'КАЛЕНДАРЬ', 'ДОСКА', 'ПРИВЫЧКИ', 'ЗНАНИЯ']
_old_header = kit.header


def header5(active='ЗНАНИЯ', right='ЧТ 05.11 · 22:40', hx=''):
    h = _old_header('—', right, hx)
    tabs = ''
    for t in TABS:
        if t == active:
            tabs += f'<a href="#" aria-current="page" style="text-decoration: none; color: {INK}; padding-bottom: 3px; border-bottom: 1px solid {OR}">{t}</a>'
        else:
            tabs += f'<a href="#" style="text-decoration: none; color: {MUT}">{t}</a>'
    a = h.index('<nav'); b = h.index('</nav>')
    return h[:a] + f'<nav aria-label="Разделы" style="display: flex; gap: 20px; flex-wrap: wrap">{tabs}' + h[b:]


kit.header = header5
R = '22:40'

FOLD = [('00 Входящие', GREY, 4), ('3D', OR, 38), ('DND', VIO, 52), ('Работа', BLUE, 17), ('Учёба', GREEN, 23), ('Личное', GOLD, 12), ('Шаблоны', GREY, 6)]
FC = {n: c for n, c, _ in FOLD}


def save3(fname, html, title, i):
    open(P + fname, 'w').write(html)
    c = json.load(open(P + 'canvas.json'))
    if not any(p['id'] == 'kb' for p in c['pages']):
        c['pages'].append({'id': 'kb', 'name': 'Знания'})
    i = {-1: 0, -0.5: 1, 0: 2, 0.5: 3, 0.7: 4}.get(i, i + 4)
    c["boards"][fname] = {"x": (i % 2) * 1360, "y": (i // 2) * 940, "w": 1280, "h": 820, "title": title, "expand": "fill", "page": 'kb'}
    if fname not in c['order']:
        c['order'].append(fname)
    json.dump(c, open(P + 'canvas.json', 'w'), ensure_ascii=False, indent=1)


def wl(t, ok=True):
    # [[ссылка]] в тексте заметки; ok=False — заметки ещё нет
    if ok:
        return f'<span style="color: {ORI}; border-bottom: 1px solid {ORL}">{t}</span>'
    return f'<span style="color: {MUT}; border-bottom: 1px dashed {DIM}">{t}</span>'


def tag(t, c=MUT):
    return f'<span style="font: 400 11px {MONO}; color: {c}; padding: 1px 6px; border-radius: 4px; border: 1px solid {LINE}">#{t}</span>'


def thumb(w, h, c, label='', r=6):
    # заглушка картинки-референса: тёмный градиент цвета сферы
    return (f'<span style="display: block; width: {w}; height: {h}px; border-radius: {r}px; box-sizing: border-box; border: 1px solid {LINE}; '
            f'background: radial-gradient(120% 90% at 30% 20%, {c}55, transparent 60%), linear-gradient(160deg, #2B2C31, #1E1F23); position: relative">'
            f'<span style="position: absolute; left: 8px; bottom: 6px; font: 400 9px {MONO}; letter-spacing: .1em; color: {DIM}">{label}</span></span>')


def search_inp(t, ph=True, w='100%'):
    c = MUT if ph else INK
    return f'<div style="width: {w}; height: 32px; box-sizing: border-box; border-radius: 8px; border: 1px solid {STRONG}; background: {BG}; display: flex; align-items: center; gap: 8px; padding: 0 10px; color: {c}"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4"></path></svg>{t}</div>'


def modeswitch(active):
    # главный переключатель раздела «Знания»: одинаковый на всех экранах, слева сверху
    out = ''
    for t, ic, k in [('Заметки', '¶', 'Ctrl 1'), ('Граф', '◉', 'Ctrl G'), ('Холст', '▦', '')]:
        on = t == active
        s_ = f'background: {OR}; color: {DARK}; font-weight: 600' if on else f'color: #C9CAD0'
        out += f'<span style="flex: 1; height: 32px; border-radius: 7px; {s_}; display: flex; align-items: center; justify-content: center; gap: 6px; font-size: 13px"><span style="opacity: .8">{ic}</span>{t}</span>'
    return f'<div style="padding: 6px; border-bottom: 1px solid {LINE}"><div role="tablist" aria-label="Вид знаний" style="display: flex; gap: 3px; padding: 3px; border-radius: 9px; background: {BG}">{out}</div></div>'


# =================== 1. ЗНАНИЯ: ПАПКИ · СПИСОК · ЗАМЕТКА · СВЯЗИ ===================
def tree_row(name, c, n, on=False, depth=0, open_=None):
    bg = f'background: {HOVER};' if on else ''
    ar = '' if open_ is None else ('▾' if open_ else '▸')
    return (f'<div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 10px 0 {10 + depth * 16}px; border-radius: 6px; margin: 0 6px; {bg}">'
            f'<span style="width: 10px; color: {DIM}; font-size: 10px">{ar}</span>{dot(c, 7) if depth == 0 else ""}<span style="color: {INK if on or depth == 0 else "#C9CAD0"}">{name}</span>'
            f'<span style="margin-left: auto; font: 400 11px {MONO}; color: {DIM}">{n}</span></div>')


tree = '<div style="padding: 8px 0">'
for name, c, n in FOLD:
    if name == '3D':
        tree += tree_row(name, c, n, open_=True)
        for sub, k in [('Ассеты', 11), ('Техники', 14), ('Референсы', 9), ('Софт', 4)]:
            tree += tree_row(sub, c, k, on=(sub == 'Техники'), depth=1)
    else:
        tree += tree_row(name, c, n, open_=(False if name not in ('00 Входящие', 'Шаблоны') else None))
tree += '</div>'
tags = ' '.join(tag(t) for t in ['substance', 'baking', 'лор', 'нпс', 'клиент', 'blender', 'идея', 'конспект'])
tree += f'<div style="border-top: 1px solid {LINE}; padding: 12px 12px 0">{micro("ТЕГИ")}<div style="display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px">{tags}</div></div>'
tree += f'<div style="position: absolute; left: 0; right: 0; bottom: 0; border-top: 1px solid {LINE}; padding: 10px 12px; display: flex; flex-direction: column; gap: 4px">{micro("ПАПКА · OBSIDIAN-VAULT")}{micro("152 ЗАМЕТКИ · 318 СВЯЗЕЙ", MUT)}</div>'

notes = [('Запекание нормалей', 'Кейдж, сглаживание, сначала низкий полигонаж…', '22:14', 6, True),
         ('Умные маски Substance', 'Грязь по кривизне, края по AO…', 'вчера', 4, False),
         ('Ретопология под анимацию', 'Петли вокруг суставов, плотность…', '03.11', 3, False),
         ('UV без растяжений', 'Швы по естественным краям…', '01.11', 5, False),
         ('Свет для презентации', 'Три точки, HDRI студии…', '28.10', 2, False),
         ('Блокинг за 30 минут', 'Сначала силуэт, потом пропорции…', '24.10', 1, False),
         ('Хард-сёрфейс: фаски', 'Weighted normals вместо…', '20.10', 0, False)]
lst = f'<div style="padding: 10px 10px 6px">{search_inp("Фильтр в папке")}</div><div style="padding: 0 10px 8px; display: flex; gap: 6px">{seg(["ИЗМЕНЕНО", "А–Я", "СВЯЗИ"], "ИЗМЕНЕНО")}</div>'
for t, s, d, k, on in notes:
    bg = f'background: {WASH}; border: 1px solid {ORL};' if on else f'border: 1px solid transparent;'
    lst += (f'<div style="margin: 0 8px 4px; padding: 9px 10px; border-radius: 8px; {bg}">'
            f'<div style="display: flex; align-items: baseline; gap: 8px"><span style="font-weight: 600; color: {INK}">{t}</span><span style="margin-left: auto; font: 400 10.5px {MONO}; color: {DIM}">{d}</span></div>'
            f'<div style="display: flex; gap: 8px; margin-top: 3px"><span style="flex: 1; font-size: 12px; color: {MUT}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{s}</span>'
            f'<span style="font: 400 10.5px {MONO}; color: {OR if k else DIM}">{"↔ " + str(k) if k else "—"}</span></div></div>')
lst += f'<div style="position: absolute; left: 8px; right: 8px; bottom: 8px">{btn("＋ Заметка", "acc", True, "; width: 100%")}</div>'

prop = lambda k, v: f'<div style="display: flex; align-items: center; gap: 10px; min-height: 28px"><span style="width: 74px; flex: none; font-size: 12px; color: {MUT}">{k}</span><span style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center">{v}</span></div>'
props = (prop('Тип', sc('Техника', True)) + prop('Теги', tag('baking', INK) + tag('substance', INK) + f'<span style="color: {DIM}">＋</span>') +
         prop('Задача', f'<span style="display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 10px; border-radius: 6px; border: 1px solid {LINE}">{check()}<span>Рендер щита</span><span style="font: 400 10px {MONO}; color: {DIM}">3D-АССЕТЫ</span></span>'))
editor = f'''<div style="height: 44px; box-sizing: border-box; padding: 0 12px 0 16px; border-radius: 11px 11px 0 0; background: {HUBFILL}; display: flex; align-items: center; gap: 10px; font: 500 10.5px {MONO}; letter-spacing: .14em; color: #FFFFFF">
  <span style="color: rgba(255,255,255,.72)">03</span><span>3D › ТЕХНИКИ</span><span style="flex: 1"></span>
  <span role="group" style="display: inline-flex; padding: 2px; border-radius: 7px; background: rgba(0,0,0,.18)"><span style="padding: 0 10px; height: 24px; display: flex; align-items: center; border-radius: 5px; background: rgba(255,255,255,.92); color: #5A3412">ПРАВКА</span><span style="padding: 0 10px; height: 24px; display: flex; align-items: center; color: rgba(255,255,255,.85)">ЧТЕНИЕ</span></span>
  <span style="font-size: 15px">⋯</span></div>
<div style="padding: 18px 22px 0">
  <div style="font: 600 24px {SANS}; letter-spacing: -.01em">Запекание нормалей</div>
  <div style="margin-top: 12px; padding: 8px 12px; border-radius: 8px; background: {HOVER}">{props}</div>
</div>
<div style="padding: 16px 22px 0; font-size: 13.5px; line-height: 22px; color: #D4D5DA">
  <div style="font: 600 15px {SANS}; color: {INK}; margin-bottom: 4px">Порядок</div>
  <div>1. Низкий полигонаж готов, UV без растяжений — см. {wl("UV без растяжений")}.</div>
  <div>2. Кейдж чуть больше модели, сглаживание одной группой.</div>
  <div>3. Пеку в Substance, потом {wl("Умные маски Substance")}.</div>
  <div style="font: 600 15px {SANS}; color: {INK}; margin: 12px 0 4px">Частые ошибки</div>
  <div>— Волны на фасках: добавить петли или {wl("Хард-сёрфейс: фаски")}.</div>
  <div>— Тёмные пятна в углах: увеличить кейдж ({wl("Справочник по кейджам", False)}).</div>
  <div style="display: flex; gap: 10px; margin-top: 12px">{thumb("150px", 84, OR, "БЫЛО.PNG")}{thumb("150px", 84, OR, "СТАЛО.PNG")}</div>
  <div style="margin-top: 12px; display: flex; flex-direction: column; gap: 4px">
    <div style="display: flex; gap: 8px; align-items: center">{check()}<span>Перепечь щит с новым кейджем</span></div>
    <div style="display: flex; gap: 8px; align-items: center">{check(True)}<span style="color: {MUT}; text-decoration: line-through">Сравнить с референсом</span></div>
  </div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 36px; box-sizing: border-box; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 16px; font: 400 10px {MONO}; letter-spacing: .1em; color: {DIM}">{dot(GREEN)}<span style="white-space: nowrap">СОХРАНЕНО 22:14 · ЗАПЕКАНИЕ НОРМАЛЕЙ.MD</span><span style="margin-left: auto; white-space: nowrap">312 СЛОВ</span></div>'''


def linkrow(t, c, sub='', side='l', top=0):
    s = f'<span style="display: block; font-size: 11.5px; color: {MUT}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{sub}</span>' if sub else ''
    return f'<div style="position: relative; padding: 6px 12px 6px 16px">{dot(c)}<span style="display: inline-block; margin-left: 8px; vertical-align: 1px">{t}</span>{s}</div>'


out_ = ''.join(linkrow(t, FC['3D']) for t in ['UV без растяжений', 'Умные маски Substance', 'Хард-сёрфейс: фаски'])
out_ += f'<div style="padding: 6px 12px 6px 16px; color: {MUT}"><span style="display: inline-block; width: 6px; height: 6px; border: 1px dashed {DIM}; border-radius: 2px"></span><span style="margin-left: 8px">Справочник по кейджам</span><span style="margin-left: 6px; font: 400 10px {MONO}; color: {OR}">СОЗДАТЬ</span></div>'
in_ = (linkrow('Щит паладина', FC['3D'], '«…нормали пекла по [[Запекание нормалей]]…»') + linkrow('Пайплайн ассета', FC['3D'], '«4. Запекание → [[Запекание нормалей]]»') +
       linkrow('Курс: текстуры', FC['Учёба'], '«конспект урока 6, см. [[Запекание…»') + f'<div style="padding: 2px 16px 8px; font-size: 12px; color: {MUT}">ещё 3 ▾</div>')
men = f'<div style="padding: 6px 12px 10px 16px; display: flex; align-items: center; gap: 8px">{dot(FC["Работа"])}<span style="flex: 1">Прайс на ассеты</span>{btn("Связать", "ghost", True, "; color: " + OR + "; height: 24px")}</div>'
links = (f'<div style="padding: 8px 0 0">{micro("  ССЫЛАЕТСЯ НА · 4", MUT, "; padding-left: 16px")}</div>{out_}'
         f'<div style="border-top: 1px solid {LINE}; padding: 8px 0 0">{micro("ССЫЛАЮТСЯ СЮДА · 6", MUT, "; padding-left: 16px")}</div>{in_}'
         f'<div style="border-top: 1px solid {LINE}; padding: 8px 0 0">{micro("УПОМЯНУТО БЕЗ ССЫЛКИ · 1", MUT, "; padding-left: 16px")}</div>{men}')

# мини-граф: соседи вокруг заметки
mg = ''
cx, cy = 130, 92
nb = [(-80, -40, OR), (-90, 30, OR), (-20, 60, OR), (70, 50, GREEN), (85, -30, OR), (30, -62, OR), (-40, -70, BLUE)]
for dx, dy, c in nb:
    mg += f'<line x1="{cx}" y1="{cy}" x2="{cx + dx}" y2="{cy + dy}" stroke="{c}" stroke-opacity=".55" stroke-width="1"/>'
for dx, dy, c in nb:
    mg += f'<circle cx="{cx + dx}" cy="{cy + dy}" r="5" fill="{c}"/>'
mg += f'<circle cx="{cx}" cy="{cy}" r="9" fill="{OR}" stroke="{ORI}" stroke-width="2"/>'
mini = f'<svg width="260" height="180" aria-hidden="true">{mg}</svg><div style="padding: 0 12px 10px; display: flex; align-items: center; gap: 8px"><span style="font-size: 12px; color: {MUT}">Глубина 1 · 7 заметок</span><span style="margin-left: auto">{btn("Весь граф G", "ghost", True, "; color: " + OR)}</span></div>'

# --- основной экран: одна боковая колонка + широкая заметка, связи по кнопке ---
def frow(name, c, n='', depth=0, open_=None, on=False, note=False):
    bg = f'background: {WASH}; box-shadow: inset 2px 0 0 {OR};' if on else ''
    ar = '' if open_ is None else ('▾' if open_ else '▸')
    ic = (f'<span style="width: 12px; color: {DIM}; font-size: 11px">¶</span>' if note
          else (dot(c, 7) if depth == 0 else f'<span style="width: 12px; color: {DIM}; font-size: 11px">▭</span>'))
    col = INK if on or depth == 0 else '#C9CAD0'
    return (f'<div style="height: 28px; display: flex; align-items: center; gap: 7px; padding: 0 10px 0 {8 + depth * 14}px; border-radius: 6px; margin: 0 6px; {bg}">'
            f'<span style="width: 10px; color: {DIM}; font-size: 10px">{ar}</span>{ic}'
            f'<span style="color: {col}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{name}</span>'
            f'<span style="margin-left: auto; font: 400 11px {MONO}; color: {DIM}">{n}</span></div>')


plus = f'<span style="flex: none; width: 32px; height: 32px; border-radius: 8px; background: {OR}; color: #2A1A0A; display: grid; place-items: center; font-size: 16px; font-weight: 600">＋</span>'
side = f'<div style="padding: 10px 10px 6px; display: flex; gap: 6px">{search_inp("Найти заметку  Ctrl K")}{plus}</div>'
side += f'<div style="padding: 8px 16px 4px">{micro("НЕДАВНИЕ", MUT)}</div>'
for t, on in [('Запекание нормалей', True), ('Пайплайн ассета', False), ('Сессия 12: порт', False)]:
    side += frow(t, OR, '', 0, None, on, True)
side += f'<div style="padding: 12px 16px 4px; border-top: 1px solid {LINE}; margin-top: 8px">{micro("ПАПКИ", MUT)}</div>'
side += frow('00 Входящие', GREY, 4)
side += frow('3D', OR, 38, 0, True)
side += frow('Ассеты', OR, 11, 1, False)
side += frow('Техники', OR, 14, 1, True)
for t in ['Запекание нормалей', 'Умные маски Substance', 'UV без растяжений', 'Ретопология под анимацию', 'Хард-сёрфейс: фаски']:
    side += frow(t, OR, '', 2, None, t == 'Запекание нормалей', True)
side += f'<div style="padding: 2px 0 4px 60px; font-size: 12px; color: {MUT}">ещё 9</div>'
side += frow('Референсы', OR, 9, 1, False)
for name, c, n in FOLD[2:6]:
    side += frow(name, c, n, 0, False)
side += (f'<div style="position: absolute; left: 0; right: 0; bottom: 0; border-top: 1px solid {LINE}; padding: 10px 14px; display: flex; align-items: center; gap: 8px">'
         f'{micro("OBSIDIAN-VAULT · 152", MUT)}<span style="margin-left: auto">{micro("ТЕГИ ▸", MUT)}</span></div>')


def tabs(active):
    out = ''
    for t in ['Запекание нормалей', 'Пайплайн ассета', 'Сессия 12: порт']:
        if t == active:
            out += f'<span style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 12px; border-radius: 7px; background: rgba(255,255,255,.92); color: #5A3412; font: 500 13px {SANS}">{t}<span style="font-size: 11px; opacity: .6">✕</span></span>'
        else:
            out += f'<span style="height: 30px; display: flex; align-items: center; padding: 0 12px; color: rgba(255,255,255,.82); font: 400 13px {SANS}">{t}</span>'
    return (f'<div style="height: 44px; box-sizing: border-box; padding: 0 10px; border-radius: 11px 11px 0 0; background: {HUBFILL}; display: flex; align-items: center; gap: 4px">'
            f'{out}<span style="padding: 0 10px; color: rgba(255,255,255,.8); font-size: 15px">＋</span></div>')


def tool(links_on):
    lb = (btn('↔ Связи · 11', 'acc', True) if links_on else btn('↔ Связи · 11', 'sec', True))
    return (f'<div style="height: 44px; box-sizing: border-box; padding: 0 14px 0 20px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 10px">'
            f'<span style="font-size: 12.5px; color: {MUT}">3D › Техники</span><span style="flex: 1"></span>'
            f'{seg(["ПРАВКА", "ЧТЕНИЕ"], "ПРАВКА")}{lb}{btn("Граф", "ghost", True)}<span style="color: {MUT}; font-size: 15px; padding: 0 4px">⋯</span></div>')


def chipv(t, c=None):
    bd = c or LINE
    return f'<span style="display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 10px; border-radius: 13px; border: 1px solid {bd}; font-size: 12.5px">{t}</span>'


def body(w):
    pr = (chipv(f'{dot(OR, 7)}Техника') + chipv(f'<span style="font: 400 12px {MONO}; color: {MUT}">#</span>baking') + chipv(f'<span style="font: 400 12px {MONO}; color: {MUT}">#</span>substance')
          + chipv(f'{check()}Рендер щита') + f'<span style="font-size: 12.5px; color: {DIM}">＋ свойство</span>')
    bl = ''
    for t, s in [('Щит паладина', '…нормали пекла по [[Запекание нормалей]], кейдж 2%…'), ('Пайплайн ассета', '4. Запекание → [[Запекание нормалей]]')]:
        bl += (f'<div style="padding: 8px 12px; border-radius: 8px; background: {HOVER}"><div style="display: flex; align-items: center; gap: 8px">{dot(OR)}<span style="font-weight: 600">{t}</span></div>'
               f'<div style="margin-top: 2px; font-size: 12.5px; color: {MUT}">{s}</div></div>')
    return f'''<div style="width: {w}px; margin: 0 auto; padding-top: 30px">
  <div style="font: 600 28px {SANS}; letter-spacing: -.01em">Запекание нормалей</div>
  <div style="margin-top: 12px; display: flex; flex-wrap: wrap; gap: 6px; align-items: center">{pr}</div>
  <div style="margin-top: 20px; font-size: 14.5px; line-height: 24px; color: #D4D5DA">
    <div style="font: 600 17px {SANS}; color: {INK}; margin-bottom: 4px">Порядок</div>
    <div>1. Низкий полигонаж готов, UV без растяжений — см. {wl("UV без растяжений")}.</div>
    <div>2. Кейдж чуть больше модели, сглаживание одной группой.</div>
    <div>3. Пеку в Substance, потом {wl("Умные маски Substance")}.<span style="display: inline-block; width: 1.5px; height: 18px; background: {OR}; vertical-align: -3px; margin-left: 2px"></span></div>
    <div style="font: 600 17px {SANS}; color: {INK}; margin: 14px 0 4px">Частые ошибки</div>
    <div>— Волны на фасках: добавить петли или {wl("Хард-сёрфейс: фаски")}.</div>
    <div>— Тёмные пятна в углах: увеличить кейдж ({wl("Справочник по кейджам", False)}).</div>
    <div style="display: flex; gap: 10px; margin-top: 14px">{thumb("180px", 96, OR, "БЫЛО.PNG")}{thumb("180px", 96, OR, "СТАЛО.PNG")}</div>
  </div>
  <div style="margin-top: 26px; padding-top: 12px; border-top: 1px solid {LINE}">
    <div style="display: flex; align-items: center">{micro("ССЫЛАЮТСЯ СЮДА · 6", MUT)}<span style="margin-left: auto; font-size: 12.5px; color: {OR}">все связи →</span></div>
    <div style="margin-top: 8px; display: grid; grid-template-columns: 1fr 1fr; gap: 8px">{bl}</div>
  </div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 34px; box-sizing: border-box; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 16px; font-size: 12px; color: {DIM}">{dot(GREEN)}<span>Сохранено · Запекание нормалей.md</span><span style="margin-left: auto">312 слов</span></div>'''


st = node(0, 0, 264, 700, modeswitch('Заметки') + side)
st += node(280, 0, 968, 700, tabs('Запекание нормалей') + tool(False) + body(640), hub=True)
NOTES = st
save3('G_Notes.dc.html', page('Знания', 'ЗНАНИЯ', st, R), 'Знания · заметка (основной экран)', 0)

st = node(0, 0, 264, 700, modeswitch('Заметки') + side)
st += node(280, 0, 664, 700, tabs('Запекание нормалей') + tool(True) + body(560), hub=True)
st += node(960, 0, 288, 700, nhead('', 'СВЯЗИ', 'ЗАКРЫТЬ ✕', OR, None, 34) + links
           + f'<div style="border-top: 1px solid {LINE}; padding: 10px 16px 0">{micro("ЛОКАЛЬНЫЙ ГРАФ · ГЛУБИНА 1", MUT)}</div>' + mini)
save3('G_NotesLinks.dc.html', page('Знания · связи', 'ЗНАНИЯ', st, R), 'Знания · заметка с открытой панелью «Связи»', 0.5)


# =================== 2. ГРАФ ===================
random.seed(7)
clusters = {'3D': (OR, 34, (360, 330)), 'DND': (VIO, 44, (720, 250)), 'Работа': (BLUE, 14, (540, 540)), 'Учёба': (GREEN, 18, (250, 520)), 'Личное': (GOLD, 10, (830, 520)), '00 Входящие': (GREY, 4, (900, 120))}
pts = []
for name, (c, n, (x0, y0)) in clusters.items():
    for i in range(n):
        pts.append({'f': name, 'c': c, 'x': x0 + random.gauss(0, 60), 'y': y0 + random.gauss(0, 50)})
edges = set()
for i, p in enumerate(pts):
    same = [j for j, q in enumerate(pts) if q['f'] == p['f'] and j != i]
    for j in random.sample(same, min(len(same), random.choice([1, 1, 2, 2, 3]))):
        edges.add((min(i, j), max(i, j)))
    if random.random() < .12:
        j = random.randrange(len(pts)); edges.add((min(i, j), max(i, j)))
# хабы: несколько заметок с большим числом связей
hubs = {0: 'Пайплайн ассета', 34: 'Кампания «Пепельный берег»', 78: 'Клиенты', 92: 'Курс: текстуры', 3: 'Запекание нормалей', 40: 'Город Вельск', 52: 'НПС: Мира Тёрн'}
for h in hubs:
    same = [j for j, q in enumerate(pts) if q['f'] == pts[h]['f'] and j != h]
    for j in random.sample(same, min(len(same), 9)):
        edges.add((min(h, j), max(h, j)))
edges.add((0, 3)); edges.add((3, 92)); edges.add((34, 40)); edges.add((34, 52)); edges.add((40, 52))
# упрощённая раскладка сил (как d3-force: отталкивание, пружины связей, притяжение к центру)
for it in range(260):
    for p in pts:
        p['vx'] = p.get('vx', 0) * .6; p['vy'] = p.get('vy', 0) * .6
    for i in range(len(pts)):
        a = pts[i]
        for j in range(i + 1, len(pts)):
            b = pts[j]; dx = a['x'] - b['x']; dy = a['y'] - b['y']; d2 = dx * dx + dy * dy + .01
            if d2 < 14000:
                f = 260 / d2; a['vx'] += dx * f; a['vy'] += dy * f; b['vx'] -= dx * f; b['vy'] -= dy * f
    for i, j in edges:
        a, b = pts[i], pts[j]; dx = b['x'] - a['x']; dy = b['y'] - a['y']; d = math.hypot(dx, dy) + .01
        f = (d - 46) * .02; a['vx'] += dx / d * f * d * .05; a['vy'] += dy / d * f * d * .05; b['vx'] -= dx / d * f * d * .05; b['vy'] -= dy / d * f * d * .05
    for p in pts:
        cx0, cy0 = clusters[p['f']][2]
        p['vx'] += (cx0 - p['x']) * .004; p['vy'] += (cy0 - p['y']) * .004
        p['x'] += max(-8, min(8, p['vx'])); p['y'] += max(-8, min(8, p['vy']))
xs = [p['x'] for p in pts]; ys = [p['y'] for p in pts]
W, H = 640, 640
for p in pts:
    p['x'] = 30 + (p['x'] - min(xs)) / (max(xs) - min(xs)) * (W - 60)
    p['y'] = 30 + (p['y'] - min(ys)) / (max(ys) - min(ys)) * (H - 60)
deg = [0] * len(pts)
for i, j in edges:
    deg[i] += 1; deg[j] += 1
SEL = 3
nbr = {j if i == SEL else i for i, j in edges if SEL in (i, j)}
g = ''
for i, j in edges:
    a, b = pts[i], pts[j]
    hot = SEL in (i, j)
    col = OR if hot else '#6E7079'
    g += f'<line x1="{a["x"]:.1f}" y1="{a["y"]:.1f}" x2="{b["x"]:.1f}" y2="{b["y"]:.1f}" stroke="{col}" stroke-opacity="{".9" if hot else ".22"}" stroke-width="{1.4 if hot else 1}"/>'
for i, p in enumerate(pts):
    r = 3 + min(deg[i], 14) * .55
    on = i == SEL or i in nbr
    op = '1' if on else '.45'
    ring = f' stroke="{ORI}" stroke-width="2"' if i == SEL else ''
    g += f'<circle cx="{p["x"]:.1f}" cy="{p["y"]:.1f}" r="{r + (3 if i == SEL else 0):.1f}" fill="{p["c"]}" fill-opacity="{op}"{ring}/>'
for i, name in hubs.items():
    p = pts[i]; r = 3 + min(deg[i], 14) * .55
    col = INK if (i == SEL or i in nbr) else MUT
    g += f'<text x="{p["x"]:.1f}" y="{p["y"] + r + 14:.1f}" text-anchor="middle" font-family="Onest, sans-serif" font-size="11.5" fill="{col}">{name}</text>'
gx, gy = 268, 44
graph = f'<svg width="{W}" height="{H}" style="position: absolute; left: {gx}px; top: {gy}px" aria-label="Граф заметок">{g}</svg>'

flt = f'<div style="padding: 10px 12px">{search_inp("Найти на графе")}</div><div style="padding: 0 12px 10px">{seg(["ВЕСЬ", "ЛОКАЛЬНЫЙ"], "ВЕСЬ")}</div>'
flt += f'<div style="border-top: 1px solid {LINE}; padding: 10px 0 4px">{micro("ГРУППЫ · ЦВЕТ ПО ПАПКЕ", MUT, "; padding-left: 12px")}</div>'
for name, c, n in FOLD[:6]:
    flt += f'<div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 12px">{dot(c, 8)}<span>{name}</span><span style="margin-left: auto; font: 400 11px {MONO}; color: {DIM}">{n}</span></div>'
flt += f'<div style="border-top: 1px solid {LINE}; margin-top: 6px; padding: 8px 12px; display: flex; flex-direction: column; gap: 8px">{micro("ПОКАЗЫВАТЬ", MUT)}{toggle(True, "Теги точками")}{toggle(False, "Вложения")}{toggle(True, "Без связей")}{toggle(True, "Ещё не созданные")}</div>'


def slider(t, v):
    return f'<div style="padding: 4px 12px"><div style="display: flex; font-size: 12px; color: {MUT}"><span>{t}</span></div><div style="position: relative; height: 16px"><div style="position: absolute; left: 0; right: 0; top: 7px; height: 2px; background: {LINE}"></div><div style="position: absolute; left: 0; width: {v}%; top: 7px; height: 2px; background: {OR}"></div><span style="position: absolute; left: calc({v}% - 6px); top: 2px; width: 12px; height: 12px; border-radius: 3px; background: {INK}"></span></div></div>'


flt += f'<div style="border-top: 1px solid {LINE}; padding: 8px 0">{micro("СИЛЫ", MUT, "; padding-left: 12px")}{slider("Отталкивание", 62)}{slider("Длина связей", 40)}{slider("Притяжение к центру", 25)}</div>'

sp = pts[SEL]
nb_ = ['Пайплайн ассета', 'UV без растяжений', 'Умные маски Substance', 'Курс: текстуры', 'Щит паладина']
rd = (nhead('', 'ЧИТАЮ · ЗАПЕКАНИЕ НОРМАЛЕЙ', '↔ 11', OR, None, 34) +
      f"""<div style="padding: 14px 16px 0"><div style="font-size: 12px; color: {MUT}">3D › Техники · изменено 22:14</div>
      <div style="margin-top: 4px; font: 600 20px {SANS}">Запекание нормалей</div>
      <div style="margin-top: 8px; display: flex; gap: 6px">{tag('baking')}{tag('substance')}</div>
      <div style="margin-top: 12px; font-size: 13.5px; line-height: 22px; color: #D4D5DA">1. Низкий полигонаж готов, UV — см. {wl('UV без растяжений')}.<br>2. Кейдж чуть больше модели.<br>3. Пеку в Substance, потом {wl('Умные маски Substance')}.<br><span style="color: {MUT}">…ещё 2 раздела</span></div>
      <div style="margin-top: 12px; font-size: 12px; color: {MUT}">Клик по ссылке — граф переезжает к той заметке, панель показывает её.</div></div>
      <div style="margin-top: 12px; border-top: 1px solid {LINE}; padding: 10px 16px 0">{micro('СОСЕДИ · 11', MUT)}<div style="margin-top: 8px; display: flex; flex-wrap: wrap; gap: 6px">{''.join(f'<span style="height: 26px; padding: 0 10px; border-radius: 13px; border: 1px solid {LINE}; display: inline-flex; align-items: center; gap: 6px; font-size: 12.5px">{dot(OR)}{n}</span>' for n in nb_)}<span style="font-size: 12.5px; color: {MUT}; align-self: center">ещё 6</span></div></div>
      <div style="position: absolute; left: 0; right: 0; bottom: 0; border-top: 1px solid {LINE}; padding: 12px 16px; display: flex; flex-direction: column; gap: 8px">{btn('Открыть в заметках', 'acc', True, '; width: 100%')}<div style="display: flex; gap: 8px">{btn('Читать целиком', sm=True, extra='; flex: 1')}{btn('Локальный граф', sm=True, extra='; flex: 1')}</div><div style="display: flex; gap: 12px; font-size: 12px; color: {MUT}"><span>{kbd('ENTER')} открыть</span><span>{kbd('L')} локальный</span><span>{kbd('ESC')} закрыть</span></div></div>""")
tip = node(928, 0, 320, 700, rd, hub=True)
tip += svg(f'<path d="M{gx + sp["x"] + 12:.0f} {gy + sp["y"]:.0f} C {gx + sp["x"] + 120:.0f} {gy + sp["y"]:.0f}, 860 60, 928 17" stroke="{OR}" stroke-width="1.5" stroke-dasharray="4 4" fill="none"></path>')
zoom = f'<div style="position: absolute; left: 872px; top: 44px; display: flex; flex-direction: column; gap: 6px">' + ''.join(f'<span style="width: 32px; height: 32px; border-radius: 8px; border: 1px solid {LINE}; background: {NODE}; display: grid; place-items: center; color: {MUT}">{t}</span>' for t in ['＋', '−', '⤢']) + '</div>'

st = node(0, 0, 252, 700, modeswitch('Граф') + flt)
st += ab(268, 6, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ГРАФ ЗНАНИЙ", INK)}{micro("152 ЗАМЕТКИ · 318 СВЯЗЕЙ · КЛИК ПО ТОЧКЕ — ЧИТАТЬ СПРАВА", MUT)}</div>')
st += graph + tip + zoom
save3('G_NotesGraph.dc.html', page('Граф знаний', 'ЗНАНИЯ', st, R), 'Знания · граф (как в Obsidian)', 1)


# =================== 3. ГРАФ ВБЛИЗИ: ТОЧКИ СТАНОВЯТСЯ НОДАМИ ===================
def nnode(x, y, w, title, folder, lines, sock_l=None, sock_r=None, hub=False, body_h=None):
    c = FC[folder]
    inner = nhead('', title.upper(), folder.upper(), c, None, 28, INK, OR if hub else LINE)
    inner += f'<div style="padding: 8px 12px; font-size: 12px; line-height: 18px; color: #C9CAD0">{lines}</div>'
    ex = ''
    for t in (sock_l or []):
        ex += sock('l', t, c)
    for t in (sock_r or []):
        ex += sock('r', t, c)
    return node(x, y, w, body_h or 0, inner, hub=hub, extra=ex)


st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ГРАФ · ПРИБЛИЖЕНИЕ ×3", INK)}{micro("БЛИЖЕ — ТОЧКИ РАСКРЫВАЮТСЯ В НОДЫ, ПРОВОДА — ССЫЛКИ [[…]]", MUT)}<span style="flex: 1"></span></div>', w=1248)
w = ''
w += wire(300, 150, 420, 300, OR) + wire(300, 420, 420, 318, OR) + wire(700, 318, 830, 170, OR) + wire(700, 336, 830, 400, GREEN)
w += wire(700, 354, 830, 600, OR, dash=True) + wire(1040, 420, 1100, 520, GREEN, dash=True)
st += svg(w)
st += nnode(60, 90, 240, 'Пайплайн ассета', '3D', '1. Блокинг<br>2. Хай-поли<br>3. Ретопология, UV<br>4. Запекание →', sock_r=[54])
st += nnode(60, 360, 240, 'UV без растяжений', '3D', 'Швы по естественным краям. Плотность одна на весь ассет.', sock_r=[54])
st += nnode(420, 250, 280, 'Запекание нормалей', '3D', 'Кейдж, сглаживание одной группой, сначала низкий полигонаж.<br>' + tag('baking') + ' ' + tag('substance'), sock_l=[44, 62], sock_r=[62, 80, 98], hub=True)
st += nnode(830, 110, 230, 'Умные маски Substance', '3D', 'Грязь по кривизне, края по AO.', sock_l=[54])
st += nnode(830, 340, 230, 'Курс: текстуры', 'Учёба', 'Урок 6 — запекание. Домашка: щит.', sock_l=[54], sock_r=[74])
st += ab(830, 560, f'<div style="width: 230px; box-sizing: border-box; border-radius: 8px; border: 1px dashed #55575F; padding: 10px 12px; color: {MUT}"><div style="font: 500 10.5px {MONO}; letter-spacing: .14em">СПРАВОЧНИК ПО КЕЙДЖАМ</div><div style="font-size: 12px; margin-top: 4px">Заметки ещё нет · {"<span style=\"color: " + OR + "\">Создать</span>"}</div></div>')
st += ab(1100, 500, f'<div style="display: flex; flex-direction: column; gap: 4px; align-items: flex-start"><span style="width: 10px; height: 10px; border-radius: 50%; background: {GREEN}"></span><span style="font-size: 11.5px; color: {MUT}">+5 заметок</span></div>')
st += ab(60, 600, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 520px; box-sizing: border-box">{coon(44, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Колёсико — масштаб, пробел + мышь — двигать холст. Перетащи ноду — граф подстроится. Двойной клик — открыть заметку.</span></div>')
st += dimline(420, 220, 280, 'ГЛАВНАЯ — ВЫБРАННАЯ')
st += stamp(968, 640, 'ГРАФ · ВБЛИЗИ', '×3', '7 НОД')
save3('G_NotesGraphNear.dc.html', page('Граф вблизи', 'ЗНАНИЯ', st, R), 'Знания · граф вблизи: ноды и провода', 2)


# =================== 4. ХОЛСТ (СХЕМА) ===================
st = node(0, 0, 1248, 48, f'<div style="height: 100%; display: flex; align-items: center; gap: 10px; padding: 0 12px">{lbl("ХОЛСТ", INK)}{micro("DND / ПЕПЕЛЬНЫЙ БЕРЕГ.CANVAS", MUT)}<span style="width: 1px; height: 20px; background: {LINE}"></span>'
          + btn('＋ Заметка', 'sec', True) + btn('＋ Текст', 'ghost', True) + btn('＋ Картинка', 'ghost', True) + btn('Группа', 'ghost', True) + '<span style="flex: 1"></span>'
          + micro('ОТКРЫТЫЙ ФОРМАТ JSON CANVAS', DIM) + btn('Авто-раскладка', 'ghost', True, '; color: ' + OR) + '</div>')
# группа-рамка
st += ab(20, 78, f'<div style="width: 760px; height: 600px; box-sizing: border-box; border-radius: 12px; border: 1px dashed {VIO}; background: rgba(180,140,240,.04)"><div style="padding: 8px 14px">{lbl("ГОРОД ВЕЛЬСК", VIO)}</div></div>')
w = wire(300, 180, 400, 250, VIO) + wire(300, 400, 400, 290, VIO) + wire(660, 280, 840, 200, VIO, dash=True) + wire(660, 300, 840, 470, VIO) + wire(300, 560, 400, 330, GOLD, dash=True)
st += svg(w)
lab = lambda x, y, t: ab(x, y, f'<span style="font: 400 10px {MONO}; letter-spacing: .1em; color: {MUT}; background: {GROUND}; padding: 1px 4px">{t}</span>')
st += nnode(60, 120, 240, 'Таверна «Сломанный рог»', 'DND', 'Хозяин — гном Борн. Тайный ход в подвале.', sock_r=[54])
st += nnode(60, 340, 240, 'НПС: Мира Тёрн', 'DND', 'Информатор фракции. Хочет уехать из города.', sock_r=[54])
st += node(60, 500, 240, 0, f'<div style="padding: 12px; font-size: 12.5px; line-height: 18px; color: #C9CAD0"><div style="font: 500 10px {MONO}; letter-spacing: .14em; color: {GOLD}; margin-bottom: 4px">ТЕКСТ НА ХОЛСТЕ</div>Игроки ещё не знают, что Мира работает на Пепельных.</div>', extra=sock('r', 54, GOLD), style=f'; border-color: #7A6620')
st += nnode(400, 210, 260, 'Сессия 12 · Пожар в доках', 'DND', '— Встреча в таверне<br>— Погоня по крышам<br>— Мира раскрывает план', sock_l=[44, 62, 98], sock_r=[54, 74], hub=True)
st += node(840, 120, 260, 0, nhead('', 'КАРТА ВЕЛЬСКА.PNG', 'КАРТИНКА', GREY, None, 28) + f'<div style="padding: 8px">{thumb("100%", 120, VIO, "ВЛОЖЕНИЯ/КАРТА.PNG")}</div>', extra=sock('l', 54, VIO))
st += nnode(840, 420, 260, 'Фракция Пепельных', 'DND', 'Цель — порт. Лидер неизвестен.<br>' + tag('лор') + ' ' + tag('фракция'), sock_l=[54])
st += lab(700, 236, 'МЕСТО'); st += lab(720, 380, 'ВРАГИ'); st += lab(318, 470, 'ТАЙНА')
st += ab(840, 590, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 380px; box-sizing: border-box">{coon(44, "ФЛАГ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Перетащи заметку из списка — появится нода. Провод от сокета к сокету — ссылка с подписью.</span></div>')
save3('G_NotesCanvas.dc.html', page('Холст', 'ЗНАНИЯ', st, R), 'Знания · холст: свои схемы из заметок', 3)


# =================== 5. КАРТОЧКИ (РЕФЕРЕНСЫ) ===================
top = f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{lbl("3D › РЕФЕРЕНСЫ", INK)}{micro("9 ЗАМЕТОК · 46 КАРТИНОК", MUT)}<span style="flex: 1"></span>{search_inp("Фильтр", w="200px")}{seg(["СПИСОК", "КАРТОЧКИ", "ТАБЛИЦА", "ГРАФ"], "КАРТОЧКИ")}{btn("＋ Заметка", "acc", True)}</div>'
st = node(0, 0, 1248, 48, top)
cards = [('Щиты: форма и кант', ['щит', 'металл'], 8), ('Средневековые мечи', ['оружие'], 6), ('Кожа и ремни', ['материал'], 5), ('Таверны: интерьер', ['dnd', 'интерьер'], 7),
         ('Стилизация: Arcane', ['стиль'], 4), ('Ржавчина и сколы', ['материал'], 5), ('Палитры: тёплый свет', ['свет'], 3), ('Броня паладина', ['броня', 'щит'], 6)]
for i, (t, tg, n) in enumerate(cards):
    x = (i % 4) * 316; y = 64 + (i // 4) * 316
    on = i == 0
    sel = f'; border-color: {ORL}' if on else ''
    hero = thumb('100%', 150, OR if i % 3 == 0 else (VIO if i == 3 else GOLD), '')
    strip = ''.join(f'<span style="flex: 1">{thumb("100%", 44, OR, "", 4)}</span>' for _ in range(3))
    inner = (f'<div style="padding: 8px 8px 0">{hero}<div style="display: flex; gap: 4px; margin-top: 4px">{strip}</div></div>'
             f'<div style="padding: 10px 12px"><div style="display: flex; align-items: baseline"><span style="font-weight: 600">{t}</span><span style="margin-left: auto; font: 400 10.5px {MONO}; color: {DIM}">{n} ФОТО</span></div>'
             f'<div style="display: flex; gap: 6px; margin-top: 8px">{"".join(tag(x_) for x_ in tg)}</div></div>')
    st += node(x, y, 300, 300, inner, style=sel)
st += ab(950, 64 + 316 + 300 + 4, '')
save3('G_NotesCards.dc.html', page('Карточки', 'ЗНАНИЯ', st, R), 'Знания · карточки с картинками', 4)


# =================== 6. ТАБЛИЦА ПО СВОЙСТВАМ ===================
top = f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{lbl("DND", INK)}{micro("52 ЗАМЕТКИ", MUT)}<span style="width: 1px; height: 20px; background: {LINE}"></span>{chip("ТИП: НПС ×", True, VIO)}{chip("＋ УСЛОВИЕ")}<span style="flex: 1"></span>{seg(["СПИСОК", "КАРТОЧКИ", "ТАБЛИЦА", "ГРАФ"], "ТАБЛИЦА")}{btn("＋ Заметка", "acc", True)}</div>'
st = node(0, 0, 1248, 48, top)
cols = [('НАЗВАНИЕ', 260), ('ТИП', 110), ('ГДЕ', 170), ('ФРАКЦИЯ', 170), ('СТАТУС', 130), ('ТЕГИ', 190), ('СВЯЗИ', 80), ('ИЗМЕНЕНО', 106)]
hd = ''.join(f'<span style="width: {w_}px; flex: none; padding: 0 12px; box-sizing: border-box">{lbl(t, MUT, 10)}</span>' for t, w_ in cols)
rows = f'<div style="display: flex; align-items: center; height: 40px; border-bottom: 1px solid {LINE}">{hd}</div>'
data = [('Мира Тёрн', 'НПС', 'Город Вельск', 'Пепельные', ('жива', GREEN), ['информатор'], 7, '03.11'),
        ('Борн', 'НПС', 'Таверна «Сломанный рог»', '—', ('жив', GREEN), ['гном', 'трактирщик'], 4, '01.11'),
        ('Капитан Эрра', 'НПС', 'Порт', 'Стража', ('пропала', GOLD), ['стража'], 5, '30.10'),
        ('Сестра Ильва', 'НПС', 'Храм Зари', 'Церковь', ('жива', GREEN), ['жрица'], 3, '28.10'),
        ('Человек в пепле', 'НПС', '?', 'Пепельные', ('тайна', VIO), ['злодей'], 9, '27.10'),
        ('Старый Кар', 'НПС', 'Доки', '—', ('погиб', RED), ['контрабанда'], 2, '22.10'),
        ('Лиса Вен', 'НПС', 'Рынок', 'Гильдия воров', ('жива', GREEN), ['воровка'], 4, '20.10')]
for k, (n, t, where, fr, (s, sc_), tg, l, d) in enumerate(data):
    bg = f'background: {HOVER};' if k == 0 else ''
    cells = [f'<span style="font-weight: 600">{n}</span>', f'<span style="color: {MUT}">{t}</span>', wl(where) if where not in ('?', '—') else f'<span style="color: {DIM}">{where}</span>',
             wl(fr) if fr != '—' else f'<span style="color: {DIM}">—</span>', f'<span style="display: inline-flex; align-items: center; gap: 6px">{dot(sc_)}{s}</span>',
             ' '.join(tag(x_) for x_ in tg), f'<span style="font: 400 11px {MONO}; color: {OR}">↔ {l}</span>', f'<span style="font: 400 11px {MONO}; color: {DIM}">{d}</span>']
    rows += f'<div style="display: flex; align-items: center; height: 44px; border-bottom: 1px solid {SOFT}; {bg}">' + ''.join(f'<span style="width: {w_}px; flex: none; padding: 0 12px; box-sizing: border-box; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{c}</span>' for c, (_, w_) in zip(cells, cols)) + '</div>'
rows += f'<div style="height: 40px; display: flex; align-items: center; padding: 0 12px; color: {MUT}">＋ Новая строка — новая заметка в DND с этими свойствами</div>'
st += node(0, 64, 1248, 0, nhead('', 'ТАБЛИЦА ПО СВОЙСТВАМ', 'СВОЙСТВА — ИЗ ШАПКИ ЗАМЕТОК (YAML)', VIO, MUT, 34) + rows, hub=True)
st += ab(0, 520, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; width: 560px; box-sizing: border-box">{coon(44, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Колонки — это свойства из шапки заметок: «тип», «где», «статус». Правка в ячейке меняет только эту строчку шапки, текст заметки не трогается.</span></div>')
save3('G_NotesTable.dc.html', page('Таблица', 'ЗНАНИЯ', st, R), 'Знания · таблица по свойствам', 5)


# =================== 7. ПОИСК CTRL K + ЗАМЕТКИ В ОКНЕ ЗАДАЧИ ===================
hl = lambda a, b, c_: f'{a}<span style="background: rgba(240,160,75,.22); color: {ORI}; border-radius: 3px; padding: 0 2px">{b}</span>{c_}'
def grp(t): return f'<div style="padding: 10px 18px 4px; font-size: 12px; color: {MUT}">{t}</div>'
res = grp('Заметки · 4')
for i, (t, s, f) in enumerate([(hl('', 'Запекание', ' нормалей'), '«…кейдж чуть больше модели…»', '3D'), ('Пайплайн ассета', hl('«4. ', 'Запекание', ' → [[Запекание нормалей]]»'), '3D'),
                               ('Курс: текстуры', hl('«урок 6 — ', 'запекание', '…»'), 'Учёба'), ('Щит паладина', hl('«нормали — см. [[', 'Запекание', ' нормалей]]»'), '3D')]):
    bg = f'background: {HOVER};' if i == 0 else ''
    res += f'<div style="margin: 0 8px; min-height: 44px; border-radius: 8px; {bg} display: flex; align-items: center; gap: 12px; padding: 4px 10px"><span style="font-size: 14px; color: {MUT}">¶</span><span style="flex: 1"><span style="display: block">{t}</span><span style="font-size: 12px; color: {MUT}">{s}</span></span><span style="display: flex; align-items: center; gap: 6px; font-size: 12px; color: {MUT}">{dot(FC[f])}{f}</span></div>'
res += grp('Задачи · 1')
res += f'<div style="margin: 0 8px; height: 40px; display: flex; align-items: center; gap: 12px; padding: 0 10px">{check()}<span style="flex: 1">Перепечь щит с новым кейджем</span><span style="font-size: 12px; color: {MUT}">3D-ассеты</span></div>'
res += grp('Действия')
res += f'<div style="padding: 0 8px">{mrow("Новая заметка «запекание»", kbd("CTRL ENTER"), icon="＋")}</div>'
body = f'''<div style="padding: 14px"><div style="height: 48px; border-radius: 10px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; gap: 10px; padding: 0 14px; font-size: 16px"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="{MUT}" stroke-width="1.8" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4"></path></svg>запекан<span style="display: inline-block; width: 1.5px; height: 20px; background: {OR}"></span><span style="margin-left: auto">{kbd("ESC")}</span></div></div>{res}
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 44px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 16px; padding: 0 18px; font-size: 12px; color: {MUT}"><span>{kbd("↑ ↓")} выбрать</span><span>{kbd("ENTER")} открыть</span><span style="margin-left: auto">Ищу по началу слов: «запекан» найдёт «запекание», ё = е</span></div>'''
st = dim(NOTES) + pop(40, 30, 640, 560, 'ПОИСК · CTRL K', body, OR, '5 НАЙДЕНО', hub=True)

# окно задачи: блок «Заметки»
tp = f'''<div style="padding: 16px 18px 0"><div style="font: 600 19px {SANS}">Рендер щита</div><div style="margin-top: 10px; padding: 8px 12px; border-radius: 8px; background: {HOVER}; font-size: 12.5px; color: {MUT}">3D-ассеты · этап «Рендер» · пт 17:00</div></div>
<div style="padding: 16px 18px 0"><div style="display: flex; align-items: center"><span style="font: 500 12.5px {SANS}; color: {MUT}">Заметки</span><span style="margin-left: auto; font-size: 12.5px; color: {OR}">＋ Связать</span></div>
 <div style="margin-top: 8px; display: flex; flex-direction: column; gap: 6px">
  <div style="display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 8px; border: 1px solid {LINE}">{dot(OR)}<span style="flex: 1">Запекание нормалей</span><span style="font: 400 10px {MONO}; color: {DIM}">3D/ТЕХНИКИ</span></div>
  <div style="display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 8px; border: 1px solid {LINE}">{dot(OR)}<span style="flex: 1">Щиты: форма и кант</span><span style="font: 400 10px {MONO}; color: {DIM}">8 ФОТО</span></div>
 </div></div>
<div style="padding: 16px 18px"><span style="font: 500 12.5px {SANS}; color: {MUT}">Из заметки в задачи</span>
 <div style="margin-top: 8px; padding: 10px 12px; border-radius: 8px; background: {BG}; border: 1px solid {LINE}; font-size: 12.5px; line-height: 22px">
  <div style="background: {WASH}; margin: 0 -6px; padding: 0 6px; border-radius: 4px">- [ ] Перепечь щит с новым кейджем</div>
  <div style="background: {WASH}; margin: 0 -6px; padding: 0 6px; border-radius: 4px">- [ ] Проверить фаски на ободе</div>
 </div>
 <div style="margin-top: 8px">{btn("Создать 2 задачи в Спутнике", "acc", True)}</div></div>'''
st += pop(720, 30, 528, 470, 'ОКНО ЗАДАЧИ · БЛОК «ЗАМЕТКИ»', tp, OR, '3D-АССЕТЫ')
st += node(720, 516, 528, 0, nhead('', 'БОТ → «00 ВХОДЯЩИЕ»', 'TELEGRAM', GREY, None, 30) +
           f'<div style="padding: 10px 14px; font-size: 12.5px; line-height: 19px; color: #C9CAD0"><span style="font: 400 12px {MONO}; color: {ORI}">/note</span> идея: таверна на сваях над болотом<br><span style="color: {MUT}">→ файл «00 Входящие/2026-11-05 Таверна на сваях.md» появится, когда откроешь Спутник</span></div>')
save3('G_NotesSearch.dc.html', page('Поиск по заметкам', 'ЗНАНИЯ', st, R), 'Знания · поиск Ctrl K, заметки в задаче, бот', 6)
print('ok')
