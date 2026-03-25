import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:developer' as developer;

import 'package:pedidosapp/features/client/widgets/client_order_form_widgets.dart';

class NewOrderPage extends StatefulWidget {
  final String numeroPedido;

  const NewOrderPage({super.key, required this.numeroPedido});

  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  final List<ArchivoAdjunto> _archivos = [];
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrdersRepository _ordersRepo = OrdersRepository();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;
  bool _isLoadingSheetOpen = false;
  String? _draftOrderId;
  String? _draftMessageId;
  DateTime? _fechaMaxEntrega;
  static const int _maxCaracteresTitulo = 50;
  static const int _maxCaracteresDescripcion = 500;
  static const int _maxTamanoArchivoBytes = 6 * 1024 * 1024;
  static const int _concurrenciaSubida = 3;

  DateTime get _fechaMinima {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  DateTime get _fechaMaxima {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 2, now.day);
  }

  String _formatearFecha(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _abrirDatePicker() async {
    if (_isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaMaxEntrega ?? _fechaMinima,
      firstDate: _fechaMinima,
      lastDate: _fechaMaxima,
      helpText: 'Fecha máxima de entrega',
    );
    if (picked != null && mounted) {
      setState(() => _fechaMaxEntrega = picked);
    }
  }

  bool get _puedeGuardar {
    return !_isLoading &&
        _tituloController.text.trim().isNotEmpty &&
        _descripcionController.text.trim().isNotEmpty &&
        _fechaMaxEntrega != null;
  }

  void _onCamposChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _obtenerDraftOrderId() {
    _draftOrderId ??= _ordersRepo.newOrderId();
    return _draftOrderId!;
  }

  String _obtenerDraftMessageId() {
    _draftMessageId ??= _ordersRepo.newMessageId();
    return _draftMessageId!;
  }

  @override
  void initState() {
    super.initState();
    _tituloController.addListener(_onCamposChanged);
    _descripcionController.addListener(_onCamposChanged);
  }

  void _mostrarExitoBottomSheet(BuildContext context) {
    showOrderFormSuccessSheet(
      context,
      title: 'Pedido guardado',
      subtitle: 'Tu pedido ha sido guardado exitosamente',
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
    );
  }

  void _mostrarCargandoBottomSheet() {
    if (!mounted || _isLoadingSheetOpen) return;
    _isLoadingSheetOpen = true;

    showOrderFormProgressSheet(
      context,
      message: 'Enviando pedido, por favor espera...',
    ).whenComplete(() {
      _isLoadingSheetOpen = false;
    });
  }

  void _cerrarCargandoBottomSheet() {
    if (!mounted || !_isLoadingSheetOpen) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _guardarPedido() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario no autenticado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _mostrarCargandoBottomSheet();
    bool guardadoExitoso = false;

    try {
      final String titulo = _tituloController.text.trim();
      final String descripcion = _descripcionController.text.trim();
      final String orderCode = widget.numeroPedido;
      final String orderId = _obtenerDraftOrderId();
      final String messageId = _obtenerDraftMessageId();
      final orderRef = _ordersRepo.orderRef(orderId);
      final messageRef = _ordersRepo.messageRef(messageId);

      await _subirAdjuntos(
        orderId: orderRef.id,
        messageId: messageRef.id,
        userId: user.uid,
      );

      final bool hayFallidos = _archivos.any(
        (a) => a.estado == EstadoAdjunto.failed,
      );

      if (hayFallidos) {
        throw Exception(
          'No se pudieron subir todos los archivos. Reintenta guardando nuevamente.',
        );
      }

      developer.log(
        '💾 Guardando pedido: código=$orderCode, título=$titulo',
        name: 'SaveOrder',
      );

      // Crear el documento del pedido
      await orderRef.set({
        FirestoreFields.orderCode: orderCode,
        FirestoreFields.title: titulo,
        FirestoreFields.state: 1, // Estado 1: Ingresado
        FirestoreFields.clientId: user.uid,
        FirestoreFields.clientEmail:
            (user.email ?? '').trim().toLowerCase(),
        FirestoreFields.maxDeliveryDate: Timestamp.fromDate(_fechaMaxEntrega!),
        FirestoreFields.createdAt: FieldValue.serverTimestamp(),
      });

      developer.log(
        '✅ Pedido creado con ID: ${orderRef.id}',
        name: 'SaveOrder',
      );

      // Crear el primer mensaje asociado al pedido
      await messageRef.set({
        FirestoreFields.orderId: orderRef.id,
        FirestoreFields.message: descripcion,
        FirestoreFields.userId: user.uid,
        FirestoreFields.attachments: _archivos
            .where((a) => a.estado == EstadoAdjunto.uploaded)
            .map(
              (a) => {
                AttachmentField.name: a.file.name,
                AttachmentField.size: a.file.size,
                AttachmentField.extension: a.file.extension,
                AttachmentField.url: a.urlDescarga,
                AttachmentField.storagePath: a.rutaStorage,
              },
            )
            .toList(),
        FirestoreFields.createdAt: FieldValue.serverTimestamp(),
      });

      developer.log(
        '✅ Mensaje inicial creado para pedido: ${orderRef.id}',
        name: 'SaveOrder',
      );

      // Marcar el código como usado en orderCodes
      await _ordersRepo.markOrderCodeUsed(
        orderCode: orderCode,
        usedByUid: user.uid,
      );

      developer.log(
        '✅ Código marcado como usado: $orderCode',
        name: 'SaveOrder',
      );
      guardadoExitoso = true;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error al guardar pedido: $e',
        name: 'SaveOrder',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _cerrarCargandoBottomSheet();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (guardadoExitoso && mounted) {
        final BuildContext rootContext = Navigator.of(
          context,
          rootNavigator: true,
        ).context;
        Navigator.of(context).pop();
        Future.delayed(const Duration(milliseconds: 300), () {
          _mostrarExitoBottomSheet(rootContext);
        });
      }
    }
  }

  Future<void> _agregarArchivo() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null) return;

