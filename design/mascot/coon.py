"""Енот-космонавт Спутника: одна фигура, несколько поз. Вставляется в доски как inline SVG.

Использование в исходниках досок:  @@COON pose size [label]@@   и   @@COON_CSS@@ в <style>.
pose: hi | cheer | sleep | think | flag | face
"""
import re, sys, pathlib

LINE = 'var(--coon-line)'

CSS = """
.sp-app{--fur:#A29D92;--fur-dark:#4A4741;--fur-light:#F4F1EA;--ear-in:#EBC6BA;--blush:#F2A08E;--suit:#EEEAE2;--suit-shade:#CFC9BD;--metal:#8E897F;--rim:#B8C6D2;--glass:rgba(170,200,228,.13);--coon-line:#2A2825;--eye:#161513}
.sp-app[data-theme="light"]{--glass:rgba(110,150,190,.10);--rim:#9FB0BF}
.coon{overflow:visible;display:block}
.coon .c-float{animation:c-float 5.5s ease-in-out infinite;transform-box:view-box;transform-origin:100px 120px}
.coon .c-wave{animation:c-wave 1.8s ease-in-out infinite;transform-box:view-box;transform-origin:132px 166px}
.coon .c-tail{animation:c-tail 3.2s ease-in-out infinite;transform-box:view-box;transform-origin:128px 178px}
.coon .c-ear{animation:c-ear 6s ease-in-out infinite;transform-box:view-box;transform-origin:126px 66px}
.coon .c-eye{animation:c-blink 4.8s infinite;transform-box:fill-box;transform-origin:center}
.coon .c-beacon{animation:c-beacon 1.6s ease-in-out infinite}
.coon .c-star{animation:c-twinkle 2.4s ease-in-out infinite;transform-box:fill-box;transform-origin:center}
.coon .c-hop{animation:c-hop 1.1s cubic-bezier(.3,.6,.4,1) infinite;transform-box:view-box;transform-origin:100px 206px}
.coon .c-z{animation:c-z 3s ease-in-out infinite;opacity:0}
.coon .c-dot{animation:c-dot 1.4s ease-in-out infinite}
.coon .c-orb{animation:c-orb 6s linear infinite;transform-box:view-box;transform-origin:100px 168px}
.coon .c-flag{animation:c-flag 1.4s ease-in-out infinite;transform-box:view-box;transform-origin:158px 92px}
@keyframes c-float{0%,100%{transform:translateY(0) rotate(-2deg)}50%{transform:translateY(-6px) rotate(2deg)}}
@keyframes c-wave{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(14deg)}}
@keyframes c-tail{0%,100%{transform:rotate(0)}50%{transform:rotate(-9deg)}}
@keyframes c-ear{0%,86%,100%{transform:rotate(0)}90%{transform:rotate(9deg)}94%{transform:rotate(-3deg)}}
@keyframes c-blink{0%,93%,100%{transform:scaleY(1)}96%{transform:scaleY(.08)}}
@keyframes c-beacon{0%,100%{opacity:.35}50%{opacity:1}}
@keyframes c-twinkle{0%,100%{opacity:.2;transform:scale(.7)}50%{opacity:1;transform:scale(1)}}
@keyframes c-hop{0%,100%{transform:translateY(0) scaleY(1)}12%{transform:translateY(0) scaleY(.94)}45%{transform:translateY(-12px) scaleY(1.02)}}
@keyframes c-z{0%{opacity:0;transform:translate(0,0)}25%{opacity:1}100%{opacity:0;transform:translate(10px,-22px)}}
@keyframes c-dot{0%,100%{opacity:.25}50%{opacity:1}}
@keyframes c-orb{to{transform:rotate(360deg)}}
@keyframes c-flag{0%,100%{transform:skewY(0)}50%{transform:skewY(-6deg)}}
@media (prefers-reduced-motion:reduce){.coon *{animation:none!important}.coon .c-z,.coon .c-dot{opacity:1}}
"""

