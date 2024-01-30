part of '../task_manager.dart';

// abstract class Execution<Data, R> {
//   TaskFlag _flag = TaskFlag.none;

//   bool get shouldCancel => _flag == TaskFlag.cancel;

//   bool get shouldPause => _flag == TaskFlag.pause;

//   Data get data;

//   void emit(Data data);

//   FutureOr<R> run();
// }

abstract class Task<D, R> {
  Task(D initialData, {String? identifier})
      : _data = initialData,
        _identifier = identifier;

  String get id => _id;

  String? get identifier => _identifier;

  TaskPriority get priority => _priority;

  bool get shouldCancel => _flag == TaskFlag.cancel;

  bool get shouldPause => _flag == TaskFlag.pause;

  TaskStatus get status => _status;

  D get data => _data;

  Stream<Task<D, R>> get stream => _controller.stream;

  FutureOr<TaskResult<D, R>> run();

  @protected
  void emit(D data) {
    _data = data;
    _controller.add(this);
    _storageTaskStatus();
  }

  void cancel() {
    if (status == TaskStatus.running ||
        status == TaskStatus.pending ||
        status == TaskStatus.paused) {
      if (_scheduler != null) {
        _scheduler?.cancel(this);
      } else {
        _changeStatus(TaskStatus.canceled, TaskFlag.none);
      }
    }
  }

  void pause() {
    if (status == TaskStatus.running || status == TaskStatus.pending) {
      if (_scheduler != null) {
        _scheduler?.pause(this);
      } else {
        _changeStatus(TaskStatus.paused, TaskFlag.none);
      }
    }
  }

  void resume() {
    if (status == TaskStatus.paused) {
      if (_scheduler != null) {
        _scheduler?.resume(this);
      } else {
        _changeStatus(TaskStatus.pending, TaskFlag.none);
      }
    }
  }

  void changePriority(TaskPriority priority) {
    if (_scheduler != null) {
      _scheduler?.changePriority(this, priority);
    } else {
      _changePriority(priority);
    }
  }

  Future<R> wait() => _completer.future;

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is Task) {
      return other.id == id;
    }
    return super == other;
  }

  @mustCallSuper
  void decodeMetadata(dynamic json) {
    _identifier = json['identifier'];
    switch (TaskStatus.values[json['status']]) {
      case TaskStatus.running:
        _status = TaskStatus.pending;
        break;
      default:
        _status = TaskStatus.paused;
    }
    _priority = TaskPriority.values[json['priority']];
  }

  @mustCallSuper
  Map<String, dynamic> encodeMetadata() {
    return {
      'identifier': _identifier,
      'status': _status.index,
      'priority': _priority.index,
    };
  }

  /// Private
  String _id = generateIncrementalId('task');
  String? _identifier;
  TaskPriority _priority = TaskPriority.normal;
  TaskStatus _status = TaskStatus.pending;
  TaskFlag _flag = TaskFlag.none;
  D _data;
  TaskScheduler? _scheduler;
  final _completer = Completer<R>();
  final _controller = StreamController<Task<D, R>>.broadcast();
}

extension TaskExtension<Data, Result> on Task<Data, Result> {
  void _setScheduler(TaskScheduler value) {
    if (_scheduler != value) {
      _scheduler = value;
      StorageManager._saveTask(this);
    }
  }

  void _changePriority(TaskPriority priority) {
    _priority = priority;
    _controller.add(this);
  }

  void _changeStatus([TaskStatus? status, TaskFlag? flag]) {
    if (status != null) {
      _status = status;
    }
    if (flag != null) {
      _flag = flag;
    }
    _controller.add(this);
  }

  void _handlerResult(TaskResult<Data, Result> result) {
    if (_completer.isCompleted) {
      return;
    }
    switch (result.type) {
      case TaskResultType.paused:
        _flag = TaskFlag.none;
        _status = TaskStatus.paused;
        if (result.data != null) {
          _data = result.data as Data;
        }
        break;
      case TaskResultType.canceled:
        _flag = TaskFlag.none;
        _status = TaskStatus.canceled;
        if (result.data != null) {
          _data = result.data as Data;
        }
        break;
      case TaskResultType.completed:
        _status = TaskStatus.completed;
        if (result.data != null) {
          _data = result.data as Data;
        }
        _completer.complete(result.result);
        break;
      case TaskResultType.error:
        _status = TaskStatus.error;
        if (result.data != null) {
          _data = result.data as Data;
        }
        _completer.completeError(result.error);
        break;
      default:
    }
    _storageTaskStatus();
    _controller.add(this);
  }

  void _storageTaskStatus() {
    switch (_status) {
      case TaskStatus.canceled:
      case TaskStatus.completed:
      case TaskStatus.error:
        StorageManager._deleteTask(this);
        break;
      case TaskStatus.paused:
      case TaskStatus.pending:
      case TaskStatus.running:
        StorageManager._saveTask(this);
        break;
    }
  }
}

extension TaskReusedObjects on Task {
  T getReusedObject<T>(String key) {
    if (_scheduler != null) {
      return _scheduler!.getReusedObject(key, this);
    }
    throw UnimplementedError();
  }

  T buildReusedObject<T>(String key) {
    throw UnimplementedError();
  }
}

// mixin StorableMixin<Data> {
//   String get id;

//   void decodeMetadata(dynamic json);

//   dynamic encodeMetadata();

//   Data fromJson(Map<String, dynamic> json);
//   Map<String, dynamic> toJson(Data data);
// }

// mixin SerializableTask {
//   String get id;

//   Map<String, dynamic> toJson();

//   void fromJson(Map<String, dynamic> json);
// }

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

enum TaskFlag {
  none,
  // Should cancel, handled by the task itself
  cancel,
  // Should pause, handled by the task itself
  pause,
}
