import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/message_detail_admin.dart';

class HistorialItem extends StatelessWidget {
  final String messageId;
  final String numeroPedido;
  final String fecha;
  final String descripcion;
  final int cantidadArchivos;

  const HistorialItem({
    super.key,
    required this.messageId,
    required this.numeroPedido,
    required this.fecha,
    required this.descripcion,
    required this.cantidadArchivos,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageDetailAdminPage(
              messageId: messageId,
              numeroPedido: numeroPedido,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fecha,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  '$cantidadArchivos archivos',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailAdminPage extends StatefulWidget {
  final String numeroPedido;
  final String titulo;

  const OrderDetailAdminPage({
    super.key,
    required this.numeroPedido,
    required this.titulo,
  });

  @override
  State<OrderDetailAdminPage> createState() => _OrderDetailAdminPageState();
}

class _OrderDetailAdminPageState extends State<OrderDetailAdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _estadoActual = 'Ingresado';
  String? _orderId;
  bool _cargandoPedido = true;

  final List<String> _estados = [
    'Ingresado',
    'Impresión y Transferencia',
    'Confección',
    'Acabados',
    'Empacado',
  ];

  @override
  void initState() {
    super.initState();
    _cargarPedido();
  }

  String _extraerOrderCode(String numeroPedido) {
    return numeroPedido.replaceAll('Pedido Nº', '').trim();
  }

  String _estadoDesdeCodigo(int? state) {
    if (state == null || state < 1 || state > _estados.length) {
      return _estados.first;
    }
    return _estados[state - 1];
  }

  int _codigoDesdeEstado(String estado) {
    final index = _estados.indexOf(estado);
    return index == -1 ? 1 : index + 1;
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

  Future<void> _cargarPedido() async {
    final orderCode = _extraerOrderCode(widget.numeroPedido);

    try {
      final pedidoQuery = await _firestore
          .collection('orders')
          .where('orderCode', isEqualTo: orderCode)
          .limit(1)
          .get();

      if (!mounted) return;

      if (pedidoQuery.docs.isEmpty) {
        setState(() {
          _orderId = null;
          _cargandoPedido = false;
        });
        return;
      }

      final pedidoDoc = pedidoQuery.docs.first;
      final pedidoData = pedidoDoc.data();
      final state = pedidoData['state'] as int?;

      setState(() {
        _orderId = pedidoDoc.id;
        _estadoActual = _estadoDesdeCodigo(state);
        _cargandoPedido = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoPedido = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar el pedido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarBottomSheetConfirmacion(String nuevoEstado) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cambiaras el estado a $nuevoEstado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text('¿Estas Seguro?', style: TextStyle(fontSize: 16)),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('No'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nuevoEstado == _estadoActual) {
                          Navigator.pop(context);
                          return;
                        }

                        if (_orderId == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No se encontro el pedido'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        final nuevoEstadoCode = _codigoDesdeEstado(nuevoEstado);

                        try {
                          await _firestore
                              .collection('orders')
                              .doc(_orderId)
                              .update({'state': nuevoEstadoCode});
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al actualizar el estado'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (!mounted) return;
                        setState(() {
                          _estadoActual = nuevoEstado;
                        });
                        Navigator.pop(context);
                        await _cargarPedido();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Sí'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarBottomSheetEstados() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Seleccionar Estado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(),
            ..._estados.map((estado) {
              return ListTile(
                title: Text(estado),
                trailing: _estadoActual == estado
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (estado == _estadoActual) {
                    return;
                  }
                  _mostrarBottomSheetConfirmacion(estado);
                },
              );
            }).toList(),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.numeroPedido),
            Text(
              widget.titulo,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_cargandoPedido)
                    const Center(child: CircularProgressIndicator())
                  else if (_orderId == null)
                    const Center(child: Text('No se encontro el pedido'))
                  else
                    StreamBuilder<QuerySnapshot>(
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
                          return const Center(
                            child: Text('No hay mensajes para este pedido'),
                          );
                        }

                        final mensajes = snapshot.data!.docs;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: mensajes.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final fecha = _formatearFecha(
                              data['createdAt'] as Timestamp?,
                            );
                            final descripcion =
                                (data['message'] as String?) ?? '';
                            final attachments =
                                (data['attachments'] as List<dynamic>?) ?? [];

                            return HistorialItem(
                              messageId: doc.id,
                              numeroPedido: widget.numeroPedido,
                              fecha: fecha,
                              descripcion: descripcion,
                              cantidadArchivos: attachments.length,
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: InkWell(
              onTap: _mostrarBottomSheetEstados,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estado: $_estadoActual',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
