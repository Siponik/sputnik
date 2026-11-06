# Знания: как переключаться между заметками, чтением и графом + режим чтения. Запуск после s_notes0.py: python3 s_notes4.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from s_notes import *

# ---------- ЧТЕНИЕ ----------
rtool = (f'<div style="height: 44px; box-sizing: border-box; padding: 0 14px 0 20px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 10px">'
         f'<span style="font-size: 12.5px; color: {MUT}">3D › Техники</span><span style="flex: 1"></span>{seg(["ПРАВКА", "ЧТЕНИЕ"], "ЧТЕНИЕ")}'
         f'<span style="font-size: 12px; color: {DIM}">Ctrl E</span>{btn("◉ На графе", "ghost", True)}<span style="color: {MUT}; font-size: 15px; padding: 0 4px">⋯</span></div>')
rbody = f'''<div style="width: 600px; margin: 0 auto; padding-top: 34px">
  <div style="font-size: 12.5px; color: {MUT}">Техника · #baking · #substance · изменено сегодня 22:14</div>
  <div style="margin-top: 6px; font: 600 30px {SANS}; letter-spacing: -.01em">Запекание нормалей</div>
  <div style="margin-top: 18px; font-size: 15.5px; line-height: 27px; color: #D9DAE0">
    <div style="font: 600 18px {SANS}; color: {INK}; margin-bottom: 6px">Порядок</div>
    <p style="margin: 0 0 10px">Сначала низкий полигонаж готов целиком и UV разложены без растяжений — как в {wl("UV без растяжений")}. Без этого запекание всё равно придётся переделывать.</p>
    <p style="margin: 0 0 10px">Кейдж делаю чуть больше модели, сглаживание одной группой. Пеку в Substance, сразу после — {wl("Умные маски Substance")}.</p>
    <div style="font: 600 18px {SANS}; color: {INK}; margin: 16px 0 6px">Частые ошибки</div>
    <p style="margin: 0">Волны на фасках — добавить петли или взять {wl("Хард-сёрфейс: фаски")}. Тёмные пятна в углах — увеличить кейдж.</p>
  </div>
</div>'''
# поля справа: мини-граф и куда дальше
mg = ''
cx, cy = 128, 96
nb = [(-84, -38, OR, 'UV'), (-92, 34, OR, 'Пайплайн'), (-10, 70, GREEN, 'Курс'), (84, 44, OR, 'Маски'), (86, -36, OR, 'Фаски'), (6, -70, OR, 'Щит')]
for dx, dy, c, t in nb:
    mg += f'<line x1="{cx}" y1="{cy}" x2="{cx + dx}" y2="{cy + dy}" stroke="{c}" stroke-opacity=".55"/>'
for dx, dy, c, t in nb:
    mg += f'<circle cx="{cx + dx}" cy="{cy + dy}" r="6" fill="{c}"/><text x="{cx + dx}" y="{cy + dy + 18}" text-anchor="middle" font-family="Onest, sans-serif" font-size="10.5" fill="{MUT}">{t}</text>'
mg += f'<circle cx="{cx}" cy="{cy}" r="10" fill="{OR}" stroke="{ORI}" stroke-width="2"/>'
nxt = ''.join(f'<div style="display: flex; align-items: center; gap: 8px; padding: 7px 0; border-bottom: 1px solid {SOFT}">{dot(c)}<span style="flex: 1">{t}</span><span style="font-size: 12px; color: {DIM}">{k}</span></div>'
              for t, c, k in [('Умные маски Substance', OR, 'дальше'), ('UV без растяжений', OR, 'до'), ('Пайплайн ассета', OR, 'ссылается'), ('Курс: текстуры', GREEN, 'ссылается')])
margin = (nhead('', 'ГДЕ ЭТА ЗАМЕТКА', 'ГЛУБИНА 1', OR, None, 34) + f'<svg width="256" height="200" aria-hidden="true">{mg}</svg>'
          + f'<div style="padding: 0 14px">{micro("ЧИТАТЬ ДАЛЬШЕ", MUT)}<div style="margin-top: 4px; font-size: 13px">{nxt}</div></div>'
          + f'<div style="position: absolute; left: 14px; right: 14px; bottom: 12px; font-size: 12px; line-height: 17px; color: {MUT}">Клик по точке или строке — открыть эту заметку тут же, в чтении. Alt ← — назад.</div>')
st = node(0, 0, 264, 700, modeswitch('Заметки') + side)
st += node(280, 0, 688, 700, tabs('Запекание нормалей') + rtool + rbody, hub=True)
st += node(984, 0, 264, 700, margin)
save3('G_NotesRead.dc.html', page('Знания · чтение', 'ЗНАНИЯ', st, R), 'Знания · чтение: текст крупно, рядом — где заметка в графе', 0.7)

