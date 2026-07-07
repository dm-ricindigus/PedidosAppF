import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/auth_repository.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:pedidosapp/features/admin/order_detail_admin.dart';
import 'package:pedidosapp/features/admin/widgets/home_admin_widgets.dart';
import 'package:pedidosapp/features/auth/login.dart';
import 'package:pedidosapp/shared/order_home_list_helpers.dart';
import 'package:pedidosapp/shared/widgets/logout_confirm_sheet.dart';
import 'package:pedidosapp/shared/widgets/order_item.dart';
import 'package:pedidosapp/services/fcm_service.dart';
import 'package:pedidosapp/services/force_update_service.dart';
import 'dart:developer' as developer;

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage>
    with WidgetsBindingObserver {
  final AuthRepository _authRepo = AuthRepository();
  final OrdersRepository _ordersRepo = OrdersRepository();

  /// Correo por código cuando el doc `orders` no trae [FirestoreFields.clientEmail] (pedidos viejos).
  final Map<String, String> _clientEmailByOrderCode = {};
  final Set<String> _clientEmailFetchInFlight = <String>{};

  int _selectedFilterId = 7; // 7 = in progress (all except delivered)
  String _sortKey = 'fecha_desc';

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
      ForceUpdateService.instance.revalidate();
      _refreshFcmToken();
    }
  }

  void _refreshFcmToken() {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) {
      FcmService.initAndSaveToken(uid);
    }
  }

  void _prefetchClientEmailsFromOrderCodes(
    List<QueryDocumentSnapshot> orderDocs,
  ) {
    for (final doc in orderDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final code = (data[FirestoreFields.orderCode] as String?)?.trim() ?? '';
      if (code.isEmpty) continue;

      final onDoc =
          (data[FirestoreFields.clientEmail] as String?)?.trim() ?? '';
      if (onDoc.isNotEmpty) continue;

      if (_clientEmailByOrderCode.containsKey(code)) continue;
      if (_clientEmailFetchInFlight.contains(code)) continue;

      _clientEmailFetchInFlight.add(code);
      _ordersRepo.getOrderCodeDoc(code).then((snap) {
        if (!mounted) return;
        final email = snap.exists
            ? (snap.data()?[FirestoreFields.clientEmail] as String?)?.trim() ??
                  ''
            : '';
        setState(() {
          _clientEmailFetchInFlight.remove(code);
          _clientEmailByOrderCode[code] = email;
        });
      });
    }
  }

  String? _clientEmailForOrderListItem(
    Map<String, dynamic> data,
    String orderCode,
  ) {
    final onDoc = (data[FirestoreFields.clientEmail] as String?)?.trim() ?? '';
    if (onDoc.isNotEmpty) return onDoc;
    final cached = _clientEmailByOrderCode[orderCode];
    if (cached == null || cached.isEmpty) return null;
    return cached;
  }

  String _labelForOrderState(int? state) {
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
      case 6:
        return 'Entregado';
      default:
        return 'Sin estado';
    }
  }

  void _showLogoutConfirmSheet(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => LogoutConfirmSheet(
        onCancel: () => Navigator.pop(modalContext),
        onLogout: () async {
          Navigator.pop(modalContext);
          final uid = _authRepo.currentUser?.uid;
          try {
            if (uid != null) {
              await FcmService.removeToken(uid);
            }
            await _authRepo.signOut();
            if (context.mounted) {
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const LoginPage(title: 'Login'),
                ),
                (route) => false,
              );
            }
          } catch (e) {
            if (context.mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Error al cerrar sesión: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showCreateOrderCodeSheet(
    BuildContext context, {
    String? initialClientEmail,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetCtx) => AdminCreateOrderCodeSheet(
        initialClientEmail: initialClientEmail,
        onSubmit: (email, sheetContext) =>
            _createOrderCode(email, sheetContext),
      ),
    );
  }

  void _showOrderItemLongPressMenu(
    BuildContext context, {
    required String orderCode,
    required String? prefilledClientEmail,
  }) {
    final theme = Theme.of(context);
    final email = prefilledClientEmail?.trim() ?? '';
    final hasEmail = email.isNotEmpty;
    final idTrimmed = orderCode.trim();
    final hasOrderId = idTrimmed.isNotEmpty && idTrimmed != 'Sin codigo';

    void snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.add_circle_outline_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Crear nuevo ID de pedido'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateOrderCodeSheet(
                      context,
                      initialClientEmail: prefilledClientEmail,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.alternate_email_rounded,
                    color: hasEmail
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Copiar correo'),
                  enabled: hasEmail,
                  onTap: hasEmail
                      ? () {
                          Clipboard.setData(ClipboardData(text: email));
                          Navigator.pop(ctx);
                          snack('Correo copiado al portapapeles');
                        }
                      : null,
                ),
                ListTile(
                  leading: Icon(
                    Icons.tag_rounded,
                    color: hasOrderId
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Copiar ID de pedido'),
                  enabled: hasOrderId,
                  onTap: hasOrderId
                      ? () {
                          Clipboard.setData(ClipboardData(text: idTrimmed));
                          Navigator.pop(ctx);
                          snack('ID de pedido copiado al portapapeles');
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const String _pendingClientEntryTitle =
      'Pendiente de ingreso por el cliente';

  Widget _buildUnusedOrderCodesList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_authRepo.currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Inicia sesión de nuevo para ver los códigos pendientes.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersRepo.watchAllUnusedOrderCodesCreatedAtDesc(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar códigos: ${snapshot.error}',
              style: textTheme.bodyMedium,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const AdminOrdersEmptyFilter();
        }

        final List<QueryDocumentSnapshot> unusedCodeDocs =
            List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: unusedCodeDocs.length,
          itemBuilder: (context, index) {
            final doc = unusedCodeDocs[index];
            final String code = doc.id;
            final data = doc.data() as Map<String, dynamic>;
            final createdTs = data[FirestoreFields.createdAt] as Timestamp?;
            final createdAt = createdTs?.toDate();
            final String? pendingEmail = () {
              final s =
                  (data[FirestoreFields.clientEmail] as String?)?.trim() ?? '';
              return s.isNotEmpty ? s : null;
            }();
            return OrderItem(
              numeroPedido: 'ID de Pedido: $code',
              titulo: _pendingClientEntryTitle,
              estado: '',
              clientEmail: pendingEmail,
              fechaCreado: createdAt,
              hideEstadoChip: true,
              onLongPress: () => _showOrderItemLongPressMenu(
                context,
                orderCode: code,
                prefilledClientEmail: pendingEmail,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrdersList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_authRepo.currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Inicia sesión de nuevo para ver los pedidos.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersRepo.watchAllOrdersCreatedAtDesc(),
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
          return const AdminOrdersEmptyInbox();
        }

        List<QueryDocumentSnapshot> orderDocs =
            List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

        if (_selectedFilterId != 0 &&
            _selectedFilterId != kAdminOrderListFilterPendingClientEntry) {
          if (_selectedFilterId == 7) {
            orderDocs = orderDocs
                .where(
                  (doc) =>
                      (doc.data()
                          as Map<String, dynamic>)[FirestoreFields.state] !=
                      6,
                )
                .toList();
          } else {
            orderDocs = orderDocs
                .where(
                  (doc) =>
                      (doc.data()
                          as Map<String, dynamic>)[FirestoreFields.state] ==
                      _selectedFilterId,
                )
                .toList();
          }
        }

        orderDocs = orderListSortedDocuments(orderDocs, _sortKey);

        if (orderDocs.isEmpty) {
          return const AdminOrdersEmptyFilter();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _prefetchClientEmailsFromOrderCodes(orderDocs);
          }
        });

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: orderDocs.length,
          itemBuilder: (context, index) {
            final data = orderDocs[index].data() as Map<String, dynamic>;
            final String orderCode =
                (data[FirestoreFields.orderCode] as String?) ?? 'Sin codigo';
            final String orderTitle =
                (data[FirestoreFields.title] as String?) ?? 'Sin titulo';
            final int? state = data[FirestoreFields.state] as int?;
            final maxDeliveryTs =
                data[FirestoreFields.maxDeliveryDate] as Timestamp?;
            final DateTime? maxDeliveryDate = maxDeliveryTs?.toDate();
            final String orderDisplayLine = 'Pedido Nº $orderCode';
            final String? listClientEmail =
                _clientEmailForOrderListItem(data, orderCode.trim());

            return OrderItem(
              numeroPedido: orderDisplayLine,
              titulo: orderTitle,
              estado: _labelForOrderState(state),
              clientEmail: listClientEmail,
              fechaMaxEntrega: maxDeliveryDate,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailAdminPage(
                      orderDisplayLine: orderDisplayLine,
                      title: orderTitle,
                      initialStateLabel: _labelForOrderState(state),
                    ),
                  ),
                );
              },
              onLongPress: () => _showOrderItemLongPressMenu(
                context,
                orderCode: orderCode.trim(),
                prefilledClientEmail: listClientEmail,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createOrderCode(String email, BuildContext sheetContext) async {
    if (email.isEmpty) {
      if (sheetContext.mounted) {
        await showAdminErrorSheet(sheetContext, 'Por favor ingresa un correo');
      }
      return;
    }

    final functions = FirebaseFunctions.instanceFor(
      app: _authRepo.firebaseApp,
      region: 'us-central1',
    );

    try {
      developer.log(
        '🔵 Iniciando creación de código...',
        name: 'CreateOrderCode',
      );

      final User? user = _authRepo.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      developer.log(
        '✅ Usuario autenticado: ${user.email}',
        name: 'CreateOrderCode',
      );

      final String? idToken = await user.getIdToken(true);
      if (idToken == null) {
        throw Exception('No se pudo obtener el token');
      }

      developer.log('✅ Token obtenido', name: 'CreateOrderCode');
      developer.log('📧 Email del cliente: $email', name: 'CreateOrderCode');

      final HttpsCallable callable = functions.httpsCallable('createOrderCode');

      developer.log('📞 Llamando a Cloud Function...', name: 'CreateOrderCode');

      final result = await callable.call({
        'clientEmail': email,
        '_authToken': idToken,
      });

      developer.log('✅ Respuesta recibida: $result', name: 'CreateOrderCode');

      final data = result.data as Map<String, dynamic>;
      developer.log('📦 Datos: $data', name: 'CreateOrderCode');

      if (data[CloudCallableKeys.success] == true &&
          data[CloudCallableKeys.code] != null) {
        final generatedCode = data[CloudCallableKeys.code] as String;
        developer.log(
          '✅ Código generado: $generatedCode',
          name: 'CreateOrderCode',
        );

        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        if (mounted) {
          await showAdminOrderCodeCreatedSheet(context, generatedCode);
        }
      } else {
        developer.log('❌ Respuesta inválida: $data', name: 'CreateOrderCode');
        throw Exception('Respuesta inválida de la función');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error: $e', name: 'CreateOrderCode');
      developer.log('❌ StackTrace: $stackTrace', name: 'CreateOrderCode');

      if (sheetContext.mounted) {
        String errorMessage = 'Error al crear el código';
        if (e is FirebaseFunctionsException) {
          errorMessage = e.message ?? errorMessage;
          developer.log(
            '❌ FirebaseFunctionsException: ${e.code} - ${e.message}',
            name: 'CreateOrderCode',
          );
        } else {
          errorMessage = e.toString();
        }
        await showAdminErrorSheet(sheetContext, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _authRepo.currentUser;
    final String userInfo = currentUser != null && currentUser.email != null
        ? 'Administrador: ${currentUser.email}'
        : 'Administrador: No identificado';
    final theme = Theme.of(context);
    final Color accentColor = theme.colorScheme.primary;
    const Color onAccentColor = Colors.white;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        title: AdminHomeAppBarTitle(
          userInfo: userInfo,
          onAccentColor: onAccentColor,
        ),
        actions: [
          IconButton(
            onPressed: () => _showLogoutConfirmSheet(context),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderCodeSheet(context),
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear ID de Pedido'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AdminOrdersFilterRow(
              stateFilterOptions: kAdminHomeOrderStateFilters,
              sortOptions: kOrderListSortOptions,
              selectedFilterId: _selectedFilterId,
              sortKey: _sortKey,
              filterLabel: orderListFilterLabel(_selectedFilterId),
              sortLabel:
                  _selectedFilterId == kAdminOrderListFilterPendingClientEntry
                  ? orderListSortLabel('fecha_desc')
                  : orderListSortLabel(_sortKey),
              sortEnabled:
                  _selectedFilterId != kAdminOrderListFilterPendingClientEntry,
              onFilterSelected: (value) =>
                  setState(() => _selectedFilterId = value),
              onSortSelected: (value) => setState(() {
                _sortKey = value;
                if (value == 'estado') {
                  _selectedFilterId = 0;
                }
              }),
              accentColor: accentColor,
            ),
            Expanded(
              child:
                  _selectedFilterId == kAdminOrderListFilterPendingClientEntry
                  ? _buildUnusedOrderCodesList(context)
                  : _buildOrdersList(context),
            ),
          ],
        ),
      ),
    );
  }
}
