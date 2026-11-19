from s_calhelp import *
def ico(t): return f'<span style="width:28px;height:28px;border-radius:7px;border:1px solid {LINE};display:grid;place-items:center;color:{INK};font-size:13px">{t}</span>'
def bar(show_open=False):
    seg_=f'<span style="display:flex;border:1px solid {LINE};border-radius:7px;overflow:hidden"><span style="padding:6px 12px;background:{INK};color:#1A1B1F;font:500 10.5px {MONO};letter-spacing:.12em">НЕДЕЛЯ</span><span style="padding:6px 12px;color:{MUT};font:500 10.5px {MONO};letter-spacing:.12em">МЕСЯЦ</span></span>'
    month=f'<span style="width:150px;height:28px;box-sizing:border-box;border-radius:7px;border:1px solid {OR if show_open else LINE};display:flex;align-items:center;justify-content:space-between;padding:0 10px;font:600 11px {MONO};letter-spacing:.12em;color:{INK}">МАРТ 2027<span style="color:{MUT}">▾</span></span>'
    now=f'<span style="height:28px;padding:0 10px;border-radius:7px;border:1px dashed {LINE};display:flex;align-items:center;gap:6px;font:500 10px {MONO};color:{MUT};letter-spacing:.1em"><span style="width:6px;height:6px;border-radius:50%;background:{OR}"></span>К СЕЙЧАС</span>'
    show=f'<span style="height:28px;padding:0 10px;border-radius:7px;border:1px solid {LINE};display:flex;align-items:center;gap:8px;font:500 10px {MONO};color:{INK};letter-spacing:.1em">ПОКАЗЫВАТЬ <span style="display:flex;gap:3px">{dot(GREY,6)}{dot(OR,6)}{dot(GOLD,6)}</span><span style="color:{MUT}">▾</span></span>'
    inner=f'<div style="height:100%;display:flex;align-items:center;gap:10px;padding:0 12px">{seg_}<span style="width:1px;height:20px;background:{LINE}"></span>{ico("‹")}{ico("›")}{month}{now}<span style="flex:1"></span>{show}</div>'
    return node(0,0,1248,48,inner)
def parts(open_=False):
    seg_=f'<span style="display:flex;border:1px solid {LINE};border-radius:7px;overflow:hidden"><span style="padding:6px 12px;background:{INK};color:#1A1B1F;font:500 10.5px {MONO};letter-spacing:.12em">НЕДЕЛЯ</span><span style="padding:6px 12px;color:{MUT};font:500 10.5px {MONO};letter-spacing:.12em">МЕСЯЦ</span></span>'
    nav=f'<span style="display:flex;align-items:center;height:28px;border:1px solid {OR if open_ else LINE};border-radius:7px"><span style="width:28px;text-align:center;color:{INK}">‹</span><span style="width:150px;height:28px;border-left:1px solid {LINE};border-right:1px solid {LINE};display:flex;align-items:center;justify-content:center;gap:8px;font:600 11px {MONO};letter-spacing:.12em;color:{INK}">МАРТ 2027<span style="color:{MUT}">▾</span></span><span style="width:28px;text-align:center;color:{INK}">›</span></span>'
    now=f'<span style="position:relative;width:28px;height:28px;border-radius:7px;border:1px solid {LINE};display:grid;place-items:center"><svg width="14" height="14" fill="none"><circle cx="7" cy="7" r="5.5" stroke="{MUT}" stroke-width="1.3"/><circle cx="7" cy="7" r="2" fill="{OR}"/></svg></span>'
    show=f'<span style="height:28px;padding:0 10px;border-radius:7px;border:1px solid {LINE};display:flex;align-items:center;gap:8px;font:500 10px {MONO};color:{INK};letter-spacing:.1em">ПОКАЗЫВАТЬ <span style="display:flex;gap:3px">{dot(GREY,6)}{dot(OR,6)}{dot(GOLD,6)}</span><span style="color:{MUT}">▾</span></span>'
    return seg_,nav,now,show
def bar2(order):
    seg_,nav,now,show=parts()
    m=dict(seg=seg_,nav=nav,now=now,show=show,sp='<span style="flex:1"></span>')
    return node(0,0,1248,48,'<div style="height:100%;display:flex;align-items:center;gap:10px;padding:0 12px">'+''.join(m[k] for k in order)+'</div>')
