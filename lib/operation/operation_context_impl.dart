part of '../task_manager.dart';

class OperationContextImpl<D, R> extends OperationContext<D, R> {
  OperationContextImpl({
    required D initialData,
    String? id,
    this.identifier,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
  })  : data = initialData,
        id = id ?? generateIncrementalId('task');

  TaskFlag _flag = TaskFlag.none;
  final _controller = StreamController<OperationContextImpl<D, R>>.broadcast();
  Completer<R>? _completer;
  R? _result;
  dynamic _error;

  @override
  final String id;

  @override
  final String? identifier;

  @override
  TaskPriority priority;

  @override
  TaskStatus status;

  @override
  D data;

  @override
  bool get shouldCancel => _flag == TaskFlag.cancel;

  @override
  bool get shouldPause => _flag == TaskFlag.pause;

  Stream<OperationContextImpl<D, R>> get stream => _controller.stream;

  Future<R> wait() {
    if (_completer != null) {
      return _completer!.future;
    }
    switch (status) {
      case TaskStatus.canceled:
        throw CanceledException();
      case TaskStatus.error:
        return Future.error(_error);
      case TaskStatus.completed:
        return Future.value(_result);
      default:
        _completer ??= Completer<R>();
        return _completer!.future;
    }
  }

  @override
  void emit(D data) {
    this.data = data;
    _controller.add(this);
  }

  void setup({
    D? data,
    TaskStatus? status,
    TaskFlag? flag,
    TaskPriority? priority,
  }) {
    if (data != null) {
      this.data = data;
    }
    if (status != null) {
      this.status = status;
    }
    if (flag != null) {
      _flag = flag;
    }
    if (priority != null) {
      this.priority = priority;
    }
    _controller.add(this);
  }

  void handlerResult(Result result) {
    switch (result.type) {
      case ResultType.paused:
        _flag = TaskFlag.none;
        status = TaskStatus.paused;
        if (result.data is D) {
          data = result.data as D;
        }
        _controller.add(this);
        break;
      case ResultType.canceled:
        _flag = TaskFlag.none;
        status = TaskStatus.canceled;
        if (result.data is D) {
          data = result.data as D;
        }

        /// Completer
        if (_completer != null) {
          _completer!.completeError(CanceledException());
        }

        /// Stream
        _controller.add(this);
        _controller.close();
        break;
      case ResultType.completed:
        status = TaskStatus.completed;
        if (result.data is D) {
          data = result.data as D;
        }

        /// Completer
        if (_completer != null) {
          _completer!.complete(result.result);
        } else {
          _result = result.result;
        }

        /// Stream
        _controller.add(this);
        _controller.close();
        break;
      case ResultType.error:
        status = TaskStatus.error;
        if (result.data is D) {
          data = result.data as D;
        }

        /// Completer
        if (_completer != null) {
          _completer!.completeError(result.error);
        } else {
          _error = result.error;
        }

        /// Stream
        _controller.add(this);
        _controller.close();
        break;
    }
  }
}
