"""Маленькие 2D-спрайты енота для колонок доски: 3 стиля × 3 места (над заголовком, сбоку из-за карточки, хвост снизу)."""
import sys

EAR_L = 'M-27 -12C-30 -24 -27 -34 -22 -38C-14 -34 -8 -28 -5 -21Z'
EAR_IN = 'M-23 -17C-25 -24 -24 -30 -21 -33C-16 -30 -12 -26 -10 -21Z'
HEAD = 'M0 -27C18 -27 30 -15 30 1C30 17 17 27 0 27C-17 27 -30 17 -30 1C-30 -15 -18 -27 0 -27Z'
MASK = 'M-29 0C-25 -11 -13 -13 -5 -7L0 -4L5 -7C13 -13 25 -11 29 0C24 9 12 9 6 6L0 3L-6 6C-12 9 -24 9 -29 0Z'
MUZZLE = 'M0 4C9 4 14 9 14 14C14 20 8 25 0 25C-8 25 -14 20 -14 14C-14 9 -9 4 0 4Z'
NOSE = 'M-4 8.5C-4 6 4 6 4 8.5C4 10.5 2 12 0 12C-2 12 -4 10.5 -4 8.5Z'
TAIL = 'M0 0C2 14 -6 26 -2 40C1 50 8 54 10 62'

STYLES = {
    'color': dict(name='Цветной', fur='#A7A196', furd='#7C776E', mask='#34312D', cream='#F3EEE4', ear='#E9A994', eye='#141210', line=None),
    'mono': dict(name='Монотонный', fur='currentColor', furd='currentColor', mask='currentColor', cream='var(--bg)', ear='var(--bg)', eye='var(--bg)', line=None),
    'sketch': dict(name='Скетч', fur='none', furd='none', mask='none', cream='none', ear='none', eye='currentColor', line='currentColor'),
}

def mir(s):
    return f'<g transform="scale(-1 1)">{s}</g>'

def head(st, sid, look=0, closed=False):
    """Голова в локальных координатах (центр 0,0, ширина ~60)."""
    if st == 'sketch':
        L = 'currentColor'
        a = f'stroke="{L}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none"'
        hatch = f'url(#{sid}-hatch)'
        ear = f'<path d="{EAR_L}" {a}></path><path d="M-22 -19C-23 -24 -22 -28 -20.5 -30" {a} opacity=".7"></path>'
        return (f'<g filter="url(#{sid}-rough)">{ear}{mir(ear)}'
                f'<path d="{HEAD}" {a.replace(chr(34)+"none"+chr(34), chr(34)+"var(--bg)"+chr(34))}></path>'
                f'<path d="{HEAD}" {a} transform="translate(.8 .6)" opacity=".45"></path>'
                f'<path d="{MASK}" fill="{hatch}" {a.replace("fill=\"none\"", "")}></path>'
                f'<path d="{MUZZLE}" {a} opacity=".85"></path>'
                f'<path d="{NOSE}" fill="currentColor" stroke="none"></path>'
                f'<circle cx="{-12+look}" cy="-2" r="3.4" fill="var(--bg)" {a.replace("fill=\"none\"", "")}></circle><circle cx="{-11.4+look}" cy="-1.6" r="1.6" fill="currentColor"></circle>'
                f'<circle cx="{12+look}" cy="-2" r="3.4" fill="var(--bg)" {a.replace("fill=\"none\"", "")}></circle><circle cx="{12.6+look}" cy="-1.6" r="1.6" fill="currentColor"></circle>'
                f'<path d="M-4 16.5C-2 18.5 2 18.5 4 16.5" {a}></path></g>')
    c = STYLES[st]
    ear = f'<path d="{EAR_L}" fill="{c["fur"]}"></path><path d="{EAR_IN}" fill="{c["ear"]}"></path>'
    eyes = ''
    for x in (-12, 12):
        if st == 'color':
            eyes += (f'<circle cx="{x+look}" cy="-2" r="4.2" fill="{c["eye"]}"></circle>'
                     f'<circle cx="{x+look+1.4}" cy="-3.6" r="1.4" fill="#fff"></circle>')
        else:
            eyes += f'<circle cx="{x+look}" cy="-2" r="3.4" fill="var(--bg)"></circle><circle cx="{x+look+.6}" cy="-1.6" r="1.7" fill="currentColor"></circle>'
    shade = f'<path d="M-30 1C-30 17 -17 27 0 27C17 27 30 17 30 1C26 16 14 22 0 22C-14 22 -26 16 -30 1Z" fill="#000" opacity=".1"></path>' if st == 'color' else ''
    mouth_c = '#2A2724' if st == 'color' else 'currentColor'
    fo = ' fill-opacity=".42"' if st == 'mono' else ''
    ear = ear.replace(f'fill="{c["fur"]}"', f'fill="{c["fur"]}"{fo}')
    return (f'{ear}{mir(ear)}<path d="{HEAD}" fill="{c["fur"]}"{fo}></path>'
            f'<path d="M0 -21C2.4 -16 2.8 -10 1.8 -5H-1.8C-2.8 -10 -2.4 -16 0 -21Z" fill="{c["mask"]}" opacity="{".45" if st == "color" else "1"}"></path>'
            f'<path d="{MASK}" fill="{c["mask"]}"></path>{eyes}'
            f'<path d="{MUZZLE}" fill="{c["cream"]}"></path>{shade}'
            f'<path d="{NOSE}" fill="{"#2A2724" if st == "color" else "currentColor"}"></path>'
            f'<path d="M-4 16.5C-2 18.5 2 18.5 4 16.5" fill="none" stroke="{mouth_c}" stroke-width="1.6" stroke-linecap="round"></path>'
            + (f'<ellipse cx="-19" cy="10" rx="4" ry="2.3" fill="#F29A80" opacity=".5"></ellipse><ellipse cx="19" cy="10" rx="4" ry="2.3" fill="#F29A80" opacity=".5"></ellipse>' if st == 'color' else ''))

