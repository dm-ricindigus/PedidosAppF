/// Claves de campos en documentos Firestore y mapas relacionados.
abstract final class FirestoreFields {
  static const String role = 'role';
  static const String email = 'email';
  static const String createdAt = 'createdAt';
  static const String orderCode = 'orderCode';
  static const String clientId = 'clientId';
  static const String state = 'state';
  static const String title = 'title';
  static const String maxDeliveryDate = 'maxDeliveryDate';
  static const String orderId = 'orderId';
  static const String message = 'message';
  static const String userId = 'userId';
  static const String attachments = 'attachments';
  static const String used = 'used';
  static const String usedAt = 'usedAt';
  static const String usedBy = 'usedBy';
  static const String clientEmail = 'clientEmail';
  static const String token = 'token';
  static const String updatedAt = 'updatedAt';
}

/// Campos de cada elemento en `attachments` (mensajes).
abstract final class AttachmentField {
  static const String name = 'name';
  static const String size = 'size';
  static const String extension = 'extension';
  static const String url = 'url';
  static const String storagePath = 'storagePath';
}

/// Claves del mapa devuelto por Cloud Functions a la app (p. ej. crear código).
abstract final class CloudCallableKeys {
  static const String success = 'success';
  static const String code = 'code';
}
