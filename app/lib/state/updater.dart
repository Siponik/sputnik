// Обновление нового Спутника из приложения. Сборка кладёт в пререлиз «app-beta» zip и app-latest.json
// { version, url, notes }. Проверка через 30 с после запуска и раз в 6 ч; «Обновить» — скачать zip,
// распаковать рядом и перезапуститься (bat-файл ждёт выхода программы, потом копирует файлы).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0-dev');
const _latest = 'https://github.com/Siponik/sputnik/releases/download/app-beta/app-latest.json';

/// Сравнение «1.2.3» по числам; true, если a новее b.
bool newer(String a, String b) {
  List<int> p(String v) => v.split(RegExp(r'[.+-]')).map((x) => int.tryParse(x) ?? 0).toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 4; i++) {
    final m = i < x.length ? x[i] : 0, n = i < y.length ? y[i] : 0;
    if (m != n) return m > n;
  }
  return false;
}

class Updater extends ChangeNotifier {
  Map<String, dynamic>? found;
  bool busy = false;
  String status = 'Проверка ещё не запускалась';
  Timer? _t;

  /// Настройка «Проверять сами» (settings.update.auto); выключено — только ручная проверка.
  bool Function() autoOn = () => true;

  void start() {
    Timer(const Duration(seconds: 30), () => autoOn() ? check() : null);
    _t = Timer.periodic(const Duration(hours: 6), (_) => autoOn() ? check() : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> check() async {
    if (busy) return;
    busy = true;
    status = 'Проверяю…';
    notifyListeners();
    final c = HttpClient();
    try {
      final req = await c.getUrl(Uri.parse(_latest));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final v = (j['version'] ?? '') as String;
      if (newer(v, appVersion)) {
        found = j;
        status = 'Вышла версия $v';
      } else {
        found = null;
        status = 'Стоит последняя версия';
      }
    } catch (e) {
      status = 'Не удалось проверить: $e';
    } finally {
      c.close();
      busy = false;
      notifyListeners();
    }
  }

  Future<void> install() async {
    final f = found;
    if (f == null || busy || !Platform.isWindows) return;
    busy = true;
    status = 'Скачиваю…';
    notifyListeners();
    final c = HttpClient();
    try {
      final tmp = await Directory.systemTemp.createTemp('sputnik-upd');
      final zip = File('${tmp.path}\\app.zip');
      final req = await c.getUrl(Uri.parse(f['url'] as String));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      await res.pipe(zip.openWrite());
      final dir = File(Platform.resolvedExecutable).parent.path;
      final exe = Platform.resolvedExecutable;
      final bat = File('${tmp.path}\\update.bat');
      await bat.writeAsString(
        '@echo off\r\n'
        'timeout /t 2 /nobreak >nul\r\n'
        'powershell -NoProfile -Command "Expand-Archive -Force \'${zip.path}\' \'${tmp.path}\\new\'"\r\n'
        'robocopy "${tmp.path}\\new" "$dir" /E /NFL /NDL /NJH /NJS >nul\r\n'
        'start "" "$exe"\r\n',
      );
      await Process.start('cmd', ['/c', bat.path], mode: ProcessStartMode.detached);
      exit(0);
    } catch (e) {
      status = 'Не обновилось: $e';
      busy = false;
      notifyListeners();
    } finally {
      c.close();
    }
  }
}

final updater = Updater();
