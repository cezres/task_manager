import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:task_manager/isolate/background_isolate.dart';

class BackgroundIsolateManager {
  BackgroundIsolateManager({
    required this.identifier,
    this.maximumNumberOfConcurrencies = 4,
  });

  final String identifier;

  final int maximumNumberOfConcurrencies;

  final _controller = StreamController<void>.broadcast();

  final Map<String, BackgroundIsolate> _running = {};
  final Set<BackgroundIsolate> _idle = {};

  StreamSubscription<void> listenIdleIsolate(VoidCallback callback) {
    return _controller.stream.listen((event) => callback());
  }

  bool hasIdleIsolate() {
    if (_idle.isNotEmpty) {
      return true;
    }
    if (_running.length < maximumNumberOfConcurrencies) {
      return true;
    }
    return false;
  }

  bool executeInIsolate(BackgroundIsolateTaskMixin task) {
    if (_idle.isNotEmpty) {
      final isolate = _idle.first;
      _idle.remove(isolate);
      _running[isolate.id] = isolate;
      isolate.execute(task);
      return true;
    } else if (_running.length < maximumNumberOfConcurrencies) {
      final isolate = _createBackgroundIsolate(task);
      _running[isolate.id] = isolate;
      return true;
    } else {
      return false;
    }
  }

  BackgroundIsolate _createBackgroundIsolate(
      BackgroundIsolateTaskMixin initialTask) {
    return BackgroundIsolate(
      onIdle: (isolate) {
        _running.remove(isolate.id);
        _idle.add(isolate);
        _controller.add(null);
      },
      willExit: (isolate) {
        return true;
      },
      initialTask: initialTask,
    );
  }
}
