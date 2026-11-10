import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import LOGO, winctl, SANS, GEAR
OR='#F0A04B'; BG='#1C1D21'; NODE='#25262B'; LINE='#3A3B42'; INK='#E2E3E8'; MUT='#8A8C96'; DIM='#62646E'
MONO="'JetBrains Mono', monospace"
def sock(side, top, fill, ring=False):
    pos = 'right' if side=='r' else 'left'
    st = f"background: {BG}; border: 1.5px solid {fill}" if ring else f"background: {fill}; border: 1.5px solid {BG}"
    return f'<span style="position: absolute; {pos}: -6px; top: {top}px; width: 10px; height: 10px; border-radius: 3px; box-sizing: border-box; {st}"></span>'
FILLS = {OR: '#8A5320', '#6FA2F2': '#2F4F86', '#B48CF0': '#5E3F92', '#7FD18C': '#2E6B3E', '#E8C65A': '#7A6620', '#A3A5AE': '#3D3E45'}
def head(num, name, kind, color, kcolor=None):
    return (f'<div style="height: 30px; box-sizing: border-box; padding: 0 10px 0 12px; border-radius: 7px 7px 0 0; background: {FILLS.get(color, "#3D3E45")}; display: flex; align-items: center; gap: 8px; font: 500 10.5px {MONO}; letter-spacing: .14em">'
            f'<span style="color: rgba(255,255,255,.72)">{num}</span><span style="color: #FFFFFF">{name}</span><span style="margin-left: auto; color: rgba(255,255,255,.72)">{kind}</span></div>')
def row(text, right, rc=MUT, tc=INK, strike=False):
    s = '; text-decoration: line-through' if strike else ''
    return (f'<div style="height: 28px; padding: 0 16px 0 12px; display: flex; align-items: center; justify-content: space-between; color: {tc}"><span style="{s[2:]}">{text}</span>'
            f'<span style="font: 400 11px {MONO}; color: {rc}">{right}</span></div>')
def node(top, h, inner, dashed=False, extra=''):
    b = f'1px dashed #55575F' if dashed else f'1px solid {LINE}'
    return f'<div style="position: absolute; left: 20px; top: {top}px; width: 230px; height: {h}px; box-sizing: border-box; border-radius: 8px; background: {NODE}; border: {b}">{inner}{extra}</div>'

src = ''
src += node(20, 88, head('01','3D-АССЕТЫ','СПИСОК',OR) + row('Текстуры для щита','15:00','#FFD29C','#FFD29C') + row('Ретопология меча','10:00',DIM,DIM,True), extra=sock('r',37,OR)+sock('r',65,'#7C7E88'))
src += node(136, 60, head('02','РАБОТА · КЛИЕНТЫ','СПИСОК','#6FA2F2') + row('Созвон «Таверна»','12:30'), extra=sock('r',37,'#6FA2F2'))
src += node(224, 60, head('03','УЧЁБА','СПИСОК','#B48CF0') + row('Глава 4 · Substance','19:00'), extra=sock('r',37,'#B48CF0'))
src += node(312, 60, head('04','ДЕЛА ПО ДОМУ','СТИКЕРЫ','#7FD18C') + row('Купить корм коту','ДЕНЬ'), extra=sock('r',37,'#7FD18C'))
src += node(400, 88, head('05','ОТ CLAUDE','ЖДУТ','#A3A5AE') + row('Счёт «Таверне»','→ РАБОТА','#6FA2F2') + row('Референсы брони','→ 3D',OR), dashed=True, extra=sock('r',37,'#A3A5AE',True)+sock('r',65,'#A3A5AE',True))
src += node(516, 116, head('06','ПРИВЫЧКИ','СЕРИИ','#E8C65A') + row('Зарядка','21 ДН','#E8C65A') + row('Вода','12 ДН') + row('Скетч 15 минут','3 НЕД'), extra=sock('r',37,'#E8C65A')+sock('r',65,'#E8C65A')+sock('r',93,'#E8C65A'))

def trow(top, n, time, title, dot, done=False):
    c = DIM if done else INK
    box = (f'<span style="width: 14px; height: 14px; border-radius: 4px; box-sizing: border-box; background: #45464D; display: grid; place-items: center; font-size: 9px; color: {INK}">✓</span>' if done
           else f'<span style="width: 14px; height: 14px; border-radius: 4px; box-sizing: border-box; border: 1px solid {MUT}"></span>')
    st = 'text-decoration: line-through; ' if done else ''
    d = f'<span style="width: 6px; height: 6px; border-radius: 2px; background: {dot}"></span>' if dot else ''
    return (f'<div style="position: absolute; left: 12px; right: 12px; top: {top}px; height: 40px; box-sizing: border-box; display: flex; align-items: center; gap: 12px; padding: 0 10px; border-bottom: 1px solid #303137; color: {c}">'
            f'<span style="font: 400 10.5px {MONO}; color: {DIM}; width: 16px">{n}</span>{box}<span style="font: 400 11.5px {MONO}; width: 42px; color: {DIM if done else MUT}">{time}</span><span style="flex: 1; {st}">{title}</span>{d}</div>')

