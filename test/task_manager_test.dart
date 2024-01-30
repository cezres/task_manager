import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/isolate/background_isolate_manager.dart';
import 'package:task_manager/task/result.dart';

import 'package:task_manager/task_manager.dart';

import 'example_isolate_task.dart';

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('setUp');
  });

  test('run a task', () async {
    final worker = TaskManagerImpl(identifier: 'temp');

    final task = CountdownTask(10);
    task.stream.listen((event) {
      debugPrint('CountdownTask: $event');
    });

    expect(task.status, TaskStatus.pending);

    worker.add(task);

    await task.wait();

    expect(task.status, TaskStatus.completed);
  });

  test('dart', () {
    final list = [0, 1, 2, 3];
    for (var element in list) {
      if (element == 2) {
        list.remove(2);
        break;
      }
    }
    debugPrint('list: $list');
  });

  test('task_manager', () async {
    final manager = TaskManagerImpl(identifier: 'test');
    manager.maximumNumberOfConcurrencies = 2;
    manager.stream.listen((event) {
      String runningTasks = "";
      for (var element in manager.runningTasks) {
        runningTasks += '$element, ';
      }
      debugPrint('runningTasks: $runningTasks');

      String pendingTasks = "";
      for (var element in manager.pendingTasks) {
        pendingTasks += '$element, ';
      }
      debugPrint('pendingTasks: $pendingTasks');
    });

    for (var i = 0; i < 6; i++) {
      manager.add(CountdownTask(10));
    }
    await manager.waitForAllTasksToComplete();
    debugPrint('All tasks completed');
  });

  test('run isolate task', () async {
    final isolateManager = BackgroundIsolateManager(identifier: '');
    final task = ExampleIsolateTask(4);

    expect(isolateManager.executeInIsolate(task), true);

    await task.wait();

    expect(task.status, TaskStatus.completed);

    await Future.delayed(const Duration(seconds: 10));
  });
}

class CountdownTask extends Task<int, void> {
  CountdownTask(super.initialData);

  @override
  FutureOr<TaskResult<int, void>> run() async {
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 100));

      final newData = data - 1;

      if (shouldPause) {
        return TaskResult.paused(newData);
      } else if (shouldCancel) {
        return TaskResult.canceled(newData);
      } else {
        emit(newData);
      }
    }
    return TaskResult.completed(0);
  }

  @override
  String toString() {
    return '$data';
  }
}
