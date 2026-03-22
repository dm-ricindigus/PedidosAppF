import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:developer' as developer;

import 'package:material_symbols_icons/material_symbols_icons.dart';

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  DashedBorderPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          (distance + dashWidth).clamp(0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

enum EstadoAdjunto { pending, uploading, uploaded, failed }

class ArchivoAdjunto {
  final PlatformFile file;
  EstadoAdjunto estado;
  String? urlDescarga;
  String? rutaStorage;
  String? error;

  ArchivoAdjunto({
    required this.file,
    this.estado = EstadoAdjunto.pending,
    this.urlDescarga,
    this.rutaStorage,
    this.error,
  });
}

class FileItemWidget extends StatelessWidget {
  final String fileName;
  final VoidCallback? onDelete;

  const FileItemWidget({
    super.key,
    required this.fileName,
    required this.onDelete,
  });

  String _acortarEnMedio(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    if (maxLength <= 3) return text.substring(0, maxLength);

    final int charsDisponibles = maxLength - 3;
    final int inicio = (charsDisponibles / 2).ceil();
    final int fin = charsDisponibles - inicio;
    return '${text.substring(0, inicio)}...${text.substring(text.length - fin)}';
  }

  String _nombreArchivoCorto(String original, {int maxLength = 32}) {
    if (original.length <= maxLength) return original;

    final int dotIndex = original.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == original.length - 1) {
      return _acortarEnMedio(original, maxLength);
    }

    final String base = original.substring(0, dotIndex);
    final String extension = original.substring(dotIndex);

    final int maxBaseLength = maxLength - extension.length;
    if (maxBaseLength <= 3) {
      return _acortarEnMedio(original, maxLength);
    }

    return '${_acortarEnMedio(base, maxBaseLength)}$extension';
  }

  @override
  Widget build(BuildContext context) {
    final nombreVisible = _nombreArchivoCorto(fileName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombreVisible,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: onDelete == null ? Colors.grey[400] : Colors.grey[700],
            ),
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    _draftOrderId ??= _firestore.collection('orders').doc().id;
    return _draftOrderId!;
  }

  String _obtenerDraftMessageId() {
    _draftMessageId ??= _firestore.collection('messages').doc().id;
    return _draftMessageId!;
  }

  @override
  void initState() {
    super.initState();
    _tituloController.addListener(_onCamposChanged);
    _descripcionController.addListener(_onCamposChanged);
  }

  void _mostrarExitoBottomSheet(BuildContext context) {
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
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pedido guardado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Tu pedido ha sido guardado exitosamente',
                style: TextStyle(fontSize: 16),
              ),
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

  void _mostrarCargandoBottomSheet() {
    if (!mounted || _isLoadingSheetOpen) return;
    _isLoadingSheetOpen = true;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PopScope(
        canPop: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: const Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Enviando pedido, por favor espera...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
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
      final orderRef = _firestore.collection('orders').doc(orderId);
      final messageRef = _firestore.collection('messages').doc(messageId);

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
        'orderCode': orderCode,
        'title': titulo,
        'state': 1, // Estado 1: Ingresado
        'clientId': user.uid,
        'maxDeliveryDate': Timestamp.fromDate(_fechaMaxEntrega!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        '✅ Pedido creado con ID: ${orderRef.id}',
        name: 'SaveOrder',
      );

      // Crear el primer mensaje asociado al pedido
      await messageRef.set({
        'orderId': orderRef.id,
        'message': descripcion,
        'userId': user.uid,
        'attachments': _archivos
            .where((a) => a.estado == EstadoAdjunto.uploaded)
            .map(
              (a) => {
                'name': a.file.name,
                'size': a.file.size,
                'extension': a.file.extension,
                'url': a.urlDescarga,
                'storagePath': a.rutaStorage,
              },
            )
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        '✅ Mensaje inicial creado para pedido: ${orderRef.id}',
        name: 'SaveOrder',
      );

      // Marcar el código como usado en orderCodes
      await _firestore.collection('orderCodes').doc(orderCode).update({
        'used': true,
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': user.uid,
      });

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
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: DashedBorderPainter(
                                  color: Colors.grey.shade400,
                                  strokeWidth: 1.0,
                                  borderRadius: 12.0,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Symbols.attach_file_off,
                                        size: 32,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No hay archivos adjuntos',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._archivos.asMap().entries.map((entry) {
                              final archivo = entry.value;
                              return FileItemWidget(
                                fileName: archivo.file.name,
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