ticks = ''.join(f'<span style="position: absolute; {v}: -5px; {h}: -5px; width: 14px; height: 14px; border-{v}-{h}-radius: 14px; border-{v}: 1.5px solid {OR}; border-{h}: 1.5px solid {OR}"></span>' for v in ('top','bottom') for h in ('left','right'))

center = f'''<section aria-label="Сегодня" style="position: absolute; left: 380px; top: 20px; width: 470px; height: 560px; box-sizing: border-box; border-radius: 12px; background: {NODE}; border: 1px solid #6A5238; box-shadow: 0 18px 40px rgba(0,0,0,.35)">{ticks}
  <div style="height: 34px; box-sizing: border-box; padding: 0 12px; border-radius: 11px 11px 0 0; background: #9A5A22; display: flex; align-items: center; gap: 10px; font: 500 10.5px {MONO}; letter-spacing: .14em"><span style="color: #FFFFFF">СЕГОДНЯ</span><span style="color: rgba(255,255,255,.72)">ЧТ 05.11</span><span style="margin-left: auto; color: rgba(255,255,255,.72)">4 ЗАДАЧИ · 3 ПРИВЫЧКИ</span></div>
  <div style="position: absolute; left: 12px; right: 12px; top: 46px; height: 36px; box-sizing: border-box; display: flex; align-items: center; gap: 8px; padding: 0 8px 0 10px; border-radius: 8px; background: {BG}; border: 1px solid {LINE}">
    <label for="addG" style="color: {OR}; font-weight: 600">＋</label>
    <input id="addG" type="text" placeholder="Добавить: «завтра 17:00 рендер щита»" style="flex: 1; min-width: 0; border: 0; background: transparent; color: {INK}; font: 400 13px 'Onest', sans-serif; outline: none">
    <span style="font: 400 10px {MONO}; letter-spacing: .1em; color: {DIM}">SHIFT A</span>
  </div>
  {trow(90,'01','10:00','Ретопология меча',None,True)}
  {trow(136,'02','12:30','Созвон с клиентом «Таверна»','#6FA2F2')}
  <div style="position: absolute; left: 12px; right: 12px; top: 182px; height: 120px; box-sizing: border-box; padding: 10px; border-radius: 8px; background-color: #2E2722; background-image: repeating-linear-gradient(-45deg, rgba(240,160,75,.07) 0 1px, transparent 1px 7px); border: 1px solid {OR}; display: flex; flex-direction: column; gap: 9px">
    <div style="display: flex; align-items: center; gap: 12px"><span style="font: 400 10.5px {MONO}; color: {OR}; width: 16px">03</span><span style="width: 14px; height: 14px; border-radius: 4px; box-sizing: border-box; border: 1px solid {OR}"></span><span style="font: 400 11.5px {MONO}; width: 42px; color: #FFD29C">15:00</span><span style="flex: 1; font-weight: 600; font-size: 14px">Текстуры для щита, 2K</span><span style="font: 500 10px {MONO}; letter-spacing: .14em; color: {OR}">ДАЛЬШЕ · 8 МИН</span></div>
    <div style="display: flex; gap: 3px; padding-left: 92px" aria-label="Этапы: 2 из 5 готово, сейчас третий"><span style="flex: 1; height: 4px; border-radius: 2px; background: #7FD18C"></span><span style="flex: 1; height: 4px; border-radius: 2px; background: #7FD18C"></span><span style="flex: 1; height: 4px; border-radius: 2px; background: {OR}"></span><span style="flex: 1; height: 4px; border-radius: 2px; background: #45464D"></span><span style="flex: 1; height: 4px; border-radius: 2px; background: #45464D"></span></div>
    <div style="padding-left: 92px; display: flex; justify-content: space-between; font: 400 10px {MONO}; letter-spacing: .1em; color: {DIM}"><span>МОДЕЛЬ</span><span>UV</span><span style="color: {OR}">ПОКРАСКА</span><span>РЕНДЕР</span><span>СДАЧА</span></div>
    <div style="padding-left: 92px; display: flex; gap: 6px; align-items: center"><button type="button" style="height: 28px; padding: 0 12px; border-radius: 6px; border: 0; background: {OR}; color: #1E1F23; font: 600 12.5px 'Onest', sans-serif">▶ Начать</button><button type="button" style="height: 28px; padding: 0 12px; border-radius: 6px; border: 1px solid #6A5238; background: transparent; color: {INK}; font: 500 12.5px 'Onest', sans-serif">Перенести</button><span style="margin-left: auto; font: 400 10px {MONO}; letter-spacing: .1em; color: #D8C2A5">ДО 17:00 · !!!</span></div>
  </div>
  {trow(308,'04','19:00','Глава 4 курса по Substance','#B48CF0')}
  {trow(354,'05','ДЕНЬ','Купить корм коту','#7FD18C')}
  <div style="position: absolute; left: 12px; right: 12px; top: 402px; height: 38px; box-sizing: border-box; display: flex; align-items: center; gap: 10px; padding: 0 10px; border-radius: 8px; border: 1px dashed #55575F; color: #A3A5AE"><span style="font: 400 10.5px {MONO}; color: {DIM}; width: 16px">＋2</span><span style="flex: 1">От Claude ждут две задачи: взять в день?</span><button type="button" style="height: 26px; padding: 0 10px; border-radius: 6px; border: 1px solid #55575F; background: transparent; color: {INK}; font: 500 12px 'Onest', sans-serif">Принять</button></div>
  <div style="position: absolute; left: 12px; right: 12px; top: 452px; height: 92px; box-sizing: border-box; padding: 10px; border-top: 1px solid #8A7424; display: flex; flex-direction: column; gap: 9px">
    <span style="display: flex; justify-content: space-between; font: 500 10.5px {MONO}; letter-spacing: .14em"><span style="color: #E8C65A">ПРИВЫЧКИ</span><span style="color: {DIM}">1 / 3</span></span>
    <div style="display: flex; gap: 6px; flex-wrap: wrap">
      <button type="button" style="height: 32px; padding: 0 12px; border-radius: 999px; border: 0; background: #E8C65A; color: #1E1F23; font: 600 12.5px 'Onest', sans-serif">✓ Зарядка · 21</button>
      <button type="button" style="height: 32px; padding: 0 12px; border-radius: 999px; border: 1px solid #8A7424; background: transparent; color: {INK}; font: 500 12.5px 'Onest', sans-serif">Вода 5/8</button>
      <button type="button" style="height: 32px; padding: 0 12px; border-radius: 999px; border: 1px solid #8A7424; background: transparent; color: {INK}; font: 500 12.5px 'Onest', sans-serif">Скетч · вечер</button>
    </div>
  </div>
  {sock('l',105,'#7C7E88')}{sock('l',151,'#6FA2F2')}{sock('l',197,OR)}{sock('l',323,'#B48CF0')}{sock('l',369,'#7FD18C')}{sock('l',415,'#A3A5AE',True)}{sock('l',485,'#E8C65A')}
  {sock('r',197,OR)}{sock('r',485,INK)}
</section>'''

