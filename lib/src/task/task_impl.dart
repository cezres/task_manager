part of '../../task_manager.dart';

class TaskImpl<D, R, O extends Operation<D, R>> extends Task<D, R>
    with PriorityMixin {
  TaskImpl._({
    required this.operation,
    required OperationContextImpl<D, R> context,
  }) : _context = context;

  @override
  String get name => operation.name;

  @override
  String get id => _context.id;

  @override
  String? get identifier => _context.identifier;

  @override
  TaskPriority get priority => _context.priority;

  @override
  TaskStatus get status => _context.status;

  @override
  D get data => _context.data;

  @override
  bool get shouldCancel => _context.shouldCancel;

  @override
  bool get shouldPause => _context.shouldPause;

  @override
  Stream<TaskImpl<D, R, O>> get stream => _context.stream.map((event) => this);

  final OperationContextImpl<D, R> _context;
  final O operation;

  FutureOr<Result<D, R>> run() {
    return operation.run(_context);
  }

  @override
  void cancel() {
    if (status == TaskStatus.running) {
      _change(flag: TaskFlag.cancel);
    } else if (status == TaskStatus.pending || status == TaskStatus.paused) {
      if (_scheduler != null) {
        _scheduler?.cancel(this);
      } else {
        _change(status: TaskStatus.canceled, flag: TaskFlag.none);
      }
    }
  }

  @override
  void pause() {
    if (status == TaskStatus.running) {
      _change(flag: TaskFlag.pause);
    } else if (status == TaskStatus.pending) {
      if (_scheduler != null) {
        _scheduler?.pause(this);
      } else {
        _change(status: TaskStatus.paused, flag: TaskFlag.none);
      }
    }
  }

  @override
  void resume() {
    if (status == TaskStatus.paused) {
      if (_scheduler != null) {
        _scheduler?.resume(this);
      } else {
        _change(status: TaskStatus.pending, flag: TaskFlag.none);
      }
    }
  }

  @override
  void changePriority(TaskPriority priority) {
    if (_scheduler != null) {
      _scheduler?.setPriority(this, priority);
    } else {
      _change(priority: priority);
    }
  }

  @override
  Future<R> wait() => _context.wait();

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
    return '${operation.runtimeType}: ${_context.data}';
  }

  @override
  int get priorityValue => _context.priority.index;

  /// Private
  Scheduler? _scheduler;

  void ensureInitialized(Scheduler value) {
    if (_scheduler != null) {
      throw StateError('Task is already initialized');
    }
    _scheduler = value;
  }

  void onCompleted(Result<D, R> result) {
    _context.handlerResult(result);
  }

  void onError(dynamic error) {
    _context.handlerResult(Result<D, R>.error(error));
  }

  void onPaused() {
    _context.handlerResult(Result<D, R>.paused());
  }

  void onCanceled() {
    _context.handlerResult(Result<D, R>.canceled());
  }

  void onRunning() {
    _context.setup(status: TaskStatus.running);
  }

  void _change({
    D? data,
    TaskStatus? status,
    TaskFlag? flag,
    TaskPriority? priority,
  }) {
    _context.setup(
      data: data,
      status: status,
      flag: flag,
      priority: priority,
    );
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

  @override
  String toString() {
    return 'CanceledException';
  }
}
