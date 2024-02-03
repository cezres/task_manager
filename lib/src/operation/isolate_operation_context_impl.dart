part of '../../task_manager.dart';

class IsolateOperationContextImpl<D, R> extends OperationContextImpl<D, R> {
  IsolateOperationContextImpl({
    required super.initialData,
    super.priority,
    super.status,
  }) {
    _receivePort.listen((message) {
      switch (message.runtimeType) {
        case SendPort:
          _sendPort.complete(message);
          break;
        case _EmitTaskAction:
          emit((message as _EmitTaskAction).data);
        case Result:
          _handlerResult(message);
          break;
        default:
      }
    });
  }

  @override
  void pause() {
    super.pause();
    _sendPort.future.then((value) => value.send(const _PauseTaskAction()));
  }

  @override
  void cancel() {
    super.cancel();
    _sendPort.future.then((value) => value.send(const _CancelTaskAction()));
  }

  @override
  Future<ResultType> run(Operation<D, R> operation) async {
    status = TaskStatus.running;
    _controller.add(this);

    try {
      final context = wrapper();
      final result = await compute(
        (message) async {
          final operation = message[0] as Operation;
          final context = message[1] as IsolateOperationContextImplWrapper;
          context.ensureInitialized();
          return await operation.run(context);
        },
        [
          operation,
          context,
        ],
      );
      _handlerResult(result as Result<D, R>);
      return result.type;
    } catch (e) {
      _handlerResult(Result<D, R>.error(e));
      return ResultType.error;
    }
  }

  @override
  void _handlerResult(Result<D, R> result) {
    super._handlerResult(result);
    switch (result.type) {
      case ResultType.canceled:
      case ResultType.completed:
      case ResultType.error:
        _receivePort.close();
        break;
      default:
    }
  }

  final ReceivePort _receivePort = ReceivePort();
  late Completer<SendPort> _sendPort;

  IsolateOperationContextImplWrapper<D, R> wrapper() {
    _sendPort = Completer<SendPort>();
    return IsolateOperationContextImplWrapper<D, R>(
      sendPort: _receivePort.sendPort,
      initialData: data,
    );
  }
}

class IsolateOperationContextImplWrapper<D, R> extends OperationContext<D, R> {
  IsolateOperationContextImplWrapper({
    required this.sendPort,
    required D initialData,
  }) : data = initialData;

  final SendPort sendPort;

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
    sendPort.send(_EmitTaskAction(data));
  }

  void ensureInitialized() {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is _CancelTaskAction) {
        _flag = TaskFlag.cancel;
      } else if (message is _PauseTaskAction) {
        _flag = TaskFlag.pause;
      }
    });
  }
}

final class _CancelTaskAction {
  const _CancelTaskAction();
}

final class _PauseTaskAction {
  const _PauseTaskAction();
}

final class _EmitTaskAction {
  _EmitTaskAction(this.data);
  final dynamic data;
}