# ---------- КАК ПЕРЕКЛЮЧАТЬСЯ ----------
def state(x, y, w, h, title, color, what, keys, hub=False):
    ks = ''.join(f'<div style="display: flex; gap: 8px; align-items: center; min-height: 26px">{kbd(k)}<span style="font-size: 12.5px; color: #C9CAD0">{t}</span></div>' for k, t in keys)
    return node(x, y, w, h, nhead('', title, '', color, None, 32, INK, OR if hub else LINE) + f'<div style="padding: 10px 14px"><div style="font-size: 13px; line-height: 19px; color: #DADBE0">{what}</div><div style="margin-top: 10px">{ks}</div></div>', hub=hub)


st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ЗНАНИЯ · КАК ПЕРЕКЛЮЧАТЬСЯ", INK)}{micro("ЗАМЕТКИ, ЧТЕНИЕ И ГРАФ — ОДНА ЗАМЕТКА В ФОКУСЕ, МЕНЯЕТСЯ ТОЛЬКО ВИД", MUT)}</div>', w=1248)
# переключатель — крупно
st += node(0, 34, 1248, 0, f'''<div style="padding: 14px 18px; display: flex; gap: 24px; align-items: center">
  <div style="width: 330px; flex: none">{modeswitch("Граф").replace("border-bottom: 1px solid " + LINE, "border-bottom: 0")}</div>
  <div style="font-size: 13px; line-height: 20px; color: #DADBE0">Главный переключатель раздела — всегда слева сверху, на всех экранах «Знаний». Граф — не спрятанная кнопка, а такой же вид, как заметки. Выбранная заметка не теряется: переключился на граф — она в центре и подсвечена, вернулся — открыта там же.</div></div>''')
Y = 170
st += state(0, Y, 280, 200, 'ЗАМЕТКИ · ПРАВКА', OR, 'Пишешь. Слева папки, справа заметка с вкладками.', [('Ctrl E', 'читать'), ('Ctrl G', 'эта заметка на графе'), ('Ctrl O', 'найти и открыть')], hub=True)
st += state(323, Y, 280, 200, 'ЗАМЕТКИ · ЧТЕНИЕ', OR, 'Текст крупно, без панелей правки. Справа — где заметка в графе и что читать дальше.', [('Ctrl E', 'править'), ('клик по [[ссылке]]', 'перейти'), ('Alt ←', 'назад')])
st += state(646, Y, 280, 200, 'ГРАФ', VIO, 'Вся база точками. Выбранная заметка в центре, соседи подсвечены. Колёсико — ближе: подписи, потом ноды.', [('клик по точке', 'читать справа'), ('L', 'только соседи'), ('/', 'найти на графе')])
st += state(968, Y, 280, 200, 'ГРАФ + ЧТЕНИЕ', VIO, 'Граф остаётся, справа панель с текстом точки. Можно гулять по ссылкам, не уходя с графа.', [('Enter', 'открыть в заметках'), ('Esc', 'закрыть панель'), ('клик по ссылке', 'граф переезжает')])
w = ''
mid = Y + 40
for x1, x2, c in [(280, 323, OR), (603, 646, VIO), (926, 968, VIO)]:
    w += wire(x1 + 1, mid, x2 - 1, mid, c, 2, k=16)
    w += wire(x2 - 1, mid + 24, x1 + 1, mid + 24, c, 1.5, dash=True, k=16)
st += svg(w)
for x, t1, t2 in [(282, 'Ctrl E', 'Ctrl E'), (605, 'Ctrl G', 'Ctrl 1'), (928, 'клик', 'Esc')]:
    st += ab(x, mid - 26, micro(t1, MUT), w=44) + ab(x, mid + 30, micro(t2, DIM), w=44)
# откуда ещё попадаешь на граф
ins = [('Кнопка «◉ На графе»', 'в шапке заметки и в чтении — граф с этой заметкой в центре'), ('Маленький граф в «Связях»', 'клик по нему — большой граф на том же месте'),
       ('«Весь граф G» в поиске Ctrl K', 'набрал название — Shift+Enter показывает её на графе'), ('Из задачи', 'блок «Заметки» в окне задачи → «на графе»')]
rows_ = ''.join(f'<div style="display: flex; gap: 14px; padding: 8px 0; border-bottom: 1px solid {SOFT}"><span style="width: 260px; flex: none; font-weight: 600">{a}</span><span style="color: #C9CAD0">{b}</span></div>' for a, b in ins)
st += node(0, 410, 820, 0, nhead('', 'ЕЩЁ ВХОДЫ В ГРАФ', '', GREY, None, 30) + f'<div style="padding: 4px 16px 8px">{rows_}</div>')
st += ab(844, 410, f'<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: 8px; border: 1px dashed #8A7424; box-sizing: border-box">{coon(44, "ДУМАЕТ")}<span style="font-size: 12.5px; line-height: 18px; color: #C9CAD0">Правило одно: заметка в фокусе одна. Любой вид показывает её — текстом, точкой на графе или нодой на холсте.</span></div>', w=404)
save3('G_NotesNav.dc.html', page('Знания · переключение', 'ЗНАНИЯ', st, R), 'Знания · как переключаться: заметки, чтение, граф', -0.5)
print('ok4')
