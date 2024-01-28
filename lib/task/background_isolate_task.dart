// import 'package:task_manager/task/task.dart';

// abstract class BackgroundIsolateTask<S, R> extends Task<S, R> {
//   BackgroundIsolateTask(super.initialState);
//   //

//   @override
//   void cancel() {
//     // TODO: implement cancel
//     super.cancel();
//     // 向后台Isolate发送取消任务的消息
//   }

//   @override
//   void pause() {
//     // TODO: implement pause
//     super.pause();
//     // 向后台Isolate发送暂停任务的消息
//   }

//   @override
//   void emit(S state) {
//     // TODO: implement emit
//     super.emit(state);
//     // 向主Isolate发送任务状态的消息
//   }
// }
