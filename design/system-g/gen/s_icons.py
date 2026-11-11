# Иконки «Системы G»: 24×24, линия 1.6, скруглённые концы, currentColor. Запуск: python3 s_icons.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

I = {}
def ic(name, body): I[name] = body

# Разделы шапки
ic('today', '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/>')
ic('calendar', '<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/><circle cx="8.5" cy="14.5" r=".9" fill="currentColor"/>')
ic('board', '<rect x="3.5" y="4" width="5" height="16" rx="1.6"/><rect x="9.5" y="4" width="5" height="10" rx="1.6"/><rect x="15.5" y="4" width="5" height="13" rx="1.6"/>')
ic('habits', '<path d="M4 12.5l4 4 4.5-5"/><path d="M12.5 15.5l1 1 6.5-8"/><path d="M4 6h7"/>')
ic('notes', '<path d="M6 3.5h8.5L19 8v12.5H6z"/><path d="M14 3.5V8h5M9 12h7M9 15.5h5"/>')
ic('graph', '<circle cx="6" cy="7" r="2.2"/><circle cx="18" cy="6" r="2.2"/><circle cx="12" cy="13" r="2.6"/><circle cx="6.5" cy="19" r="2"/><circle cx="18" cy="18" r="2"/><path d="M7.8 8.3l2.4 2.9M16.3 7.4l-2.6 3.6M10.4 14.9l-2.5 2.6M14.3 14.4l2.2 2.3"/>')
ic('canvas', '<rect x="3.5" y="4" width="7" height="6" rx="1.6"/><rect x="13.5" y="14" width="7" height="6" rx="1.6"/><path d="M10.5 7h3a3 3 0 0 1 3 3v4"/><circle cx="6" cy="17" r="2.3"/>')
ic('spheres', '<circle cx="9" cy="10" r="5.5"/><circle cx="15.5" cy="14.5" r="5"/>')
ic('archive', '<rect x="3.5" y="4" width="17" height="4.5" rx="1.4"/><path d="M5 8.5V19a1.5 1.5 0 0 0 1.5 1.5h11A1.5 1.5 0 0 0 19 19V8.5M10 12.5h4"/>')
ic('templates', '<rect x="3.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.6" stroke-dasharray="2.4 2"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.6" stroke-dasharray="2.4 2"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.6"/>')
# Шапка: действия
ic('search', '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.3-4.3"/>')
ic('plus', '<path d="M12 5v14M5 12h14"/>')
ic('settings', '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>')
ic('status', '<circle cx="5.5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/>')
ic('inbox', '<path d="M3.5 13.5l2.5-8h12l2.5 8V19a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19z"/><path d="M3.5 13.5h4.5l1.5 2.5h5l1.5-2.5h4.5"/>')
ic('update', '<path d="M12 4v10M7.5 9.5L12 14l4.5-4.5"/><path d="M4.5 16v2.5A1.5 1.5 0 0 0 6 20h12a1.5 1.5 0 0 0 1.5-1.5V16"/>')
ic('timer', '<circle cx="12" cy="13" r="7.5"/><path d="M12 9v4l2.5 2M10 2.5h4"/>')
ic('sidebar', '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><path d="M9 4.5v15"/>')
# Задачи
ic('check', '<path d="M5 12.5l4.5 4.5L19 7.5"/>')
ic('circle', '<circle cx="12" cy="12" r="7.5"/>')
ic('done', '<circle cx="12" cy="12" r="7.5"/><path d="M8.5 12.3l2.4 2.4 4.6-5"/>')
ic('priority', '<path d="M6 20V4.5M6 5h10.5l-2.5 4 2.5 4H6"/>')
ic('subtasks', '<path d="M5 4v12a2 2 0 0 0 2 2h3M5 9h5"/><rect x="11" y="6" width="9" height="6" rx="1.6"/><rect x="11" y="15" width="9" height="6" rx="1.6"/>')
ic('repeat', '<path d="M4 11a7 7 0 0 1 12-4.9L18.5 8.5M18.5 4v4.5H14"/><path d="M20 13a7 7 0 0 1-12 4.9L5.5 15.5M5.5 20v-4.5H10"/>')
ic('bell', '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>')
ic('note', '<path d="M4.5 6h15M4.5 11h15M4.5 16h9"/>')
ic('image', '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="M4 17.5l5-4.5 4 3.5 2.5-2 4.5 3.5"/>')
ic('tag', '<path d="M3.5 12.5V5a1.5 1.5 0 0 1 1.5-1.5h7.5l8 8-9 9z"/><circle cx="8" cy="8" r="1.4"/>')
ic('client', '<circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/>')
ic('money', '<rect x="3" y="6" width="18" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.6"/><path d="M6.5 9.5v5M17.5 9.5v5"/>')
ic('stage', '<circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2" stroke-dasharray="1.8 1.6"/><path d="M7 12h3M14 12h3"/>')
ic('pin', '<path d="M9 3.5h6l-1 5 3.5 3.5h-11L10 8.5z"/><path d="M12 12v8.5"/>')
ic('move', '<path d="M4 12h15M14 7l5 5-5 5"/>')
ic('copy', '<rect x="8" y="8" width="12" height="12" rx="2.2"/><path d="M16 8V5.5A1.5 1.5 0 0 0 14.5 4h-9A1.5 1.5 0 0 0 4 5.5v9A1.5 1.5 0 0 0 5.5 16H8"/>')
ic('trash', '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 12.5a1.5 1.5 0 0 0 1.5 1.5h6a1.5 1.5 0 0 0 1.5-1.5l1-12.5"/>')
ic('edit', '<path d="M4 20l1-4.5L15.5 5a2.1 2.1 0 0 1 3 3L8 18.5z"/><path d="M13.5 7l3 3"/>')
ic('more', '<circle cx="5.5" cy="12" r="1.4" fill="currentColor"/><circle cx="12" cy="12" r="1.4" fill="currentColor"/><circle cx="18.5" cy="12" r="1.4" fill="currentColor"/>')
ic('open', '<path d="M13 4.5h6.5V11M19.5 4.5l-8 8"/><path d="M17 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-10A1.5 1.5 0 0 1 4 18.5v-10A1.5 1.5 0 0 1 5.5 7H10"/>')
ic('undo', '<path d="M9 5L4.5 9.5 9 14"/><path d="M4.5 9.5H14a5.5 5.5 0 0 1 0 11h-3"/>')
# Календарь и время
ic('clock', '<circle cx="12" cy="12" r="8"/><path d="M12 7.5V12l3 2"/>')
ic('event', '<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/><rect x="7" y="13" width="6" height="4" rx="1" fill="currentColor" stroke="none"/>')
ic('birthday', '<path d="M4.5 20.5h15M5.5 20.5v-7h13v7M5.5 16.5c2 1.3 4.5 1.3 6.5 0s4.5-1.3 6.5 0"/><path d="M12 13.5V10"/><path d="M12 8.5c-1.2-1-1.2-2.6 0-4 1.2 1.4 1.2 3 0 4z"/>')
ic('week', '<rect x="3.5" y="5" width="17" height="14" rx="3"/><path d="M8.5 5v14M12 5v14M15.5 5v14"/>')
ic('month', '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><path d="M3.5 9.5h17M3.5 14.5h17M9 4.5v15M15 4.5v15"/>')
ic('prev', '<path d="M14.5 6l-6 6 6 6"/>')
ic('next', '<path d="M9.5 6l6 6-6 6"/>')
ic('freeslot', '<rect x="3.5" y="5" width="17" height="14" rx="3" stroke-dasharray="3 2.4"/><path d="M12 9v6M9 12h6"/>')
# Настройки
ic('theme', '<path d="M12 3.5a8.5 8.5 0 1 0 8.5 8.5A6.5 6.5 0 0 1 12 3.5z"/>')
ic('accent', '<path d="M12 3.5c3 4 6 7 6 10.5a6 6 0 0 1-12 0c0-3.5 3-6.5 6-10.5z"/>')
ic('motion', '<path d="M3.5 15c2.5 0 3-6 6-6s3.5 6 6 6 3-3 5-3"/><circle cx="20.5" cy="12" r="1.2" fill="currentColor"/>')
ic('eye', '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>')
ic('eyeoff', '<path d="M4 4l16 16M9.8 6A9.6 9.6 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a16 16 0 0 1-2.9 3.6M6.4 7.6A15.6 15.6 0 0 0 2.5 12S6 18.5 12 18.5a9 9 0 0 0 4-.9"/><path d="M10 10a3 3 0 0 0 4 4"/>')
ic('telegram', '<path d="M20.5 4.5L3.5 11l6 2.5M20.5 4.5L17.5 19.5l-8-6M20.5 4.5L9.5 13.5v5l3-3"/>')
ic('sync', '<path d="M4.5 12a7.5 7.5 0 0 1 13.3-4.7M19.5 4v4.5H15"/><path d="M19.5 12a7.5 7.5 0 0 1-13.3 4.7M4.5 20v-4.5H9"/>')
ic('cloud', '<path d="M7 18.5a4.5 4.5 0 0 1-.4-9 6 6 0 0 1 11.5 1.5 3.8 3.8 0 0 1-.6 7.5z"/>')
ic('backup', '<path d="M4 7.5a8 8 0 1 1-.5 6"/><path d="M3.5 4v4h4M12 8v4.5l3 1.5"/>')
ic('keyboard', '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M6 10h.01M9.5 10h.01M13 10h.01M16.5 10h.01M8 14.5h8"/>')
ic('key', '<circle cx="8" cy="15" r="4"/><path d="M11 12l8.5-8.5M16.5 6.5l2.5 2.5M14 9l2 2"/>')
ic('google', '<path d="M20 12.2c0-.7-.1-1.2-.2-1.8H12v3.4h4.5a4 4 0 0 1-1.7 2.6"/><path d="M14.8 16.4A6.5 6.5 0 1 1 16.4 7.4"/>')
ic('folder', '<path d="M3.5 7V18a1.5 1.5 0 0 0 1.5 1.5h14a1.5 1.5 0 0 0 1.5-1.5V9.5A1.5 1.5 0 0 0 19 8h-7l-2-2.5H5A1.5 1.5 0 0 0 3.5 7z"/>')
ic('beta', '<path d="M9 3.5h6M10 3.5v5.5l-5 9a1.5 1.5 0 0 0 1.3 2.2h11.4a1.5 1.5 0 0 0 1.3-2.2l-5-9V3.5"/><path d="M7 15h10"/>')
ic('share', '<circle cx="8" cy="9" r="3"/><circle cx="16.5" cy="10" r="2.5"/><path d="M3 19a5 5 0 0 1 10 0M13.5 18a4 4 0 0 1 7.5 0"/>')
# Состояния
ic('online', '<path d="M5 12.5a10 10 0 0 1 14 0M8 15.5a5.5 5.5 0 0 1 8 0"/><circle cx="12" cy="18.5" r="1.2" fill="currentColor"/><path d="M2 9.5a14.5 14.5 0 0 1 20 0"/>')
ic('offline', '<path d="M3 3l18 18M8 15.5a5.5 5.5 0 0 1 4.5-1.6M5 12.5a10 10 0 0 1 4.6-2.4M14.5 10.4A10 10 0 0 1 19 12.5"/><circle cx="12" cy="18.5" r="1.2" fill="currentColor"/>')
ic('warn', '<path d="M12 4l9 15.5H3z"/><path d="M12 10v4.5"/><circle cx="12" cy="17" r=".9" fill="currentColor"/>')
ic('info', '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5"/><circle cx="12" cy="8" r=".9" fill="currentColor"/>')
ic('star', '<path d="M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8L3.5 9.7l5.9-.8z"/>')
ic('fire', '<path d="M12 21a6 6 0 0 0 6-6c0-4-3-6.5-4-10-2.5 2-4 4-4 6.5-1-.5-1.5-1.5-1.5-3C6.5 10 6 12.5 6 15a6 6 0 0 0 6 6z"/>')
ic('orbit', '<ellipse cx="12" cy="12" rx="9" ry="4" transform="rotate(-28 12 12)"/><circle cx="12" cy="12" r="3"/><circle cx="19.5" cy="8" r="1.4" fill="currentColor"/>')
# Знания
ic('link', '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>')
ic('backlinks', '<path d="M19.5 5v6a3 3 0 0 1-3 3H6"/><path d="M9.5 10.5L6 14l3.5 3.5"/>')
ic('read', '<path d="M3.5 5.5h6A2.5 2.5 0 0 1 12 8v12a2 2 0 0 0-2-2H3.5zM20.5 5.5h-6A2.5 2.5 0 0 0 12 8v12a2 2 0 0 1 2-2h6.5z"/>')
ic('focus', '<circle cx="12" cy="12" r="3"/><path d="M4 8.5V5.5A1.5 1.5 0 0 1 5.5 4h3M15.5 4h3A1.5 1.5 0 0 1 20 5.5v3M20 15.5v3a1.5 1.5 0 0 1-1.5 1.5h-3M8.5 20h-3A1.5 1.5 0 0 1 4 18.5v-3"/>')
ic('expand', '<path d="M14 4h6v6M20 4l-6.5 6.5M10 20H4v-6M4 20l6.5-6.5"/>')
ic('filter', '<path d="M4 5h16l-6 7.5V19l-4 1.5v-8z"/>')
ic('sort', '<path d="M7 4v16M3.5 16.5L7 20l3.5-3.5M17 20V4M13.5 7.5L17 4l3.5 3.5"/>')
# Окно
ic('minimize', '<path d="M6 12h12"/>')
ic('maximize', '<rect x="6" y="6" width="12" height="12" rx="2"/>')
ic('restore', '<rect x="5.5" y="8.5" width="10" height="10" rx="2"/><path d="M8.5 8.5V7a1.5 1.5 0 0 1 1.5-1.5h7A1.5 1.5 0 0 1 18.5 7v7a1.5 1.5 0 0 1-1.5 1.5h-1.5"/>')
ic('close', '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>')
ic('drag', '<circle cx="9" cy="6.5" r="1.2" fill="currentColor"/><circle cx="15" cy="6.5" r="1.2" fill="currentColor"/><circle cx="9" cy="12" r="1.2" fill="currentColor"/><circle cx="15" cy="12" r="1.2" fill="currentColor"/><circle cx="9" cy="17.5" r="1.2" fill="currentColor"/><circle cx="15" cy="17.5" r="1.2" fill="currentColor"/>')

