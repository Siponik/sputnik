// Помощник сборки трекера в GitHub Actions (.github/workflows/tracker-build.yml).
//   node tools/ci/tracker-release.mjs prepare <номер сборки>
//       версия 0.3.<N> в tauri.conf.json; без ключа подписи (секрет TAURI_SIGNING_PRIVATE_KEY) — без файлов обновления,
//       чтобы сборка не падала, пока секреты не заведены.
//   node tools/ci/tracker-release.mjs latest <номер сборки> <путь к .msi> <заметка>
//       пишет latest.json для обновления из приложения (рядом с .msi должен лежать .msi.sig).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const CONF = join(root, 'tracker', 'src-tauri', 'tauri.conf.json');
const REPO = 'Siponik/sputnik'; // репозиторий публичный — приложение читает релизы без пароля
const [cmd, run, ...rest] = process.argv.slice(2);
if (!/^\d+$/.test(run ?? '')) throw new Error('Нужен номер сборки');
const version = `0.3.${run}`;

if (cmd === 'prepare') {
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
