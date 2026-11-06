import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board
from s_board import sidebar
K = dim(s_board.KANBAN)
ME = ('С', OR); OLYA = ('О', VIO); ANYA = ('А', GREEN)

# ---------- SHARE: people ----------
ppl = ''
for (ch, c), n, mail, st_, right in [(ME, 'Siponik · ты', 'владелец', '', btn('Изменить', sm=True)), (OLYA, 'Оля', 'olya@…', 'в сфере', btn('Убрать', 'ghost', True)), (ANYA, 'Аня', 'anya@…', 'ещё не приняла', btn('Убрать', 'ghost', True))]:
    ppl += f'<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0; border-bottom: 1px solid {SOFT}">{av(ch, c, 32)}<span style="flex: 1"><span style="display: block">{n}</span><span style="font-size: 12px; color: {GOLD if "ещё" in st_ else MUT}">{mail}{" · " + st_ if st_ else ""}</span></span>{right}</div>'
mk = f'''<div style="padding: 18px 22px; display: flex; flex-direction: column; gap: 14px">
 <div style="color: #C9CAD0; line-height: 20px">Сфера «Таверна · заказ» будет общей: её списки и задачи увидят все, кого позовёшь. Хранится в отдельном Google Календаре, своего сервера нет.</div>
 {field("Позвать по почте", f'<span style="flex: 1; min-width: 0; height: 38px; box-sizing: border-box; border-radius: 8px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; gap: 6px; padding: 0 8px">{sc("anya@…", True, GREEN, True)}<span style="color: {MUT}">ещё почта…</span></span>{btn("Позвать", "acc")}')}
 <div><span style="font: 500 12.5px {SANS}; color: {MUT}">В сфере · 3</span>{ppl}</div>
 <div style="font-size: 12px; color: {MUT}">Звать и убирать может только владелец. Личное — напоминания и таймер — каждый видит только у себя.</div>
</div>'''
prof = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 14px">
 <div style="display: flex; gap: 14px; align-items: center">{av("С", OR, 56)}<span><span style="display: block; font-weight: 600">Так тебя видят другие</span><span style="font-size: 12px; color: {MUT}">Одно на все общие сферы</span></span></div>
 {field("Имя", f'<span style="width: 100%; height: 36px; box-sizing: border-box; border-radius: 8px; border: 1px solid {STRONG}; background: {BG}; display: flex; align-items: center; padding: 0 12px">Сипоник</span>')}
 {field("Цвет", "".join(f'<span style="width: 26px; height: 26px; border-radius: 50%; background: {c}; {"outline: 2px solid " + ORI + "; outline-offset: 2px" if i == 0 else ""}"></span>' for i, c in enumerate([OR, BLUE, GREEN, VIO, GOLD, RED])))}
 {field("Фото", btn("Выбрать файл…", sm=True) + f'<span style="font-size: 12px; color: {MUT}">сожму до 64 × 64</span>')}
 <div>{btn("Сохранить", "acc", True)}</div>
