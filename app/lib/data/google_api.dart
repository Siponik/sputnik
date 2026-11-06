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
      req.add(utf8.encode(jsonEncode(body)));
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

  /// Задачи списка: открытые и выполненные за последние [doneDays] дней (для «Готово» и архива).
  Future<List<Map<String, dynamic>>> tasks(String listId, {int doneDays = 14}) async {
    final out = <Map<String, dynamic>>[];
    String? page;
    final since = Uri.encodeComponent(DateTime.now().toUtc().subtract(Duration(days: doneDays)).toIso8601String());
    do {
      final q =
          'maxResults=100&showCompleted=true&showHidden=true&completedMin=$since${page == null ? '' : '&pageToken=$page'}';
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

  Future<Map<String, dynamic>> createList(String title) => _call('POST', '$_tasks/users/@me/lists', {'title': title});

  Future<Map<String, dynamic>> createTask(String listId, Map<String, dynamic> body) =>
      _call('POST', '$_tasks/lists/$listId/tasks', body);

  Future<Map<String, dynamic>> patchTask(String listId, String taskId, Map<String, dynamic> body) =>
      _call('PATCH', '$_tasks/lists/$listId/tasks/$taskId', body);

  Future<void> deleteTask(String listId, String taskId) => _call('DELETE', '$_tasks/lists/$listId/tasks/$taskId');

  // ---------- Календарь ----------
  static const _cal = 'https://www.googleapis.com/calendar/v3';

  Future<List<Map<String, dynamic>>> calendars() async {
    final j = await _call('GET', '$_cal/users/me/calendarList?maxResults=250');
    return ((j['items'] ?? []) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> events(String calId, DateTime from, DateTime to) async {
    final out = <Map<String, dynamic>>[];
    String? page;
    final a = Uri.encodeComponent(from.toUtc().toIso8601String());
    final b = Uri.encodeComponent(to.toUtc().toIso8601String());
    do {
      final q =
          'singleEvents=true&orderBy=startTime&maxResults=250&timeMin=$a&timeMax=$b'
          '${page == null ? '' : '&pageToken=$page'}';
      final j = await _call('GET', '$_cal/calendars/${Uri.encodeComponent(calId)}/events?$q');
      out.addAll(((j['items'] ?? []) as List).cast<Map<String, dynamic>>());
      page = j['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  Future<Map<String, dynamic>> createEvent(String calId, Map<String, dynamic> body) =>
      _call('POST', '$_cal/calendars/${Uri.encodeComponent(calId)}/events', body);

  // ---------- Слой на Drive (appDataFolder, как tracker/src/lib/layer.js) ----------
  static const _drive = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';
  static const layerFile = 'sputnik-layer.json';
  String? _layerId;

  Future<String?> _findLayer() async {
    if (_layerId != null) return _layerId;
    final q = Uri.encodeComponent("name='$layerFile' and trashed=false");
    final j = await _call(
      'GET',
      '$_drive/files?spaces=appDataFolder&q=$q&fields=files(id,modifiedTime)&orderBy=modifiedTime%20desc&pageSize=10',
    );
    final files = (j['files'] ?? []) as List;
    return _layerId = files.isEmpty ? null : (files.first as Map)['id'] as String?;
  }

  /// Копия слоя из облака или null.
  Future<Map<String, dynamic>?> pullLayer() async {
    final id = await _findLayer();
    if (id == null) return null;
    try {
      return await _call('GET', '$_drive/files/$id?alt=media');
    } on ApiError catch (e) {
      if (e.status == 404) {
        _layerId = null;
        return null;
      }
      rethrow;
    }
  }

  Future<void> pushLayer(Map<String, dynamic> data) async {
    var id = await _findLayer();
    if (id == null) {
      final f = await _call('POST', '$_drive/files?fields=id', {
        'name': layerFile,
        'parents': ['appDataFolder'],
        'mimeType': 'application/json',
      });
      id = _layerId = f['id'] as String;
    }
    await _call('PATCH', '$_upload/files/$id?uploadType=media', data);
  }
}
