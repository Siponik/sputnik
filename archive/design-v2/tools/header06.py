# Новая шапка 0.6 для всех досок холста: берётся из Shell2 (CSS + разметка), классы переименованы в h6-*.
import re, pathlib, sys
S = pathlib.Path(__file__).resolve().parent.parent
src = (pathlib.Path(__file__).resolve().parents[2] / 'design/screens/Shell.dc.html').read_text()
css = re.search(r'(\.hd \*\{.*?\.win svg\{[^}]*\})', src, re.S).group(1)
css += '\n@keyframes pl{50%{opacity:.35}}'
NAMES = ['hd','brand','tab','cnt','hot','sp','find','ib','b','stat','dots','w','e','updchip','pr','timer','create','win','arc','core','sat']
def ren(s):
    for n in sorted(NAMES, key=len, reverse=True):
        s = re.sub(r'\.%s(?![\w-])' % n, '.h6-' + n, s)
    return s
CSS = ren(css).replace('@keyframes pl', '@keyframes h6pl').replace('animation:pl ', 'animation:h6pl ')
TABS = [('today', 'Сегодня', '<span class="h6-cnt h6-hot">5</span>', 'Today'), ('cal', 'Календарь', '', 'Calendar'), ('board', 'Доска', '', 'Kanban'), ('habits', 'Привычки', '<span class="h6-cnt">2</span>', 'Habits')]
LINK = {'today': 'Today063.dc.html', 'cal': 'Calendar063.dc.html', 'board': 'Kanban063.dc.html', 'habits': 'Habits063.dc.html'}
def header(active):
    tabs = ''.join(f'<a class="h6-tab" href="{LINK[k]}" aria-selected="{"true" if k == active else "false"}">{n}{c and " " + c}</a>' for k, n, c, _ in TABS)
    return f'''<header class="h6-hd" data-tauri-drag-region>
    <span class="h6-brand"><svg viewBox="0 0 512 512" aria-hidden="true"><path class="h6-arc" d="M370.9 159.6 A150 150 0 1 0 370.9 352.4"></path><circle class="h6-core" cx="256" cy="256" r="62"></circle><circle class="h6-sat" cx="370.9" cy="159.6" r="42"></circle></svg>Спутник</span>
    {tabs}
    <span class="h6-sp"></span>
    <button class="h6-find" type="button"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"></circle><path d="M16 16l4.5 4.5"></path></svg>Найти<kbd>Ctrl K</kbd></button>
    <button class="h6-stat" type="button" title="Состояние: Google, компьютеры, версия"><span class="h6-dots"><i></i><i></i><i></i></span>13:52</button>
    <button class="h6-ib" type="button" title="Входящие от Claude · 2"><svg viewBox="0 0 24 24"><path d="M4 13h4l2 3h4l2-3h4M5 5h14l1 8v6H4v-6z"></path></svg><span class="h6-b">2</span></button>
    <button class="h6-ib" type="button" title="Настройки · Ctrl+,"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"></circle><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"></path></svg></button>
    <button class="h6-create" type="button"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"></path></svg>Создать</button>
    <span class="h6-win" aria-hidden="true"><span><svg viewBox="0 0 12 12"><path d="M1 6h10"></path></svg></span><span><svg viewBox="0 0 12 12"><rect x="1.5" y="1.5" width="9" height="9"></rect></svg></span><span><svg viewBox="0 0 12 12"><path d="M1.5 1.5l9 9M10.5 1.5l-9 9"></path></svg></span></span>
  </header>'''
def swap(html, active):
    html, n = re.subn(r'<nav class="sp-tabs"[^>]*>.*?</nav>', lambda m: header(active), html, count=1, flags=re.S)
    assert n == 1, 'no nav'
    html = html.replace('</style>\n</helmet>', CSS + '\n</style>\n</helmet>', 1) if '</style>\n</helmet>' in html else re.sub(r'</style>(\s*)</helmet>', lambda m: CSS + '</style>' + m.group(1) + '</helmet>', html, count=1)
    return html
if __name__ == '__main__':
    for spec in sys.argv[1:]:
        f, active, out = spec.split(':')
        p = pathlib.Path(f); o = pathlib.Path(out)
        o.write_text(swap(p.read_text(), active)); print('ok', o.name)
