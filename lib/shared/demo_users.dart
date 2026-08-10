import 'package:pedidosapp/data/field_keys.dart';

/// Usuarios/pedidos marcados en Firestore con [FirestoreFields.isDemo] == true.
abstract final class DemoUsers {
  static bool isDemoFlag(dynamic value) => value == true;

  static bool documentIsDemo(Map<String, dynamic>? data) =>
      data != null && isDemoFlag(data[FirestoreFields.isDemo]);
}
