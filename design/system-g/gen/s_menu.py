# Меню по правому клику: список, сфера, пустое место колонки. Запуск после s_icons.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    from s_board import sidebar
    from s_icons import svg_
from kit import *

def mi(icon, t, k='', danger=False, sub=False, on=False):
    c = RED if danger else INK
    bg = f'background: {HOVER};' if on else ''
    right = f'<span style="margin-left: auto; font: 400 11px {MONO}; color: {DIM}">{k}</span>' if k else ''
    if sub: right = f'<span style="margin-left: auto; color: {MUT}">{svg_("next", 14)}</span>'
    return (f'<div style="height: 32px; display: flex; align-items: center; gap: 10px; padding: 0 10px; margin: 0 4px; border-radius: 6px; {bg} color: {c}; font-size: 13px">'
            f'<span style="color: {RED if danger else MUT}; display: grid">{svg_(icon, 16)}</span>{t}{right}</div>')
SEP = f'<div style="height: 1px; background: {LINE}; margin: 4px 0"></div>'
def menu(x, y, w, head, items):
    return (f'<div style="position: absolute; left: {x}px; top: {y}px; width: {w}px; padding: 4px 0; border-radius: 10px; background: {NODE}; border: 1px solid {STRONG}; box-shadow: 0 18px 40px rgba(0,0,0,.5)">'
            + (f'<div style="padding: 6px 14px 4px">{micro(head, MUT)}</div>' if head else '') + ''.join(items) + '</div>')

LIST = [mi('open', 'Открыть'), mi('edit', 'Переименовать', 'F2'), mi('board', 'Настроить доску…', 'Ctrl .'),
        SEP, mi('board', 'Вид', sub=True, on=True), mi('spheres', 'Сфера', sub=True), mi('templates', 'Колонки из шаблона…'),
        SEP, mi('pin', 'Закрепить сверху'), mi('eyeoff', 'Скрыть из «Сегодня»'), mi('bell', 'Без напоминаний'), mi('share', 'Поделиться…'),
        SEP, mi('archive', 'Архив списка', 'F'), mi('copy', 'Дублировать'), mi('trash', 'Удалить список…', 'Del', danger=True)]
VIEW = [mi('board', 'Канбан', '1', on=True), mi('stage', 'Конвейер', '2'), mi('note', 'Список', '3'), mi('pin', 'Стикеры', '4')]
SPH = [mi('edit', 'Изменить сферу…'), mi('accent', 'Цвет и значок'), mi('plus', 'Новый список в сфере', 'N'),
       SEP, mi('sort', 'Порядок списков'), mi('eyeoff', 'Свернуть'), mi('share', 'Сделать общей…'), SEP, mi('trash', 'Удалить сферу…', danger=True)]
COL = [mi('plus', 'Задача в эту колонку', 'N'), mi('sort', 'Сортировать', sub=True), mi('eyeoff', 'Свернуть колонку'), SEP, mi('edit', 'Переименовать колонку'), mi('priority', 'Лимит задач…'), mi('board', 'Настроить доску…')]

st = sidebar('Иконки для клиента')
# доска приглушена
st += f'<div style="position: absolute; left: 228px; top: 0; right: 0; height: 700px; border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; opacity: .35"></div>'
st += menu(196, 96, 260, 'ИКОНКИ ДЛЯ КЛИЕНТА', LIST)
st += menu(460, 268, 200, '', VIEW)
st += menu(700, 70, 250, 'СФЕРА · 3D И ЗАКАЗЫ', SPH)
st += menu(700, 420, 250, 'КОЛОНКА «В РАБОТЕ»', COL)
notes = [('Где', 'Правый клик или Shift+F10 по строке списка, заголовку сферы, шапке колонки. Меню открывается у курсора, не выходит за окно.'),
         ('Клавиши', '↑ ↓ — выбор, → — подменю, Enter — выполнить, Esc — закрыть. Буква справа — то же действие без меню.'),
         ('Удаление', 'Пункты удаления красные, всегда последние и открывают подтверждение (фокус на «Отмена»). Основной список Google не удаляется — пункт серый с подсказкой.'),
         ('Вид', 'Тот же стиль, что у меню задачи (⋯): плашка 10 px скругление, иконки 16, строки 32.')]
rw = ''.join(f'<div style="padding: 7px 0; border-bottom: 1px solid {SOFT}"><div style="font-weight: 600">{a}</div><div style="margin-top: 2px; color: #C9CAD0; line-height: 18px; font-size: 12.5px">{b}</div></div>' for a, b in notes)
st += node(980, 0, 268, 0, nhead('', 'МЕНЮ ПО ПРАВОМУ КЛИКУ', '', OR, None, 30) + f'<div style="padding: 4px 14px 8px">{rw}</div>')
save2('G_ListMenu.dc.html', page('Меню по правому клику', 'ДОСКА', st), 'Меню по правому клику: список, сфера, колонка')
print('ok menu')
