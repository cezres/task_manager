part of '../../task_manager.dart';

abstract class Storage {
  const Storage();

  Stream<TaskEntity> readAll(String worker);

  FutureOr<void> write(TaskEntity task, String worker);

  FutureOr<void> delete(String taskId, String worker);

  FutureOr<void> clear(String worker);

  FutureOr<void> close();
}

final class TaskEntity {
  TaskEntity({
    required this.operation,
    required this.id,
    required this.identifier,
    required this.isPaused,
    required this.priority,
    required this.data,
  });

  final String operation;
  final String id;
  final String? identifier;
  final bool isPaused;
  final TaskPriority priority;
  final dynamic data;

  factory TaskEntity.fromJson(Map<String, dynamic> json) {
    return TaskEntity(
      operation: json['operation'],
      id: json['id'],
      identifier: json['identifier'],
      isPaused: json['isPaused'],
      priority: TaskPriority.values[json['priority']],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'id': id,
      'identifier': identifier,
      'isPaused': isPaused,
      'priority': priority.index,
      'data': data,
    };
  }
}
