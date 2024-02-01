// part of '../task_manager.dart';

// // mixin BackgroundIsolateTaskMixin<Data, R> {
// //   String get id;

// //   FutureOr<R> _runInIsolate(void Function(dynamic data) emit);

// //   void _onIsolateCompleted(R result) {
// //     //
// //   }

// //   void _onIsolateError(dynamic error) {
// //     //
// //   }

// //   void _onIsolateEmitted(Data data) {
// //     //
// //   }

// //   void Function(String id)? sendCancelMessage;
// //   void Function(String id)? sendPauseMessage;

// //   void _cancelOnIsolate();

// //   void _pauseOnIsolate();
// // }

// final class BackgroundIsolateTask {
//   BackgroundIsolateTask({
//     required this.id,
//     required this.operation,
//     required this.context,
//   });

//   final String id;
//   final Operation operation;
//   final BackgroundIsolateOperationContext context;
// }

// class BackgroundIsolate {
//   BackgroundIsolate({
//     required this.onIdle,
//     required this.willExit,
//   }) {
//     _receivePort.listen(_listen);
//     try {
//       compute(
//         _backgroundIsolateEntryPoint,
//         _receivePort.sendPort,
//       );
//     } catch (e) {
//       debugPrint('BackgroundIsolate: $e');
//     }
//   }

//   final id = generateIncrementalId('background_isolate');
//   final _completer = Completer<void>();
//   late final SendPort _sendPort;
//   final _receivePort = ReceivePort();
//   final Map<String, Task> _tasks = {};

//   final void Function(BackgroundIsolate isolate) onIdle;
//   final bool Function(BackgroundIsolate isolate) willExit;

//   void execute(Task task) {
//     _prepareForTaskExecution(task);
//     _sendPort.send(_buildBackgroundIsolateTask(task));
//   }

//   void _listen(message) {
//     debugPrint('main received: $message');

//     if (message == _BackgroundIsolateAction.requestExit) {
//       if (willExit(this)) {
//         _receivePort.close();
//         _sendPort.send(_BackgroundIsolateAction.approveExit);
//       } else {
//         onIdle(this);
//       }
//     } else if (message is SendPort) {
//       _sendPort = message;
//       // message.send('22333');
//       _completer.complete();
//     } else if (message is BackgroundIsolateTaskCompleted) {
//       final task = _tasks.remove(message.id);
//       if (task != null) {
//         task._handlerResult(message.value);
//       }
//       if (message.isIdle) {
//         onIdle(this);
//       }
//     } else if (message is BackgroundIsolateTaskError) {
//       final task = _tasks.remove(message.id);
//       if (task != null) {
//         _onTaskCompletion(task);
//         task._handlerResult(OperationCompleter.error(null, message.error));
//       }
//       if (message.isIdle) {
//         onIdle(this);
//       }
//     } else if (message is _BackgroundIsolateTaskEmit) {
//       final task = _tasks[message.id];
//       if (task != null) {
//         task._context.emit(message.value);
//       }
//     }
//   }

//   void _prepareForTaskExecution(Task task) {
//     _tasks[task.id] = task;
//     task._context = task._context.toMainIsolateContext(_sendPort);
//   }

//   void _onTaskCompletion(Task task) {
//     _tasks.remove(task.id);
//   }

//   BackgroundIsolateTask _buildBackgroundIsolateTask<D, R>(Task<D, R> task) {
//     final BackgroundIsolateTask isolateTask = BackgroundIsolateTask(
//       id: task.id,
//       operation: task.operation,
//       context: task._context.toBackgroundIsolateContext(),
//     );
//     return isolateTask;
//   }
// }

// void _backgroundIsolateEntryPoint(SendPort sendPort) async {
//   // final sendPort = message[0] as SendPort;

//   final receivePort = ReceivePort();
//   sendPort.send(receivePort.sendPort);

//   final context = _BackgroundIsolateContext(sendPort: sendPort);

//   // _executeTaskInIsolate(context, message[1]);

//   debugPrint('BackgroundIsolate: start');
//   await for (var message in receivePort) {
//     debugPrint('background received: $message');

//     if (message is BackgroundIsolateTask) {
//       context.totalTaskCount += 1;
//       _executeTaskInIsolate(context, message);
//     } else if (message == _BackgroundIsolateAction.approveExit) {
//       debugPrint('BackgroundIsolate: exit');
//       receivePort.close();
//       return;
//     } else if (message is _CancelBackgroundIsolateTask) {
//       final task = context.tasks[message.id];
//       if (task != null) {
//         task.context._flag = TaskFlag.cancel;
//       }
//     } else if (message is _PauseBackgroundIsolateTask) {
//       final task = context.tasks[message.id];
//       if (task != null) {
//         task.context._flag = TaskFlag.pause;
//       }
//     }
//   }
// }

// Future<void> _executeTaskInIsolate(
//   _BackgroundIsolateContext context,
//   BackgroundIsolateTask task,
// ) async {
//   context.tasks[task.id] = task;
//   task.context.sendPort = context.sendPort;

//   final currentTaskFlag = context.totalTaskCount;
//   try {
//     final result = await task.operation.run(task.context);
//     context.sendPort.send(BackgroundIsolateTaskCompleted(
//       task.id,
//       result,
//       context.totalTaskCount == currentTaskFlag,
//     ));

//     context.tasks.remove(task.id);
//   } catch (e) {
//     context.sendPort.send(BackgroundIsolateTaskError(
//       task.id,
//       e,
//       context.totalTaskCount == currentTaskFlag,
//     ));

//     context.tasks.remove(task.id);
//   }

//   /// Wait for 5 seconds to see if there is any new task
//   /// If not, request exit
//   Future.delayed(const Duration(seconds: 5)).then((value) {
//     if (currentTaskFlag == context.totalTaskCount) {
//       debugPrint('BackgroundIsolate: request exit');
//       context.sendPort.send(_BackgroundIsolateAction.requestExit);
//     }
//   });
// }

// final class _CancelBackgroundIsolateTask {
//   const _CancelBackgroundIsolateTask(this.id);
//   final String id;
// }

// final class _PauseBackgroundIsolateTask {
//   const _PauseBackgroundIsolateTask(this.id);
//   final String id;
// }

// enum _BackgroundIsolateAction {
//   requestExit,
//   approveExit,
// }

// class _BackgroundIsolateContext {
//   _BackgroundIsolateContext({required this.sendPort});
//   final SendPort sendPort;
//   int totalTaskCount = 0;
//   final Map<String, BackgroundIsolateTask> tasks = {};
// }
