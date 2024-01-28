import 'dart:io';

import 'package:task_manager/task_manager.dart';

abstract class TaskStorage {
  const TaskStorage();

  Future<List<Task>> readAll(String managerIdentifier);

  Future<void> write(Task task, String managerIdentifier);

  Future<void> delete(Task task, String managerIdentifier);

  Future<void> clear(String managerIdentifier);

  Future<void> close();
}

abstract class DefaultDesktopAndMobileTaskStorage extends TaskStorage {
  const DefaultDesktopAndMobileTaskStorage(this._directory);

  final Directory _directory;
}