DEFS = """<defs>
<radialGradient id="cn-fur" cx=".38" cy=".28" r=".85"><stop offset="0" stop-color="#C4BFB4"></stop><stop offset=".55" stop-color="#9B968C"></stop><stop offset="1" stop-color="#6C6860"></stop></radialGradient>
<radialGradient id="cn-mask" cx=".42" cy=".3" r=".9"><stop offset="0" stop-color="#5C5852"></stop><stop offset="1" stop-color="#2E2C29"></stop></radialGradient>
<radialGradient id="cn-cream" cx=".42" cy=".22" r=".9"><stop offset="0" stop-color="#FFFDF8"></stop><stop offset="1" stop-color="#D6D0C4"></stop></radialGradient>
<radialGradient id="cn-suit" cx=".36" cy=".2" r=".95"><stop offset="0" stop-color="#FCFAF5"></stop><stop offset=".6" stop-color="#E1DCD2"></stop><stop offset="1" stop-color="#B3AC9F"></stop></radialGradient>
<linearGradient id="cn-sleeve" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FAF8F2"></stop><stop offset="1" stop-color="#C4BDB0"></stop></linearGradient>
<radialGradient id="cn-dark" cx=".34" cy=".28" r=".8"><stop offset="0" stop-color="#6E6A62"></stop><stop offset="1" stop-color="#2B2927"></stop></radialGradient>
<radialGradient id="cn-clay" cx=".34" cy=".25" r=".95"><stop offset="0" stop-color="#F3A47E"></stop><stop offset="1" stop-color="#B85531"></stop></radialGradient>
<radialGradient id="cn-gold" cx=".34" cy=".25" r=".95"><stop offset="0" stop-color="#F8CF85"></stop><stop offset="1" stop-color="#C98A2E"></stop></radialGradient>
<radialGradient id="cn-ear" cx=".5" cy=".65" r=".7"><stop offset="0" stop-color="#F6CDBB"></stop><stop offset="1" stop-color="#D99580"></stop></radialGradient>
<radialGradient id="cn-eye" cx=".4" cy=".3" r=".85"><stop offset="0" stop-color="#FFFFFF"></stop><stop offset="1" stop-color="#E2DED5"></stop></radialGradient>
<radialGradient id="cn-glass" cx=".5" cy=".5" r=".5"><stop offset=".72" stop-color="#C6DDF0" stop-opacity=".03"></stop><stop offset="1" stop-color="#C6DDF0" stop-opacity=".26"></stop></radialGradient>
<radialGradient id="cn-spec" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".6"></stop><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"></stop></radialGradient>
<radialGradient id="cn-ao" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#000" stop-opacity=".32"></stop><stop offset="1" stop-color="#000" stop-opacity="0"></stop></radialGradient>
<linearGradient id="cn-metal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E4E0D8"></stop><stop offset=".55" stop-color="#A8A298"></stop><stop offset="1" stop-color="#77726A"></stop></linearGradient>
</defs>"""

def spec(cx, cy, rx, ry, rot=0, op=1):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="url(#cn-spec)" opacity="{op}"></ellipse>'

EAR = """<path d="M55 84C44 66 46 44 57 33C72 33 87 45 93 58Z" fill="url(#cn-fur)"></path>
<path d="M57 33C62 32 67 33 72 35C66 38 61 43 58 50C55 44 55 38 57 33Z" fill="#3A3733" opacity=".7"></path>
<path d="M61 74C57 61 58 49 62 43C70 46 78 52 83 60Z" fill="url(#cn-ear)"></path>"""

def ears():
    return f"""<g>{EAR}</g><g class="c-ear"><g transform="translate(200 0) scale(-1 1)">{EAR}</g></g>"""

HEAD_PATH = ("M100 50C113 50 124 53 132 59C142 66 148 77 150 88C157 92 162 97 165 103C161 106 158 109 160 113"
             "C154 115 150 118 147 122C138 135 120 142 100 142C80 142 62 135 53 122C50 118 46 115 40 113"
             "C42 109 39 106 35 103C38 97 43 92 50 88C52 77 58 66 68 59C76 53 87 50 100 50Z")