def svg_(name, size=24):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{I[name]}</svg>')

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'icons')
os.makedirs(out, exist_ok=True)
for n in I:
    open(os.path.join(out, n + '.svg'), 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">{I[n]}</svg>\n')

GROUPS = [('РАЗДЕЛЫ', OR, ['today', 'calendar', 'board', 'habits', 'notes', 'graph', 'canvas', 'spheres', 'archive', 'templates']),
          ('ШАПКА', GREY, ['search', 'plus', 'settings', 'status', 'inbox', 'update', 'timer', 'sidebar']),
          ('ЗАДАЧИ', BLUE, ['check', 'circle', 'done', 'priority', 'subtasks', 'repeat', 'bell', 'note', 'image', 'tag', 'client', 'money', 'stage', 'pin', 'move', 'copy', 'trash', 'edit', 'more', 'open', 'undo']),
          ('КАЛЕНДАРЬ', GREEN, ['clock', 'event', 'birthday', 'week', 'month', 'prev', 'next', 'freeslot']),
          ('НАСТРОЙКИ', VIO, ['theme', 'accent', 'motion', 'eye', 'eyeoff', 'telegram', 'sync', 'cloud', 'backup', 'keyboard', 'key', 'google', 'folder', 'beta', 'share']),
          ('СОСТОЯНИЯ', GOLD, ['online', 'offline', 'warn', 'info', 'star', 'fire', 'orbit']),
          ('ЗНАНИЯ', OR, ['link', 'backlinks', 'read', 'focus', 'expand', 'filter', 'sort']),
          ('ОКНО', GREY, ['minimize', 'maximize', 'restore', 'close', 'drag'])]

def cell(n):
    return (f'<div style="display: flex; flex-direction: column; align-items: center; gap: 6px; width: 74px; padding: 10px 0 8px; border-radius: 8px; color: {INK}">'
            f'{svg_(n)}<span style="font: 400 9.5px {MONO}; color: {MUT}; letter-spacing: .04em">{n}</span></div>')

# раскладка: две колонки нод
st = ab(0, 0, f'<div style="display: flex; gap: 12px; align-items: center">{lbl("ИКОНКИ", INK)}{micro("24 PX · ЛИНИЯ 1.6 · СКРУГЛЁННЫЕ КОНЦЫ · ЦВЕТ — CURRENTCOLOR · ФАЙЛЫ: DESIGN/SYSTEM-G/ICONS/*.SVG", MUT)}</div>', w=1248)
colx = [0, 640]; coly = [36, 36]; colw = 608
for title, c, names in GROUPS:
    k = 0 if coly[0] <= coly[1] else 1
    per = 7
    rows = (len(names) + per - 1) // per
    h = 30 + rows * 66 + 12
    body = f'<div style="padding: 6px 8px; display: flex; flex-wrap: wrap; gap: 2px">{"".join(cell(n) for n in names)}</div>'
    st += node(colx[k], coly[k], colw, h, nhead('', title, str(len(names)), c, None, 30) + body)
    coly[k] += h + 12
H = max(coly)
# размеры и состояния
demo = ''.join(f'<span style="display: inline-flex; align-items: center; gap: 6px; color: {INK}">{svg_("calendar", s)}<span style="font: 400 10px {MONO}; color: {MUT}">{s}</span></span>' for s in (14, 16, 20, 24))
st += node(0, H, 1248, 0, nhead('', 'РАЗМЕРЫ И ЦВЕТ', '', GREY, None, 30) + f'<div style="padding: 14px 16px; display: flex; gap: 28px; align-items: center; flex-wrap: wrap">{demo}'
           f'<span style="color: {MUT}">{svg_("bell", 20)}</span><span style="color: {OR}">{svg_("bell", 20)}</span><span style="color: {RED}">{svg_("offline", 20)}</span><span style="color: {GREEN}">{svg_("done", 20)}</span>'
           f'<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0; max-width: 520px">14 — в чипах и строках, 16 — кнопки шапки и меню, 20 — пустые экраны и плашки, 24 — исходник. Обычные — серые (#9A9CA6), при наведении и выбранные — светлые, акцент — только у главного действия.</span></div>')
save2('G_Icons.dc.html', page('Иконки', 'СЕГОДНЯ', st, stage_h=H + 120), 'Иконки «Системы G»')
print('ok icons', len(I))
