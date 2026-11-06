// Общая копия «Знаний» на Google Drive: папка «Спутник / Знания» с теми же подпапками, что на компьютере
// (обычная видимая папка; право drive.file — Спутник видит только то, что создал сам).
// Метки appProperties.sputnik: «folder» — папка «Спутник» (её же использует старое приложение для картинок),
// «notes-root» — папка «Знания», «notes-dir» — подпапки, «notes» — файлы.
import 'dart:convert';
import 'dart:io';

import '../../core/notes/sync.dart';
import '../google_api.dart' show ApiError;
import '../google_auth.dart';
import 'notes_sync.dart';

const _drive = 'https://www.googleapis.com/drive/v3';
const _upload = 'https://www.googleapis.com/upload/drive/v3';
const _folderMime = 'application/vnd.google-apps.folder';

/// Тип файла по расширению (для Drive, чтобы он показывал картинки и текст как надо).
String mimeOf(String path) {
  final ext = path.contains('.') ? path.substring(path.lastIndexOf('.') + 1).toLowerCase() : '';
  return const {
        'md': 'text/markdown',
        'canvas': 'application/json',
        'json': 'application/json',
        'txt': 'text/plain',
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'svg': 'image/svg+xml',
        'pdf': 'application/pdf',
      }[ext] ??
      'application/octet-stream';
}

/// Полные пути файлов из плоского списка Drive (`id → (name, parent, isFolder)`), считая от папки [rootId].
/// Файлы вне папки или в корзине уже отфильтрованы запросом; петли и чужие родители — пропускаются.
Map<String, String> drivePaths(String rootId, Map<String, (String, String?, bool)> items) {
  final cache = <String, String?>{rootId: ''};
  String? pathOf(String id, [int depth = 0]) {
    if (cache.containsKey(id)) return cache[id];
    if (depth > 64) return null;
    final it = items[id];
    if (it == null || it.$2 == null) return cache[id] = null;
    final parent = pathOf(it.$2!, depth + 1);
    if (parent == null) return cache[id] = null;
    return cache[id] = parent.isEmpty ? it.$1 : '$parent/${it.$1}';
  }

  final out = <String, String>{};
  for (final e in items.entries) {
    if (e.value.$3) continue;
    final p = pathOf(e.key);
    if (p != null) out[e.key] = p;
  }
  return out;
}

class DriveStore implements RemoteStore {
  final GoogleAuth auth;
  final HttpClient _http = HttpClient();
  String? _root;

  /// Папки по пути (`3D/Техники` → id), заполняется при list() и создании.
  final Map<String, String> _dirs = {};

  DriveStore(this.auth);

