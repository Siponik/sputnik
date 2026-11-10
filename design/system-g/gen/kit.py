import json
OR = '#F0A04B'; ORI = '#FFD29C'; WASH = '#2E2722'; ORL = '#6A5238'
GROUND = '#191A1E'; BG = '#1C1D21'; NODE = '#25262B'; HOVER = '#2C2D33'
LINE = '#3A3B42'; SOFT = '#303137'; STRONG = '#6E7079'
INK = '#E2E3E8'; MUT = '#9A9CA6'; DIM = '#7A7C86'
BLUE = '#6FA2F2'; VIO = '#B48CF0'; GREEN = '#7FD18C'; GOLD = '#E8C65A'; GREY = '#A3A5AE'; RED = '#F0785F'
DARK = '#1E1F23'
MONO = "'JetBrains Mono', monospace"
SANS = "'Onest', 'Segoe UI', sans-serif"
P = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', 'screens') + '/'

LOGO = f'<svg width="22" height="22" viewBox="0 0 512 512" aria-hidden="true"><path d="M370.9 159.6 A150 150 0 1 0 370.9 352.4" fill="none" stroke="{OR}" stroke-width="46" stroke-linecap="round"/><circle cx="256" cy="256" r="62" fill="{INK}"/><circle cx="370.9" cy="159.6" r="42" fill="{INK}" stroke="{BG}" stroke-width="22"/></svg>'


def lbl(t, c=MUT, size=10.5, extra=''):
    return f'<span style="font: 500 {size}px {MONO}; letter-spacing: .14em; color: {c}{extra}">{t}</span>'


def micro(t, c=DIM, extra=''):
    return f'<span style="font: 400 9.5px {MONO}; letter-spacing: .12em; color: {c}{extra}">{t}</span>'


WIN_ICONS = {
    'min': '<path d="M1 5.5h9" stroke="currentColor" stroke-width="1.2"/>',
    'max': '<rect x="1.5" y="1.5" width="8" height="8" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.2"/>',
    'restore': '<rect x="1.5" y="3.5" width="6" height="6" rx="1.2" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M3.5 3.5V2.6c0-.6.5-1.1 1.1-1.1h4.3c.6 0 1.1.5 1.1 1.1v4.3c0 .6-.5 1.1-1.1 1.1H7.5" fill="none" stroke="currentColor" stroke-width="1.2"/>',
    'close': '<path d="M1.5 1.5l8 8M9.5 1.5l-8 8" stroke="currentColor" stroke-width="1.2"/>',
}


def winbtn(kind, state=''):
    bg = {'hover': HOVER, 'close': '#E5484D', 'press': SOFT}.get(state, 'transparent')
    col = '#FFFFFF' if state == 'close' else (INK if state else MUT)
    lab = {'min': 'Свернуть', 'max': 'Развернуть', 'restore': 'Восстановить', 'close': 'Закрыть'}[kind]
    return (f'<button type="button" aria-label="{lab}" style="width: 34px; height: 32px; border: 0; border-radius: 8px; background: {bg}; color: {col}; display: grid; place-items: center; padding: 0">'
            f'<svg width="11" height="11" viewBox="0 0 11 11" aria-hidden="true">{WIN_ICONS[kind]}</svg></button>')


def winctl(states=None, maxed=False):
    st = states or {}
    return (f'<span style="display: flex; align-items: center; gap: 2px; margin-left: 4px; padding-left: 10px; border-left: 1px solid {LINE}">'
            + winbtn('min', st.get('min', '')) + winbtn('restore' if maxed else 'max', st.get('max', '')) + winbtn('close', st.get('close', '')) + '</span>')


GEAR = (f'<button type="button" aria-label="Настройки · Ctrl ," style="width: 32px; height: 32px; border-radius: 8px; border: 1px solid {LINE}; background: transparent; color: {MUT}; display: grid; place-items: center; padding: 0">'
        '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg></button>')