def eyes(kind):
    if kind in ('closed', 'happy'):
        d = ('M68 101C72 107 82 107 86 101', 'M114 101C118 107 128 107 132 101') if kind == 'closed' else \
            ('M68 104C71 95 83 95 86 104', 'M114 104C117 95 129 95 132 104')
        return ''.join(f'<path d="{p}" fill="none" stroke="#F3EEE4" stroke-width="3.6" stroke-linecap="round"></path>' for p in d)
    up = kind == 'up'
    out = []
    for cx, toward in ((77, 1), (123, -1)):
        px = cx + (2.5 if up else 1.6 * toward)
        py = 96 if up else 101
        out.append(f'<g class="c-eye"><ellipse cx="{cx}" cy="99" rx="9.5" ry="11" fill="url(#cn-eye)"></ellipse>'
                   f'<ellipse cx="{px}" cy="{py}" rx="5.4" ry="6.4" fill="#1B1A18"></ellipse>'
                   f'<circle cx="{px+2}" cy="{py-2.6}" r="2.1" fill="#fff"></circle></g>')
    return ''.join(out)

def mouth(kind):
    if kind == 'open':
        return ('<path d="M92 127C93 138 107 138 108 127C103 129 97 129 92 127Z" fill="#6E2E24"></path>'
                '<path d="M95.5 133.5C98 131.6 102 131.6 104.5 133.5C102.5 135.6 97.5 135.6 95.5 133.5Z" fill="#E88E7C"></path>')
    if kind == 'o':
        return '<ellipse cx="100" cy="129.5" rx="2.8" ry="3.4" fill="#6E2E24"></ellipse>'
    if kind == 'flat':
        return '<path d="M95 129.5C98 128.5 102 128.5 105 129.5" fill="none" stroke="#2E2C29" stroke-width="2.2" stroke-linecap="round"></path>'
    return ('<path d="M100 123V126M100 126C98.2 130 93.8 130 92 127M100 126C101.8 130 106.2 130 108 127" fill="none" '
            'stroke="#2E2C29" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"></path>')

def head(eye='open', mth='smile'):
    return f"""{ears()}
<path d="{HEAD_PATH}" fill="url(#cn-fur)"></path>
<path d="M100 58C104.5 68 105.5 80 103.5 92H96.5C94.5 80 95.5 68 100 58Z" fill="#3A3733" opacity=".3"></path>
<path d="M57 86C65 75 80 72 91 80C81 80 69 84 60 92Z" fill="url(#cn-cream)"></path>
<path d="M143 86C135 75 120 72 109 80C119 80 131 84 140 92Z" fill="url(#cn-cream)"></path>
<path d="M40 104C46 90 61 84 76 85C88 86 95 92 100 97C105 92 112 86 124 85C139 84 154 90 160 104C152 114 139 118 126 116C115 114 107 109 100 109C93 109 85 114 74 116C61 118 48 114 40 104Z" fill="url(#cn-mask)"></path>
<path d="M100 107C116 107 130 115 130 125.5C130 135.5 117 141.5 100 141.5C83 141.5 70 135.5 70 125.5C70 115 84 107 100 107Z" fill="url(#cn-cream)"></path>
<path d="M53 122C62 135 80 142 100 142C120 142 138 135 147 122C136 131 119 135 100 135C81 135 64 131 53 122Z" fill="#000" opacity=".14"></path>
{spec(84, 66, 20, 8, -14)}
{eyes(eye)}
<ellipse cx="59" cy="120" rx="8" ry="4.4" fill="#F29A80" opacity=".5"></ellipse>
<ellipse cx="141" cy="120" rx="8" ry="4.4" fill="#F29A80" opacity=".5"></ellipse>
<path d="M91 116C91 111.4 109 111.4 109 116C109 120.2 104 124 100 124C96 124 91 120.2 91 116Z" fill="url(#cn-dark)"></path>
<ellipse cx="96.5" cy="114.4" rx="3" ry="1.4" fill="#fff" opacity=".5"></ellipse>
{mouth(mth)}"""

