import 'package:flutter/material.dart';
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
import 'dart:developer' as developer;

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  final AuthRepository _authRepo = AuthRepository();
  final OrdersRepository _ordersRepo = OrdersRepository();

  /// Correo por código cuando el doc `orders` no trae [FirestoreFields.clientEmail] (pedidos viejos).
  final Map<String, String> _clientEmailByOrderCode = {};
  final Set<String> _clientEmailFetchInFlight = <String>{};

  int _selectedFilterId = 7; // 7 = in progress (all except delivered)
  String _sortKey = 'fecha_desc';

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
            ? (snap.data()?[FirestoreFields.clientEmail] as String?)
                    ?.trim() ??
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
          try {
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

  void _showCreateOrderCodeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetCtx) => AdminCreateOrderCodeSheet(
        onSubmit: (email, sheetContext) =>
            _createOrderCode(email, sheetContext),
      ),
    );
  }

  static const String _pendingClientEntryTitle =
      'Pendiente de ingreso por el cliente';

  Widget _buildUnusedOrderCodesList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersRepo.watchUnusedOrderCodesByCreatedAtDesc(),
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
            return OrderItem(
              numeroPedido: 'ID de Pedido: $code',
              titulo: _pendingClientEntryTitle,
              estado: '',
              clientEmail: data[FirestoreFields.clientEmail] as String?,
              fechaCreado: createdAt,
              hideEstadoChip: true,
            );
          },
        );
      },
    );
  }

  Widget _buildOrdersList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersRepo.watchAllOrdersByCreatedAtDesc(),
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

            return OrderItem(
              numeroPedido: orderDisplayLine,
              titulo: orderTitle,
              estado: _labelForOrderState(state),
              clientEmail: _clientEmailForOrderListItem(data, orderCode.trim()),
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
            );
          },
        );
      },
    );
  }

  Future<void> _createOrderCode(
    String email,
    BuildContext sheetContext,
  ) async {
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
        'authToken': idToken,
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
              sortLabel: _selectedFilterId ==
                      kAdminOrderListFilterPendingClientEntry
                  ? orderListSortLabel('fecha_desc')
                  : orderListSortLabel(_sortKey),
              sortEnabled: _selectedFilterId !=
                  kAdminOrderListFilterPendingClientEntry,
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
              child: _selectedFilterId == kAdminOrderListFilterPendingClientEntry
                  ? _buildUnusedOrderCodesList(context)
                  : _buildOrdersList(context),
            ),
          ],
        ),
      ),
    );
  }
}