def tip(t):
    return f'<div style="background:#0F1013;border:1px solid {LINE};border-radius:6px;padding:5px 8px;font-size:11.5px;color:{INK};white-space:nowrap">{t} <span style="font:500 10px {MONO};color:{MUT};margin-left:6px">T</span></div>'
def mpick():
    ms=['ЯНВ','ФЕВ','МАР','АПР','МАЙ','ИЮН','ИЮЛ','АВГ','СЕН','ОКТ','НОЯ','ДЕК']
    g=''.join(f'<span style="height:34px;border-radius:6px;display:grid;place-items:center;font:500 11px {MONO};letter-spacing:.1em;{"background:"+OR+";color:#1A1B1F" if i==2 else ("border:1px solid "+rgba(OR,.6)+";color:"+OR if i==10 else "color:"+INK)}">{m}</span>' for i,m in enumerate(ms))
    inner=f'<div style="padding:10px 12px;display:flex;align-items:center;justify-content:space-between">{ico("‹")}<span style="font:600 13px {MONO};color:{INK};letter-spacing:.1em">2027</span>{ico("›")}</div><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:6px;padding:0 12px 10px">{g}</div><div style="border-top:1px solid {SOFT};padding:8px 12px;display:flex;justify-content:space-between;align-items:center"><span style="font:400 10px {MONO};color:{MUT}">СЕЙЧАС · НОЯ 2026</span><span style="font:500 10.5px {MONO};color:{OR};letter-spacing:.1em">СЕЙЧАС</span></div>'
    return f'<div style="width:240px;background:{NODE};border:1px solid {OR};border-radius:9px;box-shadow:0 12px 30px rgba(0,0,0,.55)">{inner}</div>'
def showpop():
    rows=''.join(f'<div style="display:flex;align-items:center;gap:10px;height:32px;padding:0 12px;font-size:13px;color:{INK}"><span style="width:14px;height:14px;border-radius:4px;{"background:"+OR+";color:#1A1B1F" if on else "border:1.5px solid "+LINE};display:grid;place-items:center;font-size:10px">{"✓" if on else ""}</span>{dot(c,7)}{t}</div>' for t,c,on in [('События',GREY,True),('Задачи',OR,True),('Привычки',GOLD,True),('Дни рождения','#F08CC0',False)])
    return f'<div style="width:220px;background:{NODE};border:1px solid {LINE};border-radius:9px;box-shadow:0 12px 30px rgba(0,0,0,.55);padding:6px 0">{rows}</div>'
st=cap(0,0,'1','ШАПКА КАЛЕНДАРЯ',1248)+ab(0,24,bar2(['now','nav','sp','seg','show']))+ab(0,78,tip('К сегодня'))
st+=note(0,130,1248,'Слева направо: «к сегодня» (иконка), ‹ МАРТ 2027 ▾ ›, справа НЕДЕЛЯ | МЕСЯЦ и «ПОКАЗЫВАТЬ ▾». Месяц и стрелки — одна кнопка-группа ‹ МАРТ 2027 ▾ › постоянной ширины: стрелки не прыгают. «К сегодня» — маленькая иконка 28 px (кольцо с точкой OR), при наведении подсказка «К сегодня · T»; скрыта, если сегодня уже на экране.')
st+=cap(0,220,'2','ВЫБОР МЕСЯЦА · КЛИК ПО «МАРТ 2027»',600)+ab(0,244,mpick())
st+=note(260,250,420,'Всплывает под кнопкой месяца, рамка OR. Сверху год ‹ 2027 ›, сетка 12 месяцев 3×4. Выбранный — залит OR, текущий месяц (сегодня) — обводка OR. Внизу «СЕЙЧАС» — к сегодняшнему дню. Клик по месяцу — переход и окно закрывается; Esc или клик мимо — закрыть.')
st+=cap(720,220,'3','ПОКАЗЫВАТЬ',600)+ab(720,244,showpop())+note(960,250,280,'Галочки OR и цветная точка типа. Меняется сразу, окно не закрывается. Выключенный тип пропадает из точек на кнопке.')
save2('G_CalHead.dc.html',page('Календарь · шапка','КАЛЕНДАРЬ',st,right='ЧТ 19.11 · 14:10',stage_h=700),'Календарь · шапка')
