import json, os, datetime
ROOT=__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', 'ds') + '/'
def w(p, s):
    os.makedirs(os.path.dirname(ROOT+p), exist_ok=True); open(ROOT+p,'w').write(s)

C=[ # name, dark, light, usage
('ground','#191A1E','#ECEDF0','Холст под нодами (основная область экрана) с тихими точками через `grid-minor`.'),
('bg','#1C1D21','#F3F3F5','Фон приложения: шапка, полосы, поля ввода внутри нод.'),
('node','#25262B','#FFFFFF','Заливка ноды, меню и окон. Главная поверхность для текста.'),
('node-hover','#2C2D33','#F7F7F9','Строка или нода под курсором, выбранная строка.'),
('line','#3A3B42','#D7D8DD','Контур ноды и разделители строк. Не несёт смысла сам по себе.'),
('line-soft','#303137','#E8E9EC','Тонкие разделители внутри ноды, между строками задач.'),
('line-strong','#6E7079','#8E909A','Рамки полей ввода, неотмеченных чекбоксов и вторичных кнопок: 3:1 к `node` в обеих темах.'),
('ink','#E2E3E8','#1C1D21','Основной текст на `node`, `bg`, `ground`.'),
('muted','#9A9CA6','#5C5E68','Вторичный текст, время, подписи-моно на `node` и `bg` (от 4.5:1).'),
('dim','#7A7C86','#767884','Номера нод и строк, засечки размерных линий. Только знаки от 3:1, не текст, который надо читать.'),
('accent','#F0A04B','#A85A0E','Акцент Спутника: «сейчас», активная нода, главный провод, активный пункт меню. Как текст — на `node`, `bg`, `accent-wash`.'),
('accent-fill','#F0A04B','#EE9A42','Заливка главной кнопки и активной отметки. Текст на ней — `on-accent`.'),
('on-accent','#1E1F23','#1E1F23','Текст и значки на `accent-fill`.'),
('accent-ink','#FFD29C','#8A4A0A','Светлый текст внутри текущей задачи (время, название) на `accent-wash`.'),
('accent-wash','#2E2722','#FBF1E6','Фон текущей задачи под штриховкой.'),
('accent-line','#6A5238','#E2B98A','Рамка главной ноды «Сегодня» и вторичной кнопки внутри текущей задачи.'),
('ink-fill','#E2E3E8','#1C1D21','Заливка кнопки «＋ Создать» в шапке. Текст на ней — `on-ink`.'),
('on-ink','#1C1D21','#FFFFFF','Текст на `ink-fill`.'),
('fill-amber','#8A5320','#8A5320','Заливка шапки ноды сферы «3D и заказы» и задач. Текст на ней — белый.'),
('fill-blue','#2F4F86','#2F4F86','Заливка шапки ноды сферы «Работа», окна «Событие».'),
('fill-violet','#5E3F92','#5E3F92','Заливка шапки сферы «Учёба», дней рождения, общих сфер.'),
('fill-green','#2E6B3E','#2E6B3E','Заливка шапки сферы «Дом», «Готово», резервных копий.'),
('fill-gold','#7A6620','#7A6620','Заливка шапки привычек.'),
('fill-grey','#3D3E45','#3D3E45','Заливка служебных шапок: «Входящие», «От Claude», настройки.'),
('fill-red','#8A3A2E','#8A3A2E','Заливка шапки «нет доступа», ошибки.'),
('fill-hub','#9A5A22','#9A5A22','Заливка шапки главной ноды экрана.'),
('on-fill','#FFFFFF','#FFFFFF','Текст и значки на любой `fill-*`.'),
('hue-amber','{accent}','{accent}','Цвет сферы и провода по умолчанию (3D-ассеты). Псевдоним `accent`.'),
('hue-blue','#6FA2F2','#2B66C4','Цвет сферы «Работа»: точка в шапке ноды, провод, метка «→ Работа».'),
('hue-violet','#B48CF0','#7446C2','Цвет сферы «Учёба».'),
('hue-green','#7FD18C','#2C7A3F','Цвет сферы «Дом» и пройденные этапы на дорожке. Рядом всегда слово или ✓.'),
('hue-gold','#E8C65A','#8A6A06','Привычки: точка, провода, отмеченная таблетка, серии.'),
('on-gold','#1E1F23','#FFFFFF','Текст на заливке `hue-gold` (отмеченная привычка).'),
('hue-grey','#A3A5AE','#62646E','Входящие от Claude: пунктирная нода, кольцевые сокеты.'),
('danger','#F0785F','#C2412A','Просрочено, ошибка синхронизации. Всегда со словом.'),
('focus','#FFD29C','#8A4A0A','Кольцо фокуса клавиатуры: 2px сплошное, отступ 2px. От 3:1 на `node`, `bg`, `ground`.'),
]
def cv(d,l):
    return d if d==l else {'dark':d,'light':l}
