import 'package:flutter/widgets.dart';

/// Shared helpers for detecting an active IME composing session.
///
/// Chinese / Japanese / Korean input methods keep a non-collapsed composing
/// range while the user is still choosing the final committed text. During
/// that phase we should avoid state fan-out that mutates controller text.
bool hasActiveComposingRange(TextEditingValue value) {
  final composing = value.composing;
  return composing.isValid && !composing.isCollapsed;
}

extension TextEditingControllerImeX on TextEditingController {
  /// Whether the controller is currently inside an active IME composing phase.
  bool get hasActiveComposing => hasActiveComposingRange(value);
}
