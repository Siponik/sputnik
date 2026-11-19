from s_calhelp import *
from s_icons import svg_
import s_cal, re
s_cal.coon=lambda *a,**k:''
PINK='#F08CC0'
src=open('s_cal2.py').read(); src=src[src.index('def mcell'):src.index('cells = [')]
src=src.replace('width: 140px; height: 112px','width: {W_}px; height: {H_}px')
exec('W_=128;H_=82\n'+src)
import random; random.seed(3)
pool=[('Ретопология меча',OR),('Созвон: бриф',BLUE),('UV щита',OR),('Курс Substance',VIO),('Обед с Олей',GREY),('Рынок',GREEN),('Рендер щита',OR),('Оплатить интернет',GREEN),('Скетч · вечер',GOLD)]
g=''
for i,d in enumerate(['ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС']):
    g+=ab(i*128,0,f'<div style="width:128px;text-align:center;font:500 10px {MONO};color:{MUT};letter-spacing:.12em">{d}</div>')
day=26
for r in range(6):
    for c in range(7):
        n=day if day<=30 else day-30; dim=day<=30 and r==0
        if r==0: n=26+c if c<5 else c-4
        num=r*7+c-5  # nov day
        if num<1: label=f'{26+c:02d}'; dimc=True
        elif num>30: label=f'{num-30:02d}'; dimc=True
        else: label=f'{num:02d}'; dimc=False
        k=random.randint(0,4) if not dimc else random.randint(0,1)
        it=[(t,col,(not dimc and num<19 and random.random()<.5)) for t,col in random.sample(pool,min(k,3))]
        it.sort(key=lambda x:x[2])
        bd={10:'Алексей',20:'Аня · 30 лет'}.get(num)
        if num==19: it=[('Текстуры для щита, 2K',OR,False),('Созвон «Таверна»',BLUE,False),('Ретопология меча',OR,True)]; k=5
        cap_=1 if bd else 2
        more=max(0,len(it)-cap_)+(k-len(it) if k>len(it) else 0)
        g+=mcell(c*128,18+r*82,label,it[:cap_],bd,num==19,more,dimc)
inner=nhead('','НОЯБРЬ 2026','ДЕЛ 41',OR,MUT,34,OR,OR)+f'<div style="position:relative;margin:10px 2px">{g}</div>'
st=s_cal.toolbar('МЕСЯЦ')
st+=node(0,64,900,556,inner,hub=True,style='; overflow: hidden')
st+=s_cal.daypanel(64,556,'ЧТ 19 · СЕГОДНЯ')
st+=ab(0,636,f'<div style="font-size:12.5px;color:#C9CAD0;line-height:1.5"><b>Месяц.</b> Без времени: точка цвета списка и название. Порядок: день рождения (розовая плашка с тортиком), весь день, по времени, сделанное (DIM) в конце. Не влезло — «+N ещё». Клик по дню — день в панели справа. Дни соседних месяцев — DIM.</div>',w=1248)
save2('G_CalMonth.dc.html',page('Календарь · месяц','КАЛЕНДАРЬ',st,right='ЧТ 19.11 · 09:30',stage_h=700),'Календарь · месяц')
