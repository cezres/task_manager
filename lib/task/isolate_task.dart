// ignore_for_file: unused_element

part of '../task_manager.dart';

typedef Emiter = void Function(dynamic data);

abstract class IsolateTask<Data, Result> extends Task<Data, Result>
    with BackgroundIsolateTaskMixin<Data, TaskResult<Data, Result>> {
  IsolateTask(super.initialState);
  //

  late Emiter _emit;
  // void Function(String id)? _sendCancelMessage;
  // void Function(String id)? _sendPauseMessage;

  @override
  void cancel() {
    if (sendCancelMessage != null) {
      sendCancelMessage?.call(id);
    } else {
      super.cancel();
    }
  }

  @override
  void pause() {
    if (sendPauseMessage != null) {
      sendPauseMessage?.call(id);
    } else {
      super.pause();
    }
  }

  @override
  void emit(Data data) {
    _emit(data);
  }

  /// Background isolate task mixin

  FutureOr<TaskResult<Data, Result>> _runInIsolate(Emiter emit) {
    _emit = emit;
    return run();
  }

  void _onIsolateCompleted(TaskResult<Data, Result> result) {
    _handlerResult(result);
  }

  void _onIsolateError(dynamic error) {
    _handlerResult(TaskResult.error(error));
  }

  void _onIsolateEmitted(Data data) {
    super.emit(data);
  }

  // void _setupMessageHandler(
  //   void Function(String id)? sendCancelMessage,
  //   void Function(String id)? sendPauseMessage,
  // ) {
  //   _sendCancelMessage = sendCancelMessage;
  //   _sendPauseMessage = sendPauseMessage;
  // }

  void _cancelOnIsolate() {
    _flag = TaskFlag.cancel;
  }

  void _pauseOnIsolate() {
    _flag = TaskFlag.pause;
  }
}

class CustomIsolateTask extends IsolateTask<int, void> {
  CustomIsolateTask(super.initialState);

  @override
  FutureOr<TaskResult<int, void>> run() {
    // TODO: implement run
    throw UnimplementedError();
  }
}
