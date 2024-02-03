part of '../../task_manager.dart';

final Map<String, WorkerImpl> _workers = {};

class WorkerImpl extends Worker {
  WorkerImpl._(String identifier) : super._() {
    _scheduler = SchedulerImpl(
      executeTask: _executeTask,
      identifier: identifier,
    );
  }

  factory WorkerImpl([String identifier = 'default']) {
    var worker = _workers[identifier];
    if (worker != null) {
      return worker;
    }
    worker = WorkerImpl._(identifier);
    _workers[identifier] = worker;
    return worker;
  }

  late final Scheduler _scheduler;

  String get identifier => _scheduler.identifier;

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
        context: operation.compute
            ? IsolateOperationContextImpl(
                initialData: initialData,
                priority: priority,
                status: isPaused ? TaskStatus.paused : TaskStatus.pending,
              )
            : OperationContextImpl(
                initialData: initialData,
                priority: priority,
                status: isPaused ? TaskStatus.paused : TaskStatus.pending,
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
    _scheduler.add(task);
    return task;
  }

  Future<ResultType> _executeTask(TaskImpl task) {
    return task.run();
  }
}
