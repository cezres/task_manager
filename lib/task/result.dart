class TaskResult<Data, Value> {
  final Data? data;
  final Value? result;
  final dynamic error;
  final TaskResultType type;

  TaskResult({
    this.data,
    this.result,
    this.error,
    required this.type,
  });

  factory TaskResult.paused([Data? data]) {
    return TaskResult(type: TaskResultType.paused, data: data);
  }

  factory TaskResult.canceled([Data? data]) {
    return TaskResult(type: TaskResultType.canceled, data: data);
  }

  factory TaskResult.completed([Data? data, Value? result]) {
    return TaskResult(
        type: TaskResultType.completed, data: data, result: result);
  }

  factory TaskResult.error([Data? data, dynamic error]) {
    return TaskResult(type: TaskResultType.error, data: data, error: error);
  }
}

enum TaskResultType {
  paused,
  canceled,
  completed,
  error,
}
