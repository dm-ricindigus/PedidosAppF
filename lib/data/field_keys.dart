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
  /// UID del admin que generó el código de pedido (en `orderCodes` y copiado a `orders`).
  static const String adminId = 'adminId';
  static const String createdByUid = 'createdByUid';
  /// Email del admin que generó el código (copiado desde `orderCodes`, si existe).
  static const String createdByEmail = 'createdByEmail';
  static const String token = 'token';
  static const String updatedAt = 'updatedAt';

  // appConfig/settings (actualización forzada)
  /// Si es `false`, no se aplica bloqueo por versión (override de emergencia).
  static const String forceUpdateEnabled = 'forceUpdateEnabled';
  /// Versión mínima para ambas plataformas (`major.minor.patch`).
  static const String minVersion = 'minVersion';
  static const String minVersionAndroid = 'minVersionAndroid';
  static const String minVersionIos = 'minVersionIos';
  /// `applicationId` publicado en Play Store (p. ej. `com.ricindigus.tsm.pedidosapp.prod`).
  static const String androidPlayStorePackageId = 'androidPlayStorePackageId';
  /// URL completa de la ficha en App Store.
  static const String iosStoreUrl = 'iosStoreUrl';
  /// Solo el id numérico de App Store Connect (alternativa a [iosStoreUrl]).
  static const String iosAppStoreId = 'iosAppStoreId';
  /// Mensaje opcional mostrado en el diálogo.
  static const String forceUpdateMessage = 'forceUpdateMessage';
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