def helmet(beacon=True):
    tip = ('<circle class="c-beacon" cx="148.5" cy="10" r="10" fill="#E8875C" opacity=".28"></circle>'
           '<circle cx="148.5" cy="10" r="5.6" fill="url(#cn-clay)"></circle>') if beacon else \
          '<circle cx="148.5" cy="10" r="5.6" fill="url(#cn-dark)"></circle>'
    return f"""<circle cx="100" cy="94" r="69" fill="url(#cn-glass)"></circle>
<circle cx="100" cy="94" r="69" fill="none" stroke="var(--rim)" stroke-width="2.4" opacity=".75"></circle>
<path d="M44 80C47 57 63 39 85 31" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity=".42"></path>
<path d="M50 96C50 92 51 88 52 85" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".3"></path>
<path d="M158 118C153 133 144 144 131 150" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" opacity=".15"></path>
<line x1="135" y1="35" x2="147" y2="14" stroke="#A9A398" stroke-width="3.2" stroke-linecap="round"></line>
{tip}<circle cx="146.6" cy="8.3" r="1.6" fill="#fff" opacity=".6"></circle>"""

TAIL_D = "M124 182C148 188 169 175 169 150C169 143 167 139 164 136"
def tail():
    return f"""<g class="c-tail">
<path d="{TAIL_D}" fill="none" stroke="url(#cn-fur)" stroke-width="19" stroke-linecap="round"></path>
<path d="{TAIL_D}" fill="none" stroke="#3A3733" stroke-width="19" stroke-dasharray="7 8" stroke-dashoffset="-6" opacity=".9"></path>
<circle cx="164" cy="136" r="9.5" fill="url(#cn-mask)"></circle>
<path d="M131 178C148 180 160 170 162 154" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".14"></path>
</g>"""

BOOT = '<path d="M74 194C69 203 76 210 90 210C99 210 101 203 98 196Z" fill="url(#cn-dark)"></path><ellipse cx="82" cy="199" rx="5" ry="2.2" fill="#fff" opacity=".18"></ellipse>'
def body():
    return f"""<g>{BOOT}</g><g transform="translate(200 0) scale(-1 1)">{BOOT}</g>
<path d="M66 160C58 174 61 193 78 199C92 203 108 203 122 199C139 193 142 174 134 160C122 152 78 152 66 160Z" fill="url(#cn-suit)"></path>
<path d="M78 199C92 203 108 203 122 199C130 196 135 190 137 183C128 192 114 195 100 195C86 195 74 191 66 186C68 192 72 197 78 199Z" fill="#000" opacity=".07"></path>
<rect x="87" y="168" width="26" height="18" rx="6" fill="url(#cn-clay)"></rect>
<path d="M106.2 172.4A6 6 0 1 0 106.2 181.6" fill="none" stroke="#2A1810" stroke-width="2.2" stroke-linecap="round"></path>
<circle cx="100.4" cy="177" r="2.2" fill="#2A1810"></circle><circle cx="106.2" cy="172.4" r="1.9" fill="#FFD68A"></circle>
<rect x="88.5" y="169" width="12" height="3" rx="1.5" fill="#fff" opacity=".22"></rect>
<ellipse cx="100" cy="154" rx="46" ry="12" fill="url(#cn-ao)"></ellipse>
<ellipse cx="100" cy="156" rx="38" ry="8.5" fill="url(#cn-metal)"></ellipse>
<ellipse cx="100" cy="154" rx="30" ry="3.6" fill="#fff" opacity=".3"></ellipse>"""

def arm(d, paw, cls=''):
    c = f' class="{cls}"' if cls else ''
    px, py = paw
    return f"""<g{c}><path d="{d}" fill="none" stroke="#B9B2A5" stroke-width="14.5" stroke-linecap="round"></path>
<path d="{d}" fill="none" stroke="url(#cn-sleeve)" stroke-width="12" stroke-linecap="round"></path>
<circle cx="{px}" cy="{py}" r="8.2" fill="url(#cn-dark)"></circle>
<ellipse cx="{px-2.4}" cy="{py-2.8}" rx="2.6" ry="1.6" fill="#fff" opacity=".28"></ellipse></g>"""

def sparkle(x, y, s, delay, color='var(--gold)'):
    return (f'<path class="c-star" style="animation-delay:{delay}s" d="M{x} {y-s}C{x+s*.15} {y-s*.2} {x+s*.2} {y-s*.15} {x+s} {y}'
            f'C{x+s*.2} {y+s*.15} {x+s*.15} {y+s*.2} {x} {y+s}C{x-s*.15} {y+s*.2} {x-s*.2} {y+s*.15} {x-s} {y}'
            f'C{x-s*.2} {y-s*.15} {x-s*.15} {y-s*.2} {x} {y-s}Z" fill="{color}"></path>')