def wire(y1,y2,c,w=1.5,dash=False,x1=250,x2=380):
    d = ' stroke-dasharray="4 4"' if dash else ''
    return f'<path d="M{x1} {y1} C {x1+60} {y1}, {x2-60} {y2}, {x2} {y2}" stroke="{c}" stroke-width="{w}"{d}></path>'
wires = ''.join([wire(92,130,'#7C7E88'), wire(178,176,'#6FA2F2'), wire(62,222,OR,2), wire(266,348,'#B48CF0'), wire(354,394,'#7FD18C'),
  wire(442,440,'#A3A5AE',1.5,True), wire(470,440,'#A3A5AE',1.5,True), wire(558,510,'#E8C65A'), wire(586,510,'#E8C65A'), wire(614,510,'#E8C65A'),
  wire(222,70,OR,2,False,850,920), wire(510,300,INK,1.5,False,850,920)])

def colhead(x, w, t):
    return f'<div style="position: absolute; left: {x}px; top: 0; width: {w}px; display: flex; align-items: center; gap: 8px; font: 500 10px {MONO}; letter-spacing: .16em; color: {DIM}"><span>{t}</span><span style="flex: 1; height: 1px; background: {LINE}"></span></div>'

def onode(top, num, name, right, rc, body, sockTop):
    return (f'<div style="position: absolute; left: 920px; top: {top}px; width: 280px; box-sizing: border-box; border-radius: 8px; background: {NODE}; border: 1px solid {LINE}">'
            f'<div style="height: 30px; box-sizing: border-box; padding: 0 10px 0 12px; border-radius: 7px 7px 0 0; background: {"#8A5320" if rc==OR else "#3D3E45"}; display: flex; align-items: center; gap: 8px; font: 500 10.5px {MONO}; letter-spacing: .14em"><span style="color: rgba(255,255,255,.72)">{num}</span><span style="color: #FFFFFF">{name}</span><span style="margin-left: auto; color: rgba(255,255,255,.72)">{right}</span></div>'
            f'{sock("l", sockTop, rc if rc!=DIM else INK)}{body}</div>')

