"""Иконка приложения Спутник (Rust): знак «С» из орбиты со спутником, «Система G».
Пишет rust/assets/icon/: sputnik.svg (крупно), sputnik.png (256, значок окна),
sputnik.ico (16…256; до 32 px — без точек холста, чтобы знак не рябил).
Запуск из корня репозитория: python design/system-g/icon/gen.py [1|2|3]  (нужны cairosvg и Pillow).
Варианты: 1 — знак на графите (выбран), 2 — орбита-чертёж, 3 — янтарь.
"""
import io, math, os, struct, sys
import cairosvg
from PIL import Image

G = dict(ground='#191A1E', node='#25262B', line='#3A3B42', strong='#6E7079', ink='#E2E3E8',
         acc='#F0A04B', accink='#FFD29C', on='#2A1A0A')
OUT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'rust', 'assets', 'icon')
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def pt(a, r=150, c=256):
    return c + r * math.cos(math.radians(a)), c + r * math.sin(math.radians(a))


def arc_c(r=150):
    """Дуга-«С»: разрыв справа, как у знака в шапке (Brand.svelte)."""
    (x0, y0), (x1, y1) = pt(-40, r), pt(40, r)
    return f'M{x0:.1f} {y0:.1f} A{r} {r} 0 1 0 {x1:.1f} {y1:.1f}'


def tile(fill, stroke):
    return f'<rect x="16" y="16" width="480" height="480" rx="112" fill="{fill}" stroke="{stroke}" stroke-width="10"/>'


def dots(op, small):
    if small:
        return ''
    return ''.join(f'<circle cx="{x}" cy="{y}" r="5" fill="#fff" fill-opacity="{op}"/>'
                   for x in range(64, 512, 64) for y in range(64, 512, 64))


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">{body}</svg>'


def v1(small=False):
    sx, sy = pt(-40)
    return svg(f'''{tile(G['ground'], G['line'])}{dots(0.10, small)}
<path d="{arc_c()}" fill="none" stroke="{G['acc']}" stroke-width="48" stroke-linecap="round"/>
<circle cx="256" cy="256" r="64" fill="{G['ink']}"/>
<circle cx="{sx:.1f}" cy="{sy:.1f}" r="60" fill="{G['ground']}"/>
<circle cx="{sx:.1f}" cy="{sy:.1f}" r="40" fill="{G['accink']}"/>''')


def v2(small=False):
    sx, sy = pt(-45, 168)
    (ax, ay), (bx, by) = pt(-25, 168), pt(100, 168)
    ticks = ''.join(
        f'<line x1="{pt(a, 190)[0]:.1f}" y1="{pt(a, 190)[1]:.1f}" x2="{pt(a, 214)[0]:.1f}" y2="{pt(a, 214)[1]:.1f}" '
        f'stroke="{G["strong"]}" stroke-width="10" stroke-linecap="round"/>' for a in (90, 180, 270))
    return svg(f'''{tile(G['node'], G['line'])}{dots(0.12, small)}
<circle cx="256" cy="256" r="168" fill="none" stroke="{G['strong']}" stroke-width="12" stroke-dasharray="2 26" stroke-linecap="round"/>
<path d="M{ax:.1f} {ay:.1f} A168 168 0 0 1 {bx:.1f} {by:.1f}" fill="none" stroke="{G['acc']}" stroke-width="22" stroke-linecap="round"/>
{ticks}
<circle cx="256" cy="256" r="84" fill="{G['acc']}"/>
<circle cx="230" cy="230" r="26" fill="#fff" fill-opacity="0.35"/>
<circle cx="{sx:.1f}" cy="{sy:.1f}" r="58" fill="{G['node']}"/>
<circle cx="{sx:.1f}" cy="{sy:.1f}" r="40" fill="{G['ink']}"/>''')


def v3(small=False):
    sx, sy = pt(-40)
    return svg(f'''<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F5B062"/><stop offset="1" stop-color="#E08A35"/></linearGradient></defs>
<rect x="16" y="16" width="480" height="480" rx="112" fill="url(#g)"/>
<path d="{arc_c()}" fill="none" stroke="{G['on']}" stroke-width="50" stroke-linecap="round"/>
<circle cx="256" cy="256" r="64" fill="{G['on']}"/>
<circle cx="{sx:.1f}" cy="{sy:.1f}" r="62" fill="#EFA04E"/>
<circle cx="{sx:.1f}" cy="{sy:.1f}" r="42" fill="#FFF4E4"/>''')


VARIANTS = {'1': v1, '2': v2, '3': v3}


def png(svg_text, n):
    return cairosvg.svg2png(bytestring=svg_text.encode(), output_width=n, output_height=n)


def ico(make):
    """ICO из PNG-кадров (Windows Vista+): у каждого размера своя отрисовка."""
    frames = [png(make(n <= 32), n) for n in SIZES]
    head = struct.pack('<HHH', 0, 1, len(frames))
    off = 6 + 16 * len(frames)
    dirs, data = b'', b''
    for n, f in zip(SIZES, frames):
        dirs += struct.pack('<BBBBHHII', n % 256, n % 256, 0, 0, 1, 32, len(f), off + len(data))
        data += f
    return head + dirs + data


def main():
    args = sys.argv[1:]
    make = VARIANTS[next((a for a in args if a in VARIANTS), '1')]
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, 'sputnik.svg'), 'w').write(make())
    open(os.path.join(OUT, 'sputnik.png'), 'wb').write(png(make(), 256))
    open(os.path.join(OUT, 'sputnik.ico'), 'wb').write(ico(make))
    print('готово:', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
