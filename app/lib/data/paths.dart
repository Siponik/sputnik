// Где лежат данные. Пилот только ЧИТАЕТ папку старого приложения (token.json, layer.json, client_secret.json).
import 'dart:io';

String dataDir() {
  final appdata = Platform.environment['APPDATA'];
  if (appdata == null) throw StateError('Нет переменной APPDATA (пилот работает только в Windows)');
  return '$appdata${Platform.pathSeparator}com.siponik.sputnik';
}

File dataFile(String name) => File('${dataDir()}${Platform.pathSeparator}$name');
