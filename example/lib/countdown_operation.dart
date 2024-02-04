import 'dart:async';

import 'package:task_manager/task_manager.dart';

class CountdownOperation extends HydratedOperation<int, void> {
  const CountdownOperation();

  @override
  String get name => 'Countdown';

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 1000));
      data -= 1;
      if (context.shouldPause) {
        return Result.paused(data);
      } else if (context.shouldCancel) {
        return Result.canceled();
      } else if (data > 0) {
        context.emit(data);
      } else {
        return Result.completed();
      }
    }
  }

  @override
  toJson(int data) {
    return data;
  }

  @override
  int fromJson(json) {
    return json;
  }
}
