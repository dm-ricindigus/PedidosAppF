import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';

enum EstadoDescarga { idle, descargando, pausado, completado, error }

class DescargaArchivoEstado {
  final EstadoDescarga estado;
  final double progreso;
  final DownloadTask? task;
  final StreamSubscription<TaskSnapshot>? subscription;
  final String? localPath;
  final int startedAtMs;

  const DescargaArchivoEstado({
    this.estado = EstadoDescarga.idle,
    this.progreso = 0,
    this.task,
    this.subscription,
    this.localPath,
    this.startedAtMs = 0,
  });

  DescargaArchivoEstado copyWith({
    EstadoDescarga? estado,
    double? progreso,
    DownloadTask? task,
    StreamSubscription<TaskSnapshot>? subscription,
    String? localPath,
    int? startedAtMs,
  }) {
    return DescargaArchivoEstado(
      estado: estado ?? this.estado,
      progreso: progreso ?? this.progreso,
      task: task ?? this.task,
      subscription: subscription ?? this.subscription,
      localPath: localPath ?? this.localPath,
      startedAtMs: startedAtMs ?? this.startedAtMs,
    );
  }
}

class MessageDetailAdminPage extends StatefulWidget {
  final String messageId;
  final String numeroPedido;

  const MessageDetailAdminPage({
    super.key,
    required this.messageId,
    required this.numeroPedido,
  });

  @override
  State<MessageDetailAdminPage> createState() => _MessageDetailAdminPageState();
}

