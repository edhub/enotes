import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../notes/models/note.dart';
import '_sync_helper_stub.dart'
    if (dart.library.js_interop) '_sync_helper_web.dart';
import '../../notes/providers/notes_provider.dart';
import '../models/auth_user.dart';
import '../services/shelf_service.dart';

// ── 状态 ──────────────────────────────────────────────────────────────────────

enum SyncStatus { idle, uploading, restoring }

/// 云同步功能的全部状态。
class SyncState {
  const SyncState({
    this.user,
    this.token,
    this.status = SyncStatus.idle,
    this.error,
  });

  /// 已登录用户，null 表示未登录（或正在初始化）。
  final AuthUser? user;

  /// Bearer token，已登录时非 null。
  final String? token;

  final SyncStatus status;

  /// 最近一次操作的错误信息，null 表示无错误。
  final String? error;

  bool get isLoggedIn => token != null;
  bool get isBusy => status != SyncStatus.idle;

  SyncState copyWith({
    AuthUser? user,
    String? token,
    SyncStatus? status,
    String? error,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) =>
      SyncState(
        user: clearUser ? null : (user ?? this.user),
        token: clearToken ? null : (token ?? this.token),
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Token 存储 ───────────────────────────────────────────────────────────────

/// 跨平台 token 持久化：shared_preferences（native → NSUserDefaults/plist；web → localStorage）。
class _TokenStorage {
  static const _key = 'shelf_token';

  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_key)?.trim();
      return (token?.isEmpty ?? true) ? null : token;
    } catch (e) {
      log('_TokenStorage.read failed: $e');
      return null;
    }
  }

  Future<void> write(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    } catch (e) {
      log('_TokenStorage.write failed: $e');
      rethrow;
    }
  }

  Future<void> delete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      log('_TokenStorage.delete failed: $e');
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

// ── Notifier ──────────────────────────────────────────────────────────────────

String _buildLoginUrl() {
  if (kIsWeb) {
    // On web, redirect back to the current origin so the Flutter app can read
    // the token from the URL query string on reload.
    final redirectUri = Uri.encodeComponent('${Uri.base.origin}/');
    return 'https://shelf.tyun.fun/auth/login?redirect_uri=$redirectUri';
  }
  return 'https://shelf.tyun.fun/auth/login?redirect_uri=enotes://auth/callback';
}

/// 管理 shelf 登录状态及云备份操作。
///
/// 初始化流程：
/// 1. 从持久化存储读取已保存的 token → 验证用户信息
/// 2. 注册 Deep Link 监听器，接收登录回调中的新 token（仅 native）
class SyncNotifier extends Notifier<SyncState> {
  final _storage = _TokenStorage();
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  SyncState build() {
    ref.onDispose(() => _deepLinkSub?.cancel());
    unawaited(_init());
    return const SyncState();
  }

