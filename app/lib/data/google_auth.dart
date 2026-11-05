// Вход в Google и токен доступа. Формат token.json как у старого приложения:
// { access_token, refresh_token, expires_at (секунды), scope }.
// Читаем свой flutter/token.json, иначе token.json старого приложения (только чтение). Пишем только свой.
// Ключ клиента: --dart-define=SPUTNIK_GOOGLE_CLIENT=<json> при сборке, иначе client_secret.json в папке данных.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/oauth.dart';
import 'paths.dart';

class AuthError implements Exception {
  AuthError(this.message, {this.needLogin = false});
  final String message;
  final bool needLogin;
  @override
  String toString() => message;
}

const _builtIn = String.fromEnvironment('SPUTNIK_GOOGLE_CLIENT');

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class GoogleAuth {
  Map<String, dynamic>? _token;
  HttpServer? _server;

  Future<({String id, String secret})> _secret() async {
    for (final f in [ownFile('client_secret.json'), dataFile('client_secret.json')]) {
      if (await f.exists()) {
        final s = parseSecret(await f.readAsString());
        if (s != null) return s;
      }
    }
    final s = _builtIn.isEmpty ? null : parseSecret(_builtIn);
    if (s == null) {
      throw AuthError('Нет ключа Google: положи client_secret.json в папку %APPDATA%\\com.siponik.sputnik');
    }
    return s;
  }

  Future<Map<String, dynamic>?> _load() async {
    for (final f in [ownFile('token.json'), dataFile('token.json')]) {
      if (await f.exists()) {
        try {
          return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _store(Map<String, dynamic> t) async {
    _token = t;
    final f = ownFile('token.json');
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(t));
  }

  Future<bool> hasLogin() async => (_token ?? await _load())?['refresh_token'] != null;

  Future<Map<String, dynamic>> _post(Map<String, String> form) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(tokenUrl));
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      req.write(Uri(queryParameters: form).query);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        final bad = body.contains('invalid_grant');
        throw AuthError(
          bad ? 'Вход устарел, войди в Google заново' : 'Google не ответил на вход (${res.statusCode})',
          needLogin: bad,
        );
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } on SocketException {
      throw AuthError('Нет связи с Google');
    } finally {
      client.close();
    }
  }

  Future<String> accessToken() async {
    final t = _token ??= await _load();
    if (t == null) throw AuthError('Войди в Google', needLogin: true);
    if (((t['expires_at'] as num?)?.toInt() ?? 0) > _now() + 60) return t['access_token'] as String;
    final refresh = t['refresh_token'] as String?;
    if (refresh == null) throw AuthError('Войди в Google', needLogin: true);
    final s = await _secret();
    final r = await _post({
      'client_id': s.id,
      'client_secret': s.secret,
      'refresh_token': refresh,
      'grant_type': 'refresh_token',
    });
    await _store({
      'access_token': r['access_token'],
      'refresh_token': r['refresh_token'] ?? refresh,
      'expires_at': _now() + ((r['expires_in'] as num?)?.toInt() ?? 3600),
      'scope': r['scope'] ?? t['scope'],
    });
    return r['access_token'] as String;
  }

  /// Токен перестал подходить (401) — в следующий раз обновить.
  void expire() => _token?['expires_at'] = 0;

  /// Вход через браузер: ждём ответ Google на 127.0.0.1, 5 минут.
  Future<void> login() async {
    final s = await _secret();
    await cancel();
    final verifier = randomB64(32);
    final state = randomB64(16);
    final server = _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}';
    final url = authorizeUri(clientId: s.id, redirect: redirect, challenge: pkceChallenge(verifier), state: state);
    await Process.run('rundll32', ['url.dll,FileProtocolHandler', url.toString()]);

    String code;
    try {
      code = await _waitCode(server, state).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw AuthError('Вход не завершён за 5 минут, попробуй ещё раз'),
      );
    } finally {
      await server.close(force: true);
      if (identical(_server, server)) _server = null;
    }
    final r = await _post({
      'code': code,
      'client_id': s.id,
      'client_secret': s.secret,
      'redirect_uri': redirect,
      'grant_type': 'authorization_code',
      'code_verifier': verifier,
    });
    final granted = r['scope'] as String?;
    if (granted != null) {
      final lack = missingScopes(granted);
      if (lack.isNotEmpty) {
        throw AuthError('Войди в Google заново: Google не дал доступ — ${lack.map((x) => scopeNames[x]).join(', ')}');
      }
    }
    await _store({
      'access_token': r['access_token'],
      'refresh_token': r['refresh_token'],
      'expires_at': _now() + ((r['expires_in'] as num?)?.toInt() ?? 3600),
      'scope': granted,
    });
  }

  Future<void> cancel() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> _waitCode(HttpServer server, String state) async {
    await for (final req in server) {
      final q = req.uri.queryParameters;
      if (!q.containsKey('code') && !q.containsKey('error')) {
        req.response.statusCode = 404;
        await req.response.close();
        continue;
      }
      final ok = q['state'] == state && q['code'] != null;
      req.response.headers.contentType = ContentType.html;
      req.response.write(
        '<!doctype html><meta charset="utf-8"><body style="font:16px sans-serif;background:#151311;color:#eee;padding:40px">'
        '${ok ? 'Готово, можно вернуться в Спутник.' : 'Вход не удался, вернись в Спутник и попробуй ещё раз.'}</body>',
      );
      await req.response.close();
      if (!ok) throw AuthError(q['error'] == 'access_denied' ? 'Вход отменён в браузере' : 'Вход не удался');
      return q['code']!;
    }
    throw AuthError('Вход остановлен');
  }
}
