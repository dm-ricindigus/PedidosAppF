import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pedidosapp/edit_order_client.dart';
import 'package:pedidosapp/message_detail_client.dart';

class HistorialItem extends StatelessWidget {
  final String fecha;
  final String descripcion;
  final int cantidadArchivos;
  final List<String> nombresArchivos;
  final String numeroPedido;
  final String estado;

  const HistorialItem({
    super.key,
    required this.fecha,
    required this.descripcion,
    this.cantidadArchivos = 0,
    this.nombresArchivos = const [],
    required this.numeroPedido,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageDetailClientPage(
              fecha: fecha,
              descripcion: descripcion,
              cantidadArchivos: cantidadArchivos,
              nombresArchivos: nombresArchivos,
              numeroPedido: numeroPedido,
              estado: estado,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  descripcion,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      cantidadArchivos == 0
                          ? Symbols.attach_file_off
                          : Symbols.attach_file,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cantidadArchivos == 0
                          ? 'Sin archivos adjuntos'
                          : cantidadArchivos == 1
                          ? '1 archivo adjunto'
                          : '$cantidadArchivos archivos adjuntos',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      final pedidoQuery = await _firestore
          .collection('orders')
          .where('orderCode', isEqualTo: orderCode)
          .where('clientId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (pedidoQuery.docs.isNotEmpty) {
        final pedidoData = pedidoQuery.docs.first.data();
        final estado = pedidoData['state'] as int? ?? 0;
        setState(() {
          _orderId = pedidoQuery.docs.first.id;
          _estadoPedido = _obtenerEstadoTexto(estado);
        });
      }
    } catch (e) {
      print('Error al obtener orderId: $e');
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
                      stream: _firestore
                          .collection('messages')
                          .where('orderId', isEqualTo: _orderId)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
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
                            final message = data['message'] as String? ?? '';
                            final createdAt = data['createdAt'] as Timestamp?;
                            final List<dynamic> attachmentsRaw =
                                (data['attachments'] as List<dynamic>?) ?? [];
                            final List<String> nombresArchivos = attachmentsRaw
                                .whereType<Map<String, dynamic>>()
                                .map((a) => a['name'] as String?)
                                .whereType<String>()
                                .toList();

                            return HistorialItem(
                              fecha: _formatearFecha(createdAt),
                              descripcion: message,
                              cantidadArchivos: nombresArchivos.length,
                              nombresArchivos: nombresArchivos,
                              numeroPedido: widget.numeroPedido,
                              estado: _estadoPedido,
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
