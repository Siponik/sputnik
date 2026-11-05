// Чистые помощники входа в Google (OAuth для настольных приложений, PKCE), порт части tracker/src-tauri/src/google.rs.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
const tokenUrl = 'https://oauth2.googleapis.com/token';

/// Те же доступы, что у старого приложения (src/scopes.rs).
const requiredScopes = [
  'https://www.googleapis.com/auth/tasks',
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/drive.appdata',
];
const scopeNames = {
  'https://www.googleapis.com/auth/tasks': 'Задачи',
  'https://www.googleapis.com/auth/calendar': 'Календарь',
  'https://www.googleapis.com/auth/drive.file': 'Файлы Спутника на Drive',
  'https://www.googleapis.com/auth/drive.appdata': 'Скрытая папка Спутника на Drive',
};

String requestedScopes() => [...requiredScopes, 'https://www.googleapis.com/auth/userinfo.email'].join(' ');

/// Каких нужных доступов нет в выданной строке scope.
List<String> missingScopes(String granted) {
  final got = granted.split(RegExp(r'\s+')).toSet();
  return requiredScopes.where((s) => !got.contains(s)).toList();
}

String b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String randomB64(int n, [Random? rnd]) {
  final r = rnd ?? Random.secure();
  return b64url(List.generate(n, (_) => r.nextInt(256)));
}

String pkceChallenge(String verifier) => b64url(sha256.convert(ascii.encode(verifier)).bytes);

/// Ключ клиента из текста client_secret.json: {installed|web: {client_id, client_secret}}.
({String id, String secret})? parseSecret(String text) {
  try {
    final j = jsonDecode(text.replaceFirst('﻿', '')) as Map<String, dynamic>;
    final c = (j['installed'] ?? j['web']) as Map<String, dynamic>?;
    final id = (c?['client_id'] as String?)?.trim() ?? '';
    if (!id.endsWith('.apps.googleusercontent.com')) return null;
    return (id: id, secret: ((c?['client_secret'] ?? '') as String).trim());
  } catch (_) {
    return null;
  }
}

Uri authorizeUri({
  required String clientId,
  required String redirect,
  required String challenge,
  required String state,
}) => Uri.parse(authUrl).replace(
  queryParameters: {
    'client_id': clientId,
    'redirect_uri': redirect,
    'response_type': 'code',
    'scope': requestedScopes(),
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
    'access_type': 'offline',
    'prompt': 'consent',
    'state': state,
  },
);
