part of '../task_manager.dart';

class HydratedTaskImpl<D, R, O extends HydratedOperation<D, R>>
    extends TaskImpl<D, R, O> {
  HydratedTaskImpl._({
    required O operation,
    required OperationContextImpl<D, R> context,
    required this.isHydrated,
  }) : super._(operation: operation, context: context) {
    stream.listen((event) {
      switch (event.status) {
        case TaskStatus.running:
        case TaskStatus.paused:
        case TaskStatus.pending:
          if (_scheduler != null) StorageManager.saveTask(this);
          break;
        case TaskStatus.canceled:
        case TaskStatus.completed:
        case TaskStatus.error:
          if (_scheduler != null) StorageManager.deleteTask(this);
          break;
        default:
      }
    });
  }

  final bool isHydrated;

  @override
  void ensureInitialized(Scheduler value) {
    super.ensureInitialized(value);

    if (!isHydrated) {
      StorageManager.saveTask(this);
    }
  }
}
