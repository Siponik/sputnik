import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from s_icons import svg_
from s_board import sidebar

# Конвейер и Список — по тому, как они уже сделаны в приложении (rust/app/ui/board.slint)
W = 1012; X = 236

def tbar(name, color, view, extra=''):
    vs = ''.join(f'<span style="padding: 0 10px; height: 26px; display: inline-flex; align-items: center; border-radius: 5px; font: 500 10px {MONO}; letter-spacing: 1.2px; {"background: " + INK + "; color: #1C1D21" if v == view else "color: " + MUT}">{v}</span>' for v in ["КАНБАН", "КОНВЕЙЕР", "СТИКЕРЫ", "СПИСОК"])
    inner = f'<div style="height: 100%; display: flex; align-items: center; gap: 12px; padding: 0 12px">{dot(color, 8)}<span style="font-weight: 600; font-size: 15px">{name}</span><span style="color: {DIM}">⋯</span>{extra}<span style="flex: 1"></span><span style="display: inline-flex; gap: 2px; padding: 2px; border: 1px solid {LINE}; border-radius: 7px">{vs}</span></div>'
    return node(X, 0, W, 48, inner)

STAGES = ["Скетч", "Блокинг", "Хайполи", "Ретопо", "Текстуры", "Сдача"]

def chip(t, s):  # 0 пройден, 1 сейчас, 2 впереди
    if s == 1: st = f'background: {OR}; color: #1C1D21; font-weight: 600'
    elif s == 0: st = f'background: #2C3A2F; border: 1px solid #3F6B47; color: {GREEN}'
    else: st = f'border: 1px solid #4A4B52; color: #62646E'
    ic = f'<span style="display: grid">{svg_("check", 10)}</span>' if s == 0 else ''
    return f'<span style="flex: 1; min-width: 0; height: 30px; box-sizing: border-box; border-radius: 6px; display: flex; align-items: center; justify-content: center; gap: 4px; font-size: 12.5px; white-space: nowrap; overflow: hidden; {st}">{ic}{t}</span>'

def thumb(c='#3A2E22'):
    return f'<span style="width: 50px; height: 50px; flex: none; border-radius: 6px; background: {c}; border: 1px solid #4A3A2A; display: grid; place-items: center; color: #8A6A48">{svg_("image", 20)}</span>'