  Future<HttpClientResponse> _send(String method, String url, {List<int>? body, String? type, bool retry = true}) async {
    final token = await auth.accessToken();
    final req = await _http.openUrl(method, Uri.parse(url));
    req.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      req.headers.set('Content-Type', type ?? 'application/json; charset=utf-8');
      req.contentLength = body.length;
      req.add(body);
    }
    final res = await req.close();
    if (res.statusCode == 401 && retry) {
      await res.drain<void>();
      auth.expire();
      return _send(method, url, body: body, type: type, retry: false);
    }
    if (res.statusCode >= 300) {
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode == 403 && text.contains('storageQuotaExceeded')) throw DriveFull();
      throw ApiError(res.statusCode, text.length > 200 ? text.substring(0, 200) : text);
    }
    return res;
  }

  Future<Map<String, dynamic>> _json(String method, String url, [Object? body]) async {
    final res = await _send(method, url, body: body == null ? null : utf8.encode(jsonEncode(body)));
    final text = await res.transform(utf8.decoder).join();
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
  }

  Future<String?> _findByProp(String value, {String? parent}) async {
    final q = "appProperties has { key='sputnik' and value='$value' } and trashed=false${parent == null ? '' : " and '$parent' in parents"}";
    final j = await _json('GET', '$_drive/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id)&pageSize=10');
    final files = (j['files'] as List?) ?? const [];
    return files.isEmpty ? null : (files.first as Map)['id'] as String;
  }

  Future<String> _mkdir(String name, String parent, String mark) async {
    final f = await _json('POST', '$_drive/files?fields=id', {
      'name': name,
      'mimeType': _folderMime,
      'parents': [parent],
      'appProperties': {'sputnik': mark},
    });
    return f['id'] as String;
  }

  /// Папка «Спутник / Знания» (создаётся при первом обращении).
  Future<String> root() async {
    if (_root != null) return _root!;
    var app = await _findByProp('folder');
    app ??= (await _json('POST', '$_drive/files?fields=id', {
      'name': 'Спутник',
      'mimeType': _folderMime,
      'appProperties': {'sputnik': 'folder'},
    }))['id'] as String;
    _root = await _findByProp('notes-root', parent: app) ?? await _mkdir('Знания', app, 'notes-root');
    return _root!;
  }

  @override
  Future<Map<String, RemoteFile>> list() async {
    final rootId = await root();
    final items = <String, (String, String?, bool)>{};
    final meta = <String, (String, int)>{};
    String? page;
    const q = "(appProperties has { key='sputnik' and value='notes' } or appProperties has { key='sputnik' and value='notes-dir' }) and trashed=false";
    do {
      final url = '$_drive/files?q=${Uri.encodeQueryComponent(q)}&pageSize=1000'
          '&fields=nextPageToken,files(id,name,mimeType,parents,md5Checksum,modifiedTime)${page == null ? '' : '&pageToken=$page'}';
      final j = await _json('GET', url);
      for (final f in (j['files'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final parents = (f['parents'] as List?)?.cast<String>() ?? const [];
        final isDir = f['mimeType'] == _folderMime;
        items[f['id'] as String] = (f['name'] as String, parents.isEmpty ? null : parents.first, isDir);
        if (!isDir) {
          meta[f['id'] as String] = (f['md5Checksum'] as String? ?? '', DateTime.tryParse(f['modifiedTime'] as String? ?? '')?.millisecondsSinceEpoch ?? 0);
        }
      }
      page = j['nextPageToken'] as String?;
    } while (page != null);
    // Пути папок — для загрузки новых файлов в нужное место.
    _dirs.clear();
    final dirItems = {for (final e in items.entries) if (e.value.$3) e.key: (e.value.$1, e.value.$2, false)};
    drivePaths(rootId, dirItems).forEach((id, p) => _dirs[p] = id);
    final out = <String, RemoteFile>{};
    drivePaths(rootId, items).forEach((id, p) {
      final m = meta[id]!;
      // Два файла с одним путём (создали одновременно с двух компьютеров) — берём более новый.
      final was = out[p];
      if (was == null || m.$2 > was.mtime) out[p] = RemoteFile(id, p, m.$1, m.$2);
    });
    return out;
  }

  Future<String> _dirFor(String path) async {
    var parent = await root();
    for (final d in parentFolders(path)) {
      final known = _dirs[d];
      if (known != null) {
        parent = known;
        continue;
      }
      final name = d.substring(d.lastIndexOf('/') + 1);
      parent = _dirs[d] = await _mkdir(name, parent, 'notes-dir');
    }
    return parent;
  }

  @override
  Future<List<int>> download(RemoteFile f) async {
    final res = await _send('GET', '$_drive/files/${f.id}?alt=media');
    final out = <int>[];
    await for (final c in res) {
      out.addAll(c);
    }
    return out;
  }

  @override
  Future<RemoteFile> upload(String path, List<int> bytes, {RemoteFile? existing}) async {
    const fields = 'id,md5Checksum,modifiedTime';
    Map<String, dynamic> j;
    if (existing != null) {
      final res = await _send('PATCH', '$_upload/files/${existing.id}?uploadType=media&fields=$fields', body: bytes, type: mimeOf(path));
      j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    } else {
      final parent = await _dirFor(path);
      const b = 'sputnik-notes-boundary';
      final meta = jsonEncode({
        'name': path.substring(path.lastIndexOf('/') + 1),
        'parents': [parent],
        'mimeType': mimeOf(path),
        'appProperties': {'sputnik': 'notes'},
      });
      final body = <int>[
        ...utf8.encode('--$b\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n--$b\r\nContent-Type: ${mimeOf(path)}\r\n\r\n'),
        ...bytes,
        ...utf8.encode('\r\n--$b--'),
      ];
      final res = await _send('POST', '$_upload/files?uploadType=multipart&fields=$fields', body: body, type: 'multipart/related; boundary=$b');
      j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    }
    return RemoteFile(j['id'] as String, path, j['md5Checksum'] as String? ?? '', DateTime.tryParse(j['modifiedTime'] as String? ?? '')?.millisecondsSinceEpoch ?? 0);
  }

  @override
  Future<void> trash(RemoteFile f) async {
    await _json('PATCH', '$_drive/files/${f.id}?fields=id', {'trashed': true});
  }
}
