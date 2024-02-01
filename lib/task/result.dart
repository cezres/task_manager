part of '../task_manager.dart';

class Result<D, R> {
  final D? data;
  final R? result;
  final dynamic error;
  final ResultType type;

  Result({
    this.data,
    this.result,
    this.error,
    required this.type,
  });

  factory Result.paused([D? data]) {
    return Result(type: ResultType.paused, data: data);
  }

  factory Result.canceled() {
    return Result(type: ResultType.canceled, data: null);
  }

  factory Result.completed([R? result]) {
    return Result(type: ResultType.completed, data: null, result: result);
  }

  factory Result.error([dynamic error]) {
    return Result(type: ResultType.error, data: null, error: error);
  }

  @override
  String toString() {
    final suffix = data != null ? ' - $data' : '';
    switch (type) {
      case ResultType.canceled:
        return 'Canceled$suffix';
      case ResultType.paused:
        return 'Paused$suffix';
      case ResultType.completed:
        if (result == null) {
          return 'Completed';
        } else {
          return 'Completed - $result';
        }
      case ResultType.error:
        return 'Error$suffix';
    }
  }
}

enum ResultType {
  paused,
  canceled,
  completed,
  error,
}

// final class TaskCompleted<D, R> {
//   final D? data;
//   final R? result;
//   TaskCompleted([this.data, this.result]);
// }

// final class TaskCanceled<D> {
//   final D? data;
//   TaskCanceled([this.data]);
// }

// final class TaskPaused<D> {
//   final D? data;
//   TaskPaused([this.data]);
// }

// final class TaskError<D> {
//   final D? data;
//   final dynamic error;
//   TaskError([this.data, this.error]);
// }
