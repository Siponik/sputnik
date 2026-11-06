// Где лежат данные. Папка старого приложения читается (token.json, layer.json, client_secret.json),
// а пишет новое приложение только в подпапку flutter/ (docs/flutter-architecture.md, п. 6).
import 'dart:io';

String dataDir() {
  // Не Windows (тесты, позже Android): своя папка во временной.
  final appdata =
      Platform.environment['APPDATA'] ?? '${Directory.systemTemp.path}${Platform.pathSeparator}sputnik-data';
  return '$appdata${Platform.pathSeparator}com.siponik.sputnik';
}

File dataFile(String name) => File('${dataDir()}${Platform.pathSeparator}$name');

/// Файл в своей подпапке flutter/ (папка создаётся при записи).
File ownFile(String name) => File('${dataDir()}${Platform.pathSeparator}flutter${Platform.pathSeparator}$name');