out1 = onode(20,'В1','ДАЛЬШЕ','T−8 МИН',OR, f'''<div style="padding: 10px 12px 12px; display: flex; flex-direction: column; gap: 8px">
  <div style="position: relative; height: 110px; background-color: #2B2520; background-image: linear-gradient(rgba(240,160,75,.08) 1px, transparent 1px), linear-gradient(90deg, rgba(240,160,75,.08) 1px, transparent 1px); background-size: 14px 14px; border: 1px solid #3F352B; border-radius: 6px; display: grid; place-items: center; color: {MUT}; font: 400 10px {MONO}; letter-spacing: .14em">ПРЕВЬЮ РЕНДЕРА
    <span style="position: absolute; left: 6px; top: 6px; width: 8px; height: 8px; border-left: 1px solid {OR}; border-top: 1px solid {OR}"></span><span style="position: absolute; right: 6px; bottom: 6px; width: 8px; height: 8px; border-right: 1px solid {OR}; border-bottom: 1px solid {OR}"></span><span style="position: absolute; right: 8px; top: 6px; font-size: 9px; color: {DIM}">2048 × 2048</span></div>
  <div style="font-weight: 600; font-size: 14px">Текстуры для щита, 2K</div>
  <div style="font: 400 10.5px {MONO}; letter-spacing: .08em; color: {MUT}">15:00—17:00 · 3D-АССЕТЫ · ЭТАП 3/5</div>
</div>''', 45)

bars = [('#36373D',0),('#45464D',0),('#36373D',0),('#2F4F86',0),('#36373D',0),('#36373D',0),('#B8692A',0),('#B8692A',0),(BG,1),(BG,1),('#5E3F92',0),('#36373D',0)]
barhtml = ''.join(f'<span style="height: 14px; border-radius: 2px; background: {c}{"; outline: 1px dashed #55575F; outline-offset: -1px" if d else ""}"></span>' for c,d in bars)
out2 = onode(270,'В2','ИТОГ ДНЯ','',DIM, f'''<div style="padding: 10px 12px 12px; display: flex; flex-direction: column; gap: 8px; font-size: 12.5px">
  <span style="display: flex; justify-content: space-between; border-bottom: 1px solid #303137; padding-bottom: 6px"><span>Задачи</span><span style="font-family: {MONO}">1 / 4</span></span>
  <span style="display: flex; justify-content: space-between; border-bottom: 1px solid #303137; padding-bottom: 6px"><span>Привычки</span><span style="font-family: {MONO}">1 / 3</span></span>
  <span style="display: flex; align-items: center; gap: 6px; font: 400 9.5px {MONO}; letter-spacing: .1em; color: {DIM}"><span>|</span><span style="flex: 1; height: 1px; background: #55575F"></span><span>12 Ч</span><span style="flex: 1; height: 1px; background: #55575F"></span><span>|</span></span>
  <span style="display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: 2px" aria-label="Занятость с 9 до 21, свободно 17–19">{barhtml}</span>
  <span style="display: flex; justify-content: space-between; font: 400 9.5px {MONO}; color: {DIM}"><span>09</span><span>15</span><span>21</span></span>
</div>''', 25)

coon = f'''<div style="position: absolute; left: 920px; top: 470px; width: 280px; box-sizing: border-box; border-radius: 8px; border: 1px dashed #55575F; padding: 12px; display: flex; gap: 12px; align-items: center">
  <span style="width: 50px; height: 50px; flex: none; border-radius: 50%; border: 1px dashed {MUT}; display: grid; place-items: center; font: 400 9px {MONO}; letter-spacing: .1em; color: {MUT}">ЕНОТ</span>
  <span style="font-size: 12.5px; color: #B5B7C0">С 17 до 19 свободно. Подключить туда «Рендер щита»? <a href="#">Подключить</a></span>
</div>'''