def head_closed(st, sid):
    h = head(st, sid)
    import re as _re
    col = {'color': '#F3EEE4', 'mono': 'var(--bg)', 'sketch': 'currentColor'}[st]
    arcs = ''.join(f'<path d="M{x-4} -2.5C{x-2.5} 0.5 {x+2.5} 0.5 {x+4} -2.5" fill="none" stroke="{col}" stroke-width="1.8" stroke-linecap="round"></path>' for x in (-12, 12))
    h = _re.sub(r'<circle cx="-?1[12](\.\d+)?" cy="-[\d.]+" r="[\d.]+"[^>]*></circle>', '', h)
    h = _re.sub(r'<circle cx="(-?1[1-3](\.\d+)?)" cy="-[\d.]+"[^>]*></circle>', '', h)
    return h.replace(f'<path d="{MUZZLE}"', arcs + f'<path d="{MUZZLE}"', 1)

def paw(st, x, y, sid):
    if st == 'sketch':
        return f'<g filter="url(#{sid}-rough)"><ellipse cx="{x}" cy="{y}" rx="6" ry="4" fill="var(--bg)" stroke="currentColor" stroke-width="1.6"></ellipse><path d="M{x-2} {y-3.5}V{y-1}M{x+2} {y-3.5}V{y-1}" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"></path></g>'
    c = STYLES[st]
    col = '#34312D' if st == 'color' else 'currentColor'
    return f'<ellipse cx="{x}" cy="{y}" rx="6" ry="4.2" fill="{col}"></ellipse>' + (f'<ellipse cx="{x-1.6}" cy="{y-1.4}" rx="1.8" ry="1" fill="#fff" opacity=".3"></ellipse>' if st == 'color' else f'<path d="M{x-2} {y-3.6}V{y-1.4}M{x+2} {y-3.6}V{y-1.4}" stroke="var(--bg)" stroke-width="1.1" stroke-linecap="round"></path>')

def defs(sid, st):
    if st != 'sketch':
        return ''
    return (f'<defs><filter id="{sid}-rough" filterUnits="userSpaceOnUse" x="-120" y="-120" width="300" height="300"><feTurbulence type="fractalNoise" baseFrequency=".06" numOctaves="2" seed="3"></feTurbulence>'
            f'<feDisplacementMap in="SourceGraphic" scale="1.8"></feDisplacementMap></filter>'
            f'<pattern id="{sid}-hatch" width="4" height="4" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><path d="M0 0V4" stroke="currentColor" stroke-width="1.3"></path></pattern></defs>')

