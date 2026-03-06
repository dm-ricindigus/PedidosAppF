import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pedidosapp/widgets/order_item.dart';
import 'package:pedidosapp/login.dart';
import 'package:pedidosapp/order_detail_admin.dart';
import 'dart:developer' as developer;

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  /// 0 = Todos, 1-5 = estados específicos
  static const List<(int, String)> _filtros = [
    (0, 'Todos'),
    (1, 'Ingresado'),
    (2, 'Impresión y Transferencia'),
    (3, 'Confección'),
    (4, 'Acabados'),
    (5, 'Empacado'),
  ];

  static const List<(String, String)> _ordenes = [
    ('fecha_desc', 'Más reciente'),
    ('fecha_asc', 'Más antiguo'),
    ('estado', 'Por estado'),
  ];

  int _filtroEstado = 0;
  String _ordenTipo = 'fecha_desc';

  String _obtenerFiltroLabel() {
    return _filtros
        .firstWhere((f) => f.$1 == _filtroEstado, orElse: () => _filtros.first)
        .$2;
  }

  String _obtenerOrdenLabel() {
    return _ordenes
        .firstWhere((o) => o.$1 == _ordenTipo, orElse: () => _ordenes.first)
        .$2;
  }

  List<QueryDocumentSnapshot> _aplicarOrden(
    List<QueryDocumentSnapshot> pedidos,
  ) {
    final lista = List<QueryDocumentSnapshot>.from(pedidos);
    lista.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>? ?? {};
      final bData = b.data() as Map<String, dynamic>? ?? {};
      final aCreatedAt = aData['createdAt'] as Timestamp?;
      final bCreatedAt = bData['createdAt'] as Timestamp?;
      final aState = aData['state'] as int? ?? 0;
      final bState = bData['state'] as int? ?? 0;

      switch (_ordenTipo) {
        case 'fecha_asc':
          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;
          return aCreatedAt.compareTo(bCreatedAt);
        case 'estado':
          final cmpEstado = aState.compareTo(bState);
          if (cmpEstado != 0) return cmpEstado;
          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;
          return bCreatedAt.compareTo(aCreatedAt);
        case 'fecha_desc':
        default:
          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;
          return bCreatedAt.compareTo(aCreatedAt);
      }
    });
    return lista;
  }

  String _estadoDesdeCodigo(int? state) {
    switch (state) {
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
        return 'Sin estado';
    }
  }

  void _mostrarModalConfirmarSalir(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;

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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '¿Estás seguro de que deseas cerrar sesión?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Text('Cancelar'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await _auth.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const LoginPage(title: 'Login'),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al cerrar sesión: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Cerrar sesión'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarModalConfirmacion(BuildContext context, String codigo) {
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  'Se creó el código de pedido:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Spacer(),
                  Text(
                    codigo,
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codigo));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Código copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Spacer(),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirModalNuevoPedido(BuildContext context) {
    final TextEditingController correoController = TextEditingController();
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
      app: _auth.app,
      region: 'us-central1',
    );
    bool _isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Indica el correo del cliente',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Ingresa el correo del cliente',
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (correoController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Por favor ingresa un correo'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              developer.log(
                                '🔵 Iniciando creación de código...',
                                name: 'CreateOrderCode',
                              );

                              // Obtener token de autenticación
                              final User? user = _auth.currentUser;
                              if (user == null) {
                                throw Exception('Usuario no autenticado');
                              }

                              developer.log(
                                '✅ Usuario autenticado: ${user.email}',
                                name: 'CreateOrderCode',
                              );

                              final String? idToken = await user.getIdToken(
                                true,
                              );
                              if (idToken == null) {
                                throw Exception('No se pudo obtener el token');
                              }

                              developer.log(
                                '✅ Token obtenido',
                                name: 'CreateOrderCode',
                              );
                              developer.log(
                                '📧 Email del cliente: ${correoController.text.trim()}',
                                name: 'CreateOrderCode',
                              );

                              // Llamar a la Cloud Function
                              final HttpsCallable callable = _functions
                                  .httpsCallable('createOrderCode');

                              developer.log(
                                '📞 Llamando a Cloud Function...',
                                name: 'CreateOrderCode',
                              );

                              final result = await callable.call({
                                'clientEmail': correoController.text.trim(),
                                '_authToken': idToken,
                              });

                              developer.log(
                                '✅ Respuesta recibida: $result',
                                name: 'CreateOrderCode',
                              );

                              final data = result.data as Map<String, dynamic>;
                              developer.log(
                                '📦 Datos: $data',
                                name: 'CreateOrderCode',
                              );

                              if (data['success'] == true &&
                                  data['code'] != null) {
                                final codigo = data['code'] as String;
                                developer.log(
                                  '✅ Código generado: $codigo',
                                  name: 'CreateOrderCode',
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _mostrarModalConfirmacion(context, codigo);
                                }
                              } else {
                                developer.log(
                                  '❌ Respuesta inválida: $data',
                                  name: 'CreateOrderCode',
                                );
                                throw Exception(
                                  'Respuesta inválida de la función',
                                );
                              }
                            } catch (e, stackTrace) {
                              developer.log(
                                '❌ Error: $e',
                                name: 'CreateOrderCode',
                              );
                              developer.log(
                                '❌ StackTrace: $stackTrace',
                                name: 'CreateOrderCode',
                              );

                              if (context.mounted) {
                                String errorMessage =
                                    'Error al crear el código';
                                if (e is FirebaseFunctionsException) {
                                  errorMessage = e.message ?? errorMessage;
                                  developer.log(
                                    '❌ FirebaseFunctionsException: ${e.code} - ${e.message}',
                                    name: 'CreateOrderCode',
                                  );
                                } else {
                                  errorMessage = e.toString();
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final User? currentUser = _auth.currentUser;
    final String userInfo = currentUser != null && currentUser.email != null
        ? 'Administrador: ${currentUser.email}'
        : 'Administrador: No identificado';
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final Color accentColor = theme.colorScheme.primary;
    const Color onAccentColor = Colors.white;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
              'Pedidos',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: onAccentColor,
              ),
            ),
            Text(
              userInfo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _mostrarModalConfirmarSalir(context);
            },
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _abrirModalNuevoPedido(context);
        },
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear ID de Pedido'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<int>(
                      initialValue: _filtroEstado,
                      onSelected: (value) =>
                          setState(() => _filtroEstado = value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 20,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _obtenerFiltroLabel(),
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => _filtros
                          .map(
                            (f) => PopupMenuItem<int>(
                              value: f.$1,
                              child: Text(f.$2),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PopupMenuButton<String>(
                      initialValue: _ordenTipo,
                      onSelected: (value) => setState(() {
                            _ordenTipo = value;
                            if (value == 'estado') _filtroEstado = 0;
                          }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_vert_rounded,
                              size: 20,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _obtenerOrdenLabel(),
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => _ordenes
                          .map(
                            (o) => PopupMenuItem<String>(
                              value: o.$1,
                              child: Text(o.$2),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('orders')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar pedidos: ${snapshot.error}',
                        style: textTheme.bodyMedium,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    final colorScheme = theme.colorScheme;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay pedidos registrados',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  var pedidos = snapshot.data!.docs.toList();

                  if (_filtroEstado != 0) {
                    pedidos = pedidos
                        .where(
                          (doc) =>
                              (doc.data() as Map<String, dynamic>)['state'] ==
                              _filtroEstado,
                        )
                        .toList();
                  }

                  pedidos = _aplicarOrden(pedidos);

                  if (pedidos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list_off,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay pedidos con este filtro',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: pedidos.length,
                    itemBuilder: (context, index) {
                      final data =
                          pedidos[index].data() as Map<String, dynamic>;
                      final String orderCode =
                          (data['orderCode'] as String?) ?? 'Sin codigo';
                      final String titulo =
                          (data['title'] as String?) ?? 'Sin titulo';
                      final int? state = data['state'] as int?;
                      final String numeroPedido = 'Pedido Nº $orderCode';

                      return OrderItem(
                        numeroPedido: numeroPedido,
                        titulo: titulo,
                        estado: _estadoDesdeCodigo(state),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailAdminPage(
                                numeroPedido: numeroPedido,
                                titulo: titulo,
                                estadoInicial: _estadoDesdeCodigo(state),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
