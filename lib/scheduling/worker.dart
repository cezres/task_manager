part of '../task_manager.dart';

final Map<String, WorkerImpl> _workers = {};

class WorkerImpl extends Worker {
  WorkerImpl._(String identifier) : super._() {
    _scheduler = SchedulerImpl(
      executeTask: executeTask,
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

  // factory Worker.isolate() => IsolateWorker();

  @override
  TaskImpl<D, R, Operation<D, R>> addTask<D, R>(
    Operation<D, R> operation,
    D initialData, {
    bool isPaused = false,
  }) {
    final task = _createTask(
      operation,
      initialData,
      isPaused: isPaused,
      isHydrated: false,
    );
    _scheduler.add(task);
    return task;
  }

  void registerScheduledTask<D, R>(
    String name,
    Duration duration,
    Task<D, R> Function() builder, {
    TaskPriority priority = TaskPriority.normal,
  }) {
    throw UnimplementedError();
  }

  void registerRepeatedTask<D, R>(
    String name,
    Duration duration,
    Task<D, R> Function() builder, {
    TaskPriority priority = TaskPriority.normal,
  }) {
    throw UnimplementedError();
  }

  void addTasks<D, R>(
    Operation<D, R> operation,
    List<D> initialDatas,
  ) {
    for (var element in initialDatas) {
      addTask(operation, element);
    }
  }

  FutureOr<Result> executeTask(TaskImpl task) {
    return task.run();
  }

  @override
  Stream<Task> loadTasksWithStorage() {
    final controller = StreamController<Task>();

    Future.microtask(() async {
      final list =
          await StorageManager.loadTasks(_scheduler.identifier).toList();
      for (var element in list) {
        final entity = element.$2;
        if (_scheduler.contains(entity.id, entity.identifier) != null) {
          continue;
        }
        final operation = element.$1;
        try {
          final task = _createTaskWithEntity(entity, operation);
          if (_scheduler.add(task)) {
            controller.add(task);
          }
        } catch (e) {
          continue;
        }
      }
      controller.close();
    }).onError((error, stackTrace) {
      controller.addError(error ?? -1, stackTrace);
      controller.close();
    });

    return controller.stream;
  }

  TaskImpl<D, R, Operation<D, R>> _createTaskWithEntity<D, R>(
    TaskEntity entity,
    HydratedOperation<D, R> operation,
  ) {
    return _createTask(
      operation,
      operation.fromJson(entity.data),
      id: entity.id,
      identifier: entity.identifier,
      priority: entity.priority,
      isPaused: entity.status == TaskStatus.paused,
      isHydrated: true,
    );
  }

  TaskImpl<D, R, Operation<D, R>> _createTask<D, R>(
    Operation<D, R> operation,
    D initialData, {
    String? id,
    String? identifier,
    TaskPriority priority = TaskPriority.normal,
    required bool isPaused,
    required bool isHydrated,
  }) {
    final context = _createContext<D, R>(
      operation,
      initialData: initialData,
      id: id,
      identifier: identifier,
      priority: priority,
      isPaused: isPaused,
    );
    if (operation is HydratedOperation<D, R>) {
      return HydratedTaskImpl._(
        operation: operation,
        context: context,
        isHydrated: isHydrated,
      );
    } else {
      return TaskImpl._(
        operation: operation,
        context: context,
      );
    }
  }

  OperationContextImpl<D, R> _createContext<D, R>(
    Operation<D, R> operation, {
    required D initialData,
    required String? id,
    required String? identifier,
    required TaskPriority priority,
    required bool isPaused,
  }) {
    return operation._createContext(
      initialData: initialData,
      id: id,
      identifier: identifier,
      priority: priority,
      isPaused: isPaused,
    );
  }
}

abstract class _Operation<D, R> {
  const _Operation();

  OperationContextImpl<D, R> _createContext({
    required D initialData,
    required String? id,
    required String? identifier,
    required TaskPriority priority,
    required bool isPaused,
  }) {
    return OperationContextImpl<D, R>(
      initialData: initialData,
      id: id,
      identifier: identifier,
      priority: priority,
      status: isPaused ? TaskStatus.paused : TaskStatus.pending,
    );
  }

  IsolateOperationContextImpl<D, R> _createIsolateContext({
    required D initialData,
    required String? id,
    required String? identifier,
    required TaskPriority priority,
    required bool isPaused,
  }) {
    return IsolateOperationContextImpl<D, R>(
      initialData: initialData,
      id: id,
      identifier: identifier,
      priority: priority,
      status: isPaused ? TaskStatus.paused : TaskStatus.pending,
    );
  }
}
