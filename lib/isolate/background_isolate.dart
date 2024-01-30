import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:task_manager/isolate/background_isolate_task_result.dart';
import 'package:task_manager/utils/generate_incremental_id.dart';

mixin BackgroundIsolateTaskMixin<Data, R> {
  String get id;

  FutureOr<R> _runInIsolate(void Function(dynamic data) emit);

  void _onIsolateCompleted(R result) {
    //
  }

  void _onIsolateError(dynamic error) {
    //
  }

  void _onIsolateEmitted(Data data) {
    //
  }

  void Function(String id)? sendCancelMessage;
  void Function(String id)? sendPauseMessage;

  void _cancelOnIsolate();

  void _pauseOnIsolate();
}

class BackgroundIsolate {
  BackgroundIsolate({
    required this.onIdle,
    required this.willExit,
    required BackgroundIsolateTaskMixin initialTask,
  }) {
    _receivePort.listen(_listen);
    _prepareForTaskExecution(initialTask);
    try {
      compute(
        _backgroundIsolateEntryPoint,
        [_receivePort.sendPort, initialTask],
      );
    } catch (e) {
      debugPrint('BackgroundIsolate: $e');
    }
  }

  final id = generateIncrementalId('background_isolate');
  final _completer = Completer<void>();
  final _receivePort = ReceivePort();
  late final SendPort _sendPort;
  final Map<String, BackgroundIsolateTaskMixin> _tasks = {};

  final void Function(BackgroundIsolate isolate) onIdle;
  final bool Function(BackgroundIsolate isolate) willExit;

  void execute(BackgroundIsolateTaskMixin task) {
    _prepareForTaskExecution(task);
    _completer.future.then((value) => _sendPort.send(_receivePort.sendPort));
  }

  void _listen(message) {
    if (message == _BackgroundIsolateAction.requestExit) {
      if (willExit(this)) {
        _receivePort.close();
        _sendPort.send(_BackgroundIsolateAction.approveExit);
      } else {
        onIdle(this);
      }
      return;
    }

    switch (message.runtimeType) {
      case SendPort:
        _sendPort = message;
        _completer.complete();
        break;
      case BackgroundIsolateTaskCompleted:
        final task = _tasks.remove(message.id);
        if (task != null) {
          _onTaskCompletion(task);
          task._onIsolateCompleted(message.value);
        }
        if (message.isIdle) {
          onIdle(this);
        }

        break;
      case BackgroundIsolateTaskError:
        final task = _tasks.remove(message.id);
        if (task != null) {
          _onTaskCompletion(task);
          task._onIsolateError(message.error);
        }
        if (message.isIdle) {
          onIdle(this);
        }

        break;
      case BackgroundIsolateTaskEmit:
        final task = _tasks[message.id];
        if (task != null) {
          task._onIsolateEmitted(message.value);
        }

        break;
      default:
    }
  }

  void _prepareForTaskExecution(BackgroundIsolateTaskMixin task) {
    _tasks[task.id] = task;
    task.sendCancelMessage = (id) {
      _completer.future
          .then((value) => _sendPort.send(_CancelBackgroundIsolateTask(id)));
    };
    task.sendPauseMessage = (id) {
      _completer.future
          .then((value) => _sendPort.send(_PauseBackgroundIsolateTask(id)));
    };
  }

  void _onTaskCompletion(BackgroundIsolateTaskMixin task) {
    _tasks.remove(task.id);
    task.sendCancelMessage = null;
    task.sendPauseMessage = null;
  }
}

void _backgroundIsolateEntryPoint(dynamic message) async {
  final sendPort = message[0] as SendPort;

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final context = _BackgroundIsolateContext(sendPort: sendPort);

  _executeTaskInIsolate(context, message[1]);

  await for (var message in receivePort) {
    if (message is BackgroundIsolateTaskMixin) {
      context.totalTaskCount += 1;
      _executeTaskInIsolate(context, message);
    } else if (message == _BackgroundIsolateAction.approveExit) {
      debugPrint('BackgroundIsolate: exit');
      receivePort.close();
      return;
    } else if (message is _CancelBackgroundIsolateTask) {
      final task = context.tasks[message.id];
      if (task != null) {
        task._cancelOnIsolate();
      }
    } else if (message is _PauseBackgroundIsolateTask) {
      final task = context.tasks[message.id];
      if (task != null) {
        task._pauseOnIsolate();
      }
    }
  }
}

void _executeTaskInIsolate(
  _BackgroundIsolateContext context,
  BackgroundIsolateTaskMixin task,
) async {
  final currentTaskFlag = context.totalTaskCount;
  try {
    final result = await task._runInIsolate((data) {
      context.sendPort.send(BackgroundIsolateTaskEmit(task.id, data));
    });
    context.sendPort.send(BackgroundIsolateTaskCompleted(
      task.id,
      result,
      context.totalTaskCount == currentTaskFlag,
    ));
  } catch (e) {
    context.sendPort.send(BackgroundIsolateTaskError(
      task.id,
      e,
      context.totalTaskCount == currentTaskFlag,
    ));
  }

  /// Wait for 10 seconds to see if there is any new task
  /// If not, request exit
  Future.delayed(const Duration(seconds: 10)).then((value) {
    if (currentTaskFlag == context.totalTaskCount) {
      debugPrint('BackgroundIsolate: request exit');
      context.sendPort.send(_BackgroundIsolateAction.requestExit);
    }
  });
}

final class _CancelBackgroundIsolateTask {
  const _CancelBackgroundIsolateTask(this.id);
  final String id;
}

final class _PauseBackgroundIsolateTask {
  const _PauseBackgroundIsolateTask(this.id);
  final String id;
}

enum _BackgroundIsolateAction {
  requestExit,
  approveExit,
}

class _BackgroundIsolateContext {
  _BackgroundIsolateContext({required this.sendPort});
  final SendPort sendPort;
  int totalTaskCount = 0;
  final Map<String, BackgroundIsolateTaskMixin> tasks = {};
}
