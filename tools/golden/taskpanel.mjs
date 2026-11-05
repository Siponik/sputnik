// Золотые данные для taskpanel. Запуск: TZ=Europe/Moscow node tools/golden/taskpanel.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as P from '../../tracker/src/lib/taskpanel.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const cols = [{ id: 'todo' }, { id: 'doing' }, { id: 'done' }];
const tasks = [{ id: 'a' }, { id: 'b' }, { id: 'c', status: 'completed' }, { id: 'd', parent: 'a' }, { id: 'e' }, { id: 'f' }];
for (const lay of [{}, null, { a: { status: 'doing' }, b: { status: 'done' }, e: { status: 'nope' }, f: { status: 'doing' } }])
  for (const c of [cols, []]) out.push({ fn: 'colCounts', tasks, cols: c, lay, out: P.colCounts(tasks, c, lay) });
out.push({ fn: 'colCounts', tasks: [], cols, lay: {}, out: P.colCounts([], cols, {}) });
for (const v of ['pipe', 'kanban', 'list']) for (const n of [0, 3, 4, 5]) {
  const c = Array.from({ length: n }, (_, i) => ({ id: 'c' + i }));
  out.push({ fn: 'stageMode', v, cols: c, out: P.stageMode(v, c) });
}
for (const m of [0, 5, 15, 60, 1440, 7, 43200]) out.push({ fn: 'leadChip', m, out: P.leadChip(m) });
const RULES = [null, { kind: 'at', at: '2026-10-29T18:00' }, { kind: 'at', at: '2026-01-05' }, { kind: 'at', at: '2026-12-31T07:05:00' }, { kind: 'at', at: '' },
  { kind: 'at' }, { kind: 'at', at: 'мусор' }, { kind: 'before', days: 1, time: '10:00' }, { kind: 'before' }, { kind: 'before', days: 5, time: '08:00' }, { kind: 'before', days: 30 },
  ...Array.from({ length: 12 }, (_, i) => ({ kind: 'at', at: `2026-${String(i + 1).padStart(2, '0')}-15T09:00` }))];
for (const r of RULES) out.push({ fn: 'customChip', r, out: P.customChip(r) });
const REM = [null, { kind: 'lead', min: 60 }, [{ kind: 'lead', min: 60 }, { kind: 'lead', min: 0 }, { kind: 'before', days: 1, time: '09:00' }, { kind: 'at', at: 'x' }], { kind: 'at', at: '2026-10-29T18:00' }];
for (const r of REM) out.push({ fn: 'splitRemind', r, out: P.splitRemind(r) });
for (const [l, c] of [[[], null], [[60], null], [[], { kind: 'at', at: 'x' }], [[60, 0], { kind: 'before', days: 1 }]]) out.push({ fn: 'joinRemind', l, c, out: P.joinRemind(l, c) });
for (const L of [{}, null, { repeat: { every: 'day' } }, { repeat: {} }, { type: 'work' }, { preview: { thumb: 'x' } }, { type: '' }]) out.push({ fn: 'moreFilled', L, out: P.moreFilled(L) });
write('taskpanel.json', out);
console.log(out.length);
