import 'dart:async';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:task_manager/src/utils/generate_incremental_id.dart';

typedef IsolateEnterPoint<M, R> = FutureOr<R> Function(
    M message, Stream receive, void Function(dynamic) emit);

abstract class IsolateCallback<R> {
  Stream get receive;

  void emit(dynamic data);

  Future<R> wait();
}

final class ReusableIsolate {
  static final Set<_IsolateWrapper> _idleIsolates = {};

  static IsolateCallback<R> run<M, R>(
      IsolateEnterPoint<M, R> entryPoint, M message) {
    if (_idleIsolates.isNotEmpty) {
      final isolate = _idleIsolates.last;
      _idleIsolates.remove(isolate);
      return isolate.run(entryPoint, message);
    } else {
      final isolate = _IsolateWrapper(
        onIdle: (wrapper) => _idleIsolates.add(wrapper),
        onRunning: (wrapper) => _idleIsolates.remove(wrapper),
        onExit: (wrapper) => _idleIsolates.remove(wrapper),
      );
      return isolate.run(entryPoint, message);
    }
  }
}

final class _IsolateWrapper {
  _IsolateWrapper({
    required this.onIdle,
    required this.onRunning,
    required this.onExit,
  }) {
    _receivePort.listen(_listen);

    Isolate.spawn(
      _backgroundIsolateEntryPoint,
      _receivePort.sendPort,
      debugName: _id,
    ).then((value) {}).onError((error, stackTrace) {
      _completer.completeError(error!);
      onExit(this);
    });
  }

  final void Function(_IsolateWrapper wrapper) onIdle;
  final void Function(_IsolateWrapper wrapper) onRunning;
  final void Function(_IsolateWrapper wrapper) onExit;

  final _id = generateIncrementalId('_IsolateWrapper');
  final _receivePort = ReceivePort();
  final _completer = Completer<SendPort>();
  final _tasks = <String, _IsolateCallback>{};

  IsolateCallback<R> run<M, R>(IsolateEnterPoint<M, R> entryPoint, M message) {
    final id = generateIncrementalId('$runtimeType-task');
    final task = _IsolateCallback<R>();
    _tasks[id] = task;

    _completer.future.then((sendPort) {
      sendPort.send(_Handler(id, entryPoint, message));
      task.emitter = (data) {
        sendPort.send(_Emitter(id, data));
      };
    }).onError((error, stackTrace) {
      debugPrint('SendPort - error: $error');
      task._onError(error);
      _tasks.remove(id);
    });

    return task;
  }

  void _listen(message) {
    if (message is SendPort) {
      _completer.complete(message);
    } else if (message is _Result) {
      if (message.isIdle) {
        onIdle(this);
      }
      final task = _tasks.remove(message.id);
      if (task != null) {
        task._onComplete(message.value);
      }
    } else if (message is _Error) {
      if (message.isIdle) {
        onIdle(this);
      }
      final task = _tasks.remove(message.id);
      if (task != null) {
        task._onError(message.error);
      }
    } else if (message is _Emitter) {
      final task = _tasks[message.id];
      if (task != null) {
        task._onReceive(message.value);
      }
    } else if (message is _RequestExit) {
      onExit(this);
      _completer.future.then((sendPort) {
        sendPort.send(_ApproveExit(message.id));
      });
    }
  }

  @override
  int get hashCode => _id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is _IsolateWrapper) {
      return other._id == _id;
    }
    return false;
  }
}

void _backgroundIsolateEntryPoint(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final broadcastReceivePort = receivePort.asBroadcastStream();
  String? lastTaskId;
  await for (var element in broadcastReceivePort) {
    if (element is _Handler) {
      Future.microtask(() async {
        final taskId = element.id;
        lastTaskId = taskId;
        try {
          final receive = broadcastReceivePort
              .where((event) => event is _Emitter)
              .cast<_Emitter>()
              .where((event) => event.id == element.id)
              .map((event) => event.value);
          final result = await element.run(
            receive,
            (value) {
              sendPort.send(_Emitter(element.id, value));
            },
          );
          sendPort.send(_Result(element.id, result, taskId == lastTaskId));
        } catch (e) {
          sendPort.send(_Error(element.id, e, taskId == lastTaskId));
        }

        Future.delayed(const Duration(seconds: 5)).then((value) {
          if (taskId == lastTaskId) {
            sendPort.send(_RequestExit(lastTaskId));
          }
        });
      });
    } else if (element is _ApproveExit) {
      if (element.id == lastTaskId) {
        receivePort.close();
        return;
      }
    }
  }
}

class _Handler<M, R> {
  const _Handler(this.id, this.entryPoint, this.message);
  final String id;
  final IsolateEnterPoint<M, R> entryPoint;
  final M message;

  FutureOr<R> run(Stream receive, void Function(dynamic) emit) {
    return entryPoint(message, receive, emit);
  }
}

class _Result {
  const _Result(this.id, this.value, this.isIdle);
  final String id;
  final dynamic value;
  final bool isIdle;

  @override
  String toString() => '$id - Result: $value';
}

class _Error {
  const _Error(this.id, this.error, this.isIdle);
  final String id;
  final dynamic error;
  final bool isIdle;

  @override
  String toString() => '$id - Error: $error';
}

class _Emitter {
  const _Emitter(this.id, this.value);
  final String id;
  final dynamic value;

  @override
  String toString() => '$id - Emitted: $value';
}

class _RequestExit {
  const _RequestExit(this.id);

  final String? id;

  @override
  String toString() => 'RequestExit';
}

class _ApproveExit {
  const _ApproveExit(this.id);

  final String? id;

  @override
  String toString() => 'ApproveExit';
}

class _IsolateCallback<R> implements IsolateCallback<R> {
  _IsolateCallback();

  final Completer<R> _completer = Completer();
  StreamController? _controller;
  final List _todo = [];
  void Function(dynamic data)? _emitter;
  set emitter(void Function(dynamic data) value) {
    _emitter = value;
    for (var data in _todo) {
      value(data);
    }
    _todo.clear();
  }

  @override
  Stream<dynamic> get receive {
    _controller ??= StreamController.broadcast();
    return _controller!.stream;
  }

  @override
  void emit(dynamic data) {
    if (_emitter != null) {
      _emitter?.call(data);
    } else {
      _todo.add(data);
    }
  }

  @override
  Future<R> wait() {
    return _completer.future;
  }

  void _onReceive(dynamic value) {
    _controller?.add(value);
  }

  void _onComplete(R value) {
    _controller?.close();
    _completer.complete(value);
  }

  void _onError(dynamic error) {
    _controller?.close();
    _completer.completeError(error);
  }
}
