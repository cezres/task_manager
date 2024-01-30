import 'dart:async';

import 'package:task_manager/task/result.dart';
import 'package:task_manager/task_manager.dart';

abstract class StatelessTask<Data> extends Task<Data, void> {
  StatelessTask(super.initialData);

  @override
  FutureOr<TaskResult<Data, void>> run() {
    // TODO: implement run
    throw UnimplementedError();
  }

  @override
  void emit(Data data) {
    //
  }
}
