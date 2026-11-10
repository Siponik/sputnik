# Шапка без рамки Windows: свои кнопки окна, логотип, отдельная кнопка настроек. Запуск последним: python3 s_win.py
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

def big(st, maxed=False):
    return f'<div style="display: flex; justify-content: flex-end; padding: 14px; background: {BG}; border-radius: 10px; border: 1px solid {LINE}">{winctl(st, maxed)}</div>'

cases = [('ОБЫЧНО', {}, False, 'Значки серые, без фона.'),
         ('НАВЕДЕНИЕ', {'min': 'hover'}, False, 'Фон #2C2D33, значок светлый.'),
         ('ЗАКРЫТЬ · НАВЕДЕНИЕ', {'close': 'close'}, False, 'Только у ✕ — красный #E5484D, значок белый.'),
         ('РАЗВЁРНУТО', {}, True, 'Вместо квадрата — два квадрата «Восстановить».')]
st = ab(0, 0, f'<div style="display: flex; gap: 12px; align-items: center">{lbl("ОКНО БЕЗ РАМКИ WINDOWS", INK)}{micro("СВОИ КНОПКИ ОКНА В ШАПКЕ · ЛОГОТИП · НАСТРОЙКИ ОТДЕЛЬНО", MUT)}</div>', w=1248)
for i, (t, s, m, d) in enumerate(cases):
    x = i * 318
    st += node(x, 40, 296, 0, nhead('', t, '', GREY, None, 30) + f'<div style="padding: 14px">{big(s, m)}<div style="margin-top: 10px; font-size: 12.5px; line-height: 18px; color: #C9CAD0">{d}</div></div>')
rules = [('Кнопки', '34×32, скругление 8, значки 11 px, отделены от «Создать» вертикальной линией. Справа без отступа до края — 20 px, как у всей шапки.'),
         ('Тянуть окно', 'За любое пустое место шапки. Двойной клик по шапке — развернуть / восстановить.'),
         ('Края', 'Окно тянется за края и углы (полоса 6 px). Win+← → ↑ и привязка к краям экрана работают как у обычного окна.'),
         ('Клавиши', 'Ctrl+W или Alt+F4 — закрыть (в трей, если включено), Win+↓ — свернуть.'),
         ('Настройки', 'Отдельная кнопка-шестерёнка справа от «Состояния» (три точки). «Состояние» — только поповер со связью, синхронизацией и ботом. Ctrl+, — то же, что шестерёнка.'),
         ('Логотип', 'Знак из прежней версии: дуга-«С» цвета акцента, белое ядро и спутник. Только знак, без надписи: название в шапке ничего не даёт. Подсказка «Спутник» при наведении.')]
rw = ''.join(f'<div style="display: flex; gap: 14px; padding: 9px 0; border-bottom: 1px solid {SOFT}"><span style="width: 150px; flex: none; font-weight: 600">{a}</span><span style="color: #C9CAD0; line-height: 19px">{b}</span></div>' for a, b in rules)
st += node(0, 226, 820, 0, nhead('', 'КАК РАБОТАЕТ', '', OR, None, 30) + f'<div style="padding: 4px 16px 8px">{rw}</div>')
st += node(844, 226, 404, 0, nhead('', 'ЗНАК', '', OR, None, 30) + f'<div style="padding: 22px; display: flex; gap: 22px; align-items: center">{LOGO.replace("width=\"22\" height=\"22\"", "width=\"84\" height=\"84\"")}<div>{LOGO}<div style="margin-top: 10px">{micro("22 PX В ШАПКЕ", MUT)}</div></div></div>')
save2('G_Window.dc.html', page('Окно без рамки', 'СЕГОДНЯ', st), 'Окно без рамки Windows: кнопки, логотип, настройки')
print('ok win')