tokens={'name':'Спутник · Схема','version':1,
 'color':{'themes':[{'id':'dark','name':'Тёмная'},{'id':'light','name':'Светлая'}],
   'tokens':[{'name':n,'value':cv(d,l),'usage':u} for n,d,l,u in C]},
 'type':{'fonts':[],
   'families':{'sans':'"Onest", "Segoe UI", system-ui, sans-serif','mono':'"JetBrains Mono", "Cascadia Mono", Consolas, monospace'},
   'groups':[
    {'name':'Текст','family':'sans','styles':[
      {'name':'numeral','fontSize':'64px','lineHeight':'64px','fontWeight':200,'letterSpacing':'-0.02em','sample':'05','usage':'Большие цифры: дата, счётчик серии. Тонкие, как размер на чертеже.'},
      {'name':'title','fontSize':'20px','lineHeight':'26px','fontWeight':500,'sample':'Текстуры для щита, 2K','usage':'Название в окне задачи и в панели.'},
      {'name':'task-now','fontSize':'14px','lineHeight':'20px','fontWeight':600,'sample':'Текстуры для щита, 2K','usage':'Название текущей задачи и заголовок карточки вывода.'},
      {'name':'body','fontSize':'13px','lineHeight':'20px','fontWeight':400,'sample':'Созвон с клиентом «Таверна»','usage':'Строки задач, текст в нодах, кнопки.'},
      {'name':'small','fontSize':'12.5px','lineHeight':'18px','fontWeight':400,'sample':'С 17 до 19 свободно','usage':'Подсказки енота, пояснения.'}]},
    {'name':'Моно','family':'mono','styles':[
      {'name':'label','fontSize':'10.5px','lineHeight':'14px','fontWeight':500,'letterSpacing':'0.14em','sample':'01 · ИСТОЧНИКИ','usage':'Шапки нод, меню, заголовки колонок. ЗАГЛАВНЫМИ.'},
      {'name':'data','fontSize':'11.5px','lineHeight':'16px','fontWeight':400,'sample':'15:00—17:00','usage':'Время, счётчики, размеры. Цифры моноширинные.'},
      {'name':'micro','fontSize':'9.5px','lineHeight':'12px','fontWeight':400,'letterSpacing':'0.12em','sample':'09:00 — 21:00 · 12 Ч','usage':'Размерные линии, штамп листа, засечки.'}]}]},
 'spacing':{'tokens':[
   {'name':'space-1','value':'4px','usage':'Зазор между сегментами дорожки, внутри чипа.'},
   {'name':'space-2','value':'8px','usage':'Зазор между кнопками, значком и текстом.'},
   {'name':'space-3','value':'12px','usage':'Внутренний отступ ноды и строки задачи.'},
   {'name':'space-4','value':'16px','usage':'Отступ холста, поля между группами в ноде.'},
   {'name':'space-5','value':'24px','usage':'Шаг мелкой сетки холста; отступы шапки.'},
   {'name':'node-head','value':'30px','usage':'Высота шапки ноды. Сокеты ставятся по центру строк, первая строка начинается под ней.'},
   {'name':'row','value':'28px','usage':'Высота строки в ноде-источнике.'},
   {'name':'row-task','value':'40px','usage':'Высота строки задачи в ноде «Сегодня».'},
   {'name':'grid-minor','value':'24px','usage':'Шаг точек на `ground`.'},
   {'name':'dot','value':'1px','usage':'Размер точки холста; цвет — `ink` 7%.'}]},
 'radius':{'tokens':[
   {'name':'radius-xs','value':'3px','usage':'Сокеты, точки цвета сферы, сегменты дорожки и полоски.'},
   {'name':'radius-sm','value':'6px','usage':'Кнопки, превью, чекбоксы — 4px внутри (`radius-xs`+1).'},
   {'name':'radius-md','value':'8px','usage':'Ноды, поля ввода, текущая задача, штамп.'},
   {'name':'radius-lg','value':'12px','usage':'Главная нода экрана («Сегодня», окно задачи).'},
   {'name':'radius-pill','value':'999px','usage':'Только таблетки привычек.'}]},
 'shadow':{'tokens':[
   {'name':'lift','value':{'dark':'0 18px 40px rgba(0,0,0,.35)','light':'0 12px 32px rgba(28,29,33,.12)'},'usage':'Только главная нода экрана и всплывающие окна. Остальные ноды без тени.'}]},
 'stroke':{'tokens':[
   {'name':'wire','value':'1.5px','usage':'Обычный провод между нодами.'},
   {'name':'wire-now','value':'2px','usage':'Провод текущей задачи (цвет `accent`).'},
   {'name':'hairline','value':'1px','usage':'Контуры нод, разделители, размерные линии.'}]}
}
w('tokens.json', json.dumps(tokens, ensure_ascii=False, indent=1))

