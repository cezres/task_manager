import 'dart:async';

import 'package:task_manager/task/result.dart';
import 'package:task_manager/task_manager.dart';

class CountdownTask extends Task<int, void> {
  CountdownTask(super.initialData);

  @override
  FutureOr<TaskResult<int, void>> run() async {
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 1000));

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
    return 'CountdownTask: $data';
  }
}
