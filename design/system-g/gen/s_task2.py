import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
import s_board

# Окно задачи, заново: большое окно по центру, как «Создать» B
K = dim(s_board.KANBAN)
C = BLUE  # цвет сферы
PI = {'Список': 'board', 'Колонка': 'stage', 'Приоритет': 'priority', 'Напомнить': 'bell', 'Повтор': 'repeat', 'Цвет': 'accent', 'Исполнитель': 'share'}
H = lambda t, r='': f'<div style="height: 30px; display: flex; align-items: center; padding: 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">{t}<span style="margin-left: auto; font: 400 11px {MONO}; letter-spacing: 0">{r}</span></div>'
box = lambda inner='', extra='': f'<div style="border-radius: 10px; border: 1px solid {LINE}; background: {BG}; overflow: hidden; {extra}">{inner}</div>'

def pr(k, v='', c=None):
    val = (f'<span style="flex: 1; min-width: 0; font-weight: 600; color: {c or INK}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{v}</span><span style="color: {MUT}">▾</span>' if v else f'<span style="flex: 1; color: #55575F">—</span>')
    return f'<div style="height: 32px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-top: 1px solid {SOFT}; font-size: 12.5px"><span style="display: grid; color: {MUT}">{svg_(PI[k], 15)}</span><span style="width: 92px; flex: none; color: {MUT}">{k}</span>{val}</div>'

def sub(t, d=False):
    ck = f'<span style="width: 14px; height: 14px; box-sizing: border-box; border-radius: 3px; {"background: " + GREEN + "; color: #1C1D21" if d else "border: 1px solid #8A8C96"}; display: grid; place-items: center">{svg_("check", 9) if d else ""}</span>'
    return f'<div style="height: 32px; display: flex; align-items: center; gap: 10px; padding: 0 10px; border-top: 1px solid {SOFT}; font-size: 13px; color: {MUT if d else INK}"><span style="color: {DIM}; display: grid">{svg_("drag", 12)}</span>{ck}<span style="{"text-decoration: line-through" if d else ""}">{t}</span></div>'

def stage(n, s, days):  # 0 пройден, 1 сейчас, 2 впереди
    st = {0: f'background: #232A25; border: 1px solid #2F4A35; color: {GREEN}', 1: f'background: {OR}; color: #1C1D21; font-weight: 600', 2: f'border: 1px solid #4A4B52; color: #62646E'}[s]
    sub_ = {0: GREEN, 1: '#1C1D21', 2: '#55575F'}[s]
    return f'<div style="flex: 1; height: 42px; box-sizing: border-box; border-radius: 8px; display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 2px; font-size: 13px; {st}"><span>{"✓ " if s == 0 else ""}{n}</span><span style="font: 400 9.5px {MONO}; letter-spacing: 1px; color: {sub_}; opacity: .85">{days}</span></div>'

fld = lambda ic, t, w='': f'<span style="height: 34px; {w}box-sizing: border-box; border-radius: 8px; border: 1px solid {ORL}; display: flex; align-items: center; gap: 8px; padding: 0 10px; font-size: 13px; background: {BG}"><span style="display: grid; color: {MUT}">{svg_(ic, 14)}</span><span style="flex: 1">{t}</span><span style="color: {MUT}; font-size: 10px">▾</span></span>'
chip = lambda t, on=False: f'<span style="height: 26px; padding: 0 10px; border-radius: 7px; display: inline-flex; align-items: center; gap: 6px; font-size: 12px; {"background: " + WASH + "; border: 1px solid " + OR + "; color: " + INK if on else "border: 1px solid " + LINE + "; color: #C9CAD0"}">{t}</span>'

X0, Y0, WW, HH = 100, 6, 1048, 688
head = (f'<div style="height: 40px; background: {FILL[C]}; display: flex; align-items: center; gap: 10px; padding: 0 8px 0 14px; font: 500 10.5px {MONO}; letter-spacing: .14em; color: #fff">'
        f'{dot("#fff", 6)}РАБОТА · КЛИЕНТЫ<span style="opacity: .6">›</span>В РАБОТЕ<span style="flex: 1"></span>'
        + ''.join(f'<span style="width: 28px; height: 28px; border-radius: 6px; display: grid; place-items: center; color: #fff; font-size: 14px">{g}</span>' for g in ['⋯', '⤢', '✕']) + '</div>')
title = (f'<div style="display: flex; align-items: center; gap: 14px; padding: 18px 22px 4px">'
                  f'<span style="font-size: 24px; font-weight: 600; letter-spacing: -.01em">Созвон с клиентом «Таверна»</span>'
         f'<span style="font: 600 13px {MONO}; color: {OR}; padding: 2px 8px; border-radius: 6px; background: {WASH}">!!</span></div>'
         f'<div style="padding: 0 22px; font-size: 12.5px; color: {MUT}">создана 02.11 · в работе 3 дн · всего 4 дн</div>')