def _peek_top_old(st, sid):
    """Выглядывает из-за верхнего края (заголовок колонки / карточка). Край — нижняя граница спрайта y=44."""
    return (f'<svg class="pk pk-top" viewBox="0 0 90 46" width="90" height="46" aria-hidden="true">{defs(sid, st)}'
            f'<clipPath id="{sid}-c"><rect x="0" y="0" width="90" height="44"></rect></clipPath>'
            f'<g clip-path="url(#{sid}-c)"><g class="pk-rise" transform="translate(45 33)">{head(st, sid)}</g></g>'
            f'{paw(st, 29, 41, sid)}{paw(st, 61, 41, sid)}</svg>')

def _peek_side_old(st, sid):
    """Подглядывает из-за правого края карточки. Край — левая граница спрайта x=0."""
    return (f'<svg class="pk pk-side" viewBox="0 0 46 70" width="46" height="70" aria-hidden="true">{defs(sid, st)}'
            f'<clipPath id="{sid}-c"><rect x="2" y="0" width="60" height="70"></rect></clipPath>'
            f'<g clip-path="url(#{sid}-c)"><g class="pk-lean" transform="translate(6 36) rotate(14)">{head(st, sid, look=2)}</g></g>'
            f'{paw(st, 3, 52, sid).replace("rx=\"6\" ry=\"4.2\"", "rx=\"4.2\" ry=\"6\"").replace("rx=\"6\" ry=\"4\"", "rx=\"4\" ry=\"6\"")}</svg>')

def _tail_old(st, sid):
    """Полосатый хвост свисает из-под нижнего края карточки. Край — верх спрайта y=0."""
    if st == 'color':
        body = (f'<path d="{TAIL}" fill="none" stroke="#A7A196" stroke-width="11" stroke-linecap="round"></path>'
                f'<path d="{TAIL}" fill="none" stroke="#34312D" stroke-width="11" stroke-dasharray="6 7" stroke-dashoffset="-6"></path>'
                f'<circle cx="10" cy="62" r="5.6" fill="#34312D"></circle>')
    elif st == 'mono':
        body = (f'<path d="{TAIL}" fill="none" stroke="currentColor" stroke-opacity=".42" stroke-width="11" stroke-linecap="round"></path>'
                f'<path d="{TAIL}" fill="none" stroke="currentColor" stroke-width="11" stroke-dasharray="6 7" stroke-dashoffset="-6"></path>'
                f'<circle cx="10" cy="62" r="5.6" fill="currentColor"></circle>')
    else:
        body = (f'<g filter="url(#{sid}-rough)"><path d="{TAIL}" fill="none" stroke="currentColor" stroke-width="12" stroke-linecap="round"></path>'
                f'<path d="{TAIL}" fill="none" stroke="var(--bg)" stroke-width="9" stroke-linecap="round"></path>'
                f'<path d="{TAIL}" fill="none" stroke="url(#{sid}-hatch)" stroke-width="9" stroke-dasharray="6 7" stroke-dashoffset="-6"></path></g>')
    return (f'<svg class="pk pk-tail" viewBox="-14 0 34 70" width="34" height="70" aria-hidden="true">{defs(sid, st)}'
            f'<g class="pk-swing" transform="translate(0 -2)">{body}</g></svg>')

CSS = """
.pk{display:block;overflow:visible}
.pk-swing{animation:pk-swing 3.4s ease-in-out infinite;transform-origin:0 0}
.pk-rise{animation:pk-rise 6s ease-in-out infinite}
.pk-lean{animation:pk-lean 7s ease-in-out infinite}
@keyframes pk-swing{0%,100%{transform:translate(0,-2px) rotate(0)}50%{transform:translate(0,-2px) rotate(7deg)}}
@keyframes pk-rise{0%,70%,100%{transform:translate(45px,33px)}78%,92%{transform:translate(45px,50px)}}
@keyframes pk-lean{0%,60%,100%{transform:translate(6px,36px) rotate(14deg)}70%,88%{transform:translate(-8px,36px) rotate(14deg)}}
@media (prefers-reduced-motion:reduce){.pk *{animation:none!important}}
"""


