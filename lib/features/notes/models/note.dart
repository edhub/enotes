import 'package:uuid/uuid.dart';

/// Immutable note data class.
///
/// [createdAt] is fixed at creation and determines which time column the note
/// belongs to. It is stored as UTC and displayed in local time.
/// Only [content] and [updatedAt] change after creation.
class Note {
  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isDraft = false,
    this.isPinned = false,
    this.pinnedOrder,
  });

  final String id;
  final String content;

  /// Immutable. Determines time-column placement. Always UTC.
  final DateTime createdAt;

  /// Updated on each edit. Does not affect column placement.
  final DateTime updatedAt;

  final bool isDraft;
  final bool isPinned;

  /// Milliseconds-since-epoch when pinned.
  /// Higher value = pinned more recently = displayed first in column.
  final int? pinnedOrder;

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
  /// Set [clearPinnedOrder] to true to reset pinnedOrder to null.
  Note copyWith({
    String? content,
    DateTime? updatedAt,
    bool? isDraft,
    bool? isPinned,
    int? pinnedOrder,
    bool clearPinnedOrder = false,
  }) =>
      Note(
        id: id,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDraft: isDraft ?? this.isDraft,
        isPinned: isPinned ?? this.isPinned,
        pinnedOrder:
            clearPinnedOrder ? null : (pinnedOrder ?? this.pinnedOrder),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_draft': isDraft,
        'is_pinned': isPinned,
        'pinned_order': pinnedOrder,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isDraft: json['is_draft'] as bool? ?? false,
        isPinned: json['is_pinned'] as bool? ?? false,
        pinnedOrder: json['pinned_order'] as int?,
      );

  @override
  String toString() => 'Note(id: $id, isDraft: $isDraft, content: ${content.substring(0, content.length.clamp(0, 20))})';
}
