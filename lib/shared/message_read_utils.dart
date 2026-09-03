import 'package:pedidosapp/data/field_keys.dart';

/// Solo `readByAdmin == false` cuenta como no leído; mensajes legacy sin campo = leídos.
bool isMessageUnreadByAdmin(Map<String, dynamic>? data) {
  if (data == null) return false;
  return data[FirestoreFields.readByAdmin] == false;
}

int adminUnreadMessageCountFromOrder(Map<String, dynamic>? data) {
  if (data == null) return 0;
  final count = data[FirestoreFields.adminUnreadMessageCount];
  if (count is int && count > 0) return count;
  if (count is num && count > 0) return count.toInt();
  return 0;
}
