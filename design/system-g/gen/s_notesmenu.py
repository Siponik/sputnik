# Знания: меню по правому клику (заметка, папка, ссылка, точка графа, вкладка). Запуск после s_menu.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    from s_notes import side, modeswitch, tabs, R
    from s_menu import mi, SEP, menu
from kit import *

NOTE = [mi('open', 'Открыть'), mi('plus', 'Открыть в новой вкладке', 'Ctrl ↵'), mi('focus', 'Открыть в фокусе', 'Ctrl E'), mi('graph', 'Показать на графе', 'Ctrl G'),
        SEP, mi('edit', 'Переименовать', 'F2'), mi('move', 'Переместить в папку…', 'Ctrl M'), mi('copy', 'Дублировать'), mi('link', 'Копировать ссылку [[…]]'),
        SEP, mi('pin', 'Закрепить в «Недавних»'), mi('check', 'Задача из заметки'), mi('folder', 'Показать в папке Windows'),
        SEP, mi('trash', 'Удалить заметку…', 'Del', danger=True)]
FOLDER = [mi('plus', 'Новая заметка', 'N'), mi('folder', 'Новая папка'), mi('templates', 'Заметка из шаблона…', sub=True),
          SEP, mi('edit', 'Переименовать', 'F2'), mi('accent', 'Цвет папки'), mi('sort', 'Сортировка', sub=True), mi('graph', 'Папка на графе'),
          SEP, mi('folder', 'Показать в папке Windows'), mi('trash', 'Удалить папку…', danger=True)]
LINK = [mi('open', 'Перейти', 'клик'), mi('plus', 'В новой вкладке', 'Ctrl клик'), mi('read', 'Подсмотреть', 'наведение'),
        SEP, mi('edit', 'Изменить ссылку'), mi('link', 'Убрать ссылку, оставить текст'), mi('graph', 'На графе')]
GNODE = [mi('read', 'Читать справа', 'клик'), mi('open', 'Открыть в заметках', '↵'), mi('focus', 'Только соседи', 'L'),
        SEP, mi('pin', 'Закрепить точку'), mi('eyeoff', 'Скрыть с графа'), mi('link', 'Связать с…'), SEP, mi('trash', 'Удалить заметку…', danger=True)]
TAB = [mi('close', 'Закрыть', 'Ctrl W'), mi('close', 'Закрыть остальные'), mi('pin', 'Закрепить вкладку'), mi('copy', 'Разделить вправо')]

st = node(0, 0, 264, 700, modeswitch('Заметки') + side)
st += f'<div style="position: absolute; left: 280px; top: 0; width: 680px; height: 700px; border-radius: 12px; background: {NODE}; border: 1px solid {LINE}; opacity: .35"></div>'
st += menu(170, 230, 270, 'ЗАМЕТКА · ЗАПЕКАНИЕ НОРМАЛЕЙ', NOTE)
st += menu(480, 40, 250, 'ПАПКА · ТЕХНИКИ', FOLDER)
st += menu(480, 410, 250, 'ССЫЛКА [[UV БЕЗ РАСТЯЖЕНИЙ]]', LINK)
st += menu(744, 40, 230, 'ТОЧКА НА ГРАФЕ', GNODE)
st += menu(744, 370, 230, 'ВКЛАДКА', TAB)
notes = [('Где', 'Строка заметки и папки слева, вкладка, [[ссылка]] в тексте, точка на графе, нода на холсте. Shift+F10 — то же с клавиатуры.'),
         ('Порядок', 'Сверху открыть, ниже правка, внизу удаление красным с подтверждением. Файлы удаляются в корзину Windows.'),
         ('Клавиши', 'Справа подписаны сочетания — их же можно жать без меню.')]
rw = ''.join(f'<div style="padding: 7px 0; border-bottom: 1px solid {SOFT}"><div style="font-weight: 600">{a}</div><div style="margin-top: 2px; color: #C9CAD0; line-height: 18px; font-size: 12.5px">{b}</div></div>' for a, b in notes)
st += node(990, 0, 258, 0, nhead('', 'ЗНАНИЯ · ПРАВЫЙ КЛИК', '', OR, None, 30) + f'<div style="padding: 4px 14px 8px">{rw}</div>')
save2('G_NotesMenu.dc.html', page('Знания · правый клик', 'ЗНАНИЯ', st, R), 'Знания · меню по правому клику')
print('ok notesmenu')
