import 'package:uuid/uuid.dart';

/// Immutable note data class.
///
/// [createdAt] is fixed at creation and determines which time column the note
/// belongs to. It is stored as UTC and displayed in local time.
/// Only [content] and [updatedAt] change after creation.
/// [deletedAt] is set on soft-delete; null means the note is active.
class Note {
  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isDraft = false,
    this.deletedAt,
  });

  final String id;
  final String content;

  /// Immutable. Determines time-column placement. Always UTC.
  final DateTime createdAt;

  /// Updated on each edit. Does not affect column placement.
  final DateTime updatedAt;

  final bool isDraft;

  /// Set when the note is soft-deleted. Null means the note is active.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Creates a brand-new note with a generated UUID and current UTC time.
  factory Note.create({required String content, bool isDraft = false}) {
    final now = DateTime.now().toUtc();
    return Note(
      id: const Uuid().v4(),
      content: content,
      createdAt: now,
      updatedAt: now,
      isDraft: isDraft,
    );
  }

  /// Returns a copy with the given fields replaced.
  /// Set [clearDeletedAt] to true to un-delete (restore) a note.
  Note copyWith({
    String? content,
    DateTime? updatedAt,
    bool? isDraft,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) =>
      Note(
        id: id,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDraft: isDraft ?? this.isDraft,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_draft': isDraft,
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isDraft: json['is_draft'] as bool? ?? false,
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
      );

  @override
  String toString() {
    final preview = content.length <= 20
        ? content
        : '${content.substring(0, 20)}…';
    return 'Note(id: $id, isDraft: $isDraft, deleted: $isDeleted, '
        'content: $preview)';
  }
}
