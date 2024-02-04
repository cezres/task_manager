part of '../../task_manager.dart';

class HydratedWorkerImpl extends WorkerImpl implements HydratedWorker {
  HydratedWorkerImpl({
    required this.storage,
    required this.identifier,
  }) : super._();

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
