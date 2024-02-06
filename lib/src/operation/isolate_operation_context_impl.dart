part of '../../task_manager.dart';

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
