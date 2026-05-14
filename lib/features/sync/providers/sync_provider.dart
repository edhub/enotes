import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../notes/models/note.dart';
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

// ── Token 文件存储 ───────────────────────────────────────────────────────────

/// 将 shelf token 存储在 Application Support 目录的隐藏文件中（权限 0600）。
///
/// 不依赖 Keychain，无需额外 entitlements，适合本地个人 macOS app。
class _TokenStorage {
  static const _filename = '.shelf_token';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<String?> read() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return null;
      final token = (await f.readAsString()).trim();
      return token.isEmpty ? null : token;
    } catch (e) {
      log('_TokenStorage.read failed: $e');
      return null;
    }
  }

  Future<void> write(String token) async {
    try {
      final f = await _file();
      await f.writeAsString(token);
      // 仅允许当前用户读写，防止其他用户帐号访问
      await Process.run('chmod', ['0600', f.path]);
    } catch (e) {
      log('_TokenStorage.write failed: $e');
      rethrow;
    }
  }

  Future<void> delete() async {
    try {
      final f = await _file();
      if (f.existsSync()) await f.delete();
    } catch (e) {
      log('_TokenStorage.delete failed: $e');
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

// ── Notifier ──────────────────────────────────────────────────────────────────

const _loginUrl = 'https://shelf.tyun.fun/auth/login'
    '?redirect_uri=enotes://auth/callback';

/// 管理 shelf 登录状态及云备份操作。
///
/// 初始化流程：
/// 1. 从文件读取已保存的 token → 验证用户信息
/// 2. 注册 Deep Link 监听器，接收登录回调中的新 token
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
    // 最先注册 stream 监听器，防止在异步等待期间错过 Deep Link 事件
    _deepLinkSub = AppLinks().uriLinkStream.listen(
      _handleDeepLink,
      onError: (Object e) => log('SyncNotifier: deep link stream error: $e'),
    );

    // 检查应用是否由 Deep Link 冷启动（launch URL）
    try {
      final initial = await AppLinks().getInitialLink();
      if (initial != null) {
        await _handleDeepLink(initial);
        return; // 已通过冷启动 URL 完成登录，无需再读 Keychain
      }
    } catch (e) {
      log('SyncNotifier: getInitialLink error: $e');
    }

    // 从文件读取已保存的 token（热启动 / 上次登录持久化）
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
    // token 写入文件
    try {
      await _storage.write(token);
    } catch (e) {
      log('SyncNotifier: failed to save token: $e');
      state = state.copyWith(error: 'Login failed: could not save token ($e)');
      return;
    }
    // token 先存入 state，即使后续 getMe 失败也显示已登录
    state = state.copyWith(token: token, clearError: true);
    await _fetchAndSetUser(token);
  }

  /// 用 token 调用 /api/me，成功后更新 user；失败时通过 state.error 提示。
  Future<void> _fetchAndSetUser(String token) async {
    try {
      final user = await ShelfService(token).getMe();
      state = state.copyWith(user: user, token: token, clearError: true);
      log('SyncNotifier: signed in as ${user.username}');
    } catch (e) {
      log('SyncNotifier: fetchUser failed: $e');
      // token 已在 state 中，用户仍视为已登录；但提示网络/鉴权错误
      state = state.copyWith(error: 'Signed in, but failed to load profile: $e');
    }
  }

  // ── 公开操作 ──────────────────────────────────────────────────────────────────

  /// 打开系统浏览器，引导用户完成 GitHub 授权。
  Future<void> login() async {
    try {
      await launchUrl(
        Uri.parse(_loginUrl),
        mode: LaunchMode.externalApplication,
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
  ///
  /// 备份格式与本地导出一致：`{ "version": 1, "exported_at": "…", "notes": […] }`
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
  ///
  /// 失败时抛出 [ShelfException]，调用方负责提示用户。
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