def header(active='СЕГОДНЯ', right='ЧТ 05.11 · 14:52', hx=''):
    tabs = ''
    for t in ['СЕГОДНЯ', 'КАЛЕНДАРЬ', 'ДОСКА', 'ПРИВЫЧКИ']:
        if t == active:
            tabs += f'<a href="#" aria-current="page" style="text-decoration: none; color: {INK}; padding: 4px 0 3px; border-bottom: 1px solid {OR}">{t}</a>'
        else:
            tabs += f'<a href="#" style="text-decoration: none; color: {MUT}; padding: 4px 0 3px; border-bottom: 1px solid transparent">{t}</a>'
    return f'''<header style="display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; padding: 14px 16px 14px 20px; border-bottom: 1px solid {LINE}; background: {BG}; font: 500 11px {MONO}; letter-spacing: .14em">
    <span title="Спутник" style="display: flex; align-items: center">{LOGO}</span>
    <nav aria-label="Разделы" style="display: flex; align-items: center; gap: 18px; margin-left: 6px; flex-wrap: wrap">{tabs}</nav>
    <span style="flex: 1"></span>
    {hx}<span style="color: {MUT}; margin-right: 6px">{right}</span>
    <span style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px; border-radius: 8px; border: 1px solid {LINE}; color: {MUT}; min-width: 150px"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4"></path></svg>НАЙТИ<span style="margin-left: auto; font-size: 10px; color: {DIM}">CTRL K</span></span>
    <span style="display: flex; align-items: center; gap: 6px; height: 32px; padding: 0 10px; border-radius: 8px; border: 1px solid {LINE}; color: {MUT}" aria-label="Состояние: всё в порядке"><span style="width: 6px; height: 6px; border-radius: 2px; background: {GREEN}"></span><span style="width: 6px; height: 6px; border-radius: 2px; background: {GREEN}"></span><span style="width: 6px; height: 6px; border-radius: 2px; background: {GREEN}"></span></span>
    {GEAR}
    <button type="button" style="height: 32px; padding: 0 14px; border-radius: 8px; border: 0; background: {INK}; color: {BG}; font: 600 13px {SANS}; letter-spacing: 0">＋ Создать</button>
    {winctl()}
  </header>'''


GRID = f"background-color: {GROUND}; background-image: radial-gradient(rgba(255,255,255,.07) 1px, transparent 1.3px); background-size: 24px 24px"


def page(title, active, stage, right='ЧТ 05.11 · 14:52', stage_h=700, aria='', overlay='', hx=''):
    return f'''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Onest:wght@200;300;400;500;600&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap">
<style>
body{{margin:0;background:{BG}}}
a{{color:{OR}}}a:hover{{color:{ORI}}}
</style>
</helmet>
<div style="position: relative; min-height: 820px; box-sizing: border-box; background: {BG}; color: {INK}; font-family: {SANS}; font-size: 13px; display: flex; flex-direction: column">
  {header(active, right, hx)}
  <main aria-label="{aria or title}" style="flex: 1; overflow: auto; {GRID}; padding: 18px 16px 16px">
    <div style="position: relative; width: 1248px; height: {stage_h}px; margin: 0 auto">
{stage}
    </div>
  </main>
{overlay}
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":1280,"height":820}}}}'>
class Component extends DCLogic {{
  renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
'''


def dot(c, s=6):
    return f'<span style="width: {s}px; height: {s}px; flex: none; border-radius: 2px; background: {c}"></span>'


def sock(side, top, fill, ring=False, abs_left=None):
    if abs_left is not None:
        pos = f'left: {abs_left}px'
    else:
        pos = 'right: -6px' if side == 'r' else ('left: -6px' if side == 'l' else side)
    st = f"background: {GROUND}; border: 1.5px solid {fill}" if ring else f"background: {fill}; border: 1.5px solid {GROUND}"
    return f'<span style="position: absolute; {pos}; top: {top}px; width: 10px; height: 10px; border-radius: 3px; box-sizing: border-box; {st}"></span>'


FILL = {OR: '#8A5320', BLUE: '#2F4F86', VIO: '#5E3F92', GREEN: '#2E6B3E', GOLD: '#7A6620', GREY: '#3D3E45', RED: '#8A3A2E'}
HUBFILL = '#9A5A22'


def nhead(num, name, kind='', color=OR, kc=None, h=30, namec=INK, under=LINE):
    if not color:
        n = f'<span style="color: {DIM}">{num}</span>' if num else ''
        k = f'<span style="margin-left: auto; color: {kc or DIM}">{kind}</span>' if kind else ''
        return (f'<div style="height: {h}px; box-sizing: border-box; padding: 0 10px 0 12px; border-bottom: 1px solid {under}; display: flex; align-items: center; gap: 8px; font: 500 10.5px {MONO}; letter-spacing: .14em">'
                f'{n}<span style="color: {namec}">{name}</span>{k}</div>')
    hub = under == OR
    bg = HUBFILL if hub else FILL.get(color, '#3D3E45')
    r = 11 if hub else 7
    soft = 'rgba(255,255,255,.72)'
    n = f'<span style="color: {soft}">{num}</span>' if num else ''
    k = f'<span style="margin-left: auto; color: {soft}">{kind}</span>' if kind else ''
    return (f'<div style="height: {h}px; box-sizing: border-box; padding: 0 10px 0 12px; border-radius: {r}px {r}px 0 0; background: {bg}; display: flex; align-items: center; gap: 8px; font: 500 10.5px {MONO}; letter-spacing: .14em">'
            f'{n}<span style="color: #FFFFFF">{name}</span>{k}</div>')


