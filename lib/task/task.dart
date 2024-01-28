part of '../task_manager.dart';

abstract class _PrivateTask<Data, Result> {
  final String id = generateIncrementalId('task');

  TaskStatus _status = TaskStatus.pending;

  TaskFlag _flag = TaskFlag.none;
  TaskFlag get flag => _flag;

  TaskPriority _priority = TaskPriority.normal;

  final Completer<Result> _completer = Completer<Result>();

  TaskScheduler? _manager;

  final _controller = StreamController<Task<Data, Result>>.broadcast();

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is Task) {
      return other.id == id;
    }
    return super == other;
  }
}

abstract class Task<Data, Result> extends _PrivateTask<Data, Result> {
  Task(Data initialData, {this.identifier}) : data = initialData;

  final String? identifier;

  Data data;

  /// 任务状态
  TaskStatus get status => _status;

  /// 任务标记
  bool get shouldCancel => _flag == TaskFlag.cancel;
  bool get shouldPause => _flag == TaskFlag.pause;

  /// 任务优先级
  TaskPriority get priority => _priority;
  set priority(TaskPriority value) {
    // TODO: 向任务调度器发送任务优先级变更的消息，再有调度器决定是否变更优先级
    // 正在运行的任务优先级会直接变更但不会影响任务调度器的优先级，如果当前任务被暂停后恢复，那么优先级变更会影响任务调度器的优先级
    throw UnimplementedError();
  }

  Stream<Task<Data, Result>> get stream => _controller.stream;

  FutureOr<TaskResult<Data, Result>> run();

  void _setFlag(TaskFlag flag) {
    if (flag != _flag) {
      _flag = flag;
      _controller.add(this);
    }
  }

  @protected
  void emit(Data data) {
    this.data = data;
    _controller.add(this);
  }

  void cancel() {
    if (status == TaskStatus.running ||
        status == TaskStatus.pending ||
        status == TaskStatus.paused) {
      if (_manager != null) {
        _manager?.cancel(this);
      } else {
        _flag = TaskFlag.none;
        _status = TaskStatus.canceled;
      }
    }
  }

  void pause() {
    if (status == TaskStatus.running || status == TaskStatus.pending) {
      if (_manager != null) {
        _manager?.pause(this);
      } else {
        _flag = TaskFlag.none;
        _status = TaskStatus.paused;
      }
    }
  }

  void resume() {
    if (status == TaskStatus.paused) {
      if (_manager != null) {
        _manager?.resume(this);
      } else {
        _flag = TaskFlag.none;
        _status = TaskStatus.pending;
      }
    }
  }

  Future<Result> wait() => _completer.future;

  void _handlerResult(TaskResult<Data, Result> result) {
    if (_status != TaskStatus.running) {
      return;
    }

    _flag = TaskFlag.none;

    switch (result.type) {
      case TaskResultType.paused:
        _status = TaskStatus.paused;
        if (result.data != null) {
          data = result.data as Data;
        }
        break;
      case TaskResultType.canceled:
        _status = TaskStatus.canceled;
        if (result.data != null) {
          data = result.data as Data;
        }
        break;
      case TaskResultType.completed:
        _status = TaskStatus.completed;
        if (result.data != null) {
          data = result.data as Data;
        }
        _completer.complete(result.result);
        break;
      case TaskResultType.error:
        _status = TaskStatus.error;
        if (result.data != null) {
          data = result.data as Data;
        }
        _completer.completeError(result.error);
        break;
      default:
    }
    _controller.add(this);
  }
}

mixin SerializableTask {
  Map<String, dynamic> toJson();

  void fromJson(Map<String, dynamic> json);
}

mixin ReusedObjectTaskMixin {
  /// 在DEBUG模式下，任务调度器会检查复用对象的类型是否一致，如果不一致会抛出异常。
  @protected
  @visibleForTesting
  T buildReusedObject<T>(String key);

  T getReusedObject<T>(String key) {
    // T.runtimeType;
    // T.toString();
    if (1 is T) {
      //
    }
    throw UnimplementedError();
  }
}

enum TaskStatus {
  pending,
  running,
  paused,
  canceled,
  completed,
  error,
}

/// 任务标记
/// none: 无标记
/// cancel: 取消
/// pause: 暂停
enum TaskFlag {
  none,
  cancel,
  pause,
}
