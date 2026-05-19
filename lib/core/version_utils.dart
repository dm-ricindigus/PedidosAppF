/// Utilidad para comparar versiones tipo semver (`major.minor.patch`), ignorando
/// sufijos de build de Flutter/Android (`-prod`, `-dev`, `+5`, etc.).
abstract final class VersionUtils {
  /// Devuelve negativo si [a] < [b], cero si iguales, positivo si [a] > [b].
  static int compare(String a, String b) {
    final pa = _parseCore(a);
    final pb = _parseCore(b);
    if (pa == null || pb == null) {
      return a.compareTo(b);
    }
    for (var i = 0; i < 3; i++) {
      final d = pa[i].compareTo(pb[i]);
      if (d != 0) return d;
    }
    return 0;
  }

  static List<int>? _parseCore(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // Quita build metadata (+123) y toma solo la parte antes del primer '-'
    // para ignorar sufijos como `-prod` en versionName de Gradle.
    final noBuild = trimmed.split('+').first;
    final core = noBuild.split('-').first.trim();
    final parts = core.split('.');
    if (parts.isEmpty) return null;
    final out = <int>[];
    for (var i = 0; i < 3; i++) {
      if (i < parts.length) {
        final n = int.tryParse(parts[i]);
        if (n == null) return null;
        out.add(n);
      } else {
        out.add(0);
      }
    }
    return out;
  }
}