stamp = f'''<div style="position: absolute; left: 920px; top: 574px; width: 280px; box-sizing: border-box; border-radius: 8px; border: 1px solid {LINE}; display: grid; grid-template-columns: 1fr 1fr 1fr; font: 400 9.5px {MONO}; letter-spacing: .12em; color: {DIM}">
  <span style="grid-column: 1 / 4; padding: 6px 8px; border-bottom: 1px solid {LINE}; color: {INK}">ЛИСТ · СЕГОДНЯ</span>
  <span style="padding: 6px 8px; border-right: 1px solid {LINE}">05.11.26</span><span style="padding: 6px 8px; border-right: 1px solid {LINE}">ВХОДОВ 06</span><span style="padding: 6px 8px">ВЕРСИЯ G3</span>
</div>'''

html = f'''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<title>Ноды со строгостью · Сегодня</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Onest:wght@300;400;500;600&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap">
<style>
body{{margin:0;background:{BG}}}
a{{color:{OR}}}a:hover{{color:#FFD29C}}
</style>
</helmet>
<div style="min-height: 820px; box-sizing: border-box; background: {BG}; color: {INK}; font-family: 'Onest', 'Segoe UI', sans-serif; font-size: 13px; display: flex; flex-direction: column">

  <header style="display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; padding: 14px 16px 14px 20px; border-bottom: 1px solid {LINE}; font: 500 11px {MONO}; letter-spacing: .14em">
    <span title="Спутник" style="display: flex; align-items: center">{LOGO}</span>
    <nav aria-label="Разделы" style="display: flex; align-items: center; gap: 18px; margin-left: 6px; flex-wrap: wrap">
      <a href="#" style="text-decoration: none; color: {INK}; padding: 4px 0 3px; border-bottom: 1px solid {OR}">СЕГОДНЯ</a>
      <a href="#" style="text-decoration: none; color: {MUT}; padding: 4px 0 3px; border-bottom: 1px solid transparent">КАЛЕНДАРЬ</a>
      <a href="#" style="text-decoration: none; color: {MUT}; padding: 4px 0 3px; border-bottom: 1px solid transparent">ДОСКА</a>
      <a href="#" style="text-decoration: none; color: {MUT}; padding: 4px 0 3px; border-bottom: 1px solid transparent">ПРИВЫЧКИ</a>
    </nav>
    <span style="flex: 1"></span>
    <span style="color: {MUT}">ЧТ 05.11 · 14:52</span>
    <span style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px; border-radius: 8px; border: 1px solid {LINE}; color: {MUT}; min-width: 150px"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4"></path></svg>НАЙТИ<span style="margin-left: auto; font-size: 10px; color: {DIM}">CTRL K</span></span>
    {GEAR}
    <button type="button" style="height: 32px; padding: 0 14px; border-radius: 8px; border: 0; background: {INK}; color: {BG}; font: 600 13px 'Onest', sans-serif">＋ Создать</button>
    {winctl()}
  </header>

  <main aria-label="Сегодня: списки, привычки и входящие сходятся в одну ноду" style="flex: 1; overflow: auto; background-color: #191A1E; background-image: radial-gradient(rgba(255,255,255,.07) 1px, transparent 1.3px); background-size: 24px 24px; padding: 18px 16px 16px">
    <div style="position: relative; width: 1220px; height: 650px; margin: 0 auto">
      <svg width="1220" height="650" style="position: absolute; inset: 0" aria-hidden="true" fill="none">{wires}</svg>
      {colhead(20,230,'01 · ИСТОЧНИКИ')}
      {colhead(380,470,'02 · СБОРКА ДНЯ')}
      {colhead(920,280,'03 · ВЫВОД')}
      {src}
      {center}
      <div style="position: absolute; left: 380px; top: 594px; width: 470px; display: flex; align-items: center; gap: 8px; font: 400 9.5px {MONO}; letter-spacing: .12em; color: {DIM}"><span>|</span><span style="flex: 1; height: 1px; background: #45464D"></span><span>09:00 — 21:00 · ЗАНЯТО 7 Ч · СВОБОДНО 17—19</span><span style="flex: 1; height: 1px; background: #45464D"></span><span>|</span></div>
      {out1}
      {out2}
      {coon}
      {stamp}
    </div>
  </main>
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
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'screens') + '/'
open(P+'NodesStrict.dc.html','w').write(html)
import json
c=json.load(open(P+'canvas.json'))
c['boards']['NodesStrict.dc.html']={"x":0,"y":2820,"w":1280,"h":820,"title":"G · Ноды со строгостью чертежа — «Сегодня»","expand":"fill","page":"r3"}
if 'NodesStrict.dc.html' not in c['order']: c['order'].append('NodesStrict.dc.html')
json.dump(c,open(P+'canvas.json','w'),ensure_ascii=False,indent=1)
print('ok', len(html))
