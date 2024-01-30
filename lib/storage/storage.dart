part of '../task_manager.dart';

abstract class Storage {
  const Storage();

  Stream<TaskEntity> readAll(String identifier);

  void write(TaskEntity task, String identifier);

  void delete(String taskId, String identifier);

  void clear(String identifier);

  Future<void> close();
}

final class TaskEntity {
  TaskEntity({
    required this.type,
    required this.id,
    required this.identifier,
    required this.status,
    required this.priority,
    required this.data,
  });

  final String type;
  final String id;
  final String? identifier;
  final TaskStatus status;
  final TaskPriority priority;
  final Map<String, dynamic> data;

  factory TaskEntity.fromJson(Map<String, dynamic> json) {
    return TaskEntity(
      type: json['type'],
      id: json['id'],
      identifier: json['identifier'],
      status: TaskStatus.values[json['status']],
      priority: TaskPriority.values[json['priority']],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'identifier': identifier,
      'status': status.index,
      'priority': priority.index,
      'data': data,
    };
  }
}
