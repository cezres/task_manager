import 'dart:async';

import 'package:task_manager/task/task_result.dart';
import 'package:task_manager/task_manager.dart';

class CountdownTask extends Task<int, void> {
  CountdownTask(super.initialData);

  @override
  FutureOr<TaskResult<int, void>> run() async {
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      emit(data - 1);

      if (shouldPause) {
        return TaskResult.paused(data);
      } else if (shouldCancel) {
        return TaskResult.canceled(data);
      }
    }
    return TaskResult.completed(0, null);
  }
}