  // ── 初始化 ───────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (kIsWeb) {
      // Web OAuth callback：服务器将 token 附在 redirect_uri 的 query string 中。
      final token = Uri.base.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        log('SyncNotifier: received token via web OAuth callback');
        clearTokenFromUrl(); // 防止刷新后重复处理
        try {
          await _storage.write(token);
        } catch (e) {
          log('SyncNotifier: failed to save token: $e');
          state = state.copyWith(error: 'Login failed: could not save token ($e)');
          return;
        }
        state = state.copyWith(token: token, clearError: true);
        await _fetchAndSetUser(token);
        return;
      }
    } else {
      // Deep links 仅在 native 平台有效（custom URL scheme 在浏览器不可用）。
      _deepLinkSub = AppLinks().uriLinkStream.listen(
        _handleDeepLink,
        onError: (Object e) => log('SyncNotifier: deep link stream error: $e'),
      );

      try {
        final initial = await AppLinks().getInitialLink();
        if (initial != null) {
          await _handleDeepLink(initial);
          return;
        }
      } catch (e) {
        log('SyncNotifier: getInitialLink error: $e');
      }
    }

    final savedToken = await _storage.read();
    if (savedToken != null) {
      await _fetchAndSetUser(savedToken);
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'enotes' || uri.host != 'auth') {
      log('SyncNotifier: ignored deep link: $uri');
      return;
    }
    final token = uri.queryParameters['token'];
    if (token == null) {
      log('SyncNotifier: deep link missing token param: $uri');
      state = state.copyWith(error: 'Login failed: missing token in callback URL');
      return;
    }
    log('SyncNotifier: received token via deep link');
    try {
      await _storage.write(token);
    } catch (e) {
      log('SyncNotifier: failed to save token: $e');
      state = state.copyWith(error: 'Login failed: could not save token ($e)');
      return;
    }
    state = state.copyWith(token: token, clearError: true);
    await _fetchAndSetUser(token);
  }

  Future<void> _fetchAndSetUser(String token) async {
    try {
      final user = await ShelfService(token).getMe();
      state = state.copyWith(user: user, token: token, clearError: true);
      log('SyncNotifier: signed in as ${user.username}');
    } catch (e) {
      log('SyncNotifier: fetchUser failed: $e');
      state = state.copyWith(error: 'Signed in, but failed to load profile: $e');
    }
  }

  // ── 公开操作 ──────────────────────────────────────────────────────────────────

  /// 打开系统浏览器，引导用户完成 GitHub 授权。
  Future<void> login() async {
    try {
      await launchUrl(
        Uri.parse(_buildLoginUrl()),
        // Web：在当前标签页导航（OAuth 回调会重定向回本页面）。
        // Native：打开外部浏览器，通过 deep link 回调。
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
    } catch (e) {
      log('SyncNotifier: launch login URL failed: $e');
      state = state.copyWith(error: '无法打开浏览器：$e');
    }
  }

  /// 清除本地 token，退出登录。
  Future<void> logout() async {
    await _storage.delete();
    state = const SyncState();
    log('SyncNotifier: signed out');
  }

  /// 将当前所有笔记打包为 JSON 备份上传到 shelf。
  Future<void> uploadBackup() async {
    final token = state.token;
    if (token == null) return;

    state = state.copyWith(status: SyncStatus.uploading, clearError: true);
    try {
      final notes = ref.read(notesProvider).allNotes;
      final payload = const JsonEncoder().convert({
        'version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'notes': notes.map((n) => n.toJson()).toList(),
      });
      await ShelfService(token).uploadBackup(payload);
      state = state.copyWith(status: SyncStatus.idle);
      log('SyncNotifier: backup uploaded (${notes.length} notes)');
    } catch (e) {
      log('SyncNotifier: uploadBackup failed: $e');
      state = state.copyWith(status: SyncStatus.idle, error: '上传失败：$e');
    }
  }

  /// 下载指定备份并导入（全量替换），返回导入的笔记数量。
  Future<int> restoreFromBackup(String backupId) async {
    final token = state.token;
    if (token == null) throw StateError('Not logged in');

    state = state.copyWith(status: SyncStatus.restoring, clearError: true);
    try {
      final raw = await ShelfService(token).downloadBackup(backupId);
      final notes = _parseBackupJson(raw);

      await ref.read(notesProvider.notifier).importNotes(notes);
      state = state.copyWith(status: SyncStatus.idle);
      log('SyncNotifier: restored ${notes.length} notes from backup $backupId');
      return notes.length;
    } catch (e) {
      state = state.copyWith(status: SyncStatus.idle, error: '恢复失败：$e');
      rethrow;
    }
  }

  /// 从 shelf 删除指定备份。
  Future<void> deleteRemoteBackup(String backupId) async {
    final token = state.token;
    if (token == null) return;
    await ShelfService(token).deleteBackup(backupId);
    log('SyncNotifier: deleted remote backup $backupId');
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  List<Note> _parseBackupJson(String raw) {
    final decoded = jsonDecode(raw);
    final List<dynamic> list;
    if (decoded is Map && decoded.containsKey('notes')) {
      list = decoded['notes'] as List<dynamic>;
    } else if (decoded is List) {
      list = decoded;
    } else {
      throw FormatException('unrecognized backup format');
    }
    return list
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