def prow(title, meta, stage, due, nxt, overdue=False, done=False, open_=False):
    chips = ''.join(chip(s, 0 if done or i < stage else 1 if i == stage else 2) for i, s in enumerate(STAGES))
    nb = '' if done else f'<span style="width: 104px; height: 32px; flex: none; border-radius: 8px; box-sizing: border-box; display: flex; align-items: center; justify-content: center; gap: 4px; font-size: 13px; font-weight: 600; {"background: " + OR + "; color: #1C1D21" if open_ else "border: 1px solid #55575F"}">{nxt} →</span>'
    head = (f'<div style="height: 62px; display: flex; align-items: center; gap: 12px; padding: 0 14px 0 12px">'
            f'<span style="color: {MUT}; font-size: 10px; width: 10px">{"▴" if open_ else "▾"}</span>'
            f'<div style="width: 200px; flex: none"><div style="font-size: 14.5px; font-weight: 600; color: {"#62646E" if done else INK}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{title}</div><div style="font-size: 12px; color: {MUT}; margin-top: 3px">{meta}</div></div>'
            f'<div style="flex: 1; display: flex; gap: 4px; min-width: 0">{chips}</div>'
            f'<span style="width: 60px; text-align: right; font-size: 13px; color: {RED if overdue else OR}">{due}</span>{nb}</div>')
    body = ''
    if open_:
        subs = ''.join(f'<div style="height: 30px; display: flex; align-items: center; gap: 10px"><span style="width: 14px; height: 14px; box-sizing: border-box; border-radius: 3px; {"background: #45464D" if d else "border: 1px solid #8A8C96"}; display: grid; place-items: center; color: {INK}">{svg_("check", 9) if d else ""}</span><span style="font-size: 13px; color: {"#62646E" if d else INK}">{t}</span></div>' for t, d in [("Силуэт и пропорции", True), ("Крупные формы шлема", True), ("Наплечники", False), ("Проверка в позе", False)])
        subs += f'<div style="height: 34px; margin-top: 4px; border-radius: 8px; border: 1px solid #55575F; display: flex; align-items: center; padding: 0 10px; font-size: 12.5px; color: {DIM}">+ Подзадача этапа… Enter — добавить</div>'
        det = '<div style="display: flex; gap: 24px">' + ''.join(f'<div style="height: 30px; display: flex; align-items: center; gap: 10px"><span style="font-size: 13px; color: {GREY}">{k}</span>{v}</div>' for k, v in [
            ("Срок", f'<span style="padding: 5px 12px; border-radius: 8px; border: 1px solid {ORL}; font-size: 13px">пт 20 ноя</span>'),
            ("Приоритет", ''.join(f'<span style="width: 34px; height: 28px; margin-right: 6px; border-radius: 8px; box-sizing: border-box; display: inline-grid; place-items: center; font: 400 12px {MONO}; {"border: 1px solid " + OR + "; background: " + WASH if p == "!!" else "border: 1px solid " + LINE}">{p}</span>' for p in ["!!!", "!!", "!"]))]) + '</div>'
        det += (f'<div style="margin-top: 12px; height: 150px; box-sizing: border-box; border-radius: 8px; border: 1px solid {LINE}; background: {BG}; display: flex; flex-direction: column">'
                f'<div style="height: 28px; display: flex; align-items: center; gap: 10px; padding: 0 10px; border-bottom: 1px solid {SOFT}; font-size: 12px; color: {MUT}">Заметка<span style="font: 400 10px {MONO}; color: {DIM}">MARKDOWN</span><span style="flex: 1"></span><span>↗ из Знаний</span><span>⤢</span></div>'
                f'<div style="flex: 1; padding: 8px 10px; font-size: 13px; line-height: 1.5">Броня в стиле «Кузни»: тяжёлая, потёртая.<br><span style="color: {MUT}">— наплечники крупнее, как на рефе 3</span><br><span style="color: {OR}">[[Референсы Кузня]]</span></div></div>')
        body = (f'<div style="position: relative; height: 274px">'
                f'<div style="position: absolute; left: 40px; top: 16px; width: 440px"><div style="font-size: 13px; font-weight: 600; margin-bottom: 12px">Этап «Блокинг»</div>{subs}</div>'
                f'<div style="position: absolute; left: 520px; right: 20px; top: 12px">{det}</div>'
                f'<div style="position: absolute; left: 0; right: 0; top: 220px; height: 54px; border-top: 1px solid {LINE}; display: flex; align-items: center; gap: 16px; padding: 0 20px 0 40px"><span style="font-size: 12.5px; color: {GREY}">← Скетч</span><span style="flex: 1"></span><span style="font: 400 10px {MONO}; color: {MUT}">ESC СВЕРНУТЬ &nbsp; ENTER ОКНО ЗАДАЧИ</span><span style="font-size: 12.5px; color: {OR}">Открыть полностью ↗</span></div></div>')
    return f'<div style="position: relative; border-radius: 8px; background: {NODE}; border: 1px solid {ORL if open_ else LINE}">{head}{body}</div>'

def grp(name, info):
    return f'<div style="height: 22px; display: flex; align-items: center; gap: 8px"><span style="width: 6px; height: 6px; border-radius: 2px; background: {OR}"></span><span style="font-size: 13px; font-weight: 600">{name}</span><span style="font-size: 12px; color: {MUT}">{info}</span></div>'

rows = (grp("В работе", "3 ассета") + prow("Броня «Кузня»", "3D", 1, "ПТ 20", "Хайполи", open_=True)
        + prow("Меч рыцаря", "3D", 3, "ВТ 17", "Текстуры", overdue=True) + prow("Сундук", "для портфолио", 0, "—", "Блокинг")
        + grp("Сдано", "2 за неделю") + prow("Щит v1", "3D", 5, "ПН 09", "", done=True))
