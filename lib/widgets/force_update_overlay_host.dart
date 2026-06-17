import 'package:flutter/material.dart';
import 'package:pedidosapp/services/force_update_service.dart';
import 'package:pedidosapp/widgets/force_update_screen.dart';

/// Overlay de actualización forzada sobre cualquier pantalla (dentro de [MaterialApp]).
class ForceUpdateOverlayHost extends StatefulWidget {
  const ForceUpdateOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<ForceUpdateOverlayHost> createState() => _ForceUpdateOverlayHostState();
}

class _ForceUpdateOverlayHostState extends State<ForceUpdateOverlayHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ForceUpdateService.instance.addListener(_onBlockChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ForceUpdateService.instance.removeListener(_onBlockChanged);
    super.dispose();
  }

  void _onBlockChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ForceUpdateService.instance.revalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = ForceUpdateService.instance.block;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (block != null)
          Positioned.fill(
            child: ForceUpdateScreen(
              policy: block.policy,
              currentVersion: block.currentVersion,
              storeUri: block.storeUri,
              onRecheck: ForceUpdateService.instance.recheck,
            ),
          ),
      ],
    );
  }
}
