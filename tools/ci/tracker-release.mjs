// Помощник сборки трекера в GitHub Actions (.github/workflows/tracker-build.yml).
//   node tools/ci/tracker-release.mjs next <теги релизов…>
//       печатает следующую версию: МАЖОР.МИНОР из tauri.conf.json, третье число — следующее после уже вышедших
//       (первый релиз минора — x.y.0; см. version.mjs).
//   node tools/ci/tracker-release.mjs prepare <версия>
//       версия в tauri.conf.json; без ключа подписи (секрет TAURI_SIGNING_PRIVATE_KEY) — без файлов обновления,
//       чтобы сборка не падала, пока секреты не заведены.
//   node tools/ci/tracker-release.mjs latest <версия> <путь к .msi> <заметка>
//       пишет latest.json для обновления из приложения (рядом с .msi должен лежать .msi.sig).
// Секрет читается при старте задания: сборка, начатая до того, как секрет завели, выйдет без подписи.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { nextVersion } from './version.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const CONF = join(root, 'tracker', 'src-tauri', 'tauri.conf.json');
const REPO = 'Siponik/sputnik'; // репозиторий публичный — приложение читает релизы без пароля
const [cmd, arg, ...rest] = process.argv.slice(2);
const version = arg;
if (cmd !== 'next' && !/^\d+\.\d+\.\d+$/.test(version ?? '')) throw new Error('Нужна версия вида 0.6.0');

if (cmd === 'next') {
  const conf = JSON.parse(readFileSync(CONF, 'utf8'));
  console.log(nextVersion(conf.version, process.argv.slice(3)));
} else if (cmd === 'prepare') {
  const conf = JSON.parse(readFileSync(CONF, 'utf8'));
  conf.version = version;
  const signed = !!process.env.TAURI_SIGNING_PRIVATE_KEY;
  conf.bundle.createUpdaterArtifacts = signed;
  writeFileSync(CONF, JSON.stringify(conf, null, 2) + '\n');
  console.log(`Версия ${version}; файлы обновления: ${signed ? 'да' : 'нет (нет секрета TAURI_SIGNING_PRIVATE_KEY)'}`);
} else if (cmd === 'latest') {
  const [msi, notes = ''] = rest;
  if (!existsSync(`${msi}.sig`)) throw new Error(`Нет подписи ${msi}.sig`);
  const latest = {
    version,
    notes,
    pub_date: new Date().toISOString(),
    platforms: {
      'windows-x86_64': {
        signature: readFileSync(`${msi}.sig`, 'utf8').trim(),
        url: `https://github.com/${REPO}/releases/download/tracker-${version}/${encodeURIComponent(basename(msi))}`,
      },
    },
  };
  writeFileSync(join(dirname(msi), 'latest.json'), JSON.stringify(latest, null, 2) + '\n');
  console.log(`latest.json для ${version} готов`);
} else {
  throw new Error(`Неизвестная команда ${cmd}`);
}