class _MessageDetailAdminPageState extends State<MessageDetailAdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, DescargaArchivoEstado> _descargas = {};
  static const int _minMsIndicadorDescarga = 900;
  late final Stream<DocumentSnapshot> _messageStream;

  @override
  void initState() {
    super.initState();
    _messageStream = _firestore
        .collection('messages')
        .doc(widget.messageId)
        .snapshots();
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

  String _claveArchivo(Map<String, String?> archivo, int index) {
    final storagePath = archivo['storagePath'];
    if (storagePath != null && storagePath.isNotEmpty) {
      return storagePath;
    }
    return '${archivo['name'] ?? 'archivo'}_$index';
  }

  ({String base, String extension}) _separarNombreYExtension(String nombre) {
    final dotIndex = nombre.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == nombre.length - 1) {
      return (base: nombre, extension: '');
    }
    return (
      base: nombre.substring(0, dotIndex),
      extension: nombre.substring(dotIndex),
    );
  }

  Future<File> _obtenerArchivoLocal(String nombreArchivo) async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${directory.path}/downloads');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }
    return File('${downloadDir.path}/$nombreArchivo');
  }

  Future<void> _iniciarDescarga(
    String clave,
    String nombreArchivo,
    String? storagePath,
  ) async {
    if (storagePath == null || storagePath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontro la ruta del archivo para descargar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final actual = _descargas[clave];
    if (actual != null &&
        (actual.estado == EstadoDescarga.descargando ||
            actual.estado == EstadoDescarga.pausado)) {
      return;
    }

    final file = await _obtenerArchivoLocal(nombreArchivo);

    final ref = _storage.ref(storagePath);
    final task = ref.writeToFile(file);

    if (!mounted) return;
    setState(() {
      _descargas[clave] = DescargaArchivoEstado(
        estado: EstadoDescarga.descargando,
        progreso: 0,
        task: task,
        localPath: file.path,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });

    final subscription = task.snapshotEvents.listen((snapshot) {
      if (!mounted) return;

      final total = snapshot.totalBytes;
      final progreso = total > 0 ? snapshot.bytesTransferred / total : 0.0;

      EstadoDescarga estado;
      switch (snapshot.state) {
        case TaskState.running:
          estado = EstadoDescarga.descargando;
          break;
        case TaskState.paused:
          estado = EstadoDescarga.pausado;
          break;
        case TaskState.success:
          // Se marca "completado" al finalizar await task para evitar parpadeo.
          estado = EstadoDescarga.descargando;
          break;
        case TaskState.error:
          estado = EstadoDescarga.error;
          break;
        case TaskState.canceled:
          estado = EstadoDescarga.idle;
          break;
      }

      final actual = _descargas[clave];
      if (actual == null) return;
      setState(() {
        _descargas[clave] = actual.copyWith(
          estado: estado,
          progreso: progreso,
          localPath: file.path,
        );
      });
    });

    if (!mounted) return;
    final actualConSubs = _descargas[clave];
    if (actualConSubs != null) {
      setState(() {
        _descargas[clave] = actualConSubs.copyWith(subscription: subscription);
      });
    }

    try {
      await task;
      final actualPostDescarga = _descargas[clave];
      if (actualPostDescarga != null) {
        final elapsed =
            DateTime.now().millisecondsSinceEpoch -
            actualPostDescarga.startedAtMs;
        final waitMs = _minMsIndicadorDescarga - elapsed;
        if (waitMs > 0) {
          await Future.delayed(Duration(milliseconds: waitMs));
        }
      }
      if (!mounted) return;
      final actualizado = _descargas[clave];
      if (actualizado != null) {
        setState(() {
          _descargas[clave] = actualizado.copyWith(
            estado: EstadoDescarga.completado,
            progreso: 1,
          );
        });
      }
      await _abrirArchivoDescargado(file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar $nombreArchivo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelarDescarga(String clave) async {
    final task = _descargas[clave]?.task;
    if (task == null) return;
    await task.cancel();
    if (!mounted) return;
    final actual = _descargas[clave];
    if (actual == null) return;
    setState(() {
      _descargas[clave] = actual.copyWith(
        estado: EstadoDescarga.idle,
        progreso: 0,
      );
    });
  }

  Future<void> _abrirArchivoDescargado(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    final result = await OpenFilex.open(localPath);
    if (!mounted) return;

    if (result.type == ResultType.done) {
      return;
    }

    String mensaje;
    switch (result.type) {
      case ResultType.noAppToOpen:
        mensaje = 'No hay aplicación para abrir este archivo';
        break;
      case ResultType.fileNotFound:
        mensaje = 'No se encontro el archivo en el dispositivo.';
        break;
      case ResultType.permissionDenied:
        mensaje = 'Permiso denegado para abrir el archivo.';
        break;
      case ResultType.error:
        mensaje = 'No se pudo abrir el archivo.';
        break;
      case ResultType.done:
        mensaje = '';
        break;
    }

    if (mensaje.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _guardarEnDescargasDesdeSistema({
    required String? localPath,
    required String nombreArchivo,
  }) async {
    if (localPath == null || localPath.isEmpty) return;

    final file = File(localPath);
    if (!file.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo local no existe'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final partes = _separarNombreYExtension(nombreArchivo);
    final fileName = partes.base.isEmpty ? 'archivo' : partes.base;
    final extension = partes.extension.isEmpty
        ? 'bin'
        : partes.extension.replaceFirst('.', '');

    if (!Platform.isAndroid && !Platform.isIOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plataforma no soportada para guardar archivos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final savedPath = await FileSaver.instance.saveAs(
        name: fileName,
        filePath: localPath,
        fileExtension: extension,
        mimeType: MimeType.other,
      );

      if (!mounted) return;
      if ((savedPath ?? '').isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Platform.isAndroid
                  ? 'Archivo guardado. Selecciona Descargas en el selector para verlo en esa carpeta'
                  : 'Archivo exportado desde el selector de iOS',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardado cancelado por el usuario'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el selector de guardado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarModalConfirmacionGuardarArchivo({
    required String? localPath,
    required String nombreArchivo,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Deseas guardar el archivo en tu equipo?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                nombreArchivo,
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _guardarEnDescargasDesdeSistema(
                          localPath: localPath,
                          nombreArchivo: nombreArchivo,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Guardar'),
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

  Future<void> _alTocarArchivo({
    required String clave,
    required String nombreArchivo,
    required String? storagePath,
  }) async {
    final estado = _descargas[clave];

    if (estado?.estado == EstadoDescarga.descargando) {
      return;
    }

    if (estado?.estado == EstadoDescarga.completado &&
        estado?.localPath != null &&
        File(estado!.localPath!).existsSync()) {
      await _abrirArchivoDescargado(estado.localPath);
      return;
    }

    final fileLocal = await _obtenerArchivoLocal(nombreArchivo);
    if (fileLocal.existsSync()) {
      if (!mounted) return;
      setState(() {
        _descargas[clave] = DescargaArchivoEstado(
          estado: EstadoDescarga.completado,
          progreso: 1,
          localPath: fileLocal.path,
        );
      });
      await _abrirArchivoDescargado(fileLocal.path);
      return;
    }

    await _iniciarDescarga(clave, nombreArchivo, storagePath);
  }

  void _mostrarModalConfirmacionAbrirArchivo({
    required String clave,
    required String nombreArchivo,
    required String? storagePath,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Deseas abrir este archivo?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                nombreArchivo,
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _alTocarArchivo(
                          clave: clave,
                          nombreArchivo: nombreArchivo,
                          storagePath: storagePath,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Abrir'),
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

  @override
  void dispose() {
    for (final item in _descargas.values) {
      item.subscription?.cancel();
    }
    super.dispose();
  }

  Widget _buildEstadoDescargaVisual({required String clave}) {
    final estado = _descargas[clave] ?? const DescargaArchivoEstado();

    switch (estado.estado) {
      case EstadoDescarga.idle:
        return const SizedBox(width: 20, height: 20);
      case EstadoDescarga.error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
      case EstadoDescarga.descargando:
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: estado.progreso.clamp(0, 1),
                strokeWidth: 2.4,
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _cancelarDescarga(clave),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        );
      case EstadoDescarga.pausado:
        return const SizedBox(width: 20, height: 20);
      case EstadoDescarga.completado:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final Color accentColor = colorScheme.primary;
    const Color onAccentColor = Colors.white;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _messageStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar mensaje: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Mensaje no encontrado'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final descripcion = (data['message'] as String?) ?? '';
          final createdAt = data['createdAt'] as Timestamp?;
          final List<dynamic> attachmentsRaw =
              (data['attachments'] as List<dynamic>?) ?? [];
          final List<Map<String, String?>> archivos = attachmentsRaw
              .whereType<Map<String, dynamic>>()
              .map(
                (a) => {
                  'name': a['name'] as String?,
                  'storagePath': a['storagePath'] as String?,
                },
              )
              .where((a) => (a['name'] ?? '').isNotEmpty)
              .toList();

          return Scaffold(
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
                    _formatearFecha(createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
                  ),
                ],
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mensaje recibido',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatearFecha(createdAt),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 168,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Text(
                        descripcion,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        softWrap: true,
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    archivos.isEmpty
                        ? 'Este mensaje no tiene archivos adjuntos'
                        : 'Archivos recibidos',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: archivos.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            itemCount: archivos.length,
                            itemBuilder: (context, index) {
                              final nombreArchivo = archivos[index]['name']!;
                              final storagePath =
                                  archivos[index]['storagePath'];
                              final clave = _claveArchivo(
                                archivos[index],
                                index,
                              );
                              final estadoDescarga = _descargas[clave];
                              final isFirst = index == 0;
                              return Column(
                                children: [
                                  if (!isFirst)
                                    Divider(
                                      color: colorScheme.outlineVariant,
                                      height: 1,
                                      thickness: 1,
                                    ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    child: InkWell(
                                      onTap: () =>
                                          _mostrarModalConfirmacionAbrirArchivo(
                                            clave: clave,
                                            nombreArchivo: nombreArchivo,
                                            storagePath: storagePath,
                                          ),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Symbols.file_present,
                                              size: 20,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Builder(
                                                builder: (context) {
                                                  final partes =
                                                      _separarNombreYExtension(
                                                        nombreArchivo,
                                                      );
                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        partes.base,
                                                        style: textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color: colorScheme
                                                                  .onSurface,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        partes.extension.isEmpty
                                                            ? 'archivo'
                                                            : 'archivo${partes.extension}',
                                                        style: textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color: colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                            SizedBox(
                                              width: 68,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  SizedBox(
                                                    width: 34,
                                                    height: 34,
                                                    child: Center(
                                                      child:
                                                          _buildEstadoDescargaVisual(
                                                            clave: clave,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  SizedBox(
                                                    width: 30,
                                                    height: 30,
                                                    child:
                                                        estadoDescarga
                                                                ?.estado ==
                                                            EstadoDescarga
                                                                .completado
                                                        ? IconButton(
                                                            onPressed: () async {
                                                              _mostrarModalConfirmacionGuardarArchivo(
                                                                localPath:
                                                                    estadoDescarga
                                                                        ?.localPath,
                                                                nombreArchivo:
                                                                    nombreArchivo,
                                                              );
                                                            },
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  2,
                                                                ),
                                                            constraints:
                                                                const BoxConstraints(
                                                                  minWidth: 30,
                                                                  minHeight: 30,
                                                                ),
                                                            icon: const Icon(
                                                              Symbols.archive,
                                                              size: 24,
                                                            ),
                                                            tooltip:
                                                                'Guardar en...',
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          )
                                                        : const SizedBox.shrink(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
