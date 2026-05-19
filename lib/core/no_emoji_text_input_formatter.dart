import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

/// Quita pictogramas emoji y símbolos tipográficos usados como emoji al escribir o pegar.
class NoEmojiTextInputFormatter extends TextInputFormatter {
  const NoEmojiTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = _stripEmojis(newValue.text);
    if (cleaned == newValue.text) return newValue;

    final sel = newValue.selection;
    if (!sel.isValid) {
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    int mapOffset(int o) {
      if (o <= 0) return 0;
      if (o >= newValue.text.length) return cleaned.length;
      final prefix = newValue.text.substring(0, o);
      return _stripEmojis(prefix).length;
    }

    final start = mapOffset(sel.start);
    final end = sel.isCollapsed ? start : mapOffset(sel.end);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection(
        baseOffset: start.clamp(0, cleaned.length),
        extentOffset: end.clamp(0, cleaned.length),
      ),
    );
  }

  static String _stripEmojis(String s) {
    final out = StringBuffer();
    for (final g in s.characters) {
      if (!_graphemeHasEmoji(g)) {
        out.write(g);
      }
    }
    return out.toString();
  }

  static bool _graphemeHasEmoji(String g) {
    for (final r in g.runes) {
      if (_isEmojiOrEmojiModifier(r)) return true;
    }
    return false;
  }

  static bool _isEmojiOrEmojiModifier(int r) {
    if (r == 0xFE0F || r == 0xFE0E) return true;
    if (r >= 0x1F1E6 && r <= 0x1F1FF) return true;
    if (r >= 0x1F300 && r <= 0x1FADF) return true;
    if (r >= 0x1F600 && r <= 0x1F64F) return true;
    if (r >= 0x1F680 && r <= 0x1F6FF) return true;
    if (r >= 0x1F700 && r <= 0x1F77F) return false;
    if (r >= 0x1F900 && r <= 0x1F9FF) return true;
    if (r >= 0x1FA70 && r <= 0x1FAFF) return true;
    if (r >= 0x2600 && r <= 0x26FF) return true;
    if (r >= 0x2700 && r <= 0x27BF) return true;
    if (r >= 0x231A && r <= 0x231B) return true;
    if (r >= 0x23E9 && r <= 0x23F3) return true;
    if (r >= 0x23F8 && r <= 0x23FA) return true;
    if (r >= 0x2763 && r <= 0x2767) return true;
    if (r == 0x00A9 || r == 0x00AE || r == 0x2122) return true;
    if (r == 0x24C2 || r == 0x3030 || r == 0x303D) return true;
    if (r >= 0xE0020 && r <= 0xE007F) return true;
    return false;
  }
}