stages = f'<div style="display: flex; gap: 6px; padding: 14px 22px 0">{stage("Входящие", 0, "1 ДН") + stage("В работе", 1, "3 ДН · ИДЁТ") + stage("Проверка", 2, "—") + stage("Готово", 2, "—")}</div>'

subs = box(H("ПОДЗАДАЧИ", "1 / 3") + f'<div style="height: 3px; margin: 0 10px 8px; border-radius: 2px; background: #45464D; position: relative"><span style="position: absolute; left: 0; top: 0; width: 33%; height: 3px; border-radius: 2px; background: {VIO}"></span></div>'
           + sub("Подготовить три варианта щита", True) + sub("Уточнить бюджет") + sub("Договориться о сроке сдачи")
           + f'<div style="height: 32px; display: flex; align-items: center; padding: 0 10px; border-top: 1px solid {SOFT}; font-size: 12.5px; color: {MUT}">＋ подзадача · Enter</div>')
note = box(f'<div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 6px 0 10px; font: 500 10px {MONO}; letter-spacing: .14em; color: {MUT}">ЗАМЕТКА<span style="font: 400 10px {MONO}; color: {DIM}; letter-spacing: 0">MARKDOWN</span><span style="margin-left: auto; height: 22px; padding: 0 8px; border-radius: 6px; border: 1px solid {LINE}; display: inline-flex; align-items: center; font: 400 11.5px {SANS}; letter-spacing: 0; color: #C9CAD0">↗ из Знаний</span><span style="width: 22px; height: 22px; border-radius: 6px; border: 1px solid {LINE}; display: inline-grid; place-items: center; font-size: 12px; color: #C9CAD0">⤢</span></div>'
           f'<div style="padding: 4px 12px 12px; font-size: 13.5px; line-height: 1.6"><b>Повестка</b><br>— показать концепты щита и меча<br>— спросить, нужен ли вариант без герба<br><span style="color: {MUT}">Бюджет из прошлого заказа:</span> <span style="color: {OR}">[[Таверна · смета]]</span></div>', 'flex: 1; display: flex; flex-direction: column')
left = f'<div style="position: absolute; left: 22px; top: 176px; width: 620px; bottom: 76px; display: flex; flex-direction: column; gap: 10px">{subs}{note}</div>'

when = box(extra='flex: none', inner=H("КОГДА") + f'<div style="padding: 0 10px 10px; display: flex; flex-direction: column; gap: 8px"><div style="display: flex; gap: 6px">{fld("clock", "12:30–13:30", "width: 140px; ")}{fld("calendar", "Сегодня, чт 5", "flex: 1; ")}</div>'
           f'<div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center"><span style="display: grid; color: {MUT}">{svg_("bell", 14)}</span>{chip("за 15 мин ×", True)}{chip("за час ×", True)}{chip("＋")}</div></div>')
props = box(extra='flex: none', inner=H("СВОЙСТВА") + pr("Список", "● Работа · клиенты", BLUE) + pr("Приоритет", "!! Обычный") + pr("Повтор") + pr("Исполнитель", "Я"))
hist = box(extra='flex: 1; min-height: 0', inner=H("ИСТОРИЯ") + ''.join(f'<div style="height: 26px; display: flex; align-items: center; gap: 8px; padding: 0 10px; font-size: 12px; color: #C9CAD0">{dot(c, 6)}<span style="flex: 1">{t}</span><span style="font: 400 10px {MONO}; color: {DIM}">{d}</span></div>' for c, t, d in [(OR, "Перенесена в «В работе»", "02.11"), (GREEN, "Подзадача выполнена", "04.11")]) + '<div style="height: 6px"></div>')
right = f'<div style="position: absolute; left: 660px; right: 22px; top: 176px; bottom: 76px; display: flex; flex-direction: column; gap: 10px">{when}{props}{hist}</div>'

foot = (f'<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 60px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 22px">'
        f'{dot(GREEN, 6)}<span style="font: 400 10.5px {MONO}; letter-spacing: 1.2px; color: {MUT}">СОХРАНЕНО В GOOGLE TASKS · 14:40</span><span style="flex: 1"></span>'
        f'<span style="height: 36px; padding: 0 12px; border-radius: 8px; display: inline-flex; align-items: center; gap: 6px; color: {MUT}; font-size: 13px">{svg_("trash", 14)}Удалить</span>'
        f'<span style="height: 36px; padding: 0 14px; border-radius: 8px; background: {OR}; color: #1C1D21; font-weight: 600; display: inline-flex; align-items: center; font-size: 13px">Проверка →</span>'
        f'</div>')
win = f'<div style="position: absolute; left: {X0}px; top: {Y0}px; width: {WW}px; height: {HH}px; border-radius: 12px; background: {NODE}; border: 1px solid {ORL}; overflow: hidden; box-shadow: 0 24px 60px rgba(0,0,0,.55)">{head}{title}{stages}{left}{right}{foot}</div>'
st = K + win
save('G_TaskFull.dc.html', page('Окно задачи', 'ДОСКА', st), 'Окно задачи · заново', 2720, 2240, 'task')
