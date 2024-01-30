import 'dart:async';

import 'package:task_manager/task/result.dart';
import 'package:task_manager/task_manager.dart';

class ExampleIsolateTask extends IsolateTask<int, void> {
  ExampleIsolateTask(super.initialState);

  @override
  FutureOr<TaskResult<int, void>> run() async {
    await Future.delayed(Duration(seconds: data));
    return TaskResult.completed();
  }
}