rows += f'<div style="height: 40px; border-radius: 8px; border: 1px solid #55575F; display: flex; align-items: center; padding: 0 12px; font-size: 13px; color: {DIM}">+ Новый ассет · Enter</div>'
st = sidebar('3D-ассеты') + tbar('3D-ассеты', OR, 'КОНВЕЙЕР') + ab(X, 64, f'<div style="display: flex; flex-direction: column; gap: 8px">{rows}</div>', w=W)
save2('G_Conveyor.dc.html', page('Доска · конвейер', 'ДОСКА', st), 'Доска · конвейер')

# ---------- СПИСОК ----------
def lrow(t, tag='', prio=False, sub=None, due='—', over=False):
    pr = f'<span style="width: 60px; font: 600 12px {MONO}; color: {OR}">&#33;&#33;</span>' if prio else ''
    s = ''
    if sub: s = f'<span style="width: 90px; height: 3px; border-radius: 2px; background: #45464D; position: relative"><span style="position: absolute; left: 0; top: 0; height: 3px; width: {90 * sub[0] // sub[1]}px; border-radius: 2px; background: {VIO}"></span></span><span style="width: 76px; font: 400 10px {MONO}; letter-spacing: 1.2px; color: {MUT}">УРОК {sub[0]}/{sub[1]}</span>'
    return (f'<div style="height: 45px; display: flex; align-items: center; gap: 10px; padding: 0 14px 0 12px; border-bottom: 1px solid {SOFT}">'
            f'<span style="width: 14px; height: 14px; box-sizing: border-box; border-radius: 3px; border: 1px solid #8A8C96; margin-right: 2px"></span>'
            f'<span style="font-size: 13.5px">{t}</span>{f"<span style=\'font-size: 12px; color: {MUT}\'>{tag}</span>" if tag else ""}<span style="flex: 1"></span>'
            f'{pr}{s}'
            f'<span style="width: 110px; text-align: right; font: 400 10.5px {MONO}; letter-spacing: 1.2px; color: {RED if over else MUT}">{due}</span></div>')

def sec(n, c):
    return f'<div style="height: 34px; display: flex; align-items: center; gap: 8px; padding-left: 14px"><span style="width: 6px; height: 6px; border-radius: 3px; background: {c}"></span><span style="font-size: 13px; color: {GREY}">{n}</span></div>'

lb = (sec("Сейчас", OR) + lrow("Курс по Substance", "онлайн", True, (4, 12), "ПН 23") + lrow("Анатомия: кисти рук", "", False, (2, 8), "СР 18")
      + sec("Потом", GREY) + lrow("Прочитать «Цвет и свет»", "книга") + lrow("Блендер: геометрические ноды", "", False, None, "ВТ 10", True) + lrow("Скульпт лица — практика")
      + f'<div style="height: 44px; display: flex; align-items: center; gap: 8px; padding-left: 16px; font-size: 13px; color: {GREY}">+ Добавить задачу<span style="width: 18px; height: 18px; box-sizing: border-box; border-radius: 3px; border: 1px solid #55575F; display: grid; place-items: center; font: 400 9px {MONO}; color: {MUT}">N</span></div>')
lv = (f'<div style="height: 36px; background: #9A5A22; display: flex; align-items: center; padding: 0 12px; font: 600 10.5px {MONO}; letter-spacing: 1.5px; color: #fff">УЧЁБА · ВСЕ ЗАДАЧИ<span style="flex: 1"></span><span style="font-weight: 400; color: #ffffffd0">5 ОТКРЫТО</span></div>' + lb)
st = sidebar('Учёба') + tbar('Учёба', VIO, 'СПИСОК') + node(X, 64, W, 0, lv, hub=True, style='overflow: hidden')
save2('G_ListView.dc.html', page('Вид «Список»', 'ДОСКА', st), 'Доска · вид «Список»')