README = r'''Спутник · Схема — визуальная система трекера «Спутник». Экран собран как схема из нод: списки, привычки и входящие — ноды-источники, провода сводят их в главную ноду экрана, справа — ноды вывода. Строгость взята из инженерного чертежа: моно-подписи заглавными, тонкие линии, нумерация, размерные линии и штамп листа. Углы мягкие, как в нодовых редакторах.

## Голос и текст

- Пиши по-русски, на «ты», коротко: «Перенести», «Принять», «С 17 до 19 свободно».
- Подписи-моно (`label`, `micro`) — ЗАГЛАВНЫМИ с разрядкой: «01 · ИСТОЧНИКИ», «ДАЛЬШЕ · 8 МИН». Текст для чтения (`body`, `small`) — обычным регистром.
- Разделитель в подписях — « · ». Диапазон времени — «15:00—17:00».
- Без эмодзи. Символы — только ＋ ✓ ▶ → и пунктир.
- Нумерация (01, 02, …) ставится, только когда порядок что-то значит: колонки схемы, задачи по времени, этапы.

## Цвет

- Тёмная тема основная, не чёрная: `ground` под нодами, `bg` у шапки, `node` у нод.
- `accent` — одно «сейчас» на экране: текущая задача, её провод (`wire-now`), активный пункт меню, рамка главной ноды (`accent-line`) и уголки. Не крась акцентом второстепенное.
- Главная кнопка — `accent-fill` с текстом `on-accent`. Кнопка «＋ Создать» в шапке — `ink-fill` с `on-ink`.
- Цвет сферы (`hue-blue`, `hue-violet`, `hue-green`, `hue-gold`, `hue-grey`, `hue-amber`) появляется трижды и в одном месте каждый раз: точка в шапке ноды-источника, провод, точка в конце строки задачи. Шапка ноды залита тёмным оттенком цвета сферы (`fill-*`), текст на ней белый (`on-fill`).
- Цвет никогда не единственный носитель смысла: у пройденного этапа ✓ или слово, у просрочки — «просрочено».
- Текст: `ink` и `muted` на `node`/`bg`/`ground` от 4.5:1 в обеих темах. `dim` — только номера и засечки.

## Шрифты

- Onest (`sans`) — весь читаемый текст: `body` для строк, `task-now` для текущей задачи, `title` в окнах, `numeral` (вес 200) для больших цифр.
- JetBrains Mono (`mono`) — всё служебное: шапки нод и меню (`label`), время и счётчики (`data`), размерные линии и штамп (`micro`).
- Оба — Google Fonts: `family=Onest:wght@200;400;500;600&family=JetBrains+Mono:wght@400;500`.

## Схема: ноды, сокеты, провода

- Экран делится на три колонки с подписью-моно и линией: «01 · ИСТОЧНИКИ», «02 · СБОРКА», «03 · ВЫВОД».
- Нода: `node`, контур `line` 1px, `radius-md`. Шапка высотой `node-head`, залита `fill-*` цвета сферы, скруглена сверху: номер, название, справа вид («СПИСОК», «СТИКЕРЫ») — всё `on-fill`.
- Главная нода экрана: `radius-lg`, рамка `accent-line`, тень `lift`, четыре уголка `accent` по углам, шапка залита `fill-hub`.
- Нода, которая ждёт решения (входящие от Claude) — пунктирный контур, кольцевые сокеты `hue-grey`.
- Сокет — квадрат 10px с `radius-xs`, выступает за край ноды на половину и стоит ровно по центру своей строки. Заливка — цвет сферы, обводка цветом `ground`; у ждущих — наоборот.
- Провод — кубическая кривая от сокета к сокету, `M x1 y1 C x1+60 y1, x2-60 y2, x2 y2`, толщина `wire`, у текущей — `wire-now`. Пунктир 4/4 — у непринятого.
- Холст `ground` с точками 1px через `grid-minor`, `ink` 7%. Линейной сетки нет: она забирает внимание.

## Чертёжные детали

- Текущая задача — `accent-wash`, штриховка под −45° через 7px, рамка `accent`, `radius-md`.
- Размерная линия «| —— 09:00 — 21:00 · 12 Ч —— |» (`micro`, `dim`) под нодой, у которой есть длина во времени.
- Штамп листа в правом нижнем углу: название экрана, дата, сколько входов.
- Превью рендера — с мелкой сеткой, уголками `accent` и размером в пикселях.

## Состояния

- Под курсором — `node-hover`. Фокус клавиатуры — `focus`, сплошное кольцо 2px с отступом 2px.
- Выполненная задача — `dim`, зачёркнуто, чекбокс залит `line-strong` с ✓.
- Нет связи — нода-источник бледнеет до 50%, провод становится пунктиром, в шапке «НЕТ СВЯЗИ».

## Движение

- Провода рисуются от источника к ноде за 300 мс при открытии экрана; при «уменьшении движения» — сразу.
- Новая задача: сокет вспыхивает цветом сферы, по проводу пробегает точка (200 мс).

## Енот

- Енот-космонавт живёт в пунктирной ноде вывода: круг 50px и одна фраза с действием («Подключить»).
'''
w('README.md', README)

