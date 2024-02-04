import 'package:task_manager/task_manager.dart';

class MemoryStorage extends Storage {
  final Map<String, Map<String, TaskEntity>> _caches = {};

  @override
  void clear(String identifier) {
    _caches.remove(identifier);
  }

  @override
  Future<void> close() async {
    _caches.clear();
  }

  @override
  void delete(String taskId, String identifier) {
    _caches[identifier]?.remove(taskId);
  }

  @override
  Stream<TaskEntity> readAll(String identifier) {
    final list = _caches[identifier]?.values.toList() ?? [];
    return Stream.fromIterable(List<TaskEntity>.from(list));
  }

  @override
  void write(TaskEntity task, String identifier) {
    _caches.putIfAbsent(identifier, () => {})[task.id] = task;
  }
}
