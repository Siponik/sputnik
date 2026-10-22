// «Что нового» для релиза трекера (.github/workflows/tracker-build.yml) — то, что видно в приложении у чипа обновления.
//   node tools/ci/notes.mjs <теги релизов…>
//       печатает список «- …» по изменениям трекера с прошлого релиза.
// Откуда пункты: из PR, слитых после прошлого релиза, — раздел «## Что нового» в описании PR (1–3 пункта
// простыми словами для пользователя). У PR без такого раздела — названия его коммитов (без «Merge pull request…»).
// Учитываются только PR и коммиты, которые меняют tracker/.
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const MAX = 8;

/** Пункты раздела «Что нового» из описания PR: строки «- …», «* …», «• …» до следующего заголовка или первой строки не-списка. */
export function sectionItems(body) {
  const lines = String(body ?? '').split(/\r?\n/);
  const out = [];
  let inside = false;
  for (const raw of lines) {
    const s = raw.trim();
    if (/^#{1,6}\s/.test(s)) {
      inside = /^#{1,6}\s*что нового/i.test(s);
      continue;
    }
    if (!inside || !s || /^<!--/.test(s)) continue;
    const m = /^[-*•✦]\s+(.+)$/.exec(s);
    if (m) out.push(m[1].trim());
    else if (out.length) inside = false; // раздел кончился и без заголовка: дальше обычный текст («**Что сделано:**» и т. п.)
  }
  return out.filter((s) => s && !/^<!--/.test(s));
}

/** Название коммита как пункт: без служебных («Merge…», «Revert…») и без хвоста «(#42)». null — пропустить. */
export function subjectItem(subject) {
  const s = String(subject ?? '').trim();
  if (!s || /^(merge|revert)\b/i.test(s)) return null;
  return s.replace(/\s*\(#\d+\)\s*$/, '').replace(/^Трекер:\s*/i, '');
}

/**
 * Итоговая заметка. changes — по порядку от старых к новым: { body, subjects } (PR) или { subjects } (коммит без PR).
 * Повторы убираются, пунктов не больше max; пусто — общая фраза.
 */
export function releaseNotes(changes, max = MAX) {
  const items = [];
  const seen = new Set();
  const add = (s) => {
    const key = s.toLowerCase().replace(/[.\s]+$/, '');
    if (!key || seen.has(key)) return;
    seen.add(key);
    items.push(s);
  };
  // Свежие изменения — первыми: в приложении видно только несколько верхних пунктов.
  for (const c of [...changes].reverse()) {
    const own = sectionItems(c.body);
    const list = own.length ? own : (c.subjects ?? []).map(subjectItem).filter(Boolean);
    list.forEach(add);
  }
  if (!items.length) return '- Небольшие исправления и улучшения.';
  const shown = items.slice(0, max).map((s) => `- ${s}`);
  if (items.length > max) shown.push(`- И ещё ${items.length - max} — подробности на странице релиза.`);
  return shown.join('\n');
}

/** Номер PR из названия коммита слияния: «Merge pull request #44 from …» или «… (#42)». */
export function prNumber(subject) {
  const m = /^Merge pull request #(\d+)\b/.exec(subject ?? '') || /\(#(\d+)\)\s*$/.exec(subject ?? '');
  return m ? Number(m[1]) : null;
}

/** Последний тег релиза по номеру версии («tracker-0.6.69» больше «tracker-0.6.7»). */
export function lastTag(tags) {
  const ver = (t) => (/^tracker-(\d+)\.(\d+)\.(\d+)$/.exec(String(t).trim()) ?? []).slice(1).map(Number);
  const ok = tags.map((t) => String(t).trim()).filter((t) => ver(t).length === 3);
  ok.sort((a, b) => {
    const [x, y] = [ver(a), ver(b)];
    return x[0] - y[0] || x[1] - y[1] || x[2] - y[2];
  });
  return ok.at(-1) ?? null;
}

const git = (...args) => execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
const lines = (s) => s.split('\n').filter(Boolean);
const touchesTracker = (from, to) => {
  try {
    git('diff', '--quiet', from, to, '--', 'tracker/');
    return false;
  } catch {
    return true;
  }
};

function prBody(num) {
  try {
    // REST, а не `gh pr view` (GraphQL): так работает и в Actions, и из облачных сессий.
    return execFileSync('gh', ['api', `repos/${process.env.GITHUB_REPOSITORY || '{owner}/{repo}'}/pulls/${num}`, '--jq', '.body // ""'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return '';
  }
}

/** Изменения от прошлого релиза до HEAD по первой линии main: слияния PR и прямые коммиты. */
function collect(tag) {
  let range = 'HEAD~20..HEAD';
  if (tag) {
    try {
      git('rev-parse', '--verify', `${tag}^{commit}`);
      range = `${tag}..HEAD`;
    } catch {}
  }
  const changes = [];
  for (const sha of lines(git('rev-list', '--first-parent', '--reverse', range))) {
    const parents = git('rev-list', '--parents', '-n', '1', sha).split(' ').slice(1);
    if (!parents.length || !touchesTracker(parents[0], sha)) continue;
    const subject = git('log', '-1', '--format=%s', sha);
    const num = prNumber(subject);
    if (parents.length > 1) {
      const subjects = lines(git('log', '--no-merges', '--reverse', '--format=%s', `${parents[0]}..${sha}`, '--', 'tracker/'));
      changes.push({ body: num ? prBody(num) : '', subjects });
    } else {
      changes.push({ body: num ? prBody(num) : '', subjects: [subject] });
    }
  }
  return changes;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.log(releaseNotes(collect(lastTag(process.argv.slice(2)))));
}