def node(x, y, w, h, inner, hub=False, wait=False, extra='', bg=NODE, r=None, style=''):
    if hub:
        b = f'1px solid {ORL}'; rr = r or 12; sh = '; box-shadow: 0 18px 40px rgba(0,0,0,.35)'
        ticks = ''.join(f'<span style="position: absolute; {v}: -5px; {hh}: -5px; width: 14px; height: 14px; border-{v}-{hh}-radius: 14px; border-{v}: 1.5px solid {OR}; border-{hh}: 1.5px solid {OR}"></span>' for v in ('top', 'bottom') for hh in ('left', 'right'))
    else:
        b = f'1px dashed #55575F' if wait else f'1px solid {LINE}'; rr = r or 8; sh = ''; ticks = ''
    hh_ = f'height: {h}px; ' if h else ''
    return f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; {hh_}box-sizing: border-box; border-radius: {rr}px; background: {bg}; border: {b}{sh}{style}">{ticks}{inner}{extra}</div>'


def wire(x1, y1, x2, y2, c, w=1.5, dash=False, k=60):
    d = ' stroke-dasharray="4 4"' if dash else ''
    return f'<path d="M{x1} {y1} C {x1 + k} {y1}, {x2 - k} {y2}, {x2} {y2}" stroke="{c}" stroke-width="{w}"{d}></path>'


def vwire(x1, y1, x2, y2, c, w=1.5, dash=False, k=40):
    d = ' stroke-dasharray="4 4"' if dash else ''
    return f'<path d="M{x1} {y1} C {x1} {y1 + k}, {x2} {y2 - k}, {x2} {y2}" stroke="{c}" stroke-width="{w}"{d}></path>'


def svg(paths, w=1248, h=700):
    return f'<svg width="{w}" height="{h}" style="position: absolute; left: 0; top: 0" aria-hidden="true" fill="none">{paths}</svg>'


def colhead(x, y, w, t):
    return f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; display: flex; align-items: center; gap: 8px; font: 500 10px {MONO}; letter-spacing: .16em; color: {DIM}"><span>{t}</span><span style="flex: 1; height: 1px; background: {LINE}"></span></div>'


def btn(t, kind='sec', sm=False, extra=''):
    h = 28 if sm else 32; fs = 12.5 if sm else 13
    if kind == 'acc':
        s = f'border: 0; background: {OR}; color: {DARK}; font: 600 {fs}px {SANS}'
    elif kind == 'ink':
        s = f'border: 0; background: {INK}; color: {BG}; font: 600 {fs}px {SANS}'
    elif kind == 'ghost':
        s = f'border: 0; background: transparent; color: {MUT}; font: 500 {fs}px {SANS}'
    else:
        s = f'border: 1px solid {STRONG}; background: transparent; color: {INK}; font: 500 {fs}px {SANS}'
    return f'<button type="button" style="height: {h}px; padding: 0 12px; border-radius: 6px; {s}{extra}">{t}</button>'


def chip(t, on=False, c=OR, extra=''):
    if on:
        s = f'background: {WASH}; border: 1px solid {c}; color: {INK}'
    else:
        s = f'background: transparent; border: 1px solid {LINE}; color: {MUT}'
    return f'<button type="button" style="height: 28px; padding: 0 10px; border-radius: 6px; {s}; font: 500 10.5px {MONO}; letter-spacing: .12em; display: inline-flex; align-items: center; gap: 6px{extra}">{t}</button>'


def seg(items, active):
    out = ''
    for t in items:
        if t == active:
            out += f'<span style="padding: 0 10px; height: 26px; display: flex; align-items: center; border-radius: 5px; background: {INK}; color: {BG}">{t}</span>'
        else:
            out += f'<span style="padding: 0 10px; height: 26px; display: flex; align-items: center; color: {MUT}">{t}</span>'
    return f'<span role="group" style="display: inline-flex; padding: 2px; border-radius: 7px; border: 1px solid {LINE}; font: 500 10.5px {MONO}; letter-spacing: .12em">{out}</span>'


