part of '../task_manager.dart';

class IsolateWorker extends WorkerImpl {
  IsolateWorker() : super._('IsolateWorker');

  Task<D, R2> addIsolateTask<D, R1, R2>(
    Operation<D, R1> operation,
    D initialData, {
    bool isPaused = false,
    Operation<R1, R2>? mainIsolateOperation,
  }) {
    throw UnimplementedError();
  }

  @override
  OperationContextImpl<D, R> _createContext<D, R>(
    Operation<D, R> operation, {
    required D initialData,
    required String? id,
    required String? identifier,
    required TaskPriority priority,
    required bool isPaused,
  }) {
    return operation._createIsolateContext(
      initialData: initialData,
      id: id,
      identifier: identifier,
      priority: priority,
      isPaused: isPaused,
    );
  }

  @override
  FutureOr<Result> executeTask(TaskImpl task) {
    final context = task._context;
    if (context is! IsolateOperationContextImpl) {
      throw ArgumentError('Invalid task');
    }
    return compute(
      (message) {
        return message.run();
      },
      IsolateTaskImpl(
        operation: task.operation,
        context: context.wrapper(),
      ),
    );
  }
}
