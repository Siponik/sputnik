// Общий Telegram-бот Спутника (bot/, Cloudflare Workers) — сеть, как tracker/src/lib/sharedbot.js.
// Ключ привязки — в слое settings.tgbot.key; Google-ключей сервер не получает.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const botUrl = 'https://sputnik-bot.siponikdev.workers.dev';
const botLink = 'https://t.me/SputnikTasksBot';

class BotError implements Exception {
  BotError(this.message, {this.unlinked = false});
  final String message;
  final bool unlinked;
  @override
  String toString() => message;
}

class BotApi {
  String _last = '';

  Future<Map<String, dynamic>> _call(String path, {String method = 'GET', String key = '', Object? body}) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await c.openUrl(method, Uri.parse('$botUrl$path'));
      if (key.isNotEmpty) req.headers.set('Authorization', 'Bearer $key');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 15));
      final text = await res.transform(utf8.decoder).join();
      Map<String, dynamic> data;
      try {
        data = text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }
      if (res.statusCode >= 300) {
        throw BotError(
          (data['error'] ?? 'Бот ответил ${res.statusCode}') as String,
          unlinked: data['unlinked'] == true,
        );
      }
      return data;
    } on TimeoutException {
      throw BotError('Бот не отвечает — проверь интернет');
    } on SocketException {
      throw BotError('Бот не отвечает — проверь интернет');
    } finally {
      c.close();
    }
  }

  Future<Map<String, dynamic>> link(String code, String key) => _call(
    '/link',
    method: 'POST',
    body: {'code': code.replaceAll(RegExp(r'\D'), ''), 'key': key, 'tz': 'Europe/Moscow'},
  );
  Future<void> test(String key) => _call('/test', method: 'POST', key: key);
  Future<void> unlink(String key) => _call('/unlink', method: 'POST', key: key);
  Future<Map<String, dynamic>> inbox(String key) => _call('/inbox', key: key);
  Future<void> ack(String key, List ids) => _call('/ack', method: 'POST', key: key, body: {'ids': ids});

  /// Напоминания и задачи на неделю — если что-то поменялось.
  Future<bool> push(String key, List items, List today, Map guess) async {
    final body = {'items': items, 'today': today, 'tz': 'Europe/Moscow', ...guess};
    final text = jsonEncode(body);
    if (text == _last) return false;
    await _call('/state', method: 'PUT', key: key, body: body);
    _last = text;
    return true;
  }

  void forget() => _last = '';
}
