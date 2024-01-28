import 'package:flutter/foundation.dart';

final Map<String, int> _incrementalIdMap = {};

int _initialTimestamp = 0;

/// Generates an incremental ID for the given type.
String generateIncrementalId(String type) {
  if (_initialTimestamp == 0) {
    _initialTimestamp = DateTime.now().millisecondsSinceEpoch;
  }
  final oldValue = _incrementalIdMap[type] ?? 0;
  final newValue = oldValue + 1;
  _incrementalIdMap[type] = newValue;

  if (kDebugMode) {
    debugPrint('$type-$_initialTimestamp-$newValue');
  }

  return '$type-$_initialTimestamp-$newValue';
}
