part of '../../task_manager.dart';

typedef OperationCreater<T extends HydratedOperation> = T Function();

class StorageManager {
  static Storage? _storage;

  static void registerStorage(Storage storage) {
    _storage = storage;
  }

  static final Map<String, OperationCreater> _registeredOperations = {};

  static void registerOperation<T extends HydratedOperation>(
      OperationCreater<T> create) {
    _registeredOperations[T.toString()] = create;
  }

  static void listenTask(TaskImpl task) {
    final operation = task.operation;
    if (!_registeredOperations.containsKey(operation.runtimeType.toString())) {
      return;
    }
    // task.stream.listen((event) {
    //   switch (event.status) {
    //     case TaskStatus.running:
    //     case TaskStatus.paused:
    //     case TaskStatus.pending:
    //       if (task.scheduler != null) {
    //         saveTask(task, task.scheduler!.identifier);
    //       }
    //       break;
    //     case TaskStatus.canceled:
    //     case TaskStatus.completed:
    //     case TaskStatus.error:
    //       if (task.scheduler != null) {
    //         deleteTask(task.id, task.scheduler!.identifier);
    //       }
    //       break;
    //     default:
    //   }
    // });
  }

  static Future<void> saveTask(
    TaskEntity entity,
    SchedulerIdentifier identifier,
  ) async {
    if (_storage == null) {
      return;
    }
    final type = entity.operation;
    if (!_registeredOperations.containsKey(type)) {
      return;
    }
    await _storage!.write(entity, identifier);
  }

  static void deleteTask(TaskId id, SchedulerIdentifier identifier) {
    _storage!.delete(id, identifier);
  }

  static Stream<(HydratedOperation, TaskEntity)> loadTaskEntity(
      SchedulerIdentifier schedulerIdentifier) {
    if (_storage == null) {
      return const Stream.empty();
    }
    return _storage!
        .readAll(schedulerIdentifier)
        .map((event) {
          final creater = _registeredOperations[event.operation];
          if (creater == null) {
            _storage!.delete(event.id, schedulerIdentifier);
            return null;
          }
          try {
            return (creater(), event);
          } catch (e) {
            debugPrint('Error when loading task: ${event.id} - $e');
            _storage!.delete(event.id, schedulerIdentifier);
          }
        })
        .skipWhile((element) => element == null)
        .cast<(HydratedOperation, TaskEntity)>();
  }

  static FutureOr<void> clear(SchedulerIdentifier schedulerIdentifier) {
    if (_storage == null) {
      return Future.value();
    }
    return _storage!.clear(schedulerIdentifier);
  }
}
