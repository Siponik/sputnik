from s_calhelp import *
from s_calstack import grid_layer
import s_cal
s_cal.coon=lambda *a,**k:''
days=['ПН 16','ВТ 17','СР 18','ЧТ 19','ПТ 20','СБ 21','ВС 22']
W=900; GX=38; CW=(W-GX-14)//7
EV=[(0,7,8,'Пробежка',GREEN,'task',True),(0,10,11,'Бриф по щиту',BLUE,'event',False),(0,14,16,'Ретопология меча',OR,'task',False),
    (1,11,13,'UV щита',OR,'task',False),(1,19,20.5,'Курс Substance',VIO,'event',False),
    (2,12,13,'Обед с Олей',GREY,'event',False),(2,15,17,'Скульпт шлема',OR,'task',False),(2,22,23,'Стрим',VIO,'event',False),
    (3,10,10.5,'Фгд 360',OR,'task',True),(3,11,12,'Созвон «Таверна»',BLUE,'event',False),(3,11,13,'Текстуры для щита, 2K',OR,'task',False),(3,14,14.5,'Оплатить интернет',GREEN,'task',False),(3,15,17,'Рендер щита',OR,'task',False),
    (4,9,10,'Сдача «Таверне»',BLUE,'task',False),(4,16,18,'Рендер щита',OR,'task',False),(5,12,14,'Рынок',GREEN,'task',False),(1,9,10,'Зарядка · 21 дн',GOLD,'habit',False),(3,9,9.5,'Зарядка',GOLD,'habit',True),(2,18,19,'Скетч · вечер',GOLD,'habit',False),(4,18,19,'Скетч · вечер',GOLD,'habit',False)]
def heads(y):
    s=''
    for i,d in enumerate(days):
        c=OR if i==3 else MUT
        s+=ab(GX+i*CW,y,f'<div style="width:{CW}px;height:34px;border-left:1px solid {SOFT};display:flex;align-items:center;justify-content:center;font:500 11px {MONO};color:{c};letter-spacing:.1em">{d}</div>')
    s+=ab(0,y+40,f"<div style=\"width:{GX}px;height:20px;display:flex;align-items:center;justify-content:center;font:500 8.5px {MONO};color:{DIM};letter-spacing:.06em\">ВЕСЬ<br>ДЕНЬ</div>")
    s+=ab(GX+4*CW+4,y+40,f'<div style="width:{CW-8}px;height:20px;border-radius:5px;background:{rgba("#F08CC0",.18)};font-size:11px;color:#F08CC0;padding:2px 8px;box-sizing:border-box">ДР · Аня 30</div>')
    return s
def evs(top,r0,r1,rh):
    s=''
    lanes={(3,11):(0,2),(3,11.0001):(1,2)}
    seen={}
    for d,a,b,t,c,k,done in EV:
        if b<=r0 or a>=r1: continue
        a2=max(a,r0);b2=min(b,r1)
        n=sum(1 for e in EV if e[0]==d and e[1]<b and e[2]>a)
        i=seen.get((d,a,b),None); key=d
        idx=sum(1 for e in EV[:EV.index((d,a,b,t,c,k,done))] if e[0]==d and e[1]<b and e[2]>a)
        w=(CW-8)//n
        s+=blk(GX+d*CW+4+idx*w,top+int((a2-r0)*rh)+1,w-(3 if n>1 else 0),int((b2-a2)*rh)-3,t,f'{int(a):02d}:{int(a%1*60):02d}',c,k,done)
    return s
def hours(top,r0,r1,rh,shade=()):
    s=''
    for h in range(r0,r1):
        y=top+(h-r0)*rh
        bg=f'background:rgba(0,0,0,.18);' if (h<7 or h>=22) else ''
        s+=ab(0,y,f'<div style="width:{W-14}px;height:{rh}px;border-top:1px solid {SOFT};{bg}"><span style="position:absolute;left:10px;top:3px;font:400 10px {MONO};color:{DIM}">{h:02d}:00</span></div>')
    for i in range(7): s+=ab(GX+i*CW,top,f'<div style="width:{CW}px;height:{(r1-r0)*rh}px;border-left:1px solid {SOFT};{"background:rgba(240,160,75,.035)" if i==3 else ""}"></div>')
    return s
