/// Códigos de [FirestoreFields.state] en pedidos.
const int kOrderStateIngresado = 1;
const int kOrderStateImpresionTransferencia = 2;
const int kOrderStateConfeccion = 3;
const int kOrderStateAcabados = 4;
const int kOrderStateEmpacado = 5;
const int kOrderStateEntregado = 6;
const int kOrderStateCancelado = 7;

const String kOrderStateCanceladoLabel = 'Cancelado';

/// Pipeline productivo (sin cancelado).
const List<String> kOrderPipelineStateLabels = [
  'Ingresado',
  'Impresión y Transferencia',
  'Confección',
  'Acabados',
  'Empacado',
  'Entregado',
];

const Map<int, String> kOrderStateLabels = {
  kOrderStateIngresado: 'Ingresado',
  kOrderStateImpresionTransferencia: 'Impresión y Transferencia',
  kOrderStateConfeccion: 'Confección',
  kOrderStateAcabados: 'Acabados',
  kOrderStateEmpacado: 'Empacado',
  kOrderStateEntregado: 'Entregado',
  kOrderStateCancelado: kOrderStateCanceladoLabel,
};

String orderStateLabel(int? state) {
  if (state == null) return 'Sin estado';
  return kOrderStateLabels[state] ?? 'Sin estado';
}

int orderStateCodeForLabel(String label) {
  if (label == kOrderStateCanceladoLabel) return kOrderStateCancelado;
  final index = kOrderPipelineStateLabels.indexOf(label);
  return index == -1 ? kOrderStateIngresado : index + 1;
}

bool isOrderCancelled(int state) => state == kOrderStateCancelado;

bool canCancelOrder(int state) => state == kOrderStateIngresado;

bool isOrderInProgress(int state) =>
    state >= kOrderStateIngresado &&
    state <= kOrderStateEmpacado;

const int kOrderCancellationReasonMinLength = 15;
const int kOrderCancellationReasonMaxLength = 500;
