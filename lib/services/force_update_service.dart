import 'package:flutter/foundation.dart';
import 'package:pedidosapp/services/force_update_checker.dart';

/// Estado global del bloqueo por versión (splash + overlay al volver a la app).
class ForceUpdateService extends ChangeNotifier {
  ForceUpdateService._();

  static final ForceUpdateService instance = ForceUpdateService._();

  final ForceUpdateChecker _checker = ForceUpdateChecker();
  bool _busy = false;
  ForceUpdateEvaluation? _block;

  ForceUpdateEvaluation? get block => _block;

  Future<void> revalidate() async {
    if (_busy) return;
    _busy = true;
    try {
      _block = await _checker.evaluate();
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> recheck() => revalidate();
}