SHADOW = '<ellipse class="c-shadow" cx="100" cy="213" rx="36" ry="4" fill="#000" opacity=".22"></ellipse>'

def pose_svg(pose):
    if pose == 'face':
        return f'{DEFS}{head()}{helmet()}', '26 -4 148 168'
    rest_l = arm('M70 166C61 172 59 182 65 188', (66, 189))
    if pose == 'hi':
        inner = f"""{tail()}{body()}{head()}{helmet()}{rest_l}
{arm('M130 166C146 160 154 148 156 136', (156, 132), 'c-wave')}"""
        return f'{DEFS}{SHADOW}<g class="c-float">{inner}</g>', '0 0 200 218'
    if pose == 'cheer':
        inner = f"""{tail()}{body()}{head('happy', 'open')}{helmet()}
{arm('M70 166C56 160 46 148 44 136', (44, 132))}
{arm('M130 166C144 160 154 148 156 136', (156, 132))}"""
        stars = sparkle(18, 108, 9, 0) + sparkle(182, 104, 8, .6) + sparkle(26, 40, 6, 1.1, 'var(--clay)') + sparkle(178, 52, 5, .3, 'var(--signal-done)') + sparkle(188, 160, 5, .9)
        return f'{DEFS}{SHADOW}{stars}<g class="c-hop">{inner}</g>', '0 0 200 218'
    if pose == 'sleep':
        inner = f"""{tail()}{body()}<g transform="rotate(-9 100 140)">{head('closed', 'o')}{helmet(beacon=False)}</g>
{arm('M71 166C68 176 76 183 87 182', (88, 181))}
{arm('M129 166C132 176 124 183 113 182', (112, 181))}"""
        z = ''.join(f'<text class="c-z" x="{x}" y="{y}" style="animation-delay:{d}s;font:700 {s}px/1 var(--font-sans)" fill="var(--ink-soft)">z</text>'
                    for x, y, s, d in ((160, 52, 14, 0), (170, 36, 18, 1), (182, 18, 22, 2)))
        return f'{DEFS}{SHADOW}<g class="c-float">{inner}</g>{z}', '0 0 210 218'
    if pose == 'think':
        orb = """<g class="c-orb"><ellipse cx="100" cy="170" rx="23" ry="7" fill="none" stroke="var(--gold)" stroke-width="2" opacity=".8"></ellipse><circle cx="123" cy="170" r="3" fill="var(--signal-done)"></circle></g>
<circle cx="100" cy="170" r="11.5" fill="url(#cn-gold)"></circle><ellipse cx="96" cy="165.5" rx="3.6" ry="2.2" fill="#fff" opacity=".5"></ellipse>"""
        inner = f"""{tail()}{body()}{head('up', 'o')}{helmet()}
{arm('M70 166C66 174 74 180 86 177', (87, 176))}
{arm('M130 166C134 174 126 180 114 177', (113, 176))}
{orb}"""
        dots = ''.join(f'<circle class="c-dot" style="animation-delay:{d}s" cx="{x}" cy="{y}" r="{r}" fill="var(--ink-soft)"></circle>'
                       for x, y, r, d in ((168, 40, 3.5, 0), (180, 26, 4.5, .25), (194, 12, 5.5, .5)))
        return f'{DEFS}{SHADOW}<g class="c-float">{inner}</g>{dots}', '0 0 210 218'
    if pose == 'flag':
        flag = """<line x1="158" y1="148" x2="158" y2="68" stroke="#8D887F" stroke-width="3.6" stroke-linecap="round"></line>
<circle cx="158" cy="67" r="3.4" fill="url(#cn-gold)"></circle>
<g class="c-flag"><path d="M159.5 72C170 68 180 76 192 72V96C180 100 170 92 159.5 96Z" fill="url(#cn-clay)"></path>
<path d="M174 79.5l1.6 3.4 3.7.4-2.8 2.5.8 3.7-3.3-1.9-3.3 1.9.8-3.7-2.8-2.5 3.7-.4z" fill="#FFD68A"></path></g>"""
        inner = f"""{tail()}{body()}{head('open', 'smile')}{helmet()}{rest_l}{flag}
{arm('M130 166C144 162 152 152 156 142', (157, 139))}"""
        return f'{DEFS}{SHADOW}<g class="c-float">{inner}</g>', '0 0 200 218'
    if pose == 'oops':
        drop = '<path d="M150 58C150 58 143 67 143 71.5C143 75.4 146.2 78 150 78C153.8 78 157 75.4 157 71.5C157 67 150 58 150 58Z" fill="#9FD0E2" opacity=".9"></path><ellipse cx="148" cy="71" rx="1.6" ry="2.6" fill="#fff" opacity=".7"></ellipse>'
        inner = f"""{tail()}{body()}<g transform="rotate(6 100 140)">{head('open', 'flat')}{helmet()}{drop}</g>
{arm('M70 166C64 174 70 182 80 182', (81, 182))}
{arm('M130 166C140 158 146 150 147 142', (147, 139))}"""
        return f'{DEFS}{SHADOW}<g class="c-float">{inner}</g>', '0 0 200 218'
    raise ValueError(pose)

