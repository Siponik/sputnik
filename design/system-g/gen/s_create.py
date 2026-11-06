import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import s_board
DIMK = f'<div style="position: absolute; inset: 0; opacity: .25; pointer-events: none">{s_board.KANBAN}</div>'

def sc(t, on=False, c=OR, x=False):
    s = f'background: {WASH}; border: 1px solid {c}; color: {INK}' if on else f'background: transparent; border: 1px solid {LINE}; color: #C9CAD0'
    cl = f'<span style="color: {MUT}; margin-left: 2px">×</span>' if x else ''
    return f'<button type="button" style="height: 30px; padding: 0 12px; border-radius: 8px; {s}; font: 400 13px {SANS}; display: inline-flex; align-items: center; gap: 6px">{t}{cl}</button>'

def field(label, inner):
    return f'<div style="display: flex; flex-direction: column; gap: 8px"><span style="font: 500 12.5px {SANS}; color: {MUT}">{label}</span><div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center">{inner}</div></div>'

kinds = ''
for i, t in enumerate(['Задача', 'Событие', 'Привычка', 'День рождения']):
    if i == 0:
        kinds += f'<span style="height: 30px; padding: 0 14px; border-radius: 8px; background: rgba(255,255,255,.92); color: #5A3412; display: flex; align-items: center; font: 600 13px {SANS}">{t}</span>'
    else:
        kinds += f'<span style="height: 30px; padding: 0 14px; border-radius: 8px; color: rgba(255,255,255,.85); display: flex; align-items: center; font: 500 13px {SANS}">{t}</span>'
hd = f'<div style="height: 50px; box-sizing: border-box; padding: 0 10px 0 12px; border-radius: 11px 11px 0 0; background: {HUBFILL}; display: flex; align-items: center; gap: 4px">{kinds}<span style="flex: 1"></span><button type="button" aria-label="Закрыть" style="width: 30px; height: 30px; border-radius: 8px; border: 0; background: transparent; color: #FFFFFF; font-size: 16px">✕</button></div>'

mark = lambda t, bg, c: f'<span style="padding: 2px 8px; border-radius: 6px; background: {bg}; color: {c}">{t}</span>'
line = f'Рендер щита {mark("завтра в 17:00", "rgba(240,160,75,.16)", ORI)} {mark("важно", "rgba(240,120,95,.16)", "#F59A86")}<span style="display: inline-block; width: 1.5px; height: 20px; background: {OR}; vertical-align: -4px; margin-left: 3px"></span>'

body = f'''<div style="padding: 22px 24px 0; display: flex; flex-direction: column; gap: 10px">
  <label for="cr-what" style="font: 500 15px {SANS}">Что нужно сделать?</label>
  <div id="cr-what" style="height: 54px; box-sizing: border-box; border-radius: 10px; border: 1.5px solid {OR}; background: {BG}; display: flex; align-items: center; padding: 0 16px; font-size: 17px">{line}</div>
  <div style="font-size: 12.5px; color: {MUT}">Пиши как в заметке: «в пятницу», «каждую неделю», «@работа». Остальное подставлю сам.</div>
</div>
<div style="padding: 20px 24px 0; display: grid; grid-template-columns: minmax(0, 1fr) 280px; gap: 24px">
  <div style="display: flex; flex-direction: column; gap: 18px">
    {field("Куда положить", f'<span style="display: inline-flex; align-items: center; gap: 8px; height: 34px; padding: 0 12px; border-radius: 8px; background: {HOVER}; border: 1px solid {LINE}">{dot(OR, 8)}<span style="font-weight: 600">3D-ассеты</span><span style="color: {GOLD}; font-size: 12px">угадал по слову «рендер»</span></span>{btn("Другой список", "ghost", True, "; color: " + OR)}')}
    {field("Когда", sc("Завтра, пт 6 ноября · 17:00", True, OR, True) + sc("Без срока"))}
    {field("Этап", sc("Модель") + sc("UV") + sc("Покраска") + sc("Рендер", True) + sc("Сдача"))}
    {field("Напомнить", sc("За час", True) + sc("За день") + sc("Не надо"))}
  </div>
  <div style="display: flex; flex-direction: column; gap: 14px">
    <span style="font: 500 12.5px {SANS}; color: {MUT}">Так появится на доске</span>
    <div style="border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; overflow: hidden">
      <div style="height: 28px; padding: 0 10px; background: {FILL[OR]}; display: flex; align-items: center; justify-content: space-between; font: 500 10px {MONO}; letter-spacing: .14em; color: #FFFFFF">3D-АССЕТЫ<span style="color: rgba(255,255,255,.72)">РЕНДЕР</span></div>
      <div style="padding: 12px; display: flex; gap: 10px; align-items: center"><span style="width: 40px; height: 40px; border-radius: 6px; background: #2B2520; border: 1px solid #3F352B; display: grid; place-items: center; color: {ORI}; font-weight: 600">Р</span><span style="flex: 1"><span style="display: block; font-weight: 600">Рендер щита</span><span style="font-size: 12px; color: {MUT}">Завтра в 17:00 · важно</span></span></div>
      <div style="padding: 0 12px 12px">{stages(4, 4, 6)}</div>
    </div>
    <div style="display: flex; gap: 12px; align-items: flex-start; padding: 12px; border-radius: 10px; background: rgba(232,198,90,.07); border: 1px solid #5C4F22">{coon(44, "ДУМАЕТ")}<span style="font-size: 13px; line-height: 19px; color: #DADBE0">В пятницу с 17:00 у тебя свободно. Рендер обычно занимает часа два.</span></div>
  </div>
</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 64px; box-sizing: border-box; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 10px; padding: 0 24px">
  <span style="font-size: 12.5px; color: {MUT}">Enter — добавить, Esc — закрыть</span><span style="flex: 1"></span>
  {btn("Добавить и ещё одну", extra="; height: 38px; padding: 0 16px; border-radius: 8px")}{btn("Добавить задачу", "acc", extra="; height: 38px; padding: 0 18px; border-radius: 8px; font-size: 14px")}
</div>'''
st = DIMK + node(214, 40, 820, 566, hd + body, hub=True)
save('G_Create.dc.html', page('Создать', 'ДОСКА', st), 'Окно «Создать»', 0, 3760, 'r4')
print('ok')
