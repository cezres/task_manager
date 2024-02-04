part of '../../task_manager.dart';

class WorkerImpl extends Worker {
  WorkerImpl._() : super._() {
    _scheduler = SchedulerImpl(
      executeTask: _executeTask,
    );
  }

  factory WorkerImpl() => WorkerImpl._();

  late final Scheduler _scheduler;

  @override
  int get maxConcurrencies => _scheduler.maxConcurrencies;

  @override
  set maxConcurrencies(int value) => _scheduler.maxConcurrencies = value;

  @override
  Stream<WorkerImpl> get stream => _scheduler.stream.map((event) => this);

  @override
  List<TaskImpl> get runningTasks => _scheduler.runningTasks;

  @override
  List<TaskImpl> get pendingTasks => _scheduler.pendingTasks;

  @override
  List<TaskImpl> get pausedTasks => _scheduler.pausedTasks;

  @override
  int get length => _scheduler.length;

  @override
  Future<void> wait() => _scheduler.waitForAllTasksToComplete();

  @override
  void clear() => _scheduler.clear();

  @override
  void cancelTask(String identifier) {
    _scheduler.taskOfIdentifier(identifier)?.cancel();
  }

  @override
  Task<D, R> run<D, R>(Operation<D, R> operation, D initialData,
      {bool isPaused = false,
      TaskPriority priority = TaskPriority.normal,
      TaskIdentifier? identifier,
      TaskIdentifierStrategy strategy = TaskIdentifierStrategy.reuse}) {
    return _putIfAbsent(
      identifier: identifier,
      priority: priority,
      strategy: strategy,
      ifAbsent: () => TaskImpl(
        operation: operation,
        context: createContext(
          operation: operation,
          initialData: initialData,
          priority: priority,
          isPaused: isPaused,
        ),
        identifier: identifier,
      ),
    );
  }

  Task<D, R> _putIfAbsent<D, R>({
    required TaskIdentifier? identifier,
    required TaskPriority priority,
    required TaskIdentifierStrategy strategy,
    required TaskImpl<D, R> Function() ifAbsent,
  }) {
    if (identifier != null) {
      final task = _scheduler.taskOfIdentifier(identifier) as Task<D, R>;
      switch (strategy) {
        case TaskIdentifierStrategy.reuse:
          if (task.priority != priority) {
            task.setPriority(priority);
          }
          return task;
        case TaskIdentifierStrategy.cancel:
          task.cancel();
      }
    }
    final task = ifAbsent();
    add(task);
    return task;
  }

  bool add(TaskImpl task) {
    return _scheduler.add(task);
  }

  OperationContextImpl<D, R> createContext<D, R>({
    required Operation<D, R> operation,
    required D initialData,
    required TaskPriority priority,
    required bool isPaused,
  }) {
    final status = isPaused ? TaskStatus.paused : TaskStatus.pending;
    if (operation.compute) {
      return IsolateOperationContextImpl(
        initialData: initialData,
        priority: priority,
        status: status,
      );
    } else {
      return OperationContextImpl(
        initialData: initialData,
        priority: priority,
        status: status,
      );
    }
  }

  Future<ResultType> _executeTask(TaskImpl task) {
    return task.run();
  }
}
