/// 单条备份记录，对应 /api/backups 列表项。
class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String id;
  final String filename;
  final String createdAt;
  final int sizeBytes;

  factory BackupEntry.fromJson(Map<String, dynamic> json) => BackupEntry(
        id: json['id'] as String,
        filename: json['filename'] as String,
        createdAt: json['created_at'] as String,
        sizeBytes: json['size_bytes'] as int,
      );

  /// 备份文件大小，人类可读格式。
  String get displaySize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// 备份时间（本地时区）。
  DateTime get createdAtLocal => DateTime.parse(createdAt).toLocal();

  @override
  String toString() => 'BackupEntry($id, $filename)';
}