    final archivosExcedidos = result.files
        .where((archivo) => archivo.size > _maxTamanoArchivoBytes)
        .toList();

    final List<ArchivoAdjunto> nuevosArchivos = result.files
        .where((archivo) => archivo.size <= _maxTamanoArchivoBytes)
        .where((archivo) {
          return !_archivos.any(
            (existente) =>
                existente.file.name == archivo.name &&
                existente.file.size == archivo.size,
          );
        })
        .map((archivo) => ArchivoAdjunto(file: archivo))
        .toList();

    if (archivosExcedidos.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${archivosExcedidos.length} archivo(s) exceden el limite de 6 MB y no fueron agregados',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }

    if (nuevosArchivos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay archivos nuevos para agregar (revisar duplicados o tamano)',
          ),
        ),
      );
      return;
    }

    setState(() {
      _archivos.insertAll(0, nuevosArchivos);
    });
  }

  void _eliminarArchivo(int index) {
    if (_isLoading) return;
    setState(() {
      _archivos.removeAt(index);
    });
  }

  Future<void> _subirAdjuntos({
    required String orderId,
    required String messageId,
    required String userId,
  }) async {
    final List<ArchivoAdjunto> aSubir = _archivos
        .where((a) => a.estado != EstadoAdjunto.uploaded)
        .toList();

    for (int i = 0; i < aSubir.length; i += _concurrenciaSubida) {
      final chunk = aSubir.skip(i).take(_concurrenciaSubida).toList();
      await Future.wait(
        chunk.map(
          (archivo) => _subirUnArchivo(
            archivo: archivo,
            orderId: orderId,
            messageId: messageId,
            userId: userId,
          ),
        ),
      );
    }
  }

  Future<void> _subirUnArchivo({
    required ArchivoAdjunto archivo,
    required String orderId,
    required String messageId,
    required String userId,
  }) async {
    setState(() {
      archivo.estado = EstadoAdjunto.uploading;
      archivo.error = null;
    });

    try {
      final bytes = archivo.file.bytes;
      if (bytes == null) {
        throw Exception('No se pudo leer el archivo');
      }

      final String fileNameSafe = archivo.file.name.replaceAll(' ', '_');
      final String storagePath =
          'orders/$orderId/messages/$messageId/${DateTime.now().millisecondsSinceEpoch}_$fileNameSafe';

      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/octet-stream',
        customMetadata: {
          'uploadedBy': userId,
          'originalName': archivo.file.name,
        },
      );

      final snapshot = await ref.putData(bytes, metadata);
      final url = await snapshot.ref.getDownloadURL();

      setState(() {
        archivo.estado = EstadoAdjunto.uploaded;
        archivo.urlDescarga = url;
        archivo.rutaStorage = storagePath;
        archivo.error = null;
      });
    } catch (e) {
      setState(() {
        archivo.estado = EstadoAdjunto.failed;
        archivo.error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nuevo Pedido'),
            Text(
              'Pedido Nº ${widget.numeroPedido}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _agregarArchivo,
            icon: const Icon(Icons.attach_file),
            tooltip: 'Agregar archivo',
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tituloController,
                    maxLength: _maxCaracteresTitulo,
                    buildCounter:
                        (
                          BuildContext context, {
                          required int currentLength,
                          required int? maxLength,
                          required bool isFocused,
                        }) {
                          return Text(
                            '$currentLength/$maxLength',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                    decoration: InputDecoration(
                      labelText: 'Asigna un titulo a tu pedido',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _descripcionController,
                    maxLength: _maxCaracteresDescripcion,
                    maxLines: 4,
                    minLines: 4,
                    buildCounter:
                        (
                          BuildContext context, {
                          required int currentLength,
                          required int? maxLength,
                          required bool isFocused,
                        }) {
                          return Text(
                            '$currentLength/$maxLength',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                    decoration: InputDecoration(
                      labelText: 'Describeme tu pedido',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                  ),
                  SizedBox(height: 20),
                  InkWell(
                    onTap: _isLoading ? null : _abrirDatePicker,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha máxima de entrega',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      child: Text(
                        _fechaMaxEntrega != null
                            ? _formatearFecha(_fechaMaxEntrega!)
                            : 'Seleccionar fecha',
                        style: TextStyle(
                          fontSize: 16,
                          color: _fechaMaxEntrega != null
                              ? null
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _archivos.isEmpty
                    ? const OrderAttachmentsEmptyPlaceholder()
                    : SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._archivos.asMap().entries.map((entry) {
                              final archivo = entry.value;
                              return OrderAttachmentFileRow(
                                fileName: archivo.file.name,
                                iconSize: 24,
                                onDelete: _isLoading
                                    ? null
                                    : () => _eliminarArchivo(entry.key),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _puedeGuardar ? _guardarPedido : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tituloController.removeListener(_onCamposChanged);
    _descripcionController.removeListener(_onCamposChanged);
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}
