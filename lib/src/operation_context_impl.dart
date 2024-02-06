part of '../task_manager.dart';

class OperationContextImpl<D, R> extends OperationContext<D, R> {
  OperationContextImpl({
    required D initialData,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
  }) : data = initialData;

  TaskFlag _flag = TaskFlag.none;
  final _controller = StreamController<OperationContextImpl<D, R>>.broadcast();
  Completer<R>? _completer;
  R? _result;
  dynamic _error;

  TaskPriority priority;

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

  void cancel() {
    switch (status) {
      case TaskStatus.running:
        _flag = TaskFlag.cancel;
        _controller.add(this);
        break;
      case TaskStatus.pending:
      case TaskStatus.paused:
        _handlerResult(Result.canceled());
        break;
      default:
    }
  }

  void pause() {
    switch (status) {
      case TaskStatus.running:
        _flag = TaskFlag.pause;
        _controller.add(this);
        break;
      case TaskStatus.pending:
        status = TaskStatus.paused;
        _controller.add(this);
        break;
      default:
    }
  }

  void resume() {
    switch (status) {
      case TaskStatus.paused:
        status = TaskStatus.pending;
        _controller.add(this);
        break;
      default:
    }
  }

  void setPriority(TaskPriority priority) {
    this.priority = priority;
    _controller.add(this);
  }

  Future<ResultType> run(Operation<D, R> operation) async {
    status = TaskStatus.running;
    _controller.add(this);

    try {
      final result = await operation.run(this);
      _handlerResult(result);
      return result.type;
    } catch (e) {
      _handlerResult(Result<D, R>.error(e));
      return ResultType.error;
    }
  }

  void _handlerResult(Result result) {
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

class IsolateOperationContextImpl<D, R> extends OperationContextImpl<D, R> {
  IsolateOperationContextImpl({
    required super.initialData,
    super.priority,
    super.status,
  });

  @override
  void pause() {
    super.pause();
    _isolateCallback?.emit(const _PauseTaskAction());
  }

  @override
  void cancel() {
    super.cancel();
    _isolateCallback?.emit(const _CancelTaskAction());
  }

  @override
  Future<ResultType> run(Operation<D, R> operation) async {
    status = TaskStatus.running;
    _controller.add(this);

    try {
      final callback = ReusableIsolate.run(
        (message, receive, emit) {
          final operation = message[0] as Operation;
          final context = message[1] as IsolateOperationContextImplWrapper;
          context.ensureInitialized(receive, emit);
          return operation.run(context);
        },
        [operation, wrapper()],
      );
      callback.receive.listen((event) {
        emit(_tryFromTransferableTypedData(event));
      });

      _isolateCallback = callback;
      final result = await callback.wait();
      _isolateCallback = null;
      _handlerResult(result.tryFromTransferableTypedData());
      return result.type;
    } catch (e) {
      _isolateCallback = null;
      _handlerResult(Result.error(e));
      return ResultType.error;
    }
  }

  IsolateCallback? _isolateCallback;

  IsolateOperationContextImplWrapper<D, R> wrapper() {
    return IsolateOperationContextImplWrapper<D, R>(initialData: data);
  }
}

class IsolateOperationContextImplWrapper<D, R> extends OperationContext<D, R> {
  IsolateOperationContextImplWrapper({
    required D initialData,
  }) : data = initialData;

  void Function(dynamic)? _emitter;

  void ensureInitialized(Stream receive, void Function(dynamic) emit) {
    _emitter = emit;
    receive.listen((message) {
      if (message is _CancelTaskAction) {
        _flag = TaskFlag.cancel;
      } else if (message is _PauseTaskAction) {
        _flag = TaskFlag.pause;
      }
    });
  }

  @override
  D data;

  @override
  bool get shouldCancel => _flag == TaskFlag.cancel;

  @override
  bool get shouldPause => _flag == TaskFlag.pause;

  TaskFlag _flag = TaskFlag.none;

  @override
  void emit(D data) {
    this.data = data;
    _emitter?.call(_tryToTransferableTypedData(data));
  }
}

final class _CancelTaskAction {
  const _CancelTaskAction();
}

final class _PauseTaskAction {
  const _PauseTaskAction();
}

dynamic _tryFromTransferableTypedData(dynamic data) {
  if (data is TransferableTypedData) {
    return data.materialize().asUint8List();
  }
  return data;
}

dynamic _tryToTransferableTypedData(dynamic data) {
  if (data is Uint8List) {
    return TransferableTypedData.fromList([data]);
  }
  return data;
}
