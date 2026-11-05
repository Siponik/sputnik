// Тонкий клиент Google Tasks REST. Ошибки сети и отказы Google — исключения ApiError.
import 'dart:convert';
import 'dart:io';

import 'google_auth.dart';

class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'Google: $status $message';
}

class GoogleApi {
  GoogleApi(this.auth);
  final GoogleAuth auth;
  final HttpClient _http = HttpClient();

  Future<Map<String, dynamic>> _call(String method, String url, [Object? body, bool retry = true]) async {
    final token = await auth.accessToken();
    final req = await _http.openUrl(method, Uri.parse(url));
    req.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    if (res.statusCode == 401 && retry) {
      await res.drain<void>();
      auth.expire();
      return _call(method, url, body, false);
    }
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 300) throw ApiError(res.statusCode, text.length > 200 ? text.substring(0, 200) : text);
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
  }

  static const _tasks = 'https://tasks.googleapis.com/tasks/v1';

  Future<List<Map<String, dynamic>>> lists() async {
    final j = await _call('GET', '$_tasks/users/@me/lists?maxResults=100');
    return ((j['items'] ?? []) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> tasks(String listId) async {
    final out = <Map<String, dynamic>>[];
    String? page;
    do {
      final q = 'maxResults=100&showCompleted=false&showHidden=false${page == null ? '' : '&pageToken=$page'}';
      final j = await _call('GET', '$_tasks/lists/$listId/tasks?$q');
      out.addAll(((j['items'] ?? []) as List).cast<Map<String, dynamic>>());
      page = j['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  Future<void> setDone(String listId, String taskId, bool done) => _call(
    'PATCH',
    '$_tasks/lists/$listId/tasks/$taskId',
    done ? {'status': 'completed'} : {'status': 'needsAction', 'completed': null},
  );
}