</div>'''
st = K + pop(150, 30, 560, 0, 'ОБЩАЯ СФЕРА · УЧАСТНИКИ', mk, VIO, 'ВМЕСТЕ · 3', hub=True)
st += pop(760, 90, 340, 0, 'КАК МЕНЯ ВИДЯТ', prof, OR)
save2('G_SharePeople.dc.html', page('Общая сфера · участники', 'ДОСКА', st), 'Общая сфера · участники и профиль')

# ---------- SHARE: board ----------
def card(t, meta, who, prio='', now=False, wait='', mine=False):
    st_ = hatch() + f'; border: 1px solid {OR}' if now else (f'background: {HOVER}; border: 1px dashed {GREEN}' if wait else f'background: {HOVER}; border: 1px solid {LINE}')
    a = av(*who, 22, ring=mine) if who else av('+', MUT, 22, dashed=True)
    p = f'<span style="font: 600 11px {MONO}; color: {OR if prio == "!!!" else MUT}">{prio}</span>' if prio else ''
    w = f'<div style="margin-top: 6px; font-size: 11.5px; color: {GREEN}">ждёт: Аня ещё не видела</div>' if wait else ''
    return f'<div style="border-radius: 8px; {st_}; padding: 10px"><div style="display: flex; gap: 8px; align-items: flex-start"><span style="flex: 1">{t}</span>{p}</div><div style="display: flex; gap: 8px; align-items: center; margin-top: 8px">{a}{micro(meta, ORI if now else MUT)}<span style="flex: 1"></span><span style="color: {DIM}">→</span></div>{w}</div>'
cols = [('ВХОДЯЩИЕ', '3', GREY, [card('Эскизы вывески', 'ПН 09', None), card('Меню на доске', 'БЕЗ СРОКА', OLYA), card('Фото интерьера', 'СР 11', None)]),
        ('В РАБОТЕ', '2 / 3', OR, [card('Логотип «Таверна»', 'СЕГОДНЯ 16:00', ME, '!!!', now=True, mine=True), card('Шрифт для меню', 'ПТ 06', ANYA, wait='y')]),
        ('ПРОВЕРКА', '1', VIO, [card('Цвета фасада', 'ЖДЁТ ОТВЕТА', OLYA)]),
        ('ГОТОВО', '3', GREEN, [card('Бриф', 'ПН 02', ME, mine=True)])]
st = sidebar('', 'В общей сфере кружок на карточке — кто делает.')
bar = f'''<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{dot(VIO, 8)}<span style="font-weight: 600; font-size: 15px">Таверна · заказ</span>{avs([ME, OLYA, ANYA])}<span style="font: 500 10px {MONO}; letter-spacing: .12em; color: {VIO}; border: 1px solid {VIO}; border-radius: 5px; padding: 2px 6px">ВМЕСТЕ</span>
<span style="flex: 1"></span>{seg(["ВСЕ 9", "МОИ 3", "НИЧЬИ 2"], "ВСЕ 9")}{btn("Участники", sm=True)}</div>'''
st += node(236, 0, 1012, 48, bar)
st += node(236, 60, 1012, 40, f'<div style="height: 100%; display: flex; align-items: center; gap: 10px; padding: 0 12px">{av(*ANYA, 22)}<span>Аня ещё не видела 2 твоих изменения. Увидит, когда откроет Спутник.</span><span style="flex: 1"></span>{btn("Понятно", "ghost", True)}</div>', wait=True)
CW_ = 232; G_ = 28; paths = ''
for i, (n, cnt, c, cs) in enumerate(cols):
    x = 236 + i * (CW_ + G_)
    ex = (sock('r', 10, c) if i < 3 else '') + (sock('l', 10, cols[i - 1][2]) if i > 0 else '')
    body = f'<div style="padding: 10px; display: flex; flex-direction: column; gap: 8px">{"".join(cs)}</div>'
    st += node(x, 114, CW_, 0, nhead(f'0{i + 1}', n, cnt, c) + body, hub=(i == 1), extra=ex)
    if i < 3: paths += wire(x + CW_ + 1, 129, x + CW_ + G_ - 1, 129, c, 1.5, k=10)
st = svg(paths) + st
who = f'<div style="padding: 6px">' + ''.join(mrow(f'{n}', kbd(k), on=(k == "1")).replace('<span>' + n + '</span>', av(ch, c, 20) + '<span>' + n + '</span>') for (ch, c), n, k in [(ME, 'Я', '1'), (OLYA, 'Оля', '2'), (ANYA, 'Аня', '3')]) + f'<div style="border-top: 1px solid {LINE}; margin-top: 4px; padding-top: 4px">{mrow("Никто", kbd("0"))}</div></div>'
st += pop(268, 300, 220, 0, 'КТО ДЕЛАЕТ · I', who, VIO)
st += f'<span style="position: absolute; left: 255px; top: 270px; width: 26px; height: 26px; border-radius: 50%; border: 1.5px solid {OR}"></span>'
st += node(236, 610, 1012, 48, f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{av(*OLYA, 26)}<span>Оля зовёт тебя в сферу «Кафе «Ёж»». Пока не примешь, её задач нигде не будет.</span><span style="flex: 1"></span>{btn("Отказаться", "ghost", True)}{btn("Принять", "acc", True)}</div>', style=SH + f'; border-color: {VIO}')
save2('G_ShareBoard.dc.html', page('Общая сфера · доска', 'ДОСКА', st), 'Общая сфера · доска, исполнитель, приглашение')

# ---------- SHARE: states ----------
st = sidebar('', 'Сфера «Студия» стала бледной: у тебя пропал доступ.')
na = f'''<div style="padding: 22px; display: flex; flex-direction: column; gap: 14px; align-items: flex-start">
 <div style="display: flex; gap: 14px; align-items: center">{coon(56, "ОЙ")}<span><span style="display: block; font: 500 18px {SANS}">Нет доступа к сфере «Студия»</span><span style="font-size: 12.5px; color: {MUT}">Владелец убрал тебя или удалил календарь сферы</span></span></div>
 <div style="color: #C9CAD0; line-height: 20px">Задачи этой сферы больше не приходят в «Сегодня» и напоминания. Можно попросить доступ снова: я скопирую письмо владельцу.</div>
 <div style="display: flex; gap: 8px">{btn("Попросить доступ", "acc")}{btn("Убрать из колонки")}</div>
