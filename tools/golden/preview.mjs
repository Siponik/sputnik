// Золотые данные для preview. Запуск: node tools/golden/preview.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as P from '../../tracker/src/lib/preview.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
for (const [w, h, m] of [[1920, 1080, 240], [100, 50, 240], [1, 5000, 240], [0, 10, 240], [-5, 10, 1600], [3000, 3000, 1600], [1601, 1, 1600], [333, 999, 240], [null, 5, 240], [2.5, 2.5, 1]])
  out.push({ fn: 'fitSize', w, h, m, out: P.fitSize(w, h, m) });
for (const u of ['data:image/jpeg;base64,QUJD', 'data:image/png;base64,', 'data:text/plain,abc', 'data:image/png;base64,a\nb', null, '', 'xdata:image/png;base64,AA'])
  out.push({ fn: 'dataUrlParts', u, out: P.dataUrlParts(u) });
const FILES = [null, {}, { type: 'image/png' }, { type: 'IMAGE/JPEG', size: 10 }, { type: 'image/jpg' }, { type: 'image/svg+xml' }, { type: 'image/avif', size: 31 * 1024 * 1024 }, { type: 'text/plain' }, { type: 'image/webp', size: 30 * 1024 * 1024 }];
for (const f of FILES) out.push({ fn: 'isImage', f, out: P.isImage(f) }, { fn: 'rejectWhy', f, out: P.rejectWhy(f) });
for (const t of [null, [], ['text/plain'], ['Files', 'text/uri-list']]) out.push({ fn: 'dragHasFile', t, out: P.dragHasFile(t ? { types: t } : null) });
for (const t of ['Сундук: финал/v2?', '  ', null, 'a\tb\nc', 'x'.repeat(100), 'ок <"|*>']) out.push({ fn: 'fileName', t, out: P.fileName(t) });
for (const L of [null, {}, { preview: {} }, { preview: { thumb: 'data:x' } }]) out.push({ fn: 'has', L, out: P.has(L) });
out.push({ fn: 'consts', out: [P.THUMB, P.FULL, P.MAX_BYTES] });
write('preview.json', out);
console.log(out.length);