def check(done=False, c=STRONG):
    if done:
        return f'<span style="width: 14px; height: 14px; flex: none; border-radius: 4px; background: #45464D; display: grid; place-items: center; font-size: 9px; color: {INK}">✓</span>'
    return f'<span style="width: 14px; height: 14px; flex: none; border-radius: 4px; box-sizing: border-box; border: 1px solid {c}"></span>'


def stages(n_ok, n_now, total, h=4):
    s = ''
    for i in range(total):
        c = GREEN if i < n_ok else (OR if i == n_now else '#45464D')
        s += f'<span style="flex: 1; height: {h}px; border-radius: 2px; background: {c}"></span>'
    return f'<span style="display: flex; gap: 3px">{s}</span>'


def coon(size=50, label=''):
    """Знак-спутник вместо енота: ядро на орбите, цвет по состоянию."""
    c = {'ОЙ': RED, 'СПИТ': DIM, 'ДУМАЕТ': GOLD, 'УРА': GREEN}.get(label, OR)
    return (f'<span aria-hidden="true" style="width: {size}px; height: {size}px; flex: none; border-radius: 50%; background: {DARK}; border: 1px solid {LINE}; display: grid; place-items: center">'
            f'<svg width="{int(size*.72)}" height="{int(size*.72)}" viewBox="0 0 40 40"><ellipse cx="20" cy="20" rx="17" ry="7" transform="rotate(-28 20 20)" fill="none" stroke="{c}" stroke-opacity=".55" stroke-width="1.4"/>'
            f'<circle cx="20" cy="20" r="6" fill="{INK}"/><circle cx="34" cy="12.5" r="3.2" fill="{c}"/></svg></span>')


def stamp(x, y, sheet, a, b, w=280):
    return (f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; box-sizing: border-box; border-radius: 8px; border: 1px solid {LINE}; display: grid; grid-template-columns: 1fr 1fr 1fr; font: 400 9.5px {MONO}; letter-spacing: .12em; color: {DIM}">'
            f'<span style="grid-column: 1 / 4; padding: 6px 8px; border-bottom: 1px solid {LINE}; color: {INK}">ЛИСТ · {sheet}</span>'
            f'<span style="padding: 6px 8px; border-right: 1px solid {LINE}">05.11.26</span><span style="padding: 6px 8px; border-right: 1px solid {LINE}">{a}</span><span style="padding: 6px 8px">{b}</span></div>')


def dimline(x, y, w, t):
    return f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; display: flex; align-items: center; gap: 8px; font: 400 9.5px {MONO}; letter-spacing: .12em; color: {DIM}"><span>|</span><span style="flex: 1; height: 1px; background: #45464D"></span><span>{t}</span><span style="flex: 1; height: 1px; background: #45464D"></span><span>|</span></div>'


def hatch(c=OR, a=.07):
    return f'background-color: {WASH}; background-image: repeating-linear-gradient(-45deg, rgba(240,160,75,{a}) 0 1px, transparent 1px 7px)'


def ab(x, y, inner, w=None, extra=''):
    ww = f' width: {w}px;' if w else ''
    return f'<div style="position: absolute; left: {x}px; top: {y}px;{ww}{extra}">{inner}</div>'


def save(fname, html, title, x, y, page_id):
    open(P + fname, 'w').write(html)
    c = json.load(open(P + 'canvas.json'))
    c['boards'][fname] = {"x": x, "y": y, "w": 1280, "h": 820, "title": title, "expand": "fill", "page": page_id}
    if fname not in c['order']:
        c['order'].append(fname)
    json.dump(c, open(P + 'canvas.json', 'w'), ensure_ascii=False, indent=1)


