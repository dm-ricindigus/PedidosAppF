import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'dart:developer' as developer;

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
    final dotIndex = original.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == original.length - 1) {
      return _acortarEnMedio(original, maxLength);
    }
    final String base = original.substring(0, dotIndex);
    final String extension = original.substring(dotIndex);
    final int maxBaseLength = maxLength - extension.length;
    if (maxBaseLength <= 3) return _acortarEnMedio(original, maxLength);
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
            child: Text(
              nombreVisible,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: onDelete == null ? Colors.grey[400] : Colors.grey[700],
            ),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class EditOrderClientPage extends StatefulWidget {
  final String numeroPedido;
  final String titulo;
  final String estado;

  const EditOrderClientPage({
    super.key,
    required this.numeroPedido,
    required this.titulo,
    required this.estado,
  });

  @override
  State<EditOrderClientPage> createState() => _EditOrderClientPageState();
}

class _EditOrderClientPageState extends State<EditOrderClientPage> {
  final List<ArchivoAdjunto> _archivos = [];
  final TextEditingController _descripcionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const int _maxCaracteresDescripcion = 500;
  static const int _maxTamanoArchivoBytes = 6 * 1024 * 1024;
  static const int _concurrenciaSubida = 3;
  bool _descripcionVacia = true;
  bool _isLoading = false;
  bool _isLoadingSheetOpen = false;
  String? _draftMessageId;

  @override
  void initState() {
    super.initState();
    _descripcionController.addListener(_actualizarEstadoDescripcion);
  }

  void _actualizarEstadoDescripcion() {
    setState(() {
      _descripcionVacia = _descripcionController.text.trim().isEmpty;
    });
  }

  void _mostrarExitoBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
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
                    Icons.check_circle_outline_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mensaje enviado',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Tu mensaje ha sido enviado exitosamente',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Entendido'),
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
        child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Enviando mensaje, por favor espera...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

  String _obtenerDraftMessageId() {
    _draftMessageId ??= _firestore.collection('messages').doc().id;
    return _draftMessageId!;
  }

  Future<void> _agregarArchivo() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

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
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (nuevosArchivos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No hay archivos nuevos para agregar (revisar duplicados o tamano)',
          ),
          behavior: SnackBarBehavior.floating,
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

  void _pedirConfirmarEliminarArchivo(int index, String fileName) {
    if (_isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
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
                'Eliminar archivo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Eliminar "$fileName" de la lista?',
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((confirmado) {
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
      if (confirmado == true && mounted) {
        _eliminarArchivo(index);
      }
    });
  }

  Future<void> _guardarMensaje() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuario no autenticado'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
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
      final String descripcion = _descripcionController.text.trim();

      // Extraer el orderCode del numeroPedido
      // Puede venir como "Pedido Nº 13928019" o solo "13928019"
      String orderCode = widget.numeroPedido;
      if (orderCode.contains('Pedido Nº')) {
        orderCode = orderCode.replaceAll('Pedido Nº', '').trim();
      }
      orderCode = orderCode.trim();

      developer.log(
        '💾 Guardando mensaje: código=$orderCode, descripción=$descripcion',
        name: 'SaveMessage',
      );

      // Obtener el orderId desde el orderCode
      final pedidoQuery = await _firestore
          .collection('orders')
          .where('orderCode', isEqualTo: orderCode)
          .where('clientId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (pedidoQuery.docs.isEmpty) {
        throw Exception('No se encontró el pedido con código: $orderCode');
      }

      final orderId = pedidoQuery.docs.first.id;
      final messageId = _obtenerDraftMessageId();
      final messageRef = _firestore.collection('messages').doc(messageId);

      developer.log('✅ OrderId encontrado: $orderId', name: 'SaveMessage');

      await _subirAdjuntos(
        orderId: orderId,
        messageId: messageId,
        userId: user.uid,
      );

      final bool hayFallidos = _archivos.any(
        (a) => a.estado == EstadoAdjunto.failed,
      );

      if (hayFallidos) {
        throw Exception(
          'No se pudieron subir todos los archivos. Reintenta enviando nuevamente.',
        );
      }

      // Crear el nuevo mensaje asociado al pedido
      await messageRef.set({
        'orderId': orderId,
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
        '✅ Mensaje guardado exitosamente para pedido: $orderId',
        name: 'SaveMessage',
      );
      guardadoExitoso = true;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error al guardar mensaje: $e',
        name: 'SaveMessage',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar mensaje: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
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
  void dispose() {
    _descripcionController.removeListener(_actualizarEstadoDescripcion);
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final Color accentColor = colorScheme.primary;
    const Color onAccentColor = Colors.white;

    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: onAccentColor,
          ),
          iconTheme: IconThemeData(color: onAccentColor),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: colorScheme.surfaceContainerLow,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: false,
          backgroundColor: accentColor,
          foregroundColor: onAccentColor,
          titleSpacing: 16,
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
                'Estado: ${widget.estado}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
              ),
            ],
          ),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.assignment_rounded,
                            size: 18,
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.titulo,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        labelText: 'Agrega nueva información al pedido',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      onEditingComplete: () => FocusScope.of(context).unfocus(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
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
                                      : () => _pedirConfirmarEliminarArchivo(
                                          entry.key,
                                          archivo.file.name,
                                        ),
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
                    onPressed: (_descripcionVacia || _isLoading)
                        ? null
                        : _guardarMensaje,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Enviar'),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
