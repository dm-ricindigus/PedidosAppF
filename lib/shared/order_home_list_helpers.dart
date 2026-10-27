import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/shared/order_states.dart';

/// UI-only filter id (not a Firestore [FirestoreFields.state]). Admin: unused order codes.
const int kAdminOrderListFilterPendingClientEntry = 8;

/// UI-only filter id for in-progress orders (excludes delivered and cancelled).
const int kOrderListFilterInProgress = 7;

/// Client home: state filters (no admin-only entries).
const List<(int, String)> kClientHomeOrderStateFilters = [
  (0, 'Todos'),
  (kOrderListFilterInProgress, 'En proceso'),
  (kOrderStateIngresado, 'Ingresado'),
  (kOrderStateImpresionTransferencia, 'Impresión y Transferencia'),
  (kOrderStateConfeccion, 'Confección'),
  (kOrderStateAcabados, 'Acabados'),
  (kOrderStateEmpacado, 'Empacado'),
  (kOrderStateEntregado, 'Entregado'),
  (kOrderStateCancelado, 'Cancelado'),
];

/// Admin home: same as client plus [kAdminOrderListFilterPendingClientEntry].
const List<(int, String)> kAdminHomeOrderStateFilters = [
  (0, 'Todos'),
  (kOrderListFilterInProgress, 'En proceso'),
  (kOrderStateIngresado, 'Ingresado'),
  (kOrderStateImpresionTransferencia, 'Impresión y Transferencia'),
  (kOrderStateConfeccion, 'Confección'),
  (kOrderStateAcabados, 'Acabados'),
  (kOrderStateEmpacado, 'Empacado'),
  (kOrderStateEntregado, 'Entregado'),
  (kOrderStateCancelado, 'Cancelado'),
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

/// Última actividad del cliente para ordenar; legacy sin [lastClientMessageAt] → [createdAt].
Timestamp? orderListActivityTimestamp(Map<String, dynamic> data) {
  final last = data[FirestoreFields.lastClientMessageAt] as Timestamp?;
  if (last != null) return last;
  return data[FirestoreFields.createdAt] as Timestamp?;
}

List<QueryDocumentSnapshot> orderListSortedDocuments(
  List<QueryDocumentSnapshot> documents,
  String sortKey,
) {
  final sorted = List<QueryDocumentSnapshot>.from(documents);
  sorted.sort((a, b) {
    final aData = a.data() as Map<String, dynamic>? ?? {};
    final bData = b.data() as Map<String, dynamic>? ?? {};
    final aActivity = orderListActivityTimestamp(aData);
    final bActivity = orderListActivityTimestamp(bData);
    final aState = aData[FirestoreFields.state] as int? ?? 0;
    final bState = bData[FirestoreFields.state] as int? ?? 0;

    switch (sortKey) {
      case 'fecha_asc':
        if (aActivity == null && bActivity == null) return 0;
        if (aActivity == null) return 1;
        if (bActivity == null) return -1;
        return aActivity.compareTo(bActivity);
      case 'estado':
        final stateCmp = aState.compareTo(bState);
        if (stateCmp != 0) return stateCmp;
        if (aActivity == null && bActivity == null) return 0;
        if (aActivity == null) return 1;
        if (bActivity == null) return -1;
        return bActivity.compareTo(aActivity);
      case 'fecha_entrega':
        final aIsDelivered = aState == kOrderStateEntregado;
        final bIsDelivered = bState == kOrderStateEntregado;
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
        if (aActivity == null && bActivity == null) return 0;
        if (aActivity == null) return 1;
        if (bActivity == null) return -1;
        return bActivity.compareTo(aActivity);
    }
  });
  return sorted;
}