CSS = r'''/* Спутник · Схема — компоненты. Значения — только из токенов. */
.sp { font-family: var(--font-sans); font-size: 13px; line-height: 20px; color: var(--ink); }
.sp *, .sp *::before, .sp *::after { box-sizing: border-box; }
.sp-mono { font-family: var(--font-mono); }
.sp-label { font: 500 10.5px/14px var(--font-mono); letter-spacing: .14em; text-transform: uppercase; }
.sp-micro { font: 400 9.5px/12px var(--font-mono); letter-spacing: .12em; color: var(--dim); }

/* холст */
.sp-ground { background-color: var(--ground);
  background-image: radial-gradient(color-mix(in srgb, var(--ink) 7%, transparent) 1px, transparent 1.3px);
  background-size: var(--grid-minor) var(--grid-minor); }
.sp-colhead { display: flex; align-items: center; gap: var(--space-2); color: var(--dim); }
.sp-colhead::after { content: ""; flex: 1; height: 1px; background: var(--line); }

/* шапка */
.sp-hd { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 26px; padding: 14px 20px; background: var(--bg); border-bottom: 1px solid var(--line); }
.sp-brand { display: flex; align-items: center; gap: 10px; color: var(--ink); }
.sp-nav { display: flex; gap: 20px; flex-wrap: wrap; }
.sp-nav a { color: var(--muted); text-decoration: none; padding-bottom: 3px; border-bottom: 1px solid transparent; }
.sp-nav a:hover { color: var(--ink); }
.sp-nav a[aria-current="page"] { color: var(--ink); border-bottom-color: var(--accent); }
.sp-search { display: flex; align-items: center; gap: var(--space-2); height: 32px; padding: 0 10px; min-width: 150px; border: 1px solid var(--line); border-radius: var(--radius-md); color: var(--muted); }

/* кнопки */
.sp-btn { display: inline-flex; align-items: center; gap: 6px; height: 32px; padding: 0 14px; border-radius: var(--radius-sm); border: 1px solid var(--line-strong); background: transparent; color: var(--ink); font: 500 13px var(--font-sans); cursor: pointer; }
.sp-btn:hover { background: var(--node-hover); }
.sp-btn--accent { background: var(--accent-fill); border-color: var(--accent-fill); color: var(--on-accent); font-weight: 600; }
.sp-btn--accent:hover { background: var(--accent-fill); filter: brightness(1.06); }
.sp-btn--ink { background: var(--ink-fill); border-color: var(--ink-fill); color: var(--on-ink); font-weight: 600; border-radius: var(--radius-md); }
.sp-btn--ink:hover { background: var(--ink-fill); filter: brightness(.94); }
.sp-btn--sm { height: 28px; padding: 0 12px; font-size: 12.5px; }
.sp-btn:focus-visible, .sp-nav a:focus-visible, .sp-pill:focus-visible, .sp-field input:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }

/* нода */
.sp-node { position: relative; background: var(--node); border: 1px solid var(--line); border-radius: var(--radius-md); }
.sp-node--wait { border-style: dashed; border-color: var(--line-strong); }
.sp-node--hub { border-color: var(--accent-line); border-radius: var(--radius-lg); box-shadow: var(--lift); }
.sp-node__hd { height: var(--node-head); padding: 0 10px 0 12px; display: flex; align-items: center; gap: var(--space-2); background: var(--f, var(--fill-grey)); color: var(--on-fill); border-radius: calc(var(--radius-md) - 1px) calc(var(--radius-md) - 1px) 0 0; }
.sp-node--hub > .sp-node__hd { height: 34px; background: var(--fill-hub); border-radius: calc(var(--radius-lg) - 1px) calc(var(--radius-lg) - 1px) 0 0; }
.sp-node__hd .n { color: color-mix(in srgb, var(--on-fill) 65%, transparent); }
.sp-node__hd .kind { margin-left: auto; color: color-mix(in srgb, var(--on-fill) 72%, transparent); }
.sp-dot { width: 6px; height: 6px; border-radius: 2px; background: var(--c, var(--accent)); flex: none; }
.sp-node__row { height: var(--row); padding: 0 16px 0 12px; display: flex; align-items: center; justify-content: space-between; gap: var(--space-2); }
.sp-node__row .v { font: 400 11px var(--font-mono); color: var(--muted); }
.sp-tick { position: absolute; width: 14px; height: 14px; border: 0 solid var(--accent); }
.sp-tick.tl { left: -5px; top: -5px; border-left-width: 1.5px; border-top-width: 1.5px; border-top-left-radius: 14px; }
.sp-tick.tr { right: -5px; top: -5px; border-right-width: 1.5px; border-top-width: 1.5px; border-top-right-radius: 14px; }
.sp-tick.bl { left: -5px; bottom: -5px; border-left-width: 1.5px; border-bottom-width: 1.5px; border-bottom-left-radius: 14px; }
.sp-tick.br { right: -5px; bottom: -5px; border-right-width: 1.5px; border-bottom-width: 1.5px; border-bottom-right-radius: 14px; }

/* сокет и провод */
.sp-sock { position: absolute; width: 10px; height: 10px; border-radius: var(--radius-xs); background: var(--c, var(--accent)); border: 1.5px solid var(--ground); }
.sp-sock--ring { background: var(--ground); border-color: var(--c, var(--hue-grey)); }
.sp-sock.r { right: -6px; } .sp-sock.l { left: -6px; }
.sp-wire { fill: none; stroke: var(--c, var(--line-strong)); stroke-width: var(--wire); }
.sp-wire--now { stroke: var(--accent); stroke-width: var(--wire-now); }
.sp-wire--wait { stroke-dasharray: 4 4; }

/* строка задачи */
.sp-row { height: var(--row-task); display: flex; align-items: center; gap: var(--space-3); padding: 0 10px; border-bottom: 1px solid var(--line-soft); }
.sp-row:hover { background: var(--node-hover); }
.sp-row .n { width: 16px; font: 400 10.5px var(--font-mono); color: var(--dim); }
.sp-row .t { width: 42px; font: 400 11.5px var(--font-mono); color: var(--muted); font-variant-numeric: tabular-nums; }
.sp-row .x { flex: 1; min-width: 0; }
.sp-check { width: 14px; height: 14px; flex: none; border-radius: 4px; border: 1px solid var(--line-strong); display: grid; place-items: center; font-size: 9px; color: var(--ink); }
.sp-row--done { color: var(--dim); }
.sp-row--done .x { text-decoration: line-through; }
.sp-row--done .sp-check { background: var(--line-strong); border-color: var(--line-strong); }
.sp-now { padding: 10px; border-radius: var(--radius-md); border: 1px solid var(--accent); background-color: var(--accent-wash);
  background-image: repeating-linear-gradient(-45deg, color-mix(in srgb, var(--accent) 8%, transparent) 0 1px, transparent 1px 7px); display: flex; flex-direction: column; gap: 9px; }
.sp-now__top { display: flex; align-items: center; gap: var(--space-3); }
.sp-now__top .n { width: 16px; font: 400 10.5px var(--font-mono); color: var(--accent); }
.sp-now__top .t { width: 42px; font: 400 11.5px var(--font-mono); color: var(--accent-ink); }
.sp-now__top .x { flex: 1; font-weight: 600; font-size: 14px; }
.sp-now__top .sp-check { border-color: var(--accent); }
.sp-now__more { padding-left: 92px; display: flex; flex-direction: column; gap: 9px; }

/* дорожка этапов */
.sp-stages { display: flex; gap: 3px; }
.sp-stages > span { flex: 1; height: 4px; border-radius: 2px; background: var(--line-strong); }
.sp-stages > .ok { background: var(--hue-green); }
.sp-stages > .now { background: var(--accent); }
.sp-stage-names { display: flex; justify-content: space-between; font: 400 10px var(--font-mono); letter-spacing: .1em; color: var(--dim); }
.sp-stage-names .now { color: var(--accent); }

/* умная строка */
.sp-field { height: 36px; display: flex; align-items: center; gap: var(--space-2); padding: 0 8px 0 10px; border-radius: var(--radius-md); background: var(--bg); border: 1px solid var(--line-strong); }
.sp-field label { color: var(--accent); font-weight: 600; }
.sp-field input { flex: 1; min-width: 0; border: 0; background: transparent; color: var(--ink); font: 400 13px var(--font-sans); outline: none; }
.sp-field input::placeholder { color: var(--muted); }
.sp-field .kbd { font: 400 10px var(--font-mono); letter-spacing: .1em; color: var(--dim); }

/* привычки */
.sp-pill { height: 32px; padding: 0 12px; border-radius: var(--radius-pill); border: 1px solid var(--hue-gold); background: transparent; color: var(--ink); font: 500 12.5px var(--font-sans); cursor: pointer; }
.sp-pill--done { background: var(--hue-gold); color: var(--on-gold); font-weight: 600; }

/* метка «→ список» */
.sp-to { font: 400 11px var(--font-mono); letter-spacing: .06em; color: var(--c, var(--muted)); }

/* размерная линия */
.sp-dim { display: flex; align-items: center; gap: var(--space-2); }
.sp-dim::before, .sp-dim::after { content: ""; flex: 1; height: 1px; background: var(--line-strong); }
.sp-dim > .e { order: -1; } .sp-dim > .e:last-child { order: 9; }

/* штамп */
.sp-stamp { display: grid; grid-template-columns: repeat(3, 1fr); border: 1px solid var(--line); border-radius: var(--radius-md); font: 400 9.5px var(--font-mono); letter-spacing: .12em; color: var(--dim); }
.sp-stamp > * { padding: 6px 8px; }
.sp-stamp > .h { grid-column: 1 / 4; border-bottom: 1px solid var(--line); color: var(--ink); }
.sp-stamp > :not(.h):not(:last-child) { border-right: 1px solid var(--line); }
'''
w('components/bundle.css', CSS)

