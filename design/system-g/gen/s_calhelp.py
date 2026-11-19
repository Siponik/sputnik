import kit
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
def rgba(h, a):
    h = h.lstrip('#'); return f'rgba({int(h[0:2],16)},{int(h[2:4],16)},{int(h[4:6],16)},{a})'
PINK = '#F08CC0'
def cap(x, y, n, t, w=600): return ab(x, y, f'<div style="display: flex; gap: 8px; align-items: baseline"><span style="font: 500 10.5px {MONO}; color: {OR}">{n}</span><span style="font: 500 10px {MONO}; letter-spacing: .16em; color: {MUT}">{t}</span></div>', w=w)
def note(x, y, w, t): return ab(x, y, f'<div style="font-size: 12px; color: #C9CAD0; line-height: 1.5">{t}</div>', w=w)
# блок события в сетке
def blk(x, y, w, h, t, tm, c, kind='task', done=False, ghost=False):
    col = c
    if tm.endswith(':00') and not tm.startswith('+'): tm = ''
    bg = rgba(col, .10) if not done else '#25262B'
    bd = f'1px solid {rgba(col, .55)}' if not done else f'1px solid {LINE}'
    if ghost: bd = f'1px dashed {OR}'; bg = rgba(OR, .10)
    tc = DIM if done else INK
    mark = (f'<span style="width: 8px; height: 8px; border-radius: 50%; box-sizing: border-box; flex: none; border: 1.5px solid {col}"></span>' if kind == 'task' else f'<span style="width: 3px; align-self: stretch; border-radius: 2px; background: {col}; flex: none"></span>')
    if kind == 'habit':
        mark = f'<span style="width: 8px; height: 8px; border-radius: 2px; box-sizing: border-box; flex: none; border: 1.5px solid {GOLD}"></span>'; bd = f'1px dashed {rgba(GOLD, .7)}'; bg = rgba(GOLD, .07)
    if done: mark = f'<span style="flex: none; width: 10px; height: 10px; border-radius: 3px; background: #45464D; display: grid; place-items: center; color: {INK}; font-size: 8px">✓</span>'
    if h < 34:  # короткое: одна строка, время и название рядом
        inner = f'<div style="display: flex; align-items: center; gap: 6px; height: 100%; padding: 0 6px; white-space: nowrap; overflow: hidden">{mark}<span style="font: 400 10px {MONO}; color: {MUT}">{tm}</span><span style="font-size: 12px; color: {tc}; overflow: hidden; text-overflow: ellipsis">{t}</span></div>'
    else:
        inner = f'<div style="display: flex; gap: 6px; padding: 5px 7px; height: 100%; box-sizing: border-box">{mark}<div style="min-width: 0"><div style="font: 400 10px {MONO}; color: {MUT}">{tm}</div><div style="font-size: 12px; color: {tc}; line-height: 1.3; overflow: hidden; display: -webkit-box; -webkit-line-clamp: {max(1, (h - 22) // 16)}; -webkit-box-orient: vertical">{t}</div></div></div>'
    return ab(x, y, f'<div style="width: {w}px; height: {h}px; box-sizing: border-box; border-radius: 5px; background: {bg}; border: {bd}; overflow: hidden">{inner}</div>')
def grid(x, y, w, h, rows, r0=8, rh=30, cols=1, colw=None):
    s = ''
    for i in range(rows):
        s += f'<div style="position: absolute; left: 0; right: 0; top: {i * rh}px; height: {rh}px; border-top: 1px solid {SOFT}"><span style="position: absolute; left: 4px; top: 2px; font: 400 9.5px {MONO}; color: {DIM}">{(r0 + i) % 24:02d}</span></div>'
    for j in range(1, cols):
        s += f'<div style="position: absolute; top: 0; bottom: 0; left: {36 + j * colw}px; border-left: 1px solid {SOFT}"></div>'
    return ab(x, y, f'<div style="position: relative; width: {w}px; height: {h}px; border-radius: 6px; border: 1px solid {LINE}; background: {NODE}; overflow: hidden">{s}</div>')