def slot(fname):
    c = json.load(open(P + 'canvas.json'))
    if fname in c['boards']:
        b = c['boards'][fname]; return b['x'], b['y']
    n = sum(1 for b in c['boards'].values() if b.get('page') == 'r4')
    return (n % 2) * 1360, (n // 2) * 940


def save2(fname, html, title):
    x, y = slot(fname)
    save(fname, html, title, x, y, 'r4')


def dim(stage, o=.25):
    return f'<div style="position: absolute; inset: 0; opacity: {o}; pointer-events: none">{stage}</div>'


SH = '; box-shadow: 0 18px 40px rgba(0,0,0,.45)'


def pop(x, y, w, h, title, body, color=GREY, kind='', hub=False):
    return node(x, y, w, h, nhead('', title, kind, color, None, 32, INK, OR if hub else LINE) + body, hub=hub, style=SH)


def sc(t, on=False, c=OR, x=False):
    s = f'background: {WASH}; border: 1px solid {c}; color: {INK}' if on else f'background: transparent; border: 1px solid {LINE}; color: #C9CAD0'
    cl = f'<span style="color: {MUT}; margin-left: 2px">×</span>' if x else ''
    return f'<button type="button" style="height: 30px; padding: 0 12px; border-radius: 8px; {s}; font: 400 13px {SANS}; display: inline-flex; align-items: center; gap: 6px">{t}{cl}</button>'


def field(label, inner):
    return f'<div style="display: flex; flex-direction: column; gap: 8px"><span style="font: 500 12.5px {SANS}; color: {MUT}">{label}</span><div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center">{inner}</div></div>'


def kbd(t):
    return f'<span style="font: 400 10px {MONO}; letter-spacing: .08em; color: {DIM}; border: 1px solid {LINE}; border-radius: 4px; padding: 1px 5px">{t}</span>'


def mrow(t, right='', on=False, c=None, danger=False, icon=''):
    bg = f'background: {HOVER};' if on else ''
    col = RED if danger else INK
    d = dot(c) if c else ''
    ic = f'<span style="width: 16px; color: {MUT}">{icon}</span>' if icon else ''
    r = f'<span style="margin-left: auto">{right}</span>' if right else ''
    return f'<div style="height: 32px; display: flex; align-items: center; gap: 10px; padding: 0 10px; border-radius: 6px; {bg} color: {col}">{ic}{d}<span>{t}</span>{r}</div>'


def toast(x, y, w, text, action='', c=GREEN):
    a = f'<button type="button" style="height: 28px; padding: 0 12px; border-radius: 6px; border: 0; background: transparent; color: {OR}; font: 600 13px {SANS}">{action}</button>' if action else ''
    return f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; height: 44px; box-sizing: border-box; border-radius: 10px; background: #2F3036; border: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 8px 0 14px{SH}">{dot(c, 8)}<span style="flex: 1">{text}</span>{a}</div>'


def toggle(on=True, label=''):
    tr = f'background: {OR}' if on else f'background: #45464D'
    kn = 'left: 18px' if on else 'left: 2px'
    l = f'<span>{label}</span>' if label else ''
    return f'<span style="display: inline-flex; align-items: center; gap: 10px">{l}<span role="switch" aria-checked="{"true" if on else "false"}" style="position: relative; width: 36px; height: 20px; border-radius: 999px; {tr}; flex: none"><span style="position: absolute; top: 2px; {kn}; width: 16px; height: 16px; border-radius: 50%; background: #FFFFFF"></span></span></span>'


def srow(label, hint, ctrl):
    h = f'<span style="display: block; font-size: 12px; color: {MUT}; margin-top: 2px">{hint}</span>' if hint else ''
    return f'<div style="display: flex; align-items: center; gap: 16px; padding: 12px 0; border-bottom: 1px solid {SOFT}"><span style="flex: 1; min-width: 0"><span style="display: block">{label}</span>{h}</span>{ctrl}</div>'


def ddtrig(t, w=220, c=LINE):
    return f'<span style="display: inline-flex; align-items: center; gap: 8px; width: {w}px; height: 32px; box-sizing: border-box; border-radius: 8px; border: 1px solid {c}; padding: 0 10px">{t}<span style="margin-left: auto; color: {MUT}">▾</span></span>'


def av(ch, c, s=22, ring=False, dashed=False):
    b = f'border: 1.5px dashed {c}; background: transparent; color: {c}' if dashed else f'background: {c}; color: {DARK}'
    r = f'; box-shadow: 0 0 0 2px {NODE}, 0 0 0 3.5px {OR}' if ring else f'; box-shadow: 0 0 0 2px {NODE}'
    return f'<span style="width: {s}px; height: {s}px; flex: none; border-radius: 50%; box-sizing: border-box; {b}; display: grid; place-items: center; font: 600 {int(s * .45)}px {SANS}{r}">{ch}</span>'


def avs(items, s=22):
    return '<span style="display: inline-flex">' + ''.join(f'<span style="margin-left: {0 if i == 0 else -6}px">{av(ch, c, s)}</span>' for i, (ch, c) in enumerate(items)) + '</span>'
