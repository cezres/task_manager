import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/task/task_result.dart';

import 'package:task_manager/task_manager.dart';

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('setUp');
  });

  test('task_manager', () async {
    final manager = TaskManagerImpl();
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
}

class CountdownTask extends Task<int, void> {
  CountdownTask(super.initialState);

  @override
  FutureOr<TaskResult<int, void>> run() async {
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      emit(data - 1);
    }
    return TaskResult.completed(0);
  }

  @override
  String toString() {
    return '$data';
  }
}
