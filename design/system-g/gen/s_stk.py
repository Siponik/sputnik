import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
from s_board import sidebar
from s_pipe import tbar, X, W

# Стикеры — по тому, как сделано в приложении (rust/app/ui/board.slint, Stickers)
def mix(a, b, f):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]; b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x * f + y * (1 - f)):02X}' for x, y in zip(a, b))

def stk(t, hue, due, pin=False, done=False, over=False, h=118):
    tone = mix(hue, '#1C1D21', .17); ink = mix(hue, '#FFFFFF', .45)
    top = (f'<span style="position: absolute; left: 112px; top: 0; width: 12px; height: 12px; border-radius: 6px; background: {RED}"></span>' if pin
           else f'<span style="position: absolute; left: 91px; top: 0; width: 54px; height: 12px; background: rgba(255,255,255,.15); border-radius: 1px"></span>')
    ck = f'<span style="width: 18px; height: 18px; box-sizing: border-box; border-radius: 9px; border: 1.5px solid {ink}; {"background: " + ink + "; color: " + tone if done else ""}; display: grid; place-items: center">{svg_("check", 10) if done else ""}</span>'
    return (f'<div style="position: relative; height: {h}px">'
            f'<div style="position: absolute; left: 0; right: 0; top: 6px; bottom: 0; border-radius: 4px; background: {tone}; {"border: 2px solid " + OR + ";" if pin else ""} box-shadow: 0 4px 10px rgba(0,0,0,.4); opacity: {.55 if done else 1}; box-sizing: border-box">'
            f'<div style="padding: 20px 14px 0; font-size: 14.5px; font-weight: 500; line-height: 1.3; color: {ink}; {"text-decoration: line-through" if done else ""}">{t}</div>'
            f'<div style="position: absolute; left: 14px; right: 10px; bottom: 14px; display: flex; align-items: center; gap: 10px">{ck}<span style="font-size: 12px; color: {"#FFB3A3" if over else ink}; opacity: {1 if over else .75}">{due}</span><span style="flex: 1"></span>{"<span style=\'display: grid; color: " + ink + "\'>" + svg_("pin", 12) + "</span>" if pin else ""}</div></div>{top}</div>')

def lane(n, hue, cards):
    return (f'<div style="width: 236px; display: flex; flex-direction: column; gap: 12px">'
            f'<div style="height: 22px; display: flex; align-items: center; gap: 8px"><span style="width: 7px; height: 7px; border-radius: 2px; background: {hue}"></span><span style="font-size: 13px; font-weight: 600">{n}</span><span style="font: 400 11px {MONO}; color: {MUT}">{len(cards)}</span></div>'
            + ''.join(cards) + f'<div style="height: 46px; box-sizing: border-box; border-radius: 4px; border: 1px solid #55575F; display: flex; align-items: center; padding: 0 12px; font-size: 13px; color: {DIM}">+ Стикер</div></div>')

lanes = (lane("Дом", GREEN, [stk("Позвонить сантехнику про кран", GREEN, "сегодня", pin=True), stk("Разобрать балкон", GREEN, "сб 21")])
         + lane("Покупки", GOLD, [stk("Лампочки E27", GOLD, "без срока"), stk("Подарок маме", GOLD, "вт 17", over=True), stk("Корм коту", GOLD, "вчера", done=True)])
         + lane("Здоровье", BLUE, [stk("Записаться к стоматологу", BLUE, "до пт 20")])
         + lane("Разное", VIO, []))
cols = ["#F0C56A", "#8FD19A", "#9DB8F5", "#F0A87A", "#C9A8F0"]
dots = ''.join(f'<span style="position: absolute; left: {8 + (i % 3) * 18}px; bottom: {8 + (i // 3) * 18}px; width: 14px; height: 14px; border-radius: 3px; background: {cols[i % 5]}"></span>' for i in range(7))
jar = (f'<div style="width: 494px; height: 124px; box-sizing: border-box; border-radius: 8px; background: {NODE}; border: 1px solid {LINE}; position: relative">'
       f'<div style="position: absolute; left: 16px; top: 14px; width: 70px; height: 92px; box-sizing: border-box; border-radius: 8px; background: {HOVER}; border: 2px solid #55575F"><span style="position: absolute; left: 4px; right: 4px; top: -4px; height: 6px; border-radius: 2px; background: #55575F"></span>{dots}</div>'
       f'<div style="position: absolute; left: 102px; top: 20px; right: 16px"><div style="font-size: 14px; font-weight: 600">Баночка · 7 за неделю</div><div style="margin-top: 6px; font-size: 12.5px; color: {GREY}">Последнее: «Корм коту», вчера</div><div style="margin-top: 18px; font-size: 12.5px; color: {OR}">Открыть баночку</div></div></div>')
seg2 = f'<span style="display: inline-flex; gap: 2px; padding: 2px; border: 1px solid {LINE}; border-radius: 7px">' + ''.join(f'<span style="padding: 0 10px; height: 24px; display: inline-flex; align-items: center; border-radius: 5px; font: 500 10px {MONO}; letter-spacing: 1.2px; {"background: " + INK + "; color: #1C1D21" if i == 0 else "color: " + MUT}">{t}</span>' for i, t in enumerate(["ПО ТЕМАМ", "ПО СРОКАМ"])) + '</span>'
body = f'<div style="display: flex; flex-direction: column; gap: 16px"><div style="display: flex; gap: 22px; align-items: flex-start">{lanes}</div><div style="padding-left: 516px">{jar}</div></div>'
st = sidebar('Дела по дому') + tbar('Дела по дому', GREEN, 'СТИКЕРЫ', seg2) + ab(X, 64, body, w=W)
save2('G_Stickers.dc.html', page('Доска · стикеры', 'ДОСКА', st), 'Доска · стикеры')