def sleeper(st, sid):
    """Спит, свернувшись клубком, в углу пустой колонки."""
    T = 'M74 40C82 50 70 56 50 56C32 56 18 54 14 47'
    if st == 'sketch':
        a = 'stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"'
        body = (f'<g filter="url(#{sid}-rough)"><ellipse cx="48" cy="40" rx="30" ry="15" fill="var(--bg)" {a}></ellipse>'
                f'<path d="{T}" fill="none" stroke="currentColor" stroke-width="11" stroke-linecap="round"></path><path d="{T}" fill="none" stroke="var(--bg)" stroke-width="8" stroke-linecap="round"></path>'
                f'<path d="{T}" fill="none" stroke="url(#{sid}-hatch)" stroke-width="8" stroke-dasharray="6 7"></path></g>')
    elif st == 'mono':
        body = (f'<ellipse cx="48" cy="40" rx="30" ry="15" fill="currentColor" fill-opacity=".42"></ellipse>'
                f'<path d="{T}" fill="none" stroke="currentColor" stroke-opacity=".42" stroke-width="10" stroke-linecap="round"></path>'
                f'<path d="{T}" fill="none" stroke="currentColor" stroke-width="10" stroke-dasharray="6 7" stroke-dashoffset="-3"></path>')
    else:
        body = (f'<ellipse cx="48" cy="40" rx="30" ry="15" fill="#A7A196"></ellipse><ellipse cx="50" cy="46" rx="24" ry="8" fill="#000" opacity=".1"></ellipse>'
                f'<path d="{T}" fill="none" stroke="#A7A196" stroke-width="10" stroke-linecap="round"></path>'
                f'<path d="{T}" fill="none" stroke="#34312D" stroke-width="10" stroke-dasharray="6 7" stroke-dashoffset="-3"></path>')
    zc = 'currentColor'
    z = ''.join(f'<text class="pk-z" x="{x}" y="{y}" style="animation-delay:{d}s;font:700 {f}px/1 sans-serif" fill="{zc}">z</text>' for x, y, f, d in ((36, 14, 8, 0), (43, 7, 10, .9)))
    return (f'<svg class="pk pk-sleep" viewBox="0 -4 92 64" width="92" height="64" aria-hidden="true">{defs(sid, st)}{body}'
            f'<g class="pk-breathe" transform="translate(24 36) rotate(-12) scale(.62)">{head_closed(st, sid)}</g>{z}</svg>')

CSS += """.pk-z{animation:pk-z 3s ease-in-out infinite;opacity:.2}
.pk-breathe{animation:pk-breathe 3.6s ease-in-out infinite}
@keyframes pk-z{0%,100%{opacity:.15;transform:translateY(0)}50%{opacity:1;transform:translateY(-3px)}}
@keyframes pk-breathe{0%,100%{transform:translate(24px,36px) rotate(-12deg) scale(.62)}50%{transform:translate(24px,35px) rotate(-12deg) scale(.63)}}
@media (prefers-reduced-motion:reduce){.pk *{animation:none!important;opacity:1}}
"""


# ───── правки скетча (20.10): лапки отдельно от мордочки, пушистый хвост ─────
import math as _m

def _bz(t, P=((0, 0), (5, 18), (-9, 40), (5, 60))):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = P
    u = 1 - t
    x = u**3*x0 + 3*u*u*t*x1 + 3*u*t*t*x2 + t**3*x3
    y = u**3*y0 + 3*u*u*t*y1 + 3*u*t*t*y2 + t**3*y3
    dx = 3*u*u*(x1-x0) + 6*u*t*(x2-x1) + 3*t*t*(x3-x2)
    dy = 3*u*u*(y1-y0) + 6*u*t*(y2-y1) + 3*t*t*(y3-y2)
    l = _m.hypot(dx, dy) or 1
    return x, y, -dy/l, dx/l

def _w(t):
    return 3.4 + 4.4 * _m.sin(_m.pi * min(1, t * 1.05)) ** .8 + (1.8 * (t - .75) / .25 if t > .75 else 0)

def _band(t0, t1, n=10):
    L, R = [], []
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / n
        x, y, nx, ny = _bz(t); w = _w(t)
        L.append((x + nx*w, y + ny*w)); R.append((x - nx*w, y - ny*w))
    pts = L + R[::-1]
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + 'Z'

