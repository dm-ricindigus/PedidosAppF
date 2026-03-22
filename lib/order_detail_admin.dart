import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pedidosapp/message_detail_admin.dart';
import 'package:pedidosapp/widgets/order_item.dart';

class HistorialItem extends StatelessWidget {
  final String messageId;
  final String numeroPedido;
  final String titulo;
  final String fecha;
  final String descripcion;
  final int cantidadArchivos;

  const HistorialItem({
    super.key,
    required this.messageId,
    required this.numeroPedido,
    required this.titulo,
    required this.fecha,
    required this.descripcion,
    required this.cantidadArchivos,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageDetailAdminPage(
              messageId: messageId,
              numeroPedido: numeroPedido,
              titulo: titulo,
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

class OrderDetailAdminPage extends StatefulWidget {
  final String numeroPedido;
  final String titulo;
  final String? estadoInicial;

  const OrderDetailAdminPage({
    super.key,
    required this.numeroPedido,
    required this.titulo,
    this.estadoInicial,
  });

  @override
  State<OrderDetailAdminPage> createState() => _OrderDetailAdminPageState();
}

class _OrderDetailAdminPageState extends State<OrderDetailAdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _estadoActual;
  String? _orderId;
  Timestamp? _maxDeliveryDate;
  bool _cargandoPedido = true;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.estadoInicial ?? _estados.first;
    _cargarPedido();
  }

  final List<String> _estados = [
    'Ingresado',
    'Impresión y Transferencia',
    'Confección',
    'Acabados',
    'Empacado',
    'Entregado',
  ];

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

  String _formatearFechaCorta(Timestamp? timestamp) {
    if (timestamp == null) return 'No disponible';
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
      final maxDeliveryDate = pedidoData['maxDeliveryDate'] as Timestamp?;

      setState(() {
        _orderId = pedidoDoc.id;
        _estadoActual = _estadoDesdeCodigo(state);
        _maxDeliveryDate = maxDeliveryDate;
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
              final (_, colorFg, icono) = obtenerEstiloEstado(
                estado,
                Theme.of(context).colorScheme,
              );
              return ListTile(
                leading: Icon(icono, size: 22, color: colorFg),
                title: Text(
                  estado,
                  style: TextStyle(color: colorFg, fontWeight: FontWeight.w600),
                ),
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final Color accentColor = theme.colorScheme.primary;
    const Color onAccentColor = Colors.white;
    final (chipBg, chipFg, chipIcon) = obtenerEstiloEstado(
      _estadoActual,
      theme.colorScheme,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.numeroPedido,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: onAccentColor,
              ),
            ),
            Text(
              widget.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _mostrarBottomSheetEstados,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(chipIcon, size: 20, color: chipFg),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _estadoActual,
                            style: textTheme.titleSmall?.copyWith(
                              color: chipFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: chipFg),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fecha máxima de entrega: ${_formatearFechaCorta(_maxDeliveryDate)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _cargandoPedido
                  ? const Center(child: CircularProgressIndicator())
                  : _orderId == null
                  ? const Center(child: Text('No se encontro el pedido'))
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
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        final mensajes = snapshot.data!.docs;

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: mensajes.length,
                          itemBuilder: (context, index) {
                            final data =
                                mensajes[index].data() as Map<String, dynamic>;
                            final fecha = _formatearFecha(
                              data['createdAt'] as Timestamp?,
                            );
                            final descripcion =
                                (data['message'] as String?) ?? '';
                            final attachments =
                                (data['attachments'] as List<dynamic>?) ?? [];

                            return HistorialItem(
                              messageId: mensajes[index].id,
                              numeroPedido: widget.numeroPedido,
                              titulo: widget.titulo,
                              fecha: fecha,
                              descripcion: descripcion,
                              cantidadArchivos: attachments.length,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