FONTS='<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Onest:wght@200;400;500;600&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap">'
def prev(name, group, h, body, sub=''):
    s = f'<!-- @dsCard group="{group}" height={h}' + (f' subtitle="{sub}"' if sub else '') + ' -->\n'
    s += f'<!doctype html>\n<html lang="ru">\n<head><meta charset="utf-8"><title>{name}</title>{FONTS}<style>body{{margin:0;background:var(--ground)}}</style></head>\n<body>\n{body}\n</body>\n</html>\n'
    return s
LOGO='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true"><ellipse cx="12" cy="12" rx="10" ry="4" transform="rotate(-28 12 12)" stroke="currentColor" stroke-width="1"></ellipse><path d="M15.5 8.2a5 5 0 1 0 0 7.6" stroke="currentColor" stroke-width="1.5"></path><rect x="18" y="6" width="3" height="3" style="fill:var(--accent)"></rect></svg>'

comps = {
'Header': ('Каркас', 64, '''<header class="sp sp-hd sp-label">
  <span class="sp-brand">'''+LOGO+'''СПУТНИК</span>
  <nav class="sp-nav" aria-label="Разделы"><a href="#" aria-current="page">СЕГОДНЯ</a><a href="#">КАЛЕНДАРЬ</a><a href="#">ДОСКА</a><a href="#">ПРИВЫЧКИ</a></nav>
  <span style="flex:1"></span>
  <span style="color:var(--muted)">ЧТ 05.11 · 14:52</span>
  <span class="sp-search">НАЙТИ<span style="margin-left:auto;font-size:10px;color:var(--dim)">CTRL K</span></span>
  <button type="button" class="sp-btn sp-btn--ink" style="letter-spacing:0;text-transform:none">＋ Создать</button>
</header>''',
'''# Header

Шапка приложения: знак, четыре раздела, дата, поиск и «＋ Создать».

- Разделы — `label` заглавными; активный — `ink` и линия `accent` снизу (`aria-current="page"`), остальные — `muted`.
- Справа налево: «＋ Создать» (`sp-btn--ink`), поиск «НАЙТИ · CTRL K», дата и время.
- Фон `bg`, снизу `line`. Других кнопок в шапке не добавлять: «Состояние», таймер и обновление — чипы того же вида, что поиск.
- Классы: `sp-hd`, `sp-brand`, `sp-nav`, `sp-search`.
'''),
'Node': ('Схема', 210, '''<div class="sp sp-ground" style="padding:20px;display:flex;gap:28px;flex-wrap:wrap;align-items:flex-start">
  <div class="sp-node" style="width:230px">
    <div class="sp-node__hd sp-label" style="--f:var(--fill-blue)"><span class="n">02</span><span>РАБОТА · КЛИЕНТЫ</span><span class="kind">СПИСОК</span></div>
    <div class="sp-node__row"><span>Созвон «Таверна»</span><span class="v">12:30</span></div>
    <div class="sp-node__row"><span>Счёт за октябрь</span><span class="v">ДЕНЬ</span></div>
    <span class="sp-sock r" style="--c:var(--hue-blue);top:37px"></span><span class="sp-sock r" style="--c:var(--hue-blue);top:65px"></span>
  </div>
  <div class="sp-node sp-node--wait" style="width:230px">
    <div class="sp-node__hd sp-label" style="--f:var(--fill-grey)"><span class="n">05</span><span>ОТ CLAUDE</span><span class="kind">ЖДУТ</span></div>
    <div class="sp-node__row"><span>Счёт «Таверне»</span><span class="sp-to" style="--c:var(--hue-blue)">→ РАБОТА</span></div>
    <div class="sp-node__row"><span>Референсы брони</span><span class="sp-to" style="--c:var(--accent)">→ 3D</span></div>
    <span class="sp-sock sp-sock--ring r" style="top:37px"></span><span class="sp-sock sp-sock--ring r" style="top:65px"></span>
  </div>
  <div class="sp-node sp-node--hub" style="width:260px;height:120px">
    <span class="sp-tick tl"></span><span class="sp-tick tr"></span><span class="sp-tick bl"></span><span class="sp-tick br"></span>
    <div class="sp-node__hd sp-label"><span>СЕГОДНЯ</span><span class="n">ЧТ 05.11</span><span class="kind">4 ЗАДАЧИ</span></div>
    <span class="sp-sock l" style="top:56px;--c:var(--hue-blue)"></span>
  </div>
</div>''',
'''# Node

Нода — единица экрана: источник (список, привычки), ждущая (входящие) или главная (экран целиком).

- Источник: `sp-node`, шапка `sp-node__hd` — заливка цвета сферы (`--f: var(--fill-…)`), номер, название, вид. Строки `sp-node__row` высотой `row`.
- Ждущая: `sp-node--wait`, пунктир и кольцевые сокеты. Используется, пока задачи не приняты.
- Главная: `sp-node--hub` — одна на экране, четыре `sp-tick`, тень `lift`, `radius-lg`.
- Цвет сферы передаётся переменной `--c`, сама шапка не заливается.
- Нельзя: тени на обычных нодах, две главных ноды, цветная заливка шапки.
'''),
'Wire': ('Схема', 150, '''<div class="sp sp-ground" style="position:relative;height:150px">
  <svg width="460" height="150" style="position:absolute;left:0;top:0" aria-hidden="true">
    <path class="sp-wire" style="--c:var(--hue-blue)" d="M120 30 C 180 30, 240 60, 300 60"></path>
    <path class="sp-wire sp-wire--now" d="M120 75 C 180 75, 240 80, 300 80"></path>
    <path class="sp-wire sp-wire--wait" style="--c:var(--hue-grey)" d="M120 120 C 180 120, 240 100, 300 100"></path>
  </svg>
  <span class="sp-sock" style="left:115px;top:25px;--c:var(--hue-blue)"></span>
  <span class="sp-sock" style="left:115px;top:70px"></span>
  <span class="sp-sock sp-sock--ring" style="left:115px;top:115px"></span>
  <span class="sp-sock" style="left:295px;top:55px;--c:var(--hue-blue)"></span><span class="sp-sock" style="left:295px;top:75px"></span><span class="sp-sock sp-sock--ring" style="left:295px;top:95px"></span>
  <span class="sp-micro" style="position:absolute;left:330px;top:54px">ОБЫЧНЫЙ</span><span class="sp-micro" style="position:absolute;left:330px;top:74px;color:var(--accent)">СЕЙЧАС</span><span class="sp-micro" style="position:absolute;left:330px;top:94px">ЖДЁТ</span>
</div>''',
'''# Wire

Сокет и провод связывают строку источника со строкой главной ноды.

- Сокет `sp-sock` (квадрат 10px, `radius-xs`) ставится по центру строки, на половину за краем ноды: `.r` справа, `.l` слева.
- Провод — SVG-кривая `M x1 y1 C x1+60 y1, x2-60 y2, x2 y2`, класс `sp-wire`, цвет сферы через `--c`.
- Текущая задача — `sp-wire--now` (`accent`, `wire-now`); непринятое — `sp-wire--wait` и `sp-sock--ring`.
- Провода лежат под нодами (SVG первым в слое), не пересекают текст.
'''),
'TaskRow': ('Задачи', 250, '''<div class="sp" style="background:var(--node);padding:12px;width:470px">
  <div class="sp-row sp-row--done"><span class="n">01</span><span class="sp-check">✓</span><span class="t">10:00</span><span class="x">Ретопология меча</span></div>
  <div class="sp-row"><span class="n">02</span><span class="sp-check"></span><span class="t">12:30</span><span class="x">Созвон с клиентом «Таверна»</span><span class="sp-dot" style="--c:var(--hue-blue)"></span></div>
  <div class="sp-now" style="margin-top:6px">
    <div class="sp-now__top"><span class="n">03</span><span class="sp-check"></span><span class="t">15:00</span><span class="x">Текстуры для щита, 2K</span><span class="sp-label" style="font-size:10px;color:var(--accent)">ДАЛЬШЕ · 8 МИН</span></div>
    <div class="sp-now__more">
      <div class="sp-stages" aria-label="Этапы: 2 из 5 готово, сейчас третий"><span class="ok"></span><span class="ok"></span><span class="now"></span><span></span><span></span></div>
      <div style="display:flex;gap:6px"><button type="button" class="sp-btn sp-btn--accent sp-btn--sm">▶ Начать</button><button type="button" class="sp-btn sp-btn--sm" style="border-color:var(--accent-line)">Перенести</button></div>
    </div>
  </div>
</div>''',
'''# TaskRow

Строка задачи в главной ноде: номер по порядку, отметка, время, название, точка сферы.

- `sp-row` высотой `row-task`; время в `data`, без времени — «ДЕНЬ».
- Выполненная — `sp-row--done`: `dim`, зачёркнуто, отметка залита.
- Текущая (одна на экране) — `sp-now`: штриховка, рамка `accent`, под названием дорожка этапов и кнопки «▶ Начать» и «Перенести».
- Точка в конце — цвет сферы списка (тот же, что у провода).
'''),
'Button': ('Действия', 80, '''<div class="sp" style="background:var(--node);padding:20px;display:flex;gap:10px;flex-wrap:wrap;align-items:center">
  <button type="button" class="sp-btn sp-btn--accent">▶ Начать</button>
  <button type="button" class="sp-btn">Перенести</button>
  <button type="button" class="sp-btn sp-btn--ink">＋ Создать</button>
  <button type="button" class="sp-btn sp-btn--sm">Принять</button>
</div>''',
'''# Button

Кнопки: главная, вторичная, кнопка шапки и малая.

- `sp-btn--accent` — одно главное действие на ноду («▶ Начать», «Добавить»), текст `on-accent`.
- `sp-btn` — вторичное: контур `line-strong`, прозрачная.
- `sp-btn--ink` — только «＋ Создать» в шапке.
- `sp-btn--sm` (28px) — внутри строк и текущей задачи.
- Подпись — глагол: «Перенести», «Принять», «Подключить». Фокус — кольцо `focus`.
'''),
'SmartInput': ('Ввод', 76, '''<div class="sp" style="background:var(--node);padding:20px">
  <div class="sp-field"><label for="ds-add">＋</label><input id="ds-add" type="text" placeholder="Добавить: «завтра 17:00 рендер щита»"><span class="kbd">SHIFT A</span></div>
</div>''',
'''# SmartInput

Умная строка добавления сверху главной ноды: текст словами, время и `#тип`, `@список` распознаются.

- `sp-field`: фон `bg`, рамка `line-strong`, `radius-md`, высота 36px.
- Слева ＋ цвета `accent` (это `label` поля), справа клавиша в `micro`.
- Подсказка — пример реальной фразы в кавычках-ёлочках.
'''),
'HabitPill': ('Привычки', 76, '''<div class="sp" style="background:var(--node);padding:20px;display:flex;gap:6px;flex-wrap:wrap">
  <button type="button" class="sp-pill sp-pill--done">✓ Зарядка · 21</button>
  <button type="button" class="sp-pill">Вода 5/8</button>
  <button type="button" class="sp-pill">Скетч · вечер</button>
</div>''',
'''# HabitPill

Привычка на сегодня — таблетка, отметить в одно касание.

- Единственное место с `radius-pill`. Контур `hue-gold`, отмеченная — заливка `hue-gold` и ✓ с серией.
- У количества — «5/8», у части дня — «· вечер».
'''),
'StageTrack': ('Задачи', 70, '''<div class="sp" style="background:var(--node);padding:20px;display:flex;flex-direction:column;gap:6px;max-width:420px">
  <div class="sp-stages" aria-label="Этапы: 2 из 5 готово, сейчас покраска"><span class="ok"></span><span class="ok"></span><span class="now"></span><span></span><span></span></div>
  <div class="sp-stage-names"><span>МОДЕЛЬ ✓</span><span>UV ✓</span><span class="now">ПОКРАСКА</span><span>РЕНДЕР</span><span>СДАЧА</span></div>
</div>''',
'''# StageTrack

Дорожка этапов ассета: сегменты по числу этапов и подписи под ними.

- Пройденный — `hue-green` и ✓ в подписи, текущий — `accent`, будущие — `line-strong`.
- Подписи — `micro`/моно 10px, текущая — `accent`.
'''),
'Blueprint': ('Схема', 140, '''<div class="sp sp-ground" style="padding:20px;display:flex;flex-direction:column;gap:16px">
  <div class="sp-colhead sp-label" style="max-width:460px">02 · СБОРКА ДНЯ</div>
  <div class="sp-dim sp-micro" style="max-width:460px"><span class="e">|</span><span>09:00 — 21:00 · ЗАНЯТО 7 Ч · СВОБОДНО 17—19</span><span class="e">|</span></div>
  <div class="sp-stamp" style="width:280px"><span class="h">ЛИСТ · СЕГОДНЯ</span><span>05.11.26</span><span>ВХОДОВ 06</span><span>ВЕРСИЯ G2</span></div>
</div>''',
'''# Blueprint

Чертёжные детали: заголовок колонки, размерная линия, штамп листа.

- `sp-colhead` — номер и название колонки схемы, справа линия `line`.
- `sp-dim` — размерная линия под нодой, у которой есть длина во времени (день, неделя). Текст — факт, не украшение.
- `sp-stamp` — один на экран, правый нижний угол: экран, дата, число входов.
'''),
}
for name,(g,h,body,readme) in comps.items():
    w(f'components/{name}/preview.html', prev(name,g,h,body))
    w(f'components/{name}/README.md', readme)