_N = 0

def svg(pose, size, label='Енот-космонавт'):
    inner, vb = pose_svg(pose)
    x, y, w, h = map(float, vb.split())
    size = int(size); width = size; height = int(round(size * h / w))
    inner = re.sub(r'\n\s*', '', inner)
    global _N
    _N += 1
    inner = inner.replace('cn-', f'cn{_N}-')
    return f'<svg class="coon" viewBox="{vb}" width="{width}" height="{height}" role="img" aria-label="{label}">{inner}</svg>'

HEAD = """<helmet>
<style>
body{margin:0}
.sp-app{--bg:#1C1B19;--wash:#22211E;--raised:#282723;--hairline:#34332E;--edge:#3A3934;--ink:#ECEAE3;--ink-soft:#A8A69D;--ink-faint:#7C7B72;--clay:#D9774F;--clay-soft:#30221B;--on-clay:#1C1B19;--gold:#E0A04A;--gold-soft:#3A2E1A;--signal-overdue:#F07A6A;--signal-soon:var(--gold);--signal-done:#6FB6CF;--type-work:#7FA6E8;--type-creative:var(--clay);--type-study:#B79BE6;--type-personal:#8FBF7F;--type-habit:var(--gold);--shadow-lift:0 6px 18px rgba(0,0,0,.45);color-scheme:dark;--font-display:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;--font-sans:-apple-system,"Segoe UI",system-ui,sans-serif;--font-mono:"Cascadia Mono",ui-monospace,Consolas,monospace;--space-1:4px;--space-2:8px;--space-3:12px;--space-4:16px;--space-5:24px;--space-6:32px;--space-7:48px;--radius-sm:4px;--radius-md:8px;--radius-lg:12px;--radius-pill:999px;background:var(--bg);color:var(--ink);font-family:var(--font-sans)}
.sp-app[data-theme="light"]{--bg:#FCFCFB;--wash:#F5F4F0;--raised:#FFFFFF;--hairline:#E4E3DC;--edge:#E1E1DF;--ink:#2E2C27;--ink-soft:#6B6A63;--ink-faint:#8A897F;--clay:#AD4F2C;--clay-soft:#FBEEE7;--on-clay:#FFFFFF;--gold:#8F5A00;--gold-soft:#FBF1DF;--signal-overdue:#B42318;--signal-done:#1F6A80;--type-work:#2F5DA8;--type-study:#6D4AA5;--type-personal:#3E6B31;--shadow-lift:0 6px 18px rgba(46,44,39,.14);color-scheme:light}
a{color:inherit;text-decoration:none}
.sp-app .sp-tab{text-decoration:none;display:inline-block}
button:focus-visible,a:focus-visible{outline:2px solid var(--clay);outline-offset:2px}
.tick{width:20px;height:20px;flex:none;border-radius:6px;box-sizing:border-box;border:1.5px solid var(--ink-faint);background:none;padding:0;display:grid;place-items:center;cursor:pointer;color:var(--bg)}
.tick[aria-pressed="true"]{background:var(--signal-done);border-color:var(--signal-done)}
.ring{width:20px;height:20px;flex:none;border-radius:50%;box-sizing:border-box;padding:0;border:2px solid var(--clay);background:none;display:grid;place-items:center;cursor:pointer;color:var(--bg)}
.ring[aria-pressed="true"]{border-color:var(--gold);background:var(--gold)}
.bubble{position:relative;padding:10px 14px;border-radius:14px;background:var(--raised);border:1px solid var(--edge);font-size:14px;line-height:20px;box-shadow:var(--shadow-lift)}
.bubble::after{content:"";position:absolute;width:12px;height:12px;background:var(--raised);border:1px solid var(--edge);border-top:0;border-left:0;transform:rotate(45deg);right:-7px;top:50%;margin-top:-6px}
.cap{margin:0 0 8px;font-size:11.5px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:var(--ink-faint)}
@@EXTRA_CSS@@
@@COON_CSS@@
</style>
</helmet>"""

