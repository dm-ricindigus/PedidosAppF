import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/auth_repository.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:pedidosapp/features/auth/login.dart';
import 'package:pedidosapp/features/client/new_order_client.dart';
import 'package:pedidosapp/features/client/order_detail_client.dart';
import 'package:pedidosapp/features/client/widgets/home_client_widgets.dart';
import 'package:pedidosapp/shared/order_home_list_helpers.dart';
import 'package:pedidosapp/shared/widgets/logout_confirm_sheet.dart';
import 'package:pedidosapp/shared/widgets/order_item.dart';
import 'package:pedidosapp/services/fcm_service.dart';
import 'dart:developer' as developer;

class HomeClientPage extends StatefulWidget {
  const HomeClientPage({super.key});

  @override
  State<HomeClientPage> createState() => _HomeClientPageState();
}

class _HomeClientPageState extends State<HomeClientPage>
    with WidgetsBindingObserver {
  final AuthRepository _authRepo = AuthRepository();
  final OrdersRepository _ordersRepo = OrdersRepository();

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
      _refreshFcmToken();
    }
  }

  void _refreshFcmToken() {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) {
      FcmService.initAndSaveToken(uid);
    }
  }

  String _labelForClientOrderState(int estado) {
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => LogoutConfirmSheet(
        onCancel: () => Navigator.pop(modalContext),
        onLogout: () async {
          Navigator.pop(modalContext);
          try {
            final uid = _authRepo.currentUser?.uid;
            if (uid != null) {
              await FcmService.removeToken(uid);
            }
            await _authRepo.signOut();
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
      ),
    );
  }

  void _abrirModalCodigoPedido() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => OrderCodePedidoSheet(
        onSubmit: _handleOrderCodeSubmit,
      ),
    );
  }

  Future<void> _handleOrderCodeSubmit(
    String codigo,
    BuildContext sheetContext,
  ) async {
    try {
      final User? user = _authRepo.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Usuario no autenticado');
      }

      final String userEmail = user.email!.toLowerCase();

      developer.log(
        '🔵 Validando código: $codigo para usuario: $userEmail',
        name: 'ValidateOrderCode',
      );

      final codigoDoc = await _ordersRepo.getOrderCodeDoc(codigo);

      if (!codigoDoc.exists) {
        throw Exception('El código no existe');
      }

      final codigoData = codigoDoc.data()!;
      developer.log(
        '✅ Código encontrado: ${codigoData.toString()}',
        name: 'ValidateOrderCode',
      );

      final codigoClientEmail =
          (codigoData[FirestoreFields.clientEmail] as String?)
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

      final pedidosQuery = await _ordersRepo.ordersByCodeAndClient(
        orderCode: codigo,
        clientId: user.uid,
      );

      if (pedidosQuery.docs.isNotEmpty) {
        final pedidoData = pedidosQuery.docs.first.data();
        final estado = pedidoData[FirestoreFields.state] as int? ?? 0;
        if (estado >= 1) {
          throw Exception('Este código ya ha sido usado');
        }
      }

      final used = codigoData[FirestoreFields.used] as bool? ?? false;
      if (used) {
        throw Exception('Este código ya ha sido usado');
      }

      developer.log(
        '✅ Código válido, navegando a NewOrderPage',
        name: 'ValidateOrderCode',
      );

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewOrderPage(numeroPedido: codigo),
          ),
        );
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

      String errorMessage = 'Error al validar el código';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      developer.log(
        '📝 Mensaje de error a mostrar: $errorMessage',
        name: 'ValidateOrderCode',
      );

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
        developer.log('✅ Modal cerrado', name: 'ValidateOrderCode');
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        developer.log(
          '🔵 Mostrando bottom sheet de error',
          name: 'ValidateOrderCode',
        );
        await showClientValidationErrorSheet(context, errorMessage);
      } else {
        developer.log(
          '⚠️ Widget no montado, no se puede mostrar bottom sheet',
          name: 'ValidateOrderCode',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _authRepo.currentUser;
    final String userInfo = currentUser != null && currentUser.email != null
        ? '${currentUser.email}'
        : 'Cliente no identificado';
    final theme = Theme.of(context);
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
        title: ClientHomeAppBarTitle(
          userInfo: userInfo,
          onAccentColor: onAccentColor,
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
            ClientOrdersFilterRow(
              stateFilterOptions: kClientHomeOrderStateFilters,
              sortOptions: kOrderListSortOptions,
              selectedFilterId: _selectedFilterId,
              sortKey: _sortKey,
              filterLabel: orderListFilterLabel(_selectedFilterId),
              sortLabel: orderListSortLabel(_sortKey),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _authRepo.currentUser != null
                    ? _ordersRepo.watchClientOrders(_authRepo.currentUser!.uid)
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
                    return const ClientOrdersEmptyInbox();
                  }

                  var orderDocs = snapshot.data!.docs.toList();

                  if (_selectedFilterId == 7) {
                    orderDocs = orderDocs
                        .where(
                          (doc) =>
                              (doc.data()
                                      as Map<String, dynamic>)[FirestoreFields
                                  .state] !=
                              6,
                        )
                        .toList();
                  } else if (_selectedFilterId != 0) {
                    orderDocs = orderDocs
                        .where(
                          (doc) =>
                              (doc.data()
                                      as Map<String, dynamic>)[FirestoreFields
                                  .state] ==
                              _selectedFilterId,
                        )
                        .toList();
                  }

                  orderDocs = orderListSortedDocuments(orderDocs, _sortKey);

                  if (orderDocs.isEmpty) {
                    return const ClientOrdersEmptyFilter();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: orderDocs.length,
                    itemBuilder: (context, index) {
                      final pedidoDoc = orderDocs[index];
                      final pedidoData =
                          pedidoDoc.data() as Map<String, dynamic>;

                      final orderCode =
                          pedidoData[FirestoreFields.orderCode] as String? ??
                              '';
                      final title =
                          pedidoData[FirestoreFields.title] as String? ??
                              'Sin título';
                      final state =
                          pedidoData[FirestoreFields.state] as int? ?? 0;
                      final maxDeliveryTs =
                          pedidoData[FirestoreFields.maxDeliveryDate]
                              as Timestamp?;
                      final fechaMaxEntrega = maxDeliveryTs?.toDate();

                      return OrderItem(
                        numeroPedido: 'Pedido Nº $orderCode',
                        titulo: title,
                        estado: _labelForClientOrderState(state),
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