def nowline(top,r0,rh):
    y=top+int((9.5-r0)*rh)
    return ab(GX+3*CW,y,f'<div style="width:{CW}px;border-top:1.5px solid {OR}"></div>')
def frame(title,body,h,foot):
    st=s_cal.toolbar('НЕДЕЛЯ')
    st+=node(0,64,W,h,nhead('',f'НЕДЕЛЯ · 16—22 НОЯБРЯ','ЗАНЯТО 24 Ч',OR,MUT,34,OR,OR)+f'<div style="position:relative">{body}</div>',hub=True,style='; overflow: hidden')
    st+=s_cal.daypanel(64,h,'ЧТ 19 · СЕГОДНЯ')
    st+=ab(0,64+h+14,f'<div style="font-size:12.5px;color:#C9CAD0;line-height:1.5">{foot}</div>',w=1248)
    return st
# A
TOP=96; rh=34; r0=8; vis=13
GL,TA=grid_layer(EV,GX,CW,W,r0,r0+vis,rh)
b=heads(0)+ab(0,TOP-20,GL)
b+=ab(W-10,TOP-20,f'<div style="width:4px;height:{vis*rh}px;border-radius:2px;background:{SOFT}"><div style="margin-top:{int(8/24*vis*rh)}px;width:4px;height:{int(vis/24*vis*rh)}px;border-radius:2px;background:#55575F"></div></div>')
A=frame('А',b,TOP-20+TA+40,'<b>А · все 24 часа.</b> Сетка 00–24, каждый час одной высоты (34 px), ничего не сворачивается. Дела в одно время — одним блоком со списком, эти часы растут во всех днях. Наведение — всплывашка с полным названием, датой, временем и заметкой. При открытии прокручено к 08:00 (или к первой задаче, если она раньше). Колесо мыши — прокрутка, полоса справа показывает, где ты в сутках. Ночь (до 07 и после 22) чуть темнее. Длинная привычка «Работа 08–17» — часы чуть тонированы золотом (6 %), тонкие золотые линии на 08 и 17, подпись сверху; дела поверх. Стрим в 22:00 в среду — ниже, надо прокрутить.')
save2('G_CalWeekAP.dc.html',page('Календарь · неделя А','КАЛЕНДАРЬ',A,right='ЧТ 19.11 · 09:30',stage_h=700),'Неделя · А · с панелью дня')
# B
r0=9;r1=19;rh=40
chip=lambda t:f'<span style="font:500 10px {MONO};color:{OR};background:{rgba(OR,.14)};border:1px solid {rgba(OR,.4)};padding:3px 10px;border-radius:5px">{t}</span>'
bb=ab(0,0,'<div style="position:relative">'+hours(0,r0,r1,rh)+evs(0,r0,r1,rh)+nowline(0,r0,rh)+'</div>')
b=heads(0)+ab(GX,TOP-20-2,'<div style="position:relative;top:-0px"></div>')+ab(0,TOP-20,'')
GL,TB=grid_layer(EV,GX,CW,W,r0,r1,rh)
b=heads(0)+ab(GX+4,TOP-14,chip('↑ 07:00 · ПРОБЕЖКА · ЕЩЁ 1 РАНЬШЕ'))+ab(0,TOP+8,GL)+ab(GX+2*CW+4,TOP+8+TB+6,chip('↓ 19:00 · 22:00 · ЕЩЁ 2 ПОЗЖЕ'))
B=frame('Б',b,TOP+8+TB+80,'<b>Неделя.</b> Видно от первой до последней задачи <i>рабочих</i> часов недели (по умолчанию 09–19, сам расширяется). Час 40 px, ничего не сжато. Что выпало за край — чипы над и под сеткой, в своей колонке: «↑ 07:00 · ещё 1 раньше». Клик по чипу раскрывает диапазон до этой задачи, повторный — сворачивает. Пустых ночных часов не видно. Длинная привычка «Работа 08–17» — часы чуть тонированы золотом (6 %), тонкие золотые линии на 08 и 17; дела поверх. Дела в одно время — одним блоком со списком внутри, эти часы растут во всех днях (до ×2). Наведение на дело — всплывашка: полное название, дата и время, список, заметка.')
save2('G_CalWeek.dc.html',page('Календарь · неделя','КАЛЕНДАРЬ',B,right='ЧТ 19.11 · 09:30',stage_h=700),'Календарь · неделя')
