library task_manager;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:task_manager/src/task/task_priority.dart';
import 'package:task_manager/src/utils/generate_incremental_id.dart';
import 'package:task_manager/src/utils/priority_queue.dart';

part 'src/task/task_impl.dart';
part 'src/task/hydrated_task_impl.dart';
part 'src/task/result.dart';

part 'src/operation/operation_context_impl.dart';
part 'src/operation/isolate_operation_context_impl.dart';

part 'src/scheduling/scheduler.dart';
part 'src/scheduling/worker.dart';
part 'src/scheduling/worker_isolate.dart';

part 'src/storage/storage.dart';
part 'src/storage/storage_manager.dart';

abstract class OperationContext<D, R> {
  String get id;

  String? get identifier;

  TaskPriority get priority;

  TaskStatus get status;

  D get data;

  bool get shouldCancel;

  bool get shouldPause;

  void emit(D data);
}

abstract class Operation<D, R> extends _Operation<D, R> {
  const Operation();

  String get name => runtimeType.toString();

  FutureOr<Result<D, R>> run(OperationContext<D, R> context);
}

mixin HydratedOperationMixin<D, R> {
  D fromJson(dynamic json);
  dynamic toJson(D data);
}

abstract class HydratedOperation<D, R> extends Operation<D, R>
    with HydratedOperationMixin<D, R> {
  const HydratedOperation();
}

abstract class Task<D, R> {
  String get name;

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

  void changePriority(TaskPriority priority);
}

abstract class Worker {
  Worker._();
  factory Worker() => WorkerImpl();

  int get maxConcurrencies;
  set maxConcurrencies(int value);

  Stream<Worker> get stream;

  int get length;

  List<Task> get runningTasks;
  List<Task> get pendingTasks;
  List<Task> get pausedTasks;

  Task<D, R> addTask<D, R>(Operation<D, R> operation, D initialData,
      {bool isPaused = false});

  Future<void> wait();

  void clear();

  Stream<Task> loadTasksWithStorage();
}
