import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/order_detail_client.dart';
import 'package:pedidosapp/new_order_client.dart';
import 'package:pedidosapp/login.dart';
import 'package:pedidosapp/widgets/order_item.dart';
import 'package:pedidosapp/services/fcm_service.dart';
import 'dart:developer' as developer;

class HomeClientPage extends StatefulWidget {
  const HomeClientPage({super.key});

  @override
  State<HomeClientPage> createState() => _HomeClientPageState();
}

class _HomeClientPageState extends State<HomeClientPage>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 0 = Todos, 1-6 = estados específicos, 7 = En proceso (todos menos Entregado)
  static const List<(int, String)> _filtros = [
    (0, 'Todos'),
    (7, 'En proceso'),
    (1, 'Ingresado'),
    (2, 'Impresión y Transferencia'),
    (3, 'Confección'),
    (4, 'Acabados'),
    (5, 'Empacado'),
    (6, 'Entregado'),
  ];

  static const List<(String, String)> _ordenes = [
    ('fecha_desc', 'Más reciente'),
    ('fecha_asc', 'Más antiguo'),
    ('estado', 'Por estado'),
    ('fecha_entrega', 'Por fecha de entrega'),
  ];

  int _filtroEstado = 7; // 7 = En proceso
  String _ordenTipo = 'fecha_desc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshFcmToken();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFcmToken();
    }
  }

  void _refreshFcmToken() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      FcmService.initAndSaveToken(uid);
    }
  }

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
        case 'fecha_entrega': {
          final aEntregado = aState == 6;
          final bEntregado = bState == 6;
          if (aEntregado && !bEntregado) return 1;
          if (!aEntregado && bEntregado) return -1;
          final aMaxDelivery = aData['maxDeliveryDate'] as Timestamp?;
          final bMaxDelivery = bData['maxDeliveryDate'] as Timestamp?;
          if (aEntregado && bEntregado) {
            if (aMaxDelivery == null && bMaxDelivery == null) return 0;
            if (aMaxDelivery == null) return 1;
            if (bMaxDelivery == null) return -1;
            return bMaxDelivery.compareTo(aMaxDelivery);
          }
          if (aMaxDelivery == null && bMaxDelivery == null) return 0;
          if (aMaxDelivery == null) return 1;
          if (bMaxDelivery == null) return -1;
          return aMaxDelivery.compareTo(bMaxDelivery);
        }
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

  void _mostrarModalConfirmarSalir() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    Navigator.pop(modalContext);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(modalContext).colorScheme.primary,
                  ),
                  child: Text('Cancelar'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(modalContext);
                    try {
                      final uid = _auth.currentUser?.uid;
                      if (uid != null) {
                        await FcmService.removeToken(uid);
                      }
                      await _auth.signOut();
                      if (mounted) {
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(title: 'Login'),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
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

  void _mostrarErrorBottomSheet(BuildContext context, String mensaje) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error de validación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(mensaje, style: TextStyle(fontSize: 16)),
              SizedBox(height: 24),
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

  void _abrirModalCodigoPedido() {
    final TextEditingController codigoController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !isLoading,
          child: Container(
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
                  'Codigo de pedido',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: codigoController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  enabled: !isLoading,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setState(
                      () {},
                    ); // Actualizar para habilitar/deshabilitar botón
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    counterText: '',
                    hintText: 'Ingresa 8 dígitos',
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    if (!isLoading)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    if (!isLoading) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isLoading || codigoController.text.length != 8)
                        ? null
                        : () async {
                            setState(() {
                              isLoading = true;
                            });

                            try {
                              final User? user = _auth.currentUser;
                              if (user == null || user.email == null) {
                                throw Exception('Usuario no autenticado');
                              }

                              final String codigo = codigoController.text;
                              final String userEmail = user.email!
                                  .toLowerCase();

                              developer.log(
                                '🔵 Validando código: $codigo para usuario: $userEmail',
                                name: 'ValidateOrderCode',
                              );

                              // 1. Verificar que el código existe en orderCodes
                              final codigoDoc = await _firestore
                                  .collection('orderCodes')
                                  .doc(codigo)
                                  .get();

                              if (!codigoDoc.exists) {
                                throw Exception('El código no existe');
                              }

                              final codigoData = codigoDoc.data()!;
                              developer.log(
                                '✅ Código encontrado: ${codigoData.toString()}',
                                name: 'ValidateOrderCode',
                              );

                              // 2. Verificar que el código está asociado al email del usuario
                              final codigoClientEmail =
                                  (codigoData['clientEmail'] as String?)
                                      ?.toLowerCase() ??
                                  '';
                              developer.log(
                                '📧 Email del código: $codigoClientEmail, Email del usuario: $userEmail',
                                name: 'ValidateOrderCode',
                              );
                              if (codigoClientEmail != userEmail) {
                                throw Exception(
                                  'Este código no está asociado a tu cuenta de correo',
                                );
                              }

                              // 3. Verificar que el código no ha sido usado
                              // Un código está usado si existe un pedido con ese código y state >= 1
                              final pedidosQuery = await _firestore
                                  .collection('orders')
                                  .where('orderCode', isEqualTo: codigo)
                                  .where('clientId', isEqualTo: user.uid)
                                  .limit(1)
                                  .get();

                              if (pedidosQuery.docs.isNotEmpty) {
                                final pedidoData = pedidosQuery.docs.first
                                    .data();
                                final estado = pedidoData['state'] as int? ?? 0;
                                if (estado >= 1) {
                                  throw Exception(
                                    'Este código ya ha sido usado',
                                  );
                                }
                              }

                              // 4. Verificar también el campo 'used' por si acaso
                              final used = codigoData['used'] as bool? ?? false;
                              if (used) {
                                throw Exception('Este código ya ha sido usado');
                              }

                              developer.log(
                                '✅ Código válido, navegando a NewOrderPage',
                                name: 'ValidateOrderCode',
                              );

                              // Si todo está bien, navegar a NewOrderPage
                              developer.log(
                                '✅ Todas las validaciones pasaron, cerrando modal y navegando',
                                name: 'ValidateOrderCode',
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          NewOrderPage(numeroPedido: codigo),
                                    ),
                                  );
                                }
                              }
                            } catch (e, stackTrace) {
                              developer.log(
                                '❌ Error validando código: $e',
                                name: 'ValidateOrderCode',
                              );
                              developer.log(
                                '❌ StackTrace: $stackTrace',
                                name: 'ValidateOrderCode',
                              );

                              String errorMessage =
                                  'Error al validar el código';
                              if (e is Exception) {
                                errorMessage = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                              }

                              developer.log(
                                '📝 Mensaje de error a mostrar: $errorMessage',
                                name: 'ValidateOrderCode',
                              );

                              // Cerrar el modal del código primero
                              if (context.mounted) {
                                Navigator.pop(context);
                                developer.log(
                                  '✅ Modal cerrado',
                                  name: 'ValidateOrderCode',
                                );
                              }

                              // Esperar un momento para que se cierre el modal
                              await Future.delayed(Duration(milliseconds: 300));

                              // Mostrar error en bottom sheet usando el contexto del widget padre
                              if (mounted) {
                                developer.log(
                                  '🔵 Mostrando bottom sheet de error',
                                  name: 'ValidateOrderCode',
                                );
                                _mostrarErrorBottomSheet(
                                  this.context,
                                  errorMessage,
                                );
                              } else {
                                developer.log(
                                  '⚠️ Widget no montado, no se puede mostrar bottom sheet',
                                  name: 'ValidateOrderCode',
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;
    final String userInfo = currentUser != null && currentUser.email != null
        ? '${currentUser.email}'
        : 'Cliente no identificado';
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
            onPressed: _mostrarModalConfirmarSalir,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalCodigoPedido,
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo pedido'),
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
                stream: _auth.currentUser != null
                    ? _firestore
                          .collection('orders')
                          .where('clientId', isEqualTo: _auth.currentUser!.uid)
                          .snapshots()
                    : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error al cargar pedidos: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    final colorScheme = Theme.of(context).colorScheme;
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
                            'No tienes pedidos aún',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crea tu primer pedido',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }

                  var pedidos = snapshot.data!.docs.toList();

                  if (_filtroEstado == 7) {
                    pedidos = pedidos
                        .where(
                          (doc) =>
                              (doc.data() as Map<String, dynamic>)['state'] !=
                              6,
                        )
                        .toList();
                  } else if (_filtroEstado != 0) {
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
                    final colorScheme = Theme.of(context).colorScheme;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list_off,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay pedidos con este filtro',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: pedidos.length,
                    itemBuilder: (context, index) {
                      final pedidoDoc = pedidos[index];
                      final pedidoData =
                          pedidoDoc.data() as Map<String, dynamic>;

                      final orderCode =
                          pedidoData['orderCode'] as String? ?? '';
                      final title =
                          pedidoData['title'] as String? ?? 'Sin título';
                      final state = pedidoData['state'] as int? ?? 0;
                      final maxDeliveryTs =
                          pedidoData['maxDeliveryDate'] as Timestamp?;
                      final fechaMaxEntrega =
                          maxDeliveryTs?.toDate();

                      return OrderItem(
                        numeroPedido: 'Pedido Nº $orderCode',
                        titulo: title,
                        estado: _obtenerEstadoTexto(state),
                        fechaMaxEntrega: fechaMaxEntrega,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailPage(
                                numeroPedido: 'Pedido Nº $orderCode',
                                titulo: title,
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
