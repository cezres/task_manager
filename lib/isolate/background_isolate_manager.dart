// part of '../task_manager.dart';

// class BackgroundIsolateManager {
//   BackgroundIsolateManager._();

//   static BackgroundIsolateManager? _manager;

//   static BackgroundIsolateManager get manager =>
//       _manager ??= BackgroundIsolateManager._();

//   int _maximumNumberOfConcurrencies = 4;

//   int get maximumNumberOfConcurrencies => _maximumNumberOfConcurrencies;

//   set maximumNumberOfConcurrencies(int value) {
//     if (value < 1) {
//       throw ArgumentError.value(value, 'maximumNumberOfConcurrencies');
//     }
//     if (value > _maximumNumberOfConcurrencies) {
//       _maximumNumberOfConcurrencies = value;
//       _idleController.add(null);
//     } else {
//       _maximumNumberOfConcurrencies = value;
//     }
//   }

//   final _idleController = StreamController<void>.broadcast();

//   final Map<String, BackgroundIsolate> _running = {};
//   final Set<BackgroundIsolate> _idle = {};

//   StreamSubscription<void> listenIdleIsolate(VoidCallback callback) {
//     return _idleController.stream.listen((event) => callback());
//   }

//   bool hasIdleIsolate() {
//     if (_idle.isNotEmpty) {
//       return true;
//     }
//     if (_running.length < maximumNumberOfConcurrencies) {
//       return true;
//     }
//     return false;
//   }

//   bool executeInIsolate(Task task) {
//     if (_idle.isNotEmpty) {
//       final isolate = _idle.first;
//       _idle.remove(isolate);
//       _running[isolate.id] = isolate;
//       isolate.execute(task);
//       return true;
//     } else if (_running.length < maximumNumberOfConcurrencies) {
//       final isolate = _createBackgroundIsolate();
//       _running[isolate.id] = isolate;
//       isolate._completer.future.then((value) {
//         isolate.execute(task);
//       });
//       return true;
//     } else {
//       return false;
//     }
//   }

//   BackgroundIsolate _createBackgroundIsolate() {
//     return BackgroundIsolate(
//       onIdle: (isolate) {
//         _running.remove(isolate.id);

//         if (_maximumNumberOfConcurrencies > (_running.length + _idle.length)) {
//           _idle.add(isolate);
//           _idleController.add(null);
//         }
//       },
//       willExit: (isolate) {
//         return true;
//       },
//       // initialTask: initialTask,
//     );
//   }
// }
