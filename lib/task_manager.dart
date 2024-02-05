library task_manager;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:task_manager/src/utils/generate_incremental_id.dart';
import 'package:task_manager/src/utils/priority_queue.dart';

part 'src/task/task_impl.dart';
part 'src/task/result.dart';

part 'src/operation/operation_context_impl.dart';
part 'src/operation/isolate_operation_context_impl.dart';

part 'src/scheduling/scheduler.dart';
part 'src/scheduling/worker.dart';
part 'src/scheduling/hydrated_worker.dart';

part 'src/storage/storage.dart';

abstract class OperationContext<D, R> {
  D get data;

  bool get shouldCancel;

  bool get shouldPause;

  void emit(D data);
}

abstract class Operation<D, R> {
  const Operation();

  String get name => runtimeType.toString();

  /// If [compute] is true, the operation will run in isolate
  bool get compute => false;

  FutureOr<Result<D, R>> run(OperationContext<D, R> context);
}

abstract class Task<D, R> {
  String get name => operation.name;

  Operation<D, R> get operation;

  String get id;

  String? get identifier;

  TaskPriority get priority;

  TaskStatus get status;

  D get data;

  bool get shouldCancel;

  bool get shouldPause;

  Stream<Task<D, R>> get stream;

  Future<R> wait();

  void cancel();

  void pause();

  void resume();

  void setPriority(TaskPriority priority);
}

abstract class Worker {
  factory Worker() = WorkerImpl;

  int get maxConcurrencies;
  set maxConcurrencies(int value);

  Stream<Worker> get stream;

  int get length;

  List<Task> get runningTasks;
  List<Task> get pendingTasks;
  List<Task> get pausedTasks;

  Task<D, R> run<D, R>(
    Operation<D, R> operation,
    D initialData, {
    bool isPaused = false,
    TaskPriority priority = TaskPriority.normal,
    TaskIdentifier? identifier,
    TaskIdentifierStrategy strategy = TaskIdentifierStrategy.reuse,
  });

  void registerRepeatedTask<D, R>(
    Operation<D, R> operation,
    D initialData, {
    required String name,
    required Duration timeInterval,
    TaskPriority priority = TaskPriority.normal,
    Duration Function(
      R result,
      int runCount,
      int runTime,
      Duration previousTimeInterval,
    )? nextTimeInterval,
    bool Function(R? result, dynamic error, int runCount, int runTime)?
        terminate,
  });

  void registerScheduledTask<D, R>(
    String name,
    Duration duration,
    Task<D, R> Function() builder, {
    TaskPriority priority = TaskPriority.normal,
  });

  Future<void> wait();

  void clear();

  void cancelTask(String identifier);
}

abstract class HydratedOperation<D, R> extends Operation<D, R> {
  const HydratedOperation();

  D fromJson(dynamic json);
  dynamic toJson(D data);
}

abstract class HydratedWorker implements Worker {
  factory HydratedWorker({
    required Storage storage,
    required String identifier,
  }) = HydratedWorkerImpl;

  @override
  Task<D, R> run<D, R>(
    covariant HydratedOperation<D, R> operation,
    D initialData, {
    bool isPaused = false,
    TaskPriority priority = TaskPriority.normal,
    TaskIdentifier? identifier,
    TaskIdentifierStrategy strategy = TaskIdentifierStrategy.reuse,
  });

  void register<D, R>(HydratedOperation<D, R> Function() create);

  Stream<Task> loadTasks();
}

enum TaskPriority {
  veryLow,
  low,
  normal,
  high,
  veryHigh,
}