TABS = [('today', 'Today2.dc.html', 'Сегодня <span class="n">· 5</span>'), ('cal', 'Calendar2.dc.html', 'Календарь'),
        ('board', 'Main2.dc.html', 'Доска'), ('habits', 'Habits2.dc.html', 'Привычки')]

def nav(active, cta):
    tabs = ''.join(f'<a class="sp-tab" href="{h}" aria-selected="{"true" if k == active else "false"}">{t}</a>' for k, h, t in TABS)
    return f"""<nav class="sp-tabs" aria-label="Разделы" style="flex-wrap: wrap; padding-left: max(24px, env(safe-area-inset-left, 0px)); padding-right: max(24px, env(safe-area-inset-right, 0px))">
    <span class="sp-brand"><svg viewBox="0 0 512 512" aria-hidden="true"><path class="arc" d="M370.9 159.6 A150 150 0 1 0 370.9 352.4"></path><circle class="core" cx="256" cy="256" r="62"></circle><circle class="sat" cx="370.9" cy="159.6" r="42"></circle></svg>Спутник</span>
    {tabs}
    <div style="margin-left: auto; display: flex; align-items: center; gap: 14px; padding-bottom: 8px">
      <span style="display: inline-flex; align-items: center; gap: 6px; font-size: 12px; line-height: 16px; color: var(--ink-soft)"><span style="width: 8px; height: 8px; border-radius: 50%; background: var(--signal-done)"></span>Синхронизировано · 13:52</span>
      <a href="Today2.dc.html" class="sp-btn sp-btn-ghost" style="min-height: 32px; padding: 0 10px" aria-label="Входящие от Claude, 2"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 13h4l2 3h4l2-3h4M5 5h14l1 8v6H4v-6z"></path></svg><span style="font: 600 11px/1 var(--font-mono); color: var(--clay)">2</span></a>
      <button class="sp-btn sp-btn-primary" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"></path></svg>{cta}</button>
    </div>
  </nav>"""

CHECK = '<svg viewBox="0 0 24 24" aria-hidden="true" style="width: 12px; height: 12px; fill: none; stroke: currentColor; stroke-width: 3.2; stroke-linecap: round; stroke-linejoin: round"><path d="M5 12.5l4.5 4.5L19 7.5"></path></svg>'

def build(src, dst):
    s = pathlib.Path(src).read_text()
    m = re.search(r'<!--EXTRA_CSS(.*?)-->', s, re.S)
    if '@@HEAD@@' in s:
        s = s.replace('@@HEAD@@', HEAD.replace('@@EXTRA_CSS@@', m.group(1).strip() if m else ''))
    if m:
        s = s.replace(m.group(0), '')
    s = re.sub(r'@@NAV (\w+) ([^@]+)@@', lambda mm: nav(mm.group(1), mm.group(2)), s)
    s = s.replace('@@CHECK@@', CHECK)
    s = s.replace('@@COON_CSS@@', re.sub(r'\n', '', CSS))
    def rep(m):
        parts = m.group(1).split(' ', 2)
        return svg(parts[0], parts[1], parts[2] if len(parts) > 2 else 'Енот-космонавт')
    s = re.sub(r'@@COON ([^@]+)@@', rep, s)
    pathlib.Path(dst).write_text(s)

if __name__ == '__main__':
    src_dir, out_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    for f in sorted(src_dir.glob('*.dc.html')):
        build(f, out_dir / f.name)
        print('built', f.name)
