// Токен доступа Google из token.json старого приложения (формат: access_token, refresh_token, expires_at в секундах).
// Если токен просрочен — обновляет его через client_secret.json, когда он лежит в папке. Назад в файл не пишет (пилот).
import 'dart:convert';
import 'dart:io';

import 'paths.dart';

class AuthError implements Exception {
  AuthError(this.message);
  final String message;
  @override
  String toString() => message;
}

class GoogleAuth {
  String? _access;
  int _expires = 0;

  Future<String> accessToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_access != null && _expires > now + 60) return _access!;
    final f = dataFile('token.json');
    if (!await f.exists()) throw AuthError('Нет token.json: войди в Google в старом Спутнике');
    final t = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final exp = (t['expires_at'] as num?)?.toInt() ?? 0;
    if (exp > now + 60) {
      _access = t['access_token'] as String;
      _expires = exp;
      return _access!;
    }
    final refresh = t['refresh_token'] as String?;
    final sec = dataFile('client_secret.json');
    if (refresh == null || !await sec.exists()) {
      throw AuthError('Токен просрочен. Открой старый Спутник на минуту: он обновит вход');
    }
    final s = jsonDecode(await sec.readAsString()) as Map<String, dynamic>;
    final c = (s['installed'] ?? s['web']) as Map<String, dynamic>;
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      req.write(Uri(queryParameters: {
        'client_id': c['client_id'] as String,
        'client_secret': (c['client_secret'] ?? '') as String,
        'refresh_token': refresh,
        'grant_type': 'refresh_token',
      }).query);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw AuthError('Google не обновил вход (${res.statusCode})');
      final j = jsonDecode(body) as Map<String, dynamic>;
      _access = j['access_token'] as String;
      _expires = now + ((j['expires_in'] as num?)?.toInt() ?? 3600);
      return _access!;
    } finally {
      client.close();
    }
  }
}