COVER = '''<!-- @dsCard height=288 -->
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<title>Спутник · Схема</title>
'''+FONTS+'''
<style>
  html, body { margin:0; height:100%; }
  body { background:var(--ground); color:var(--ink); font-family:var(--font-sans); overflow:hidden; }
  .cover { position:relative; height:288px; overflow:hidden; }
  .art { position:absolute; top:0; left:480px; width:480px; height:288px; overflow:hidden; }
  .art svg { display:block; width:480px; height:288px; }
  .nd { fill:var(--node); stroke:var(--line-strong); stroke-width:1; rx:var(--radius-md); }
  .hub { fill:var(--accent-wash); stroke:var(--accent); stroke-width:1.5; rx:var(--radius-lg); }
  .acc { fill:var(--accent-fill); rx:var(--radius-md); }
  .blue { fill:var(--hue-blue); rx:var(--radius-md); }
  .gold { fill:var(--hue-gold); rx:var(--radius-md); }
  .sk { rx:var(--radius-xs); }
  .sk.a { fill:var(--accent); } .sk.b { fill:var(--hue-blue); } .sk.g { fill:var(--hue-gold); } .sk.v { fill:var(--hue-violet); }
  .w { fill:none; stroke-width:2; }
  .w.a { stroke:var(--accent); } .w.b { stroke:var(--hue-blue); } .w.g { stroke:var(--hue-gold); }
  .words { position:absolute; left:24px; right:24px; bottom:24px; max-width:440px; }
  .name { margin:0; font-size:96px; line-height:.92; font-weight:500; letter-spacing:-.03em; color:var(--ink); }
  .tag { margin:8px 0 0 4px; font:400 13px/20px var(--font-mono); letter-spacing:.08em; color:var(--muted); }
</style>
</head>
<body>
<div class="cover">
<div class="art" aria-hidden="true">
<svg viewBox="0 0 480 288" width="480" height="288">
<!--
  blocks      accent-fill 120×96 (главный цвет) · accent-wash главная нода 168×208 с рамкой accent · hue-blue 120×48 · hue-gold 120×48 · node 120×64 — около трети обложки
  arrangement слева колонка источников, справа одна большая нода, которая уходит за правый край, как главная нода экрана
  pattern     литеральный мотив «ноды и провода»: квадратные сокеты 10px с radius-xs и три провода-кривые, из README «Схема: ноды, сокеты, провода»
  scales      стороны кратны space-5 (24px) и space-4; зазоры space-5; углы radius-md, главная нода radius-lg, сокеты radius-xs
-->
<rect class="acc" x="24" y="24" width="120" height="96" rx="8"/>
<rect class="blue" x="24" y="144" width="120" height="48" rx="8"/>
<rect class="gold" x="24" y="216" width="120" height="48" rx="8"/>
<rect class="hub" x="312" y="40" width="192" height="208" rx="12"/>
<rect class="nd" x="168" y="-24" width="96" height="64" rx="8"/>
<path class="w a" d="M149 72 C 230 72, 240 112, 312 112"/>
<path class="w b" d="M149 168 C 230 168, 240 152, 312 152"/>
<path class="w g" d="M149 240 C 230 240, 240 192, 312 192"/>
<rect class="sk a" x="139" y="67" width="10" height="10" rx="3"/>
<rect class="sk b" x="139" y="163" width="10" height="10" rx="3"/>
<rect class="sk g" x="139" y="235" width="10" height="10" rx="3"/>
<rect class="sk a" x="307" y="107" width="10" height="10" rx="3"/>
<rect class="sk b" x="307" y="147" width="10" height="10" rx="3"/>
<rect class="sk g" x="307" y="187" width="10" height="10" rx="3"/>
<rect class="sk v" x="259" y="11" width="10" height="10" rx="3"/>
</svg>
</div>
<div class="words">
<h1 class="name">Спутник</h1>
<p class="tag">ДЕНЬ СОБИРАЕТСЯ ИЗ СПИСКОВ, КАК СХЕМА ИЗ НОД</p>
</div>
</div>
</body>
</html>
'''
w('components/Cover/preview.html', COVER)

now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
idx = {"v":3,"layout":"files","createdOnFiles":{"v":1,"at":now},"title":"Спутник · Схема","namespace":"Sputnik","libraries":[],
 "sections":{},"groups":[],"assetGroups":{},"blobs":{},"docs":{"readme":"project/README.md","sections":[]},
 "lastChange":{"by":"Siponik","at":now,"via":"Claude Code","note":"Первая версия системы на основе варианта G"}}
w('design-system.json', json.dumps(idx, ensure_ascii=False, indent=1))
print('done')
