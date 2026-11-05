# Знания: синхронизация через Google Drive. Запуск после s_notes2.py: python3 s_notes3.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from s_notes import *

def srow_(dotc, t, s, right=''):
    return f'<div style="display: flex; align-items: center; gap: 10px; min-height: 36px; padding: 4px 0; border-bottom: 1px solid {SOFT}">{dot(dotc, 8)}<span style="flex: 1"><span style="display: block">{t}</span><span style="font-size: 12px; color: {MUT}">{s}</span></span>{right}</div>'

common = srow_(GREEN, 'Google', 'задачи и календари · 22:39') + srow_(GREEN, 'Бот', 'на связи')
variants = [
    ('ВСЁ ОТПРАВЛЕНО', GREEN, srow_(GREEN, 'Знания: всё отправлено', '152 заметки на Drive · 22:38')),
    ('ОТПРАВЛЯЮ', GOLD, srow_(GOLD, 'Знания: отправляю 3', 'Запекание нормалей и ещё 2', micro('1 / 3', GOLD))),
    ('НЕТ СВЯЗИ', RED, srow_(RED, 'Знания: нет связи', '5 изменений ждут · отправлю сам', btn('Повторить', sm=True))),
]
st = ab(0, 0, f'<div style="display: flex; align-items: center; gap: 12px">{lbl("ЗНАНИЯ · СИНХРОНИЗАЦИЯ С GOOGLE DRIVE", INK)}{micro("ПАПКА «СПУТНИК / ЗНАНИЯ» НА DRIVE · БЕЗ ПРОГРАММЫ «GOOGLE ДИСК»", MUT)}</div>', w=1248)
for i, (k, c, row) in enumerate(variants):
    dots = ''.join(f'<span style="width: 6px; height: 6px; border-radius: 50%; background: {cc}"></span>' for cc in (GREEN, GREEN, c))
    body = f'<div style="padding: 6px 14px 10px">{common}{row}</div>'
    st += ab(i * 140 + 300, 32, f'<span style="display: inline-flex; gap: 4px; padding: 8px 10px; border-radius: 8px; border: 1px solid {LINE}; background: {BG}">{dots}</span>') if False else ''
    st += pop(0, 40 + i * 200, 380, 184, 'СОСТОЯНИЕ · ' + k, body, {GREEN: GREEN, GOLD: GOLD, RED: RED}[c], dots and '')
# конфликт
copy = lambda title, when, who, lines, on: (f'<div style="flex: 1; min-width: 0; border-radius: 10px; border: {"1.5px solid " + OR if on else "1px solid " + LINE}; background: {BG}; overflow: hidden">'
    f'<div style="padding: 10px 12px; border-bottom: 1px solid {LINE}; display: flex; align-items: center; gap: 8px"><span style="flex: 1"><span style="display: block; font-weight: 600">{title}</span><span style="font-size: 12px; color: {MUT}">{when} · {who}</span></span></div>'
    f'<div style="padding: 10px 12px; font-size: 12.5px; line-height: 20px; color: #C9CAD0">{lines}</div>'
    f'<div style="padding: 0 12px 12px">{btn("Оставить эту", "acc" if on else "sec", True)}</div></div>')
add = lambda t: f'<div style="background: rgba(127,209,140,.12); border-left: 2px solid {GREEN}; margin: 0 -12px; padding: 0 10px">{t}</div>'
rem = lambda t: f'<div style="background: rgba(240,120,95,.10); border-left: 2px solid {RED}; margin: 0 -12px; padding: 0 10px; text-decoration: line-through; color: {MUT}">{t}</div>'
a = ('## Порядок<br>1. Низкий полигонаж готов…<br>' + add('2. Кейдж на 2% больше модели.') + '3. Пеку в Substance.')
b = ('## Порядок<br>1. Низкий полигонаж готов…<br>' + rem('2. Кейдж чуть больше модели.') + add('2. Кейдж — авто, «Average normals».') + '3. Пеку в Substance.')
cf = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 14px">
 <div><div style="font: 500 16px {SANS}">«Запекание нормалей» поменяли на двух компьютерах</div><div style="margin-top: 4px; font-size: 12.5px; color: {MUT}">Я ничего не затёр: обе копии сохранены. Выбери, какую оставить, — другая уйдёт в корзину Drive.</div></div>
 <div style="display: flex; gap: 12px">{copy("Эта копия", "сегодня 22:31", "этот компьютер", a, True)}{copy("С другого компьютера", "сегодня 22:12", "ноутбук", b, False)}</div>
 <div style="display: flex; align-items: center; gap: 10px">{btn("Оставить обе", sm=True)}<span style="font-size: 12px; color: {MUT}">вторая станет «Запекание нормалей (с другого компьютера).md»</span></div>
</div>'''
st += pop(404, 40, 844, 384, 'КОНФЛИКТ · ДВЕ КОПИИ', cf, GOLD, 'НИЧЕГО НЕ ЗАТЁРТО', hub=True)
# Drive полон
bar = lambda w, c: f'<span style="display: block; width: {w}%; height: 100%; background: {c}"></span>'
full = f'''<div style="padding: 16px 18px; display: flex; flex-direction: column; gap: 12px">
 <div style="display: flex; gap: 14px; align-items: center">{coon(52, "ОЙ")}<div><div style="font: 500 16px {SANS}">Google Drive полон</div><div style="margin-top: 4px; font-size: 12.5px; color: {MUT}">Заметки сохраняются на этом компьютере, но на Drive не уходят. 12 изменений ждут.</div></div></div>
 <div><div style="height: 10px; border-radius: 5px; overflow: hidden; display: flex; background: {SOFT}">{bar(8, OR)}{bar(91, '#6E7079')}</div>
 <div style="margin-top: 6px; display: flex; gap: 16px; font-size: 12px; color: {MUT}"><span>{dot(OR)} Знания 1,2 ГБ — из них картинки 1,1 ГБ</span><span>{dot('#6E7079')} другое 13,7 ГБ</span><span style="margin-left: auto; font: 400 11px {MONO}; color: {RED}">14,9 / 15 ГБ</span></div></div>
 <div style="display: flex; gap: 8px; flex-wrap: wrap">{btn("Открыть Drive, освободить место", "acc", True)}{btn("Не отправлять картинки", sm=True)}{btn("Позже", "ghost", True)}</div>
</div>'''
st += pop(404, 440, 600, 250, 'GOOGLE DRIVE ПОЛОН', full, RED, 'ОТПРАВКА НА ПАУЗЕ', hub=False)
nc = f'''<div style="padding: 14px 16px; display: flex; flex-direction: column; gap: 10px">
 <div style="font: 500 14px {SANS}">Второй компьютер</div>
 <div style="font-size: 12.5px; line-height: 18px; color: {MUT}">На Drive уже есть 152 заметки. Выбери пустую папку — скачаю всё туда.</div>
 {btn("Выбрать папку и скачать", "acc", True)}
</div>'''
st += pop(1024, 440, 224, 250, 'НОВЫЙ КОМПЬЮТЕР', nc, BLUE, '')
save3('G_NotesSync.dc.html', page('Знания · синхронизация', 'ЗНАНИЯ', st, R), 'Знания · синхронизация с Drive: состояние, конфликт, Drive полон', 10)
print('ok3')
