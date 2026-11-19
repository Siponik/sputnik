from s_calhelp import *
import math
def clusters(EV,r0,r1):
    out=[]
    for d in range(7):
        es=sorted([e for e in EV if e[0]==d and e[2]>r0 and e[1]<r1],key=lambda e:e[1])
        cur=[]
        for e in es:
            if cur and e[1]<max(c[2] for c in cur): cur.append(e)
            else:
                if cur: out.append(cur)
                cur=[e]
        if cur: out.append(cur)
    return out
def rowh(EV,r0,r1,rh):
    H={h:rh for h in range(r0,r1)}
    for c in clusters(EV,r0,r1):
        if len(c)<2: continue
        a=int(max(r0,min(e[1] for e in c))); b=math.ceil(min(r1,max(e[2] for e in c)))
        need=22+28*len(c); per=min(2*rh,max(rh,math.ceil(need/(b-a))))
        for h in range(a,b): H[h]=max(H[h],per)
    return H
def Yf(H,r0,t):
    y=0
    for h in range(r0,int(t)): y+=H[h]
    if t%1: y+=H[int(t)]*(t%1)
    return int(y)
def stackblk(x,y,w,h,c):
    def line(e):
        _,a,b,t,col,k,done=e
        if k=='event': m=f'<span style="width:3px;height:26px;background:{col};border-radius:2px;flex:none"></span>'
        elif k=='habit': m=f'<span style="width:8px;height:8px;border-radius:2px;border:1.5px solid {GOLD};box-sizing:border-box;flex:none;margin-top:3px"></span>'
        else: m=f'<span style="width:8px;height:8px;border-radius:50%;border:1.5px solid {col};box-sizing:border-box;flex:none;margin-top:3px"></span>'
        tm=f'{int(a):02d}:{int(a%1*60):02d}–{int(b):02d}:{int(b%1*60):02d}'
        return f'<div style="display:flex;gap:6px;padding:4px 0;border-top:1px solid {SOFT}">{m}<div style="min-width:0"><div style="font-size:12px;color:{DIM if done else INK};line-height:1.25;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{t}</div></div></div>'
    a=min(e[1] for e in c); b=max(e[2] for e in c)
    return ab(x,y,f'<div style="width:{w}px;height:{h}px;box-sizing:border-box;border-radius:5px;background:{rgba(OR,.08)};border:1px solid {rgba(OR,.5)};padding:4px 7px;overflow:hidden"><div style="font:500 9px {MONO};color:{OR};letter-spacing:.08em;padding-bottom:2px">{len(c)} ДЕЛА · {int(a):02d}–{math.ceil(b):02d}</div>{"".join(line(e) for e in c)}</div>')
def grid_layer(EV,GX,CW,W,r0,r1,rh):
    H=rowh(EV,r0,r1,rh); tot=Yf(H,r0,r1); s=''
    for h in range(r0,r1):
        y=Yf(H,r0,h); bg='background:rgba(0,0,0,.18);' if (h<7 or h>=22) else ('background:rgba(240,160,75,.03);' if H[h]>rh else '')
        s+=ab(0,y,f'<div style="width:{W-14}px;height:{H[h]}px;border-top:1px solid {SOFT};{bg}"><span style="position:absolute;left:0;width:38px;text-align:center;top:3px;font:400 10px {MONO};color:{DIM}">{h:02d}</span></div>')
    for i in range(7): s+=ab(GX+i*CW,0,f'<div style="width:{CW}px;height:{tot}px;border-left:1px solid {SOFT};{"background:rgba(240,160,75,.035)" if i==3 else ""}"></div>')
    for d in range(6):
        a=max(r0,8); b=min(r1,17)
        if b>a:
            y0=Yf(H,r0,a); hh=Yf(H,r0,b)-y0
            s+=ab(GX+d*CW+1,y0,f'<div style="width:{CW-1}px;height:{hh}px;background:{rgba(GOLD,.06)};border-top:1px solid {rgba(GOLD,.5)};border-bottom:1px solid {rgba(GOLD,.5)};box-sizing:border-box"></div>')
            if d==0 or True: s+=ab(GX+d*CW+6,y0+3,f'<span style="font:500 8.5px {MONO};color:{GOLD};letter-spacing:.08em;white-space:nowrap;opacity:.85">РАБОТА 08–17</span>') if r0<=8 else ''
    for c in clusters(EV,r0,r1):
        d=c[0][0]; a=max(r0,min(e[1] for e in c)); b=min(r1,max(e[2] for e in c))
        y0=Yf(H,r0,a)+1; hh=Yf(H,r0,b)-Yf(H,r0,a)-3
        if len(c)>1: s+=stackblk(GX+d*CW+4,y0,CW-8,hh,c)
        else:
            _,a1,b1,t,col,k,done=c[0]
            s+=blk(GX+d*CW+4,y0,CW-8,max(22,hh),t,f'{int(a1):02d}:{int(a1%1*60):02d}',col,k,done)
    for c in clusters(EV,r0,r1):
        if len(c)>1 and c[0][0]==3:
            y0=Yf(H,r0,12)+10; x=GX+4*CW-10
            s+=ab(x,y0,f'<div style="width:250px;background:{NODE};border:1px solid {LINE};border-radius:8px;box-shadow:0 10px 28px rgba(0,0,0,.55);overflow:hidden;z-index:5;position:relative"><div style="height:3px;background:{OR}"></div><div style="padding:10px 12px;display:flex;flex-direction:column;gap:6px"><div style="font-size:13.5px;font-weight:600;color:{INK}">Текстуры для щита, 2K</div><div style="font:400 10.5px {MONO};color:{MUT}">ЧТ 19 НОЯ · 11:00–13:00 · 2 Ч</div><div style="font:500 9.5px {MONO};color:{OR};letter-spacing:.08em">РАБОТА · ЗАКАЗ «ТАВЕРНА»</div><div style="font-size:12px;color:#C9CAD0;line-height:1.45;border-top:1px solid {SOFT};padding-top:6px">Запечь AO с хайполи, металл потёртый по краям. Отдать до 18:00.</div></div></div>')
            s+=ab(x-14,y0+16,f'<svg width="18" height="14" fill="none"><path d="M2 2 L4 12 L7 9 L11 13 L13 11 L9 7 L12 5 Z" fill="{INK}" stroke="#000" stroke-width="1"/></svg>')
    ny=Yf(H,r0,9.5); s+=ab(GX+3*CW,ny,f'<div style="width:{CW}px;border-top:1.5px solid {OR}"></div>')
    return '<div style="position:relative">'+s+'</div>',tot
