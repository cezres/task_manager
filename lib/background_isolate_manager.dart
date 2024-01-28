import 'dart:async';

import 'package:flutter/foundation.dart';

abstract class BackgroundIsolateManager {
  BackgroundIsolateManager({
    required this.identifier,
    this.maximumNumberOfConcurrencies = 4,
  });

  final String identifier;

  final int maximumNumberOfConcurrencies;

  final _controller = StreamController<void>.broadcast();

  final List<BackgroundIsolate> _runningBackgroundIsolates = [];
  final List<BackgroundIsolate> _idleBackgroundIsolates = [];

  StreamSubscription<void> listenForIdleBackgroundIsolate(
      VoidCallback callback) {
    return _controller.stream.listen((event) => callback());
  }

  BackgroundIsolate? getIdleBackgroundIsolate() {
    return null;
  }
}

class BackgroundIsolate {
  //
}
