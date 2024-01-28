library task_manager;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:task_manager/task/task_priority.dart';
import 'package:task_manager/task/task_result.dart';
import 'package:task_manager/utils/generate_incremental_id.dart';

part 'task_scheduler.dart';
part 'task/task.dart';

abstract class TaskManager extends TaskSchedulerImpl {
  TaskManager({this.identifier = 'default'}) {
    // SchedulerBinding.instance!.addPostFrameCallback((timeStamp) {
    //   _executeWaitingTasks();
    // });
  }

  final String identifier;

  void registerSerializableTask<S, R>(
      String name, Task<S, R> Function(S state) builder);

  void register<D, R, T extends Task<D, R>>({
    String? name,
    required T Function(D data) builder,
  }) {
    T.toString();
  }

  Task<S, R> buildSerializableTask<S, R>(String name, S initialState);

  /// 注册定时任务, 任务调度器会在指定的时间后执行任务
  void registerScheduledTask<S, R>(
    String name,
    Duration duration,
    Task<S, R> Function(S state) builder,
  ) {
    // registerSerializableTask(
    //   name,
    //   (state) => ScheduledTask<S, R>(state, duration, builder),
    // );
  }

  /// 注册重复任务, 任务调度器会在指定的时间间隔后执行任务
  void registerRepeatedTask<S, R>(
    String name,
    Duration duration,
    Task<S, R> Function(S state) builder,
  ) {
    // registerSerializableTask(
    //   name,
    //   (state) => RepeatedTask<S, R>(state, duration, builder),
    // );
  }

  @override
  String toString() {
    return 'TaskManager($identifier)';
  }
}

typedef TaskBuilder<S, R> = Task<S, R> Function(S state);

class TaskManagerImpl extends TaskManager {
  final Map<String, TaskBuilder> _builders = {};

  @override
  void registerSerializableTask<S, R>(String name, TaskBuilder<S, R> builder) {
    _builders[name] = builder as TaskBuilder;
  }

  @override
  Task<S, R> buildSerializableTask<S, R>(String name, S initialState) {
    final builder = _builders[name];
    if (builder == null) {
      throw ArgumentError('No task builder found for $name');
    }
    return builder(initialState) as Task<S, R>;
  }

  @override
  @protected
  void executeTask(Task task) {
    // PaintingBinding.instance.scheduleTask(
    //   () {
    //     return task.run();
    //   },
    //   Priority.idle,
    // ).then((value) {
    //   handlerTaskResult(task.id, value);
    // }).onError((error, stackTrace) {
    //   handlerTaskResult(task.id, TaskResult.error(error));
    // });

    task._status = TaskStatus.running;
    task._setFlag(TaskFlag.none);

    Future.microtask(() => task.run()).then((value) {
      handlerTaskResult(task.id, value);
    }).onError((error, stackTrace) {
      handlerTaskResult(task.id, TaskResult.error(error));
    });
  }
}
