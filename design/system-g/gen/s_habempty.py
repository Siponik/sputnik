from s_calhelp import *
def orbit(sz=120):
    return f'<svg width="{sz}" height="{sz}" viewBox="0 0 120 120" fill="none"><circle cx="60" cy="60" r="44" stroke="{rgba(GOLD,.35)}" stroke-dasharray="3 5"/><circle cx="60" cy="60" r="28" stroke="{rgba(GOLD,.2)}"/><circle cx="60" cy="60" r="9" fill="{rgba(GOLD,.25)}" stroke="{GOLD}" stroke-width="1.5"/><rect x="97" y="40" width="10" height="10" rx="2" transform="rotate(20 102 45)" stroke="{GOLD}" stroke-width="1.5" fill="{NODE}"/></svg>'
def tpl(name,sub):
    return f'<div style="flex:1;border:1px dashed {rgba(GOLD,.5)};border-radius:8px;padding:10px 12px;display:flex;gap:10px;align-items:center;background:{rgba(GOLD,.04)}"><span style="width:10px;height:10px;border-radius:2px;border:1.5px solid {GOLD};flex:none"></span><div><div style="font-size:13px;color:{INK}">{name}</div><div style="font:400 10px {MONO};color:{MUT};margin-top:2px">{sub}</div></div><span style="margin-left:auto;font-size:16px;color:{GOLD}">＋</span></div>'
inner=nhead('','ПРИВЫЧКИ · СЕГОДНЯ','0',GOLD,MUT,34,INK,GOLD)+f'''<div style="display:flex;flex-direction:column;align-items:center;padding:34px 40px 30px;gap:14px">
{orbit()}
<div style="font-size:20px;font-weight:600;color:{INK}">Пока ни одной привычки</div>
<div style="font-size:13px;color:#C9CAD0;text-align:center;max-width:430px;line-height:1.5">Привычка — дело, которое повторяется. Спутник считает серии дней и показывает их в календаре.</div>
<div style="margin-top:6px;height:42px;padding:0 22px;border-radius:9px;background:{GOLD};color:#1A1B1F;display:flex;align-items:center;gap:10px;font-size:14px;font-weight:600;box-shadow:0 0 0 4px {rgba(GOLD,.15)}">＋ Завести первую привычку <span style="font:500 10px {MONO};opacity:.7">N</span></div>
<div style="margin-top:14px;font:500 9.5px {MONO};letter-spacing:.14em;color:{MUT}">ИЛИ ВЗЯТЬ ГОТОВУЮ</div>
<div style="display:flex;gap:10px;width:100%">{tpl("Зарядка","КАЖДЫЙ ДЕНЬ · 08:00")}{tpl("Вода","8 СТАКАНОВ В ДЕНЬ")}{tpl("Чтение","20 МИН · ВЕЧЕРОМ")}</div>
</div>'''
st=node(164,10,920,0,inner,hub=True)
st+=ab(164,530,f'<div style="font-size:12.5px;color:#C9CAD0;line-height:1.5;width:920px"><b>Привычек нет.</b> Вместо пустой строки ввода — нода по центру: знак орбиты в цвете привычек (GOLD), заголовок, одна фраза, крупная кнопка GOLD «Завести первую привычку» (открывает «Создать» на вкладке «Привычка», хоткей N) и три готовые привычки пунктиром — клик создаёт сразу, потом можно поправить. «Отметить все» и шапка «СЕГОДНЯ» в пустом состоянии не показываются. Как только есть одна привычка — обычный экран со строкой «＋ Новая привычка» внизу списка.</div>')
save2('G_HabitsEmpty.dc.html',page('Привычки · пусто','ПРИВЫЧКИ',st,right='ЧТ 19.11 · 09:30',stage_h=620),'Привычки · пусто')
