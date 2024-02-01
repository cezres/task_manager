part of '../task_manager.dart';

class IsolateOperationContextImpl<D, R> extends OperationContextImpl<D, R> {
  IsolateOperationContextImpl({
    required super.initialData,
    super.id,
    super.identifier,
    super.priority,
    super.status,
  }) {
    _receivePort.listen((message) {
      debugPrint('receive: $message');
      if (message is SendPort) {
        _sendPort.complete(message);
        message.send('hello background');
      } else if (message is _Emit) {
        emit(message.data);
      } else if (message is Result<D, R>) {
        handlerResult(message);
      }
    });
  }

  @override
  void setup(
      {D? data, TaskStatus? status, TaskFlag? flag, TaskPriority? priority}) {
    super.setup(data: data, status: status, flag: flag, priority: priority);
    if (flag == TaskFlag.cancel) {
      _sendPort.future.then((value) => value.send(const _Cancel()));
    } else if (flag == TaskFlag.pause) {
      _sendPort.future.then((value) => value.send(const _Pause()));
    }
  }

  @override
  void handlerResult(Result result) {
    super.handlerResult(result);
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
      id: id,
      identifier: identifier,
      priority: priority,
    );
  }
}

class IsolateOperationContextImplWrapper<D, R> extends OperationContext<D, R> {
  IsolateOperationContextImplWrapper({
    required this.sendPort,
    required D initialData,
    required this.id,
    required this.identifier,
    required this.priority,
  }) : data = initialData;

  final SendPort sendPort;
  late final ReceivePort receivePort;

  @override
  D data;

  @override
  final String id;

  @override
  final String? identifier;

  @override
  final TaskPriority priority;

  @override
  TaskStatus get status => TaskStatus.running;

  TaskFlag _flag = TaskFlag.none;

  @override
  void emit(D data) {
    this.data = data;
    sendPort.send(_Emit(data));
  }

  void ensureInitialized() {
    receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is _Cancel) {
        _flag = TaskFlag.cancel;
      } else if (message is _Pause) {
        _flag = TaskFlag.pause;
      }
    });
  }

  @override
  bool get shouldCancel => _flag == TaskFlag.cancel;

  @override
  bool get shouldPause => _flag == TaskFlag.pause;
}

final class _Cancel {
  const _Cancel();
}

final class _Pause {
  const _Pause();
}

final class _Emit {
  _Emit(this.data);
  final dynamic data;

  @override
  String toString() {
    return '$data';
  }
}

class IsolateTaskImpl<D, R> {
  IsolateTaskImpl({required this.operation, required this.context});

  factory IsolateTaskImpl.from(TaskImpl<D, R, Operation<D, R>> task) =>
      IsolateTaskImpl(
        operation: task.operation,
        context: (task._context as IsolateOperationContextImpl<D, R>).wrapper(),
      );

  final Operation<D, R> operation;
  final IsolateOperationContextImplWrapper<D, R> context;

  Future<Result<D, R>> run() async {
    try {
      context.ensureInitialized();
      final result = await operation.run(context);
      return result;
    } catch (e) {
      return Result<D, R>.error(e);
    }
  }
}
