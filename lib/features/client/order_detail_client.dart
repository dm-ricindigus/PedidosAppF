import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:pedidosapp/features/client/edit_order_client.dart';
import 'package:pedidosapp/features/client/message_detail_client.dart';
import 'package:pedidosapp/shared/widgets/order_message_history_card.dart';

class OrderDetailPage extends StatefulWidget {
  final String numeroPedido;
  final String titulo;

  const OrderDetailPage({
    super.key,
    required this.numeroPedido,
    required this.titulo,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final OrdersRepository _ordersRepo = OrdersRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _orderId;
  String _estadoPedido = 'Estado no disponible';

  @override
  void initState() {
    super.initState();
    _obtenerOrderId();
  }

  Future<void> _obtenerOrderId() async {
    // Extraer el orderCode del numeroPedido (ej: "Pedido Nº 13928019" -> "13928019")
    final orderCode = widget.numeroPedido.replaceAll('Pedido Nº ', '').trim();
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final pedidoQuery = await _ordersRepo.ordersByCodeAndClient(
        orderCode: orderCode,
        clientId: user.uid,
      );

      if (pedidoQuery.docs.isNotEmpty) {
        final pedidoData = pedidoQuery.docs.first.data();
        final estado = pedidoData[FirestoreFields.state] as int? ?? 0;
        setState(() {
          _orderId = pedidoQuery.docs.first.id;
          _estadoPedido = _obtenerEstadoTexto(estado);
        });
      }
    } catch (e, st) {
      developer.log(
        'Error al obtener orderId: $e',
        name: 'OrderDetailClient',
        error: e,
        stackTrace: st,
      );
    }
  }

  String _obtenerEstadoTexto(int estado) {
    switch (estado) {
      case 1:
        return 'Ingresado';
      case 2:
        return 'Impresión y Transferencia';
      case 3:
        return 'Confección';
      case 4:
        return 'Acabados';
      case 5:
        return 'Empacado';
      case 6:
        return 'Entregado';
      default:
        return 'Desconocido';
    }
  }

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha no disponible';

    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'pm' : 'am';

    return '$day/$month/$year - $hour:$minute$amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.numeroPedido,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              'Estado: $_estadoPedido',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _orderId == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: _ordersRepo.watchMessagesForOrder(_orderId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar mensajes: ${snapshot.error}',
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No hay mensajes aún',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          );
                        }

                        final mensajes = snapshot.data!.docs;

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: mensajes.length,
                          itemBuilder: (context, index) {
                            final data =
                                mensajes[index].data() as Map<String, dynamic>;
                            final message =
                                data[FirestoreFields.message] as String? ?? '';
                            final createdAt =
                                data[FirestoreFields.createdAt] as Timestamp?;
                            final List<dynamic> attachmentsRaw =
                                (data[FirestoreFields.attachments]
                                        as List<dynamic>?) ??
                                    [];
                            final List<String> nombresArchivos = attachmentsRaw
                                .whereType<Map<String, dynamic>>()
                                .map((a) => a[AttachmentField.name] as String?)
                                .whereType<String>()
                                .toList();

                            final fecha = _formatearFecha(createdAt);
                            return OrderMessageHistoryCard(
                              timestampLine: fecha,
                              bodyPreview: message,
                              attachmentCount: nombresArchivos.length,
                              onTap: () {
                                showClientMessageDetailBottomSheet(
                                  context,
                                  fecha: fecha,
                                  descripcion: message,
                                  nombresArchivos: nombresArchivos,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditOrderClientPage(
                numeroPedido: widget.numeroPedido,
                titulo: widget.titulo,
                estado: _estadoPedido,
              ),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Editar pedido'),
      ),
    );
  }
}
