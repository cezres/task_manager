part of '../../task_manager.dart';

typedef TaskIdentifier = String;
typedef TaskId = String;
typedef SchedulerIdentifier = String;

enum TaskIdentifierStrategy {
  reuse,
  cancel,
}

abstract class Scheduler {
  SchedulerIdentifier get identifier;

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

  void putIfAbsent(
      TaskId id, TaskIdentifier? identifier, TaskImpl Function() ifAbsent);

  bool add(TaskImpl task);

  // void addAll(Iterable<E> schedulables);

  void pause(TaskImpl task);

  void resume(TaskImpl task);

  void cancel(TaskImpl task);

  void setPriority(TaskImpl task, TaskPriority newPriority);

  Future<void> waitForAllTasksToComplete();

  void clear();

  // void cancelWithIdentifier(String identifier);

  operator [](TaskId id);
}

class SchedulerImpl extends Scheduler {
  final Map<TaskId, TaskImpl> _runningTasks = {};
  final PriorityQueue<TaskImpl> _pendingTasks = PriorityQueueImpl<TaskImpl>();
  final Map<TaskId, TaskImpl> _pausedTasks = {};

  final Map<TaskId, TaskImpl> _taskOfId = {};
  final Map<TaskIdentifier, TaskImpl> _taskOfIdentifier = {};

  SchedulerImpl({
    required this.executeTask,
    required this.identifier,
  });

  @override
  final String identifier;

  final FutureOr<Result> Function(TaskImpl task) executeTask;

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
  void putIfAbsent(TaskId id, TaskIdentifier? identifier,
      TaskImpl<dynamic, dynamic, Operation> Function() ifAbsent) {
    if (contains(id, identifier) == null) {
      add(ifAbsent());
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
      _updateAndNotify(() {
        _pendingTasks.remove(task);
        _pausedTasks[task.id] = task;
        task.onPaused();
      });
    }
  }

  @override
  void resume(TaskImpl task) {
    if (task.status == TaskStatus.paused) {
      _updateAndNotify(() {
        _pausedTasks.remove(task.id);
        _pendingTasks.add(task);
        task.onRunning();
        _resetCompleter();
        executePendingTasks();
      });
    }
  }

  @override
  void cancel(TaskImpl task) {
    _updateAndNotify(() {
      if (task.status == TaskStatus.pending) {
        _pendingTasks.remove(task);
        task.onCanceled();
      } else if (task.status == TaskStatus.paused) {
        _pausedTasks.remove(task.id);
        task.onCanceled();
      }
    });
  }

  @override
  void setPriority(TaskImpl task, TaskPriority newPriority) {
    if (task.status == TaskStatus.running || task.status == TaskStatus.paused) {
      task._change(priority: newPriority);
    } else if (task.status == TaskStatus.pending) {
      _pendingTasks.remove(task);
      task._change(priority: newPriority);
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
    _updateAndNotify(() {
      while (!isPendingTasksEmpty && !isMaxConcurrencyReached) {
        final task = _pendingTasks.removeFirst();
        _executeTask(task);
      }
    });

    if (_runningTasks.isEmpty &&
        _pendingTasks.isEmpty &&
        _pausedTasks.isEmpty) {
      _complete();
    }
  }

  void _executeTask(TaskImpl task) async {
    _updateAndNotify(() {
      _runningTasks[task.id] = task;
      task.onRunning();
    });

    Future.microtask(() => executeTask(task)).then((value) {
      _updateAndNotify(() {
        _runningTasks.remove(task.id);
        task.onCompleted(value);

        if (value.type == ResultType.paused) {
          _pausedTasks[task.id] = task;
        }

        if (isPendingTasksEmpty) {
          if (_pausedTasks.isEmpty && _runningTasks.isEmpty) {
            _complete();
          }
        } else {
          executePendingTasks();
        }
      });
    }).onError((error, stackTrace) {
      task.onError(error);
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

  String? _changeIdentifier;

  void _updateAndNotify(void Function() callback) {
    if (_changeIdentifier != null) {
      callback();
    } else {
      _changeIdentifier = generateIncrementalId('scheduler-change');

      final runningTasksCount = _runningTasks.length;
      final pendingTasksCount = _pendingTasks.length;
      final pausedTasksCount = _pausedTasks.length;

      try {
        callback();
        if (runningTasksCount != _runningTasks.length ||
            pendingTasksCount != _pendingTasks.length ||
            pausedTasksCount != _pausedTasks.length) {
          _controller.add(this);
        }

        _changeIdentifier = null;
      } catch (e) {
        debugPrint('Error: $e');

        if (runningTasksCount != _runningTasks.length ||
            pendingTasksCount != _pendingTasks.length ||
            pausedTasksCount != _pausedTasks.length) {
          _controller.add(this);
        }

        _changeIdentifier = null;
        rethrow;
      }
    }
  }

  void _notify() {
    _controller.add(this);
  }

  @override
  operator [](TaskId id) => _taskOfId[id];
}
