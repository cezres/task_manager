part of '../task_manager.dart';

class DefaultWebStorage extends Storage {
  const DefaultWebStorage();

  @override
  void clear(String identifier) {
    // TODO: implement clear
  }

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  void delete(String taskId, String identifier) {
    // TODO: implement delete
  }

  @override
  Stream<TaskEntity> readAll(String identifier) {
    // TODO: implement readAll
    throw UnimplementedError();
  }

  @override
  void write(TaskEntity task, String identifier) {
    // TODO: implement write
  }
}
