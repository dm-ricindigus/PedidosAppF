import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// ——— Download state (shared with screen) ———

enum FileDownloadPhase { idle, downloading, paused, completed, error }

class FileDownloadState {
  final FileDownloadPhase phase;
  final double progress;
  final DownloadTask? task;
  final StreamSubscription<TaskSnapshot>? subscription;
  final String? localPath;
  final int startedAtMs;

  const FileDownloadState({
    this.phase = FileDownloadPhase.idle,
    this.progress = 0,
    this.task,
    this.subscription,
    this.localPath,
    this.startedAtMs = 0,
  });

  FileDownloadState copyWith({
    FileDownloadPhase? phase,
    double? progress,
    DownloadTask? task,
    StreamSubscription<TaskSnapshot>? subscription,
    String? localPath,
    int? startedAtMs,
  }) {
    return FileDownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      task: task ?? this.task,
      subscription: subscription ?? this.subscription,
      localPath: localPath ?? this.localPath,
      startedAtMs: startedAtMs ?? this.startedAtMs,
    );
  }
}

// ——— Utilities ———

({String base, String extension}) splitFileNameAndExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return (base: fileName, extension: '');
  }
  return (
    base: fileName.substring(0, dotIndex),
    extension: fileName.substring(dotIndex),
  );
}

/// Confirmation bottom sheet (open / save file).
Future<void> showAdminFileConfirmSheet(
  BuildContext context, {
  required String title,
  required String fileName,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: Theme.of(sheetContext).colorScheme.surface,
        borderRadius: const BorderRadius.only(
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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              fileName,
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
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
                      Navigator.pop(sheetContext);
                      await onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(
                        sheetContext,
                      ).colorScheme.primary,
                      foregroundColor: Theme.of(
                        sheetContext,
                      ).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(confirmLabel),
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

/// Download progress / icon next to attachment.
class AttachmentDownloadStatusIcon extends StatelessWidget {
  const AttachmentDownloadStatusIcon({
    super.key,
    required this.phase,
    required this.progress,
    required this.onCancel,
  });

  final FileDownloadPhase phase;
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case FileDownloadPhase.idle:
        return const SizedBox(width: 20, height: 20);
      case FileDownloadPhase.error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
      case FileDownloadPhase.downloading:
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 2.4,
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        );
      case FileDownloadPhase.paused:
        return const SizedBox(width: 20, height: 20);
      case FileDownloadPhase.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
  }
}

/// Row for a received file (open / status / save).
class AdminMessageAttachmentTile extends StatelessWidget {
  const AdminMessageAttachmentTile({
    super.key,
    required this.fileName,
    required this.colorScheme,
    required this.textTheme,
    required this.onOpenTap,
    required this.downloadStatus,
    required this.showSaveAction,
    this.onSaveTap,
  });

  final String fileName;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onOpenTap;
  final Widget downloadStatus;
  final bool showSaveAction;
  final VoidCallback? onSaveTap;

  @override
  Widget build(BuildContext context) {
    final parts = splitFileNameAndExtension(fileName);

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onOpenTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                Symbols.file_present,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parts.base,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parts.extension.isEmpty
                          ? 'archivo'
                          : 'archivo${parts.extension}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 68,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(child: downloadStatus),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: showSaveAction
                          ? IconButton(
                              onPressed: onSaveTap,
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(Symbols.archive, size: 24),
                              tooltip: 'Guardar en...',
                              color: Theme.of(context).colorScheme.primary,
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
    );
  }
}
