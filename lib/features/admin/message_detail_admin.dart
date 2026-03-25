import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pedidosapp/features/admin/widgets/message_detail_admin_widgets.dart';

/// Coincide con [OrderDetailAdminPage] AppBar (título en dos líneas).
const double kOrderDetailAdminAppBarToolbarHeight = 72;

class MessageDetailAdminPage extends StatefulWidget {
  final String messageId;
  final String orderDisplayLine;
  final String title;

  const MessageDetailAdminPage({
    super.key,
    required this.messageId,
    required this.orderDisplayLine,
    required this.title,
  });

  @override
  State<MessageDetailAdminPage> createState() => _MessageDetailAdminPageState();
}

class _MessageDetailAdminPageState extends State<MessageDetailAdminPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final Color accentColor = colorScheme.primary;
    const Color onAccentColor = Colors.white;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        toolbarHeight: kOrderDetailAdminAppBarToolbarHeight,
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
              widget.orderDisplayLine,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: onAccentColor,
              ),
            ),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
            ),
          ],
        ),
      ),
      body: AdminMessageDetailBody(messageId: widget.messageId),
    );
  }
}

class AdminMessageDetailBody extends StatefulWidget {
  const AdminMessageDetailBody({
    super.key,
    required this.messageId,
    this.shrinkWrapAttachments = false,
  });

  final String messageId;
  final bool shrinkWrapAttachments;

  @override
  State<AdminMessageDetailBody> createState() => _AdminMessageDetailBodyState();
}

class _AdminMessageDetailBodyState extends State<AdminMessageDetailBody> {
  final OrdersRepository _ordersRepo = OrdersRepository();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, FileDownloadState> _downloads = {};
  static const int _minDownloadIndicatorMs = 900;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _messageStream;

  @override
  void initState() {
    super.initState();
    _messageStream = _ordersRepo.watchMessage(widget.messageId);
  }

  Widget _buildLoadedContent({
    required Map<String, dynamic> data,
    required List<Map<String, String?>> attachmentMaps,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final description = (data[FirestoreFields.message] as String?) ?? '';
    final createdAt = data[FirestoreFields.createdAt] as Timestamp?;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          _formatMessageTimestamp(createdAt),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Text(
            description,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            softWrap: true,
            textAlign: TextAlign.justify,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          attachmentMaps.isEmpty
              ? 'Este mensaje no tiene archivos adjuntos'
              : 'Archivos recibidos',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    Widget attachmentList() {
      if (attachmentMaps.isEmpty) return const SizedBox.shrink();
      return ListView.builder(
        shrinkWrap: widget.shrinkWrapAttachments,
        physics: widget.shrinkWrapAttachments
            ? const NeverScrollableScrollPhysics()
            : null,
        itemCount: attachmentMaps.length,
        itemBuilder: (context, index) {
          final displayName = attachmentMaps[index][AttachmentField.name]!;
          final storagePath =
              attachmentMaps[index][AttachmentField.storagePath];
          final key = _attachmentKey(attachmentMaps[index], index);
          final downloadState = _downloads[key];

          final download = downloadState ?? const FileDownloadState();
          return Column(
            children: [
              AdminMessageAttachmentTile(
                fileName: displayName,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onOpenTap: () => _showOpenFileConfirmSheet(
                  key: key,
                  displayName: displayName,
                  storagePath: storagePath,
                ),
                downloadStatus: AttachmentDownloadStatusIcon(
                  phase: download.phase,
                  progress: download.progress,
                  onCancel: () => _cancelDownload(key),
                ),
                showSaveAction: download.phase == FileDownloadPhase.completed,
                onSaveTap: () {
                  _showSaveFileConfirmSheet(
                    localPath: download.localPath,
                    displayName: displayName,
                  );
                },
              ),
            ],
          );
        },
      );
    }

    if (widget.shrinkWrapAttachments) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [header, attachmentList()],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Expanded(child: attachmentList()),
      ],
    );
  }

