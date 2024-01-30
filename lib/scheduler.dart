part of 'task_manager.dart';

typedef TaskIdentifier = String;
typedef TaskId = String;

enum TaskIdentifierStrategy {
  reuse,
  cancelOtherTasks,
}

abstract class Schedulable {
  String get id;

  String? get identifier;

  TaskPriority get priority;

  void _changePriority(TaskPriority value);
}

// class Scheduler {
//   //
// }

// class Worker {
//   //
// }

abstract class TaskScheduler {
  int get maximumNumberOfConcurrencies;

  set maximumNumberOfConcurrencies(int value);

  List<Task> get runningTasks;
  List<Task> get pausedTasks;
  List<Task> get pendingTasks;

  Stream<TaskScheduler> get stream;

  void add(Task task);

  void pause(Task task);

  void resume(Task task);

  void cancel(Task task);

  void cancelAll();

  void changePriority(Task task, TaskPriority priority);

  Future<void> waitForAllTasksToComplete();

  T getReusedObject<T>(String key, Task task) {
    throw UnimplementedError();
  }
}

abstract class TaskSchedulerImpl extends TaskScheduler {
  final _PendingTaskQueue _pendingTasks = _PendingTaskQueue();
  final Map<TaskId, Task> _runningTasks = {};
  final Map<TaskId, Task> _pausedTasks = {};
  final _controller = StreamController<TaskScheduler>.broadcast();

  @override
  List<Task> get runningTasks => _runningTasks.values.toList();
  @override
  List<Task> get pausedTasks => _pausedTasks.values.toList();
  @override
  List<Task> get pendingTasks => _pendingTasks.toList();

  @override
  Stream<TaskScheduler> get stream => _controller.stream;

  Completer<void> _completer = Completer<void>();

  int _maximumNumberOfConcurrencies = 4;

  @override
  int get maximumNumberOfConcurrencies => _maximumNumberOfConcurrencies;

  @override
  set maximumNumberOfConcurrencies(int value) {
    if (value < 1) {
      throw ArgumentError('Invalid maximum number of concurrencies: $value');
    }
    if (value > _maximumNumberOfConcurrencies) {
      _maximumNumberOfConcurrencies = value;
      _processNextTask();
    } else {
      _maximumNumberOfConcurrencies = value;
      // Cancel redundant tasks, cancel tasks with the lowest priority that support cancellation first
    }
  }

  @override
  void add(Task task) {
    if (task._scheduler != null) {
      throw ArgumentError('Task already added to a manager ${task._scheduler}');
    }

    switch (task.status) {
      case TaskStatus.pending:
        // Reset completer
        if (_completer.isCompleted) {
          _completer = Completer<void>();
        }

        task._setScheduler(this);

        if (_runningTasks.length < maximumNumberOfConcurrencies) {
          // Current number of running tasks is less than the maximum number of concurrencies
          // Execute task directly
          _runningTasks[task.id] = task;
          _executeTask(task);
        } else {
          // Current number of running tasks is greater than or equal to the maximum number of concurrencies
          // Add task to pending queue
          _pendingTasks.add(task);
        }

        _notify();
        break;
      case TaskStatus.paused:
        task._scheduler = this;

        // Task already paused, add task to paused queue
        _pausedTasks[task.id] = task;

        _notify();
        break;
      default:
        throw ArgumentError('Invalid task status: ${task.status}');
    }
  }

  @override
  void cancel(Task task) {
    switch (task.status) {
      case TaskStatus.running:
        // Send cancel message to task
        // Let the task handle the cancel logic by itself
        task._changeStatus(null, TaskFlag.cancel);
        break;
      case TaskStatus.pending:
        // Remove task from pending queue
        _pendingTasks.remove(task);

        _notify();
      case TaskStatus.paused:
        // Remove task from paused queue
        _pausedTasks.remove(task.id);

        _notify();
      default:
    }
  }

  @override
  void cancelAll() {
    /// Cancel all pending and paused tasks
    final tasks = [..._pendingTasks.toList(), ..._pausedTasks.values];
    _pendingTasks.clear();
    _pausedTasks.clear();
    for (var element in tasks) {
      element._handlerResult(TaskResult.canceled());
    }

    /// Send cancel message to running tasks
    for (var element in _runningTasks.values) {
      element.cancel();
    }

    _notify();
  }

  @override
  void pause(Task task) {
    switch (task.status) {
      case TaskStatus.running:
        // Send pause message to task
        // Let the task handle the pause logic by itself
        task._changeStatus(null, TaskFlag.pause);
        break;
      case TaskStatus.pending:
        // Remove task from pending queue
        _pendingTasks.remove(task);
        // Add task to paused queue
        _pausedTasks[task.id] = task;
        // Update task status
        task._status = TaskStatus.paused;
        // Notify
        _notify();
        break;
      default:
    }
  }

