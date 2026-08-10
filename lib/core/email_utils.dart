/// Validación de correos (solo el email completo, sin texto extra).
abstract final class EmailUtils {
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String normalize(String value) => value.trim().toLowerCase();

  static bool isValid(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return false;
    return _emailPattern.hasMatch(normalized);
  }

  static String? validationError(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) {
      return 'Por favor ingresa el correo del cliente';
    }
    if (normalized.contains(' ')) {
      return 'El correo no puede contener espacios ni texto adicional';
    }
    if (!isValid(normalized)) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }
}
