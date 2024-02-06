part of '../task_manager.dart';

typedef TaskIdentifier = String;
typedef TaskId = String;

enum TaskIdentifierStrategy {
  reuse, // Reuse tasks with the same identifier
  cancel, // Cancel the previous task with the same identifier
}

abstract class Scheduler {
  Stream<Scheduler> get stream;

  int maxConcurrencies = 4;

  int get length;

  bool get isPendingTasksEmpty;

  bool get isMaxConcurrencyReached;

  bool get isCompleted;

  List<TaskImpl> get runningTasks;
  List<TaskImpl> get pausedTasks;
  List<TaskImpl> get pendingTasks;

  TaskImpl? contains(TaskId id, TaskIdentifier? identifier);

  TaskImpl? taskOfIdentifier(TaskIdentifier identifier);

  TaskImpl putIfAbsent(TaskIdentifier identifier, TaskImpl Function() ifAbsent);

  bool add(TaskImpl task);

  void pause(TaskImpl task);

  void resume(TaskImpl task);

  void cancel(TaskImpl task);

  void setPriority(TaskImpl task, {required TaskPriority oldPriority});

  Future<void> waitForAllTasksToComplete();

  void clear();

  operator [](TaskId id);
}

class SchedulerImpl extends Scheduler {
  final Map<TaskId, TaskImpl> _runningTasks = {};
  final PriorityQueue<TaskImpl> _pendingTasks = PriorityQueueImpl<TaskImpl>();
  final Map<TaskId, TaskImpl> _pausedTasks = {};

  final Map<TaskId, TaskImpl> _taskOfId = {};
  final Map<TaskIdentifier, TaskImpl> _taskOfIdentifier = {};

  SchedulerImpl({required this.executeTask});

  final Future<ResultType> Function(TaskImpl task) executeTask;

  final _controller = StreamController<Scheduler>.broadcast();
  Completer<void> _completer = Completer<void>();

  @override
  Stream<Scheduler> get stream => _controller.stream;

  @override
  int get length =>
      _runningTasks.length + _pendingTasks.length + _pausedTasks.length;

  @override
  bool get isPendingTasksEmpty => _pendingTasks.isEmpty;

  @override
  bool get isMaxConcurrencyReached => _runningTasks.length >= maxConcurrencies;

  @override
  bool get isCompleted => length == 0;

  @override
  List<TaskImpl> get runningTasks => _runningTasks.values.toList();

  @override
  List<TaskImpl> get pendingTasks => _pendingTasks.toList();

  @override
  List<TaskImpl> get pausedTasks => _pausedTasks.values.toList();

  @override
  TaskImpl? contains(TaskId id, TaskIdentifier? identifier) {
    if (identifier != null) {
      final task = _taskOfIdentifier[identifier];
      if (task != null) {
        return task;
      }
    }
    return _taskOfId[id];
  }

  @override
  TaskImpl? taskOfIdentifier(TaskIdentifier identifier) {
    return _taskOfIdentifier[identifier];
  }

  @override
  TaskImpl putIfAbsent(
      TaskIdentifier identifier, TaskImpl Function() ifAbsent) {
    final task = _taskOfIdentifier[identifier];
    if (task == null) {
      final task = ifAbsent();
      add(task);
      return task;
    } else {
      return task;
    }
  }

  @override
  bool add(TaskImpl task) {
    task.ensureInitialized(this);

    if (contains(task.id, task.identifier) != null) {
      return false;
    }

    switch (task.status) {
      case TaskStatus.running:
      case TaskStatus.pending:
        if (maxConcurrencies > _runningTasks.length) {
          _executeTask(task);
        } else {
          _pendingTasks.add(task);
        }

        _taskOfId[task.id] = task;
        if (task.identifier != null) {
          _taskOfIdentifier[task.identifier!] = task;
        }

        _resetCompleter();
        _notify();
        return true;
      case TaskStatus.paused:
        _pausedTasks[task.id] = task;

        _taskOfId[task.id] = task;
        if (task.identifier != null) {
          _taskOfIdentifier[task.identifier!] = task;
        }

        _resetCompleter();
        _notify();
        return true;
      default:
        throw StateError('Invalid status: ${task.status}');
    }
  }

  @override
  void pause(TaskImpl task) {
    if (task.status == TaskStatus.pending) {
      _pendingTasks.remove(task);
      _pausedTasks[task.id] = task;
      _notify();
    }
  }

  @override
  void resume(TaskImpl task) {
    _pausedTasks.remove(task.id);
    _pendingTasks.add(task);
    executePendingTasks();
  }

  @override
  void cancel(TaskImpl task) {
    if (task.status == TaskStatus.pending) {
      _pendingTasks.remove(task);
    } else if (task.status == TaskStatus.paused) {
      _pausedTasks.remove(task.id);
    }
    _notify();
  }

  @override
  void setPriority(TaskImpl task, {required TaskPriority oldPriority}) {
    if (task.status == TaskStatus.pending) {
      _pendingTasks.remove(task, priority: oldPriority.index);
      _pendingTasks.add(task);
    }
  }

  @override
  void clear() {
    for (var element in _runningTasks.values) {
      element.cancel();
    }
    _runningTasks.clear();
    _pendingTasks.clear();
    _pausedTasks.clear();
    _taskOfId.clear();
    _taskOfIdentifier.clear();
    _resetCompleter();
    _notify();
  }

  @override
  Future<void> waitForAllTasksToComplete() {
    return _completer.future;
  }

  void executePendingTasks() {
    if (_runningTasks.isEmpty &&
        _pendingTasks.isEmpty &&
        _pausedTasks.isEmpty) {
      _complete();
      return;
    }

    while (!isPendingTasksEmpty && !isMaxConcurrencyReached) {
      final task = _pendingTasks.removeFirst();
      _executeTask(task);
    }
    _notify();
  }

  void _executeTask(TaskImpl task) async {
    _runningTasks[task.id] = task;
    _notify();

    executeTask(task).then((value) {
      if (value == ResultType.paused) {
        _pausedTasks[task.id] = task;
      }
    }).whenComplete(() {
      _runningTasks.remove(task.id);
      if (isPendingTasksEmpty) {
        if (_pausedTasks.isEmpty && _runningTasks.isEmpty) {
          _complete();
        }
        _notify();
      } else {
        executePendingTasks();
      }
    });
  }

  void _resetCompleter() {
    if (_completer.isCompleted) {
      _completer = Completer<void>();
    }
  }

  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void _notify() {
    _controller.add(this);
  }

  @override
  operator [](TaskId id) => _taskOfId[id];
}

mixin Scheduleable {
  Scheduler? _scheduler;

  Scheduler? get scheduler => _scheduler;

  void ensureInitialized(Scheduler value) {
    if (_scheduler == null) {
      _scheduler = value;
    } else {
      throw StateError('Task is already initialized');
    }
  }

  TaskStatus get status;

  FutureOr<ResultType> run();
}
