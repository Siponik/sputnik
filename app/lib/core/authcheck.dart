// Порт tracker/src/lib/authcheck.js — проверка client_secret.json и тексты ошибок входа.
import 'dart:convert';

const secretMax = 64 * 1024;

/// '' — похоже на ключ Desktop app; иначе — что не так.
String checkSecretText(Object? text, [int? size]) {
  final str = (text ?? '').toString();
  if ((size ?? str.length) > secretMax) {
    return 'Файл слишком большой — это не client_secret.json. Нужен маленький файл ключа из Google Cloud.';
  }
  final t = str.replaceFirst(RegExp('^﻿'), '').trim();
  if (t.isEmpty) return 'Файл пустой. Скачай JSON клиента в Google Cloud ещё раз.';
  Object? j;
  try {
    j = jsonDecode(t);
  } catch (_) {
    return 'Это не похоже на client_secret.json: в файле не JSON.';
  }
  if (j is! Map) return 'Это не похоже на client_secret.json из Google Cloud.';
  bool truthy(Object? v) => v != null && v != false && v != 0 && v != '';
  if (!truthy(j['installed']) && truthy(j['web'])) {
    return 'Это ключ типа «Веб-приложение», а нужен «Приложение для компьютера» (Desktop app). Создай в Google Cloud клиента Desktop app и скачай его JSON.';
  }
  if (j['type'] == 'service_account') {
    return 'Это ключ сервисного аккаунта, а нужен ключ OAuth типа Desktop app (Google Cloud → Clients).';
  }
  final inst = j['installed'];
  if (!truthy(inst) || inst is! Map) {
    return 'В файле нет раздела «installed» — нужен ключ OAuth типа Desktop app из Google Cloud → Clients.';
  }
  final id = (inst['client_id'] ?? '').toString().trim();
  if (id.isEmpty || RegExp(r'\s').hasMatch(id) || !id.endsWith('.apps.googleusercontent.com')) {
    return 'В файле неправильный client_id — скачай JSON клиента заново.';
  }
  return '';
}

bool isStopped(Object? e) => (e ?? '').toString().contains('Вход прерван');

bool isScopeLack(Object? e) => RegExp(
  r'не дал(?: Спутнику все)? доступ|insufficient authentication scopes',
  caseSensitive: false,
).hasMatch((e ?? '').toString());

String loginHint(Object? e) {
  final s = (e ?? '').toString().replaceFirst(RegExp(r'^Error:\s*'), '');
  if (s.isEmpty || isStopped(s)) return '';
  if (isScopeLack(s)) {
    final names = RegExp(r'не дал доступ — (.+?)\.').firstMatch(s)?[1];
    return '${names != null ? 'Google не дал доступ: $names.' : 'Google не дал Спутнику все доступы.'}'
        ' Нажми «Открыть вход» ещё раз и на странице Google отметь все галочки (или «Выбрать всё»).';
  }
  if (s.contains('access_denied')) {
    return 'Вход отменён на странице Google. Если там было «доступ заблокирован» — приложение в Google Cloud ещё в режиме теста: добавь свою почту в тестовые пользователи или опубликуй его.';
  }
  if (RegExp(r'invalid_client|unauthorized_client|401', caseSensitive: false).hasMatch(s)) {
    return 'Google не принял ключ приложения. Верни встроенный ключ или скачай client_secret.json заново.';
  }
  if (s.contains('за 5 минут')) return 'Вход не завершился за 5 минут. Нажми «Открыть вход» ещё раз.';
  return s;
}

/// Первый запуск: включены только основной календарь и праздники.
bool calDefaultOn(Object? c) =>
    c is Map && ((c['primary'] != null && c['primary'] != false) || (c['id'] ?? '').toString().contains('#holiday@'));