  String _formatMessageTimestamp(Timestamp? timestamp) {
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

  String _attachmentKey(Map<String, String?> file, int index) {
    final storagePath = file[AttachmentField.storagePath];
    if (storagePath != null && storagePath.isNotEmpty) {
      return storagePath;
    }
    return '${file[AttachmentField.name] ?? 'archivo'}_$index';
  }

  Future<File> _localDownloadFile(String displayName) async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${directory.path}/downloads');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }
    return File('${downloadDir.path}/$displayName');
  }

  Future<void> _startDownload(
    String key,
    String displayName,
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

    final current = _downloads[key];
    if (current != null &&
        (current.phase == FileDownloadPhase.downloading ||
            current.phase == FileDownloadPhase.paused)) {
      return;
    }

    final file = await _localDownloadFile(displayName);

    final ref = _storage.ref(storagePath);
    final task = ref.writeToFile(file);

    if (!mounted) return;
    setState(() {
      _downloads[key] = FileDownloadState(
        phase: FileDownloadPhase.downloading,
        progress: 0,
        task: task,
        localPath: file.path,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });

    final subscription = task.snapshotEvents.listen((snapshot) {
      if (!mounted) return;

      final total = snapshot.totalBytes;
      final progress = total > 0 ? snapshot.bytesTransferred / total : 0.0;

      FileDownloadPhase phase;
      switch (snapshot.state) {
        case TaskState.running:
          phase = FileDownloadPhase.downloading;
          break;
        case TaskState.paused:
          phase = FileDownloadPhase.paused;
          break;
        case TaskState.success:
          phase = FileDownloadPhase.downloading;
          break;
        case TaskState.error:
          phase = FileDownloadPhase.error;
          break;
        case TaskState.canceled:
          phase = FileDownloadPhase.idle;
          break;
      }

      final actual = _downloads[key];
      if (actual == null) return;
      setState(() {
        _downloads[key] = actual.copyWith(
          phase: phase,
          progress: progress,
          localPath: file.path,
        );
      });
    });

    if (!mounted) return;
    final withSub = _downloads[key];
    if (withSub != null) {
      setState(() {
        _downloads[key] = withSub.copyWith(subscription: subscription);
      });
    }

    try {
      await task;
      final after = _downloads[key];
      if (after != null) {
        final elapsed =
            DateTime.now().millisecondsSinceEpoch - after.startedAtMs;
        final waitMs = _minDownloadIndicatorMs - elapsed;
        if (waitMs > 0) {
          await Future.delayed(Duration(milliseconds: waitMs));
        }
      }
      if (!mounted) return;
      final updated = _downloads[key];
      if (updated != null) {
        setState(() {
          _downloads[key] = updated.copyWith(
            phase: FileDownloadPhase.completed,
            progress: 1,
          );
        });
      }
      await _openDownloadedFile(file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar $displayName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelDownload(String key) async {
    final task = _downloads[key]?.task;
    if (task == null) return;
    await task.cancel();
    if (!mounted) return;
    final actual = _downloads[key];
    if (actual == null) return;
    setState(() {
      _downloads[key] = actual.copyWith(
        phase: FileDownloadPhase.idle,
        progress: 0,
      );
    });
  }

  Future<void> _openDownloadedFile(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    final result = await OpenFilex.open(localPath);
    if (!mounted) return;

    if (result.type == ResultType.done) {
      return;
    }

    String userMessage;
    switch (result.type) {
      case ResultType.noAppToOpen:
        userMessage = 'No hay aplicación para abrir este archivo';
        break;
      case ResultType.fileNotFound:
        userMessage = 'No se encontro el archivo en el dispositivo.';
        break;
      case ResultType.permissionDenied:
        userMessage = 'Permiso denegado para abrir el archivo.';
        break;
      case ResultType.error:
        userMessage = 'No se pudo abrir el archivo.';
        break;
      case ResultType.done:
        userMessage = '';
        break;
    }

    if (userMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _saveToSystemDownloads({
    required String? localPath,
    required String displayName,
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

    final parts = splitFileNameAndExtension(displayName);
    final fileName = parts.base.isEmpty ? 'archivo' : parts.base;
    final extension = parts.extension.isEmpty
        ? 'bin'
        : parts.extension.replaceFirst('.', '');

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

  void _showSaveFileConfirmSheet({
    required String? localPath,
    required String displayName,
  }) {
    showAdminFileConfirmSheet(
      context,
      title: '¿Deseas guardar el archivo en tu equipo?',
      fileName: displayName,
      confirmLabel: 'Guardar',
      onConfirm: () => _saveToSystemDownloads(
        localPath: localPath,
        displayName: displayName,
      ),
    );
  }

  Future<void> _onAttachmentTap({
    required String key,
    required String displayName,
    required String? storagePath,
  }) async {
    final download = _downloads[key];

    if (download?.phase == FileDownloadPhase.downloading) {
      return;
    }

    if (download?.phase == FileDownloadPhase.completed &&
        download?.localPath != null &&
        File(download!.localPath!).existsSync()) {
      await _openDownloadedFile(download.localPath);
      return;
    }

    final fileLocal = await _localDownloadFile(displayName);
    if (fileLocal.existsSync()) {
      if (!mounted) return;
      setState(() {
        _downloads[key] = FileDownloadState(
          phase: FileDownloadPhase.completed,
          progress: 1,
          localPath: fileLocal.path,
        );
      });
      await _openDownloadedFile(fileLocal.path);
      return;
    }

    await _startDownload(key, displayName, storagePath);
  }

  void _showOpenFileConfirmSheet({
    required String key,
    required String displayName,
    required String? storagePath,
  }) {
    showAdminFileConfirmSheet(
      context,
      title: '¿Deseas abrir este archivo?',
      fileName: displayName,
      confirmLabel: 'Abrir',
      onConfirm: () => _onAttachmentTap(
        key: key,
        displayName: displayName,
        storagePath: storagePath,
      ),
    );
  }

  @override
  void dispose() {
    for (final item in _downloads.values) {
      item.subscription?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _messageStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
        final List<dynamic> attachmentsRaw =
            (data[FirestoreFields.attachments] as List<dynamic>?) ?? [];
        final List<Map<String, String?>> attachmentMaps = attachmentsRaw
            .whereType<Map<String, dynamic>>()
            .map(
              (a) => {
                AttachmentField.name: a[AttachmentField.name] as String?,
                AttachmentField.storagePath:
                    a[AttachmentField.storagePath] as String?,
              },
            )
            .where((a) => (a[AttachmentField.name] ?? '').isNotEmpty)
            .toList();

        final content = _buildLoadedContent(
          data: data,
          attachmentMaps: attachmentMaps,
          textTheme: textTheme,
          colorScheme: colorScheme,
        );

        return Padding(
          padding: widget.shrinkWrapAttachments
              ? const EdgeInsets.fromLTRB(24, 0, 24, 24)
              : const EdgeInsets.all(24),
          child: content,
        );
      },
    );
  }
}

/// Debajo del AppBar real: en el [body] del [Scaffold], [MediaQuery.padding] suele
/// llevar el top ya consumido; [viewPadding] conserva status/notch.
double _adminMessageDetailSheetTopInset(
  BuildContext context, {
  required double appBarToolbarHeight,
}) {
  return MediaQuery.viewPaddingOf(context).top + appBarToolbarHeight;
}

/// Detalle del mensaje en modal hasta debajo del AppBar (misma pantalla de pedido).
Future<void> showAdminMessageDetailBottomSheet(
  BuildContext context, {
  required String messageId,

  /// Si se mide el AppBar con [GlobalKey] + [RenderBox], usar ese valor (px globales).
  double? sheetTopInset,
  double appBarToolbarHeight = kToolbarHeight,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final topInset =
      sheetTopInset ??
      _adminMessageDetailSheetTopInset(
        context,
        appBarToolbarHeight: appBarToolbarHeight,
      );
  final sheetHeight = (MediaQuery.sizeOf(context).height - topInset).clamp(
    120.0,
    double.infinity,
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Material(
          color: colorScheme.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: sheetHeight,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Cerrar',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                      child: AdminMessageDetailBody(
                        messageId: messageId,
                        shrinkWrapAttachments: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
