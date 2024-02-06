part of '../task_manager.dart';

class TaskImpl<D, R> extends Task<D, R> with PriorityMixin {
  TaskImpl({
    required this.operation,
    required this.context,
    String? id,
    this.identifier,
  }) : id = id ?? generateIncrementalId('task');

  final OperationContextImpl<D, R> context;

  @override
  final Operation<D, R> operation;

  @override
  final String id;

  @override
  final String? identifier;

  @override
  TaskPriority get priority => context.priority;

  @override
  TaskStatus get status => context.status;

  @override
  D get data => context.data;

  @override
  bool get shouldCancel => context.shouldCancel;

  @override
  bool get shouldPause => context.shouldPause;

  @override
  Stream<TaskImpl<D, R>> get stream => context.stream.map((event) => this);

  Future<ResultType> run() => context.run(operation);

  @override
  void cancel() {
    _scheduler?.cancel(this);
    context.cancel();
  }

  @override
  void pause() {
    _scheduler?.pause(this);
    context.pause();
  }

  @override
  void resume() {
    _scheduler?.resume(this);
    context.resume();
  }

  @override
  void setPriority(TaskPriority priority) {
    _scheduler?.setPriority(this, oldPriority: context.priority);
    context.setPriority(priority);
  }

  @override
  Future<R> wait() => context.wait();

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is TaskImpl) {
      return other.id == id;
    }
    return super == other;
  }

  @override
  String toString() {
    return '${operation.runtimeType}: ${context.status}';
  }

  @override
  int get priorityValue => context.priority.index;

  /// Private
  Scheduler? _scheduler;

  void ensureInitialized(Scheduler value) {
    if (_scheduler != null) {
      throw StateError('Task is already initialized');
    }
    _scheduler = value;
  }
}

enum TaskStatus {
  pending,
  running,
  paused,
  canceled,
  completed,
  error,
}

enum TaskFlag {
  none,
  // Should cancel, handled by the task itself
  cancel,
  // Should pause, handled by the task itself
  pause,
}

class CanceledException extends Error {
  CanceledException();
}

enum TaskType {
  normal,
  isolate,
}

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

  Result tryToTransferableTypedData() {
    switch (type) {
      case ResultType.completed:
        return Result.completed(_tryToTransferableTypedData(result));
      case ResultType.paused:
        return Result.paused(_tryToTransferableTypedData(data));
      default:
    }
    return this;
  }

  Result tryFromTransferableTypedData() {
    switch (type) {
      case ResultType.completed:
        return Result.completed(_tryFromTransferableTypedData(result));
      case ResultType.paused:
        return Result.paused(_tryFromTransferableTypedData(data));
      default:
    }
    return this;
  }
}

enum ResultType {
  paused,
  canceled,
  completed,
  error,
}
