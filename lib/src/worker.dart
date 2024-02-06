part of '../task_manager.dart';

class WorkerImpl implements Worker {
  WorkerImpl() {
    _scheduler = SchedulerImpl(
      executeTask: _executeTask,
    );
  }

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

  @override
  void registerRepeatedTask<D, R>(Operation<D, R> operation, D initialData,
      {required String name,
      required Duration timeInterval,
      TaskPriority priority = TaskPriority.normal,
      Duration Function(R result, int runCount, int runTime,
              Duration previousTimeInterval)?
          nextTimeInterval,
      bool Function(R? result, dynamic error, int runCount, int runTime)?
          terminate}) {
    // TODO: implement registerRepeatedTask
    throw UnimplementedError();
  }

  @override
  void registerScheduledTask<D, R>(
      String name, Duration duration, Task<D, R> Function() builder,
      {TaskPriority priority = TaskPriority.normal}) {
    // TODO: implement registerScheduledTask
    throw UnimplementedError();
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

class HydratedWorkerImpl extends WorkerImpl implements HydratedWorker {
  HydratedWorkerImpl({
    required this.storage,
    required this.identifier,
  }) : super();

  final Storage storage;
  final String identifier;

  final Map<String, HydratedTaskBuilder> _builders = {};
  // final Map<String, List<TaskEntity>> _entities = {};

  @override
  Task<D, R> run<D, R>(
      covariant HydratedOperation<D, R> operation, D initialData,
      {bool isPaused = false,
      TaskPriority priority = TaskPriority.normal,
      TaskIdentifier? identifier,
      TaskIdentifierStrategy strategy = TaskIdentifierStrategy.reuse}) {
    if (!_builders.containsKey(operation.runtimeType.toString())) {
      throw ArgumentError('Operation not registered');
    }
    final task = super.run(
      operation,
      initialData,
      isPaused: isPaused,
      priority: priority,
      identifier: identifier,
      strategy: strategy,
    );

    /// Write the task to the storage
    _writeTask(task);
    return task;
  }

  @override
  bool add(TaskImpl task) {
    if (super.add(task)) {
      /// Listen to the task stream and write the task to the storage
      task.stream.listen((event) {
        switch (event.status) {
          case TaskStatus.running:
          case TaskStatus.pending:
          case TaskStatus.paused:
            _writeTask(event);
            break;
          case TaskStatus.canceled:
          case TaskStatus.completed:
          case TaskStatus.error:
            _deleteTask(event.id);
            break;
          default:
        }
      });
      return true;
    } else {
      return false;
    }
  }

  @override
  void register<D, R>(HydratedOperation<D, R> Function() create) {
    final operation = create();
    final builder = HydratedTaskBuilder<D, R>(create);
    _builders[operation.runtimeType.toString()] = builder;
  }

  @override
  Stream<Task> loadTasks() {
    final controller = StreamController<Task>();

    Future.microtask(() async {
      await for (var entity in storage.readAll(identifier)) {
        final builder = _builders[entity.operation];
        if (builder == null) {
          continue;
        }
        try {
          final task = builder.build(entity);
          if (add(task)) {
            controller.add(task);
          }
        } catch (e) {
          _deleteTask(entity.id);
        }
      }
    }).whenComplete(() {
      controller.close();
    });

    return controller.stream;
  }

  void _writeTask(Task task) {
    final operation = task.operation;
    if (operation is! HydratedOperation) {
      return;
    }
    storage.write(
      TaskEntity(
        operation: operation.runtimeType.toString(),
        id: task.id,
        identifier: task.identifier,
        isPaused: task.status == TaskStatus.paused,
        priority: task.priority,
        data: operation.toJson(task.data),
      ),
      identifier,
    );
  }

  void _deleteTask(TaskId id) {
    storage.delete(id, identifier);
  }
}

typedef HydratedOperationCreator<T extends HydratedOperation> = T Function();

class HydratedTaskBuilder<D, R> {
  const HydratedTaskBuilder(this.create);

  final HydratedOperationCreator<HydratedOperation<D, R>> create;

  TaskImpl<D, R> build(TaskEntity entity) {
    final operation = create();
    final initialData = operation.fromJson(entity.data);
    final status = entity.isPaused ? TaskStatus.paused : TaskStatus.pending;
    final context = operation.compute
        ? IsolateOperationContextImpl<D, R>(
            initialData: initialData,
            priority: entity.priority,
            status: status,
          )
        : OperationContextImpl<D, R>(
            initialData: initialData,
            priority: entity.priority,
            status: status,
          );
    return TaskImpl<D, R>(
      operation: operation,
      context: context,
      id: entity.id,
      identifier: entity.identifier,
    );
  }
}