  @override
  void resume(Task task) {
    if (task.status == TaskStatus.paused) {
      /// Remove task from paused queue
      _pausedTasks.remove(task.id);

      /// Update task status to pending
      task._changeStatus(TaskStatus.pending, TaskFlag.none);

      /// Add task to pending queue
      _pendingTasks.add(task);

      /// Try to handle next task
      if (!_processNextTask()) {
        _notify();
      }
    }
  }

  @override
  void changePriority(Task task, TaskPriority priority) {
    switch (task.status) {
      case TaskStatus.running:
      case TaskStatus.canceled:
      case TaskStatus.completed:
      case TaskStatus.error:
        break;
      case TaskStatus.pending:
        _pendingTasks.remove(task);
        task._changePriority(priority);
        _pendingTasks.add(task);
        break;
      case TaskStatus.paused:
        task._changePriority(priority);
        break;
    }
  }

  @override
  Future<void> waitForAllTasksToComplete() => _completer.future;

  bool _processNextTask() {
    if (_pendingTasks.isEmpty) {
      if (_runningTasks.isEmpty && _pausedTasks.isEmpty) {
        _completer.complete();
      }
      return false;
    }

    if (_runningTasks.length >= maximumNumberOfConcurrencies) {
      return false;
    }

    final task = _pendingTasks.nextWhere((task) => true);
    if (task != null) {
      _runningTasks[task.id] = task;

      _executeTask(task);

      _notify();

      return true;
    } else {
      return false;
    }
  }

  @protected
  void executeTask(Task task);

  @protected
  void handlerTaskResult(String id, TaskResult result) {
    debugPrint('[handlerTaskResult] - $id: $result');

    /// Remove task from running queue
    final task = _runningTasks.remove(id);
    if (task != null) {
      task._handlerResult(result);
      if (result.type == TaskResultType.paused) {
        // Add task to paused queue
        _pausedTasks[id] = task;
      }
    } else {
      debugPrint('[handlerTaskResult] - Task not found: $id');
    }

    /// Try to handle next task
    if (!_processNextTask()) {
      _notify();
    }
  }

  void _notify() {
    _controller.add(this);
  }

  void _executeTask(Task task) {
    task._changeStatus(TaskStatus.running, TaskFlag.none);
    executeTask(task);
  }
}

class _PendingTaskQueue {
  _PendingTaskQueue();

  final List<TaskPriority> priorities = [];

  final Map<TaskPriority, List<Task>> tasksOfPriority = {};

  operator [](TaskPriority priority) {
    return tasksOfPriority[priority] ?? [];
  }

  List<Task> toList() {
    final list = <Task>[];
    for (var priority in priorities) {
      list.addAll(tasksOfPriority[priority] ?? []);
    }
    return list;
  }

  bool get isEmpty => priorities.isEmpty;

  /// Add task
  /// [top] If true, add the task to the top of the queue
  void add(Task task, {bool top = false}) {
    final list = tasksOfPriority[task.priority];
    if (list != null) {
      if (top) {
        list.insert(0, task);
      } else {
        list.add(task);
      }
    } else {
      tasksOfPriority[task.priority] = [task];
      priorities.add(task.priority);
      priorities.sort();
    }
  }

  /// Remove task
  void remove(Task task) {
    final list = tasksOfPriority[task.priority];
    if (list != null) {
      list.removeWhere((element) => element.id == task.id);
      if (list.isEmpty) {
        tasksOfPriority.remove(task.priority);
        priorities.remove(task.priority);
      }
    }
  }

  void clear() {
    tasksOfPriority.clear();
    priorities.clear();
  }

  /// Remove the first task
  Task? removeFirst() {
    if (priorities.isEmpty) {
      return null;
    }

    final priority = priorities.first;
    final list = tasksOfPriority[priority];
    if (list != null) {
      final identifier = list.removeAt(0);
      if (list.isEmpty) {
        tasksOfPriority.remove(priority);
        priorities.remove(priority);
      }
      return identifier;
    } else {
      priorities.remove(priority);
    }

    return removeFirst();
  }

  Task? nextWhere(bool Function(Task task) test) {
    if (priorities.isEmpty) {
      return null;
    }

    for (var priorityIndex = 0;
        priorityIndex < priorities.length;
        priorityIndex++) {
      final priority = priorities[priorityIndex];
      final list = tasksOfPriority[priority];
      if (list == null) {
        continue;
      }
      for (var taskIndex = 0; taskIndex < list.length; taskIndex++) {
        final task = list[taskIndex];
        if (test(task)) {
          list.removeAt(taskIndex);
          if (list.isEmpty) {
            tasksOfPriority.remove(priority);
            priorities.removeAt(priorityIndex);
          }
          return task;
        }
      }
    }
    return null;
  }
}