</div>'''
st += node(236, 0, 500, 260, nhead('', 'СФЕРА · СТУДИЯ', 'НЕТ ДОСТУПА', RED) + na, wait=True)
# conveyor with people
STN = ['МОДЕЛЬ', 'UV', 'ПОКРАСКА', 'РЕНДЕР', 'СДАЧА']
whos = [ANYA, ANYA, ME, OLYA, ME]
trk = ''
for i, (n, w) in enumerate(zip(STN, whos)):
    x = 150 + i * 76
    stl = f'background: {GREEN}' if i < 2 else (f'background: {OR}' if i == 2 else f'border: 1.5px solid {STRONG}; background: {NODE}')
    if i == 3: stl = f'border: 2px solid {VIO}; background: {NODE}'
    trk += f'<span style="position: absolute; left: {x - 4}px; top: 22px">{av(*w, 16)}</span><span style="position: absolute; left: {x}px; top: 46px; width: 12px; height: 12px; border-radius: 3px; box-sizing: border-box; {stl}"></span><span style="position: absolute; left: {x - 14}px; top: 64px; width: 40px; text-align: center">{micro(n, OR if i == 2 else DIM)}</span>'
    if i < 4: trk += f'<span style="position: absolute; left: {x + 12}px; top: 51px; width: 64px; height: 2px; background: {GREEN if i < 2 else "#45464D"}"></span>'
cv = f'''<div style="position: relative; height: 96px">{av(*ME, 30, ring=True).replace("<span", "<span", 1)}<span style="position: absolute; left: 14px; top: 20px">{av(*ME, 30, ring=True)}</span><span style="position: absolute; left: 56px; top: 18px; font-weight: 600">Вывеска</span><span style="position: absolute; left: 56px; top: 40px">{micro("ВЕДЁШЬ ТЫ", OR)}</span>{trk}</div>
<div style="padding: 0 14px 14px; display: flex; flex-direction: column; gap: 6px"><span style="font-size: 12.5px; color: {ORI}">Передано тебе · от Ани, вчера в 18:20</span><span style="font-size: 12.5px; color: {MUT}">Дальше: рендер делает Оля. Нажмёшь «Этап →» — задача уйдёт к ней.</span><div style="display: flex; gap: 8px; margin-top: 4px">{btn("Этап → Оле", "acc", True)}{btn("Кто на этапах ▾", sm=True)}</div></div>'''
cv = cv.replace(av(*ME, 30, ring=True), '', 1)
st += node(752, 0, 496, 0, nhead('', 'КОНВЕЙЕР · КТО НА ЭТАПАХ', 'SHIFT I', OR, None, 34, INK, OR) + cv, hub=True)
# stickers by people
lanes = [(ME, 'Я', ['Купить краску', 'Позвонить мастеру']), (OLYA, 'Оля', ['Забрать заказ']), (None, 'Ничьи', ['Вынести мусор', 'Полить цветы'])]
lx = 236
for who_, n, items in lanes:
    hd = (av(*who_, 20) if who_ else av('+', MUT, 20, dashed=True)) + f'<span style="font-weight: 600">{n}</span>{micro(str(len(items)))}'
    cards = ''.join(f'<div style="border-radius: 8px; background: {NODE}; border: 1px solid {OR if who_ == ME else LINE}; padding: 10px 12px; display: flex; gap: 10px; align-items: center"><span style="width: 16px; height: 16px; border-radius: 50%; border: 1.5px solid {GREEN}; box-sizing: border-box"></span><span style="flex: 1">{t}</span>{"" if who_ else micro("ВЗЯТЬ СЕБЕ", OR)}</div>' for t in items)
    st += ab(lx, 290, f'<div style="display: flex; align-items: center; gap: 8px; margin-bottom: 10px">{hd}<span style="flex: 1; height: 1px; background: {LINE}"></span></div><div style="display: flex; flex-direction: column; gap: 8px">{cards}</div>', w=320)
    lx += 340
st += colhead(236, 272, 1012, 'СТИКЕРЫ · РАСКЛАДКА «ПО ЛЮДЯМ» · ПЕРЕТАЩИ В КОЛОНКУ, ЧТОБЫ ОТДАТЬ')
st += toast(236, 520, 480, 'Оля сделала «Забрать заказ»', 'Вернуть', VIO)
st += toast(236, 574, 480, 'Тебе отдали задачу «Логотип «Таверна»»', 'Открыть', BLUE)
save2('G_ShareStates.dc.html', page('Общая сфера · состояния', 'ДОСКА', st), 'Общая сфера · нет доступа, конвейер, стикеры по людям')
print('ok')
