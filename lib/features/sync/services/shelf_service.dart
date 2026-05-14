import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import '../models/backup_entry.dart';

/// shelf 服务端 API 客户端。
///
/// 所有请求均通过 `Authorization: Bearer <token>` 鉴权。
/// 失败时抛出 [ShelfException]，调用方负责处理。
class ShelfService {
  static const _baseUrl = 'https://shelf.tyun.fun';
  static const _backupFilename = 'enotes.json';

  const ShelfService(this._token);

  final String _token;

  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  // ── 用户信息 ────────────────────────────────────────────────────────────────

  /// GET /api/me
  Future<AuthUser> getMe() async {
    final resp = await http
        .get(Uri.parse('$_baseUrl/api/me'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    _checkStatus(resp, 200, 'getMe');
    return AuthUser.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  // ── 备份操作 ────────────────────────────────────────────────────────────────

  /// POST /api/backups — 以 multipart/form-data 上传 JSON 备份内容。
  Future<BackupEntry> uploadBackup(String jsonContent) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/backups'),
    )..headers.addAll(_headers);

    request.files.add(http.MultipartFile.fromString(
      'file',
      jsonContent,
      filename: _backupFilename,
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);
    _checkStatus(resp, 201, 'uploadBackup');

    return BackupEntry.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  /// GET /api/backups — 返回按时间降序排列的备份列表。
  Future<List<BackupEntry>> listBackups() async {
    final resp = await http
        .get(Uri.parse('$_baseUrl/api/backups'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    _checkStatus(resp, 200, 'listBackups');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => BackupEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/backups/{id} — 下载备份，返回原始 JSON 字符串。
  Future<String> downloadBackup(String id) async {
    final resp = await http
        .get(Uri.parse('$_baseUrl/api/backups/$id'), headers: _headers)
        .timeout(const Duration(seconds: 30));

    _checkStatus(resp, 200, 'downloadBackup');
    return resp.body;
  }

  /// DELETE /api/backups/{id}
  Future<void> deleteBackup(String id) async {
    final resp = await http
        .delete(Uri.parse('$_baseUrl/api/backups/$id'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    _checkStatus(resp, 204, 'deleteBackup');
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  void _checkStatus(http.Response resp, int expected, String method) {
    if (resp.statusCode != expected) {
      final body = resp.body.trim();
      final msg = '$method failed: HTTP ${resp.statusCode}'
          '${body.isNotEmpty ? ' — $body' : ''}';
      log('ShelfService: $msg');
      throw ShelfException(msg);
    }
  }
}

/// shelf API 操作失败时抛出。
class ShelfException implements Exception {
  const ShelfException(this.message);
  final String message;

  @override
  String toString() => 'ShelfException: $message';
}