def _tail_outline():
    L, R = [], []
    n = 40
    for i in range(n + 1):
        t = i / n
        x, y, nx, ny = _bz(t); w = _w(t)
        L.append((x + nx*w, y + ny*w)); R.append((x - nx*w, y - ny*w))
    xe, ye, nxe, nye = _bz(1.0); we = _w(1.0)
    # закруглённый пушистый кончик
    tip = f'C{L[-1][0]+2:.1f} {L[-1][1]+8:.1f} {R[-1][0]+2:.1f} {R[-1][1]+9:.1f} {R[-1][0]:.1f} {R[-1][1]:.1f}'
    d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in L) + ' ' + tip + ' L' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in R[::-1]) + 'Z'
    return d

def tail(st, sid):
    if st != 'sketch':
        return _tail_old(st, sid)
    out = _tail_outline()
    bands = ''.join(f'<path d="{_band(a, b)}" fill="currentColor" fill-opacity=".55" stroke="currentColor" stroke-width="1.2" stroke-linejoin="round"></path>' for a, b in ((.17, .28), (.42, .54), (.67, .79)))
    tipband = (f'<path d="{_band(.9, 1.0)}" fill="currentColor" fill-opacity=".8"></path>'
               f'<path d="M{_bz(1)[0]-5:.1f} {_bz(1)[1]:.1f}C{_bz(1)[0]-5:.1f} {_bz(1)[1]+8:.1f} {_bz(1)[0]+7:.1f} {_bz(1)[1]+8:.1f} {_bz(1)[0]+7:.1f} {_bz(1)[1]:.1f}Z" fill="currentColor" fill-opacity=".8"></path>')
    fluff = ''.join(f'<path d="M{x:.1f} {y:.1f}l{dx:.1f} {dy:.1f}" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"></path>'
                    for x, y, dx, dy in ((-6.5, 44, -2.4, 1.2), (8.5, 54, 2.4, .8), (-5, 28, -2.2, .4), (9, 63, 2, 1.6)))
    body = (f'<g filter="url(#{sid}-rough)"><path d="{out}" fill="var(--bg)" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"></path>'
            f'{bands}{tipband}<path d="{out}" fill="none" stroke="currentColor" stroke-width="1" opacity=".45" transform="translate(.9 .5)"></path>{fluff}</g>')
    return (f'<svg class="pk pk-tail" viewBox="-18 0 40 78" width="40" height="78" aria-hidden="true">{defs(sid, st)}'
            f'<g class="pk-swing">{body}</g></svg>')

def paw_sk(x, y, sid):
    # ореол цвета фона отделяет лапку от мордочки
    return (f'<g filter="url(#{sid}-rough)"><ellipse cx="{x}" cy="{y}" rx="7.6" ry="5.6" fill="var(--bg)"></ellipse>'
            f'<ellipse cx="{x}" cy="{y}" rx="6" ry="4.2" fill="var(--bg)" stroke="currentColor" stroke-width="1.6"></ellipse>'
            f'<path d="M{x-2.2} {y-3.6}V{y-1.2}M{x+2.2} {y-3.6}V{y-1.2}" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"></path></g>')

def peek_top(st, sid):
    if st != 'sketch':
        return _peek_top_old(st, sid)
    return (f'<svg class="pk pk-top" viewBox="0 0 100 50" width="100" height="50" aria-hidden="true">{defs(sid, st)}'
            f'<clipPath id="{sid}-c"><rect x="0" y="0" width="100" height="48"></rect></clipPath>'
            f'<g clip-path="url(#{sid}-c)"><g class="pk-rise2" transform="translate(50 40)">{head(st, sid)}</g></g>'
            f'{paw_sk(13, 47, sid)}{paw_sk(87, 47, sid)}</svg>')

def peek_side(st, sid):
    if st != 'sketch':
        return _peek_side_old(st, sid)
    return (f'<svg class="pk pk-side" viewBox="0 0 46 76" width="46" height="76" aria-hidden="true">{defs(sid, st)}'
            f'<clipPath id="{sid}-c"><rect x="2" y="0" width="60" height="76"></rect></clipPath>'
            f'<g clip-path="url(#{sid}-c)"><g class="pk-lean" transform="translate(6 36) rotate(14)">{head(st, sid, look=2)}</g></g>'
            f'</svg>')

CSS += """
.pk-rise2{animation:pk-rise2 6s ease-in-out infinite}
@keyframes pk-rise2{0%,70%,100%{transform:translate(50px,40px)}78%,92%{transform:translate(50px,52px)}}
"""
