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

  static Future<void> saveTask(HydratedTaskImpl task) async {
    if (_storage == null) {
      return;
    }
    if (task.status == TaskStatus.canceled ||
        task.status == TaskStatus.completed ||
        task.status == TaskStatus.error) {
      return;
    }
    final scheduler = task._scheduler;
    if (scheduler == null) {
      return;
    }
    final type = task.operation.runtimeType.toString();
    if (!_registeredOperations.containsKey(type)) {
      return;
    }
    await _storage!.write(
      TaskEntity(
        type: type,
        id: task.id,
        identifier: task.identifier,
        status: task.status == TaskStatus.paused
            ? TaskStatus.paused
            : TaskStatus.pending,
        priority: task.priority,
        data: task.operation.toJson(task.data),
      ),
      scheduler.identifier,
    );
  }

  static void deleteTask(HydratedTaskImpl task) {
    if (_storage == null) {
      return;
    }
    final scheduler = task._scheduler;
    if (scheduler == null) {
      return;
    }
    _storage!.delete(task.id, scheduler.identifier);
  }

  static Stream<(HydratedOperation, TaskEntity)> loadTasks(
      SchedulerIdentifier schedulerIdentifier) {
    if (_storage == null) {
      return const Stream.empty();
    }
    return _storage!
        .readAll(schedulerIdentifier)
        .map((event) {
          final creater = _registeredOperations[event.type];
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
