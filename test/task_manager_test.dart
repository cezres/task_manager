import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/task_manager.dart';

import 'memory_storage.dart';

void main() {
  // setUp(() {
  //   WidgetsFlutterBinding.ensureInitialized();
  //   debugPrint('setUp');
  // });

  Future<void> ensureDataStored() {
    return Future.delayed(const Duration(milliseconds: 100));
  }

  test('xxx', () async {
    final Completer<int> completer = Completer<int>();

    Future.delayed(const Duration(seconds: 1), () {
      // completer.complete(1);
      // completer.complete();
      completer.completeError(CanceledException());
    });

    try {
      debugPrint('${await completer.future}');
    } catch (e) {
      debugPrint('catch: $e');
    }
  });

  test('run a task', () async {
    final worker = WorkerImpl();
    final task = worker.addCountdownTask(10);

    task.stream.listen((event) {
      debugPrint('CountdownTask: ${event.data} - ${event.status}');
      if (event.data == 0) {
        debugPrint('Finish');
      }
    });

    expect(task.status, TaskStatus.running);
    await task.wait();
    expect(task.status, TaskStatus.completed);
    expect(task.data, 0);
    expect(worker.length, 0);
  });

  test('storage', () async {
    /// Initialize
    final worker = WorkerImpl();
    StorageManager.registerStorage(MemoryStorage());
    StorageManager.registerOperation(() => const CountdownOperation());
    StorageManager.clear(worker.identifier);

    /// Add a paused task
    final task = worker.addCountdownTask(6, isPaused: true);
    expect(task.status, TaskStatus.paused);
    expect(worker.length, 1);
    await ensureDataStored();

    worker.clear();
    expect(worker.length, 0);
    var list = await worker.loadTasksWithStorage().toList();
    expect(list.length, 1);
    expect(list[0].status, TaskStatus.paused);

    /// Resume the task to completed
    list[0].resume();
    await list[0].wait();
    await ensureDataStored();
    expect(worker.length, 0);

    /// Load tasks from storage
    list = await worker.loadTasksWithStorage().toList();
    expect(list.length, 0);
  });

  test('worker', () async {
    final worker = WorkerImpl();
    worker.maxConcurrencies = 2;
    worker.stream.listen((event) {
      String runningTasks = "";
      for (var element in worker.runningTasks) {
        runningTasks += '${element.id}, ';
      }
      debugPrint('------');
      debugPrint('runningTasks: $runningTasks');

      String pendingTasks = "";
      for (var element in worker.pendingTasks) {
        pendingTasks += '${element.id}, ';
      }
      debugPrint('pendingTasks: $pendingTasks');
    });

    for (var i = 0; i < 4; i++) {
      worker.addCountdownTask(6);
    }
    expect(worker.length, 4);

    await worker.wait();
    debugPrint('All tasks completed');
    expect(worker.length, 0);
  });

  test('run isolate task', () async {
    final worker = IsolateWorker();
    final task = worker.addCountdownTask(10);

    task.stream.listen((event) {
      debugPrint('CountdownTask: ${event.data} - ${event.status}');
      if (event.data == 0) {
        debugPrint('Finish');
      }
    });

    await Future.delayed(const Duration(milliseconds: 400));
    debugPrint('Pause');
    task.pause();

    await Future.delayed(const Duration(milliseconds: 400));
    expect(task.status, TaskStatus.paused);

    await Future.delayed(const Duration(seconds: 4));

    debugPrint('Resume');
    task.resume();
    expect(task.status, TaskStatus.running);

    await Future.delayed(const Duration(milliseconds: 400));
    debugPrint('Cancel');
    task.cancel();

    try {
      await task.wait();
    } catch (e) {
      debugPrint('catch: $e');
    }

    await worker.wait();
    debugPrint('done');

    expect(task.status, TaskStatus.canceled);
    expect(worker.length, 0);
  });
}

class CountdownOperation extends HydratedOperation<int, void> {
  const CountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 200));
      data -= 1;
      if (context.shouldCancel) {
        return Result.canceled();
      } else if (context.shouldPause) {
        return Result.paused(data);
      } else if (data > 0) {
        context.emit(data);
      } else {
        return Result.completed();
      }
    }
  }

  @override
  int fromJson(json) {
    return json;
  }

  @override
  toJson(int data) {
    return data;
  }
}

extension on WorkerImpl {
  TaskImpl<int, void, Operation<int, void>> addCountdownTask(int initialData,
      {bool isPaused = false}) {
    return addTask(
      const CountdownOperation(),
      initialData,
      isPaused: isPaused,
    );
  }
}
