import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pedidosapp/data/field_keys.dart';

/// UI-only filter id (not a Firestore [FirestoreFields.state]). Admin: unused order codes.
const int kAdminOrderListFilterPendingClientEntry = 8;

/// Client home: state filters (no admin-only entries).
const List<(int, String)> kClientHomeOrderStateFilters = [
  (0, 'Todos'),
  (7, 'En proceso'),
  (1, 'Ingresado'),
  (2, 'Impresión y Transferencia'),
  (3, 'Confección'),
  (4, 'Acabados'),
  (5, 'Empacado'),
  (6, 'Entregado'),
];

/// Admin home: same as client plus [kAdminOrderListFilterPendingClientEntry].
const List<(int, String)> kAdminHomeOrderStateFilters = [
  (0, 'Todos'),
  (7, 'En proceso'),
  (1, 'Ingresado'),
  (2, 'Impresión y Transferencia'),
  (3, 'Confección'),
  (4, 'Acabados'),
  (5, 'Empacado'),
  (6, 'Entregado'),
  (kAdminOrderListFilterPendingClientEntry, 'Pendiente de ingreso'),
];

const List<(String, String)> kOrderListSortOptions = [
  ('fecha_desc', 'Más reciente'),
  ('fecha_asc', 'Más antiguo'),
  ('estado', 'Por estado'),
  ('fecha_entrega', 'Por fecha de entrega'),
];

String orderListFilterLabel(int filterId) {
  for (final f in kAdminHomeOrderStateFilters) {
    if (f.$1 == filterId) return f.$2;
  }
  for (final f in kClientHomeOrderStateFilters) {
    if (f.$1 == filterId) return f.$2;
  }
  return kClientHomeOrderStateFilters.first.$2;
}

String orderListSortLabel(String sortKey) {
  return kOrderListSortOptions
      .firstWhere(
        (o) => o.$1 == sortKey,
        orElse: () => kOrderListSortOptions.first,
      )
      .$2;
}

List<QueryDocumentSnapshot> orderListSortedDocuments(
  List<QueryDocumentSnapshot> documents,
  String sortKey,
) {
  final sorted = List<QueryDocumentSnapshot>.from(documents);
  sorted.sort((a, b) {
    final aData = a.data() as Map<String, dynamic>? ?? {};
    final bData = b.data() as Map<String, dynamic>? ?? {};
    final aCreatedAt = aData[FirestoreFields.createdAt] as Timestamp?;
    final bCreatedAt = bData[FirestoreFields.createdAt] as Timestamp?;
    final aState = aData[FirestoreFields.state] as int? ?? 0;
    final bState = bData[FirestoreFields.state] as int? ?? 0;

    switch (sortKey) {
      case 'fecha_asc':
        if (aCreatedAt == null && bCreatedAt == null) return 0;
        if (aCreatedAt == null) return 1;
        if (bCreatedAt == null) return -1;
        return aCreatedAt.compareTo(bCreatedAt);
      case 'estado':
        final stateCmp = aState.compareTo(bState);
        if (stateCmp != 0) return stateCmp;
        if (aCreatedAt == null && bCreatedAt == null) return 0;
        if (aCreatedAt == null) return 1;
        if (bCreatedAt == null) return -1;
        return bCreatedAt.compareTo(aCreatedAt);
      case 'fecha_entrega':
        final aIsDelivered = aState == 6;
        final bIsDelivered = bState == 6;
        if (aIsDelivered && !bIsDelivered) return 1;
        if (!aIsDelivered && bIsDelivered) return -1;
        final aMaxDelivery =
            aData[FirestoreFields.maxDeliveryDate] as Timestamp?;
        final bMaxDelivery =
            bData[FirestoreFields.maxDeliveryDate] as Timestamp?;
        if (aIsDelivered && bIsDelivered) {
          if (aMaxDelivery == null && bMaxDelivery == null) return 0;
          if (aMaxDelivery == null) return 1;
          if (bMaxDelivery == null) return -1;
          return bMaxDelivery.compareTo(aMaxDelivery);
        }
        if (aMaxDelivery == null && bMaxDelivery == null) return 0;
        if (aMaxDelivery == null) return 1;
        if (bMaxDelivery == null) return -1;
        return aMaxDelivery.compareTo(bMaxDelivery);
      case 'fecha_desc':
      default:
        if (aCreatedAt == null && bCreatedAt == null) return 0;
        if (aCreatedAt == null) return 1;
        if (bCreatedAt == null) return -1;
        return bCreatedAt.compareTo(aCreatedAt);
    }
  });
  return sorted;
}
