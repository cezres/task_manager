import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:example/storage/custom_storage.dart';
import 'package:path/path.dart';
import 'package:task_manager/task_manager.dart';

class CustomStorageIOImpl extends CustomStorage {
  @override
  Stream<TaskEntity> readAll(String identifier) async* {
    final directory = await getDirectory(identifier);
    final list = await directory.list().toList();
    for (var element in list) {
      if (!element.path.endsWith('json')) {
        continue;
      }
      final file = File(element.path);
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      yield TaskEntity.fromJson(json);
    }
  }

  @override
  FutureOr<void> write(TaskEntity task, String identifier) async {
    return getFile(task.id, identifier).then(
      (value) => value.writeAsString(
        json.encode(task.toJson()),
      ),
    );
  }

  @override
  FutureOr<void> delete(String taskId, String identifier) async {
    return getFile(taskId, identifier).then((value) async {
      if (await value.exists()) {
        value.delete();
      }
    });
  }

  @override
  FutureOr<void> clear(String identifier) {
    return getDirectory(identifier).then((value) => value.delete());
  }

  @override
  FutureOr<void> close() {}

  Future<Directory> getDirectory(String managerIdentifier) async {
    final directory = Directory('task_storage/$managerIdentifier');
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> getFile(String taskId, String identifier) async {
    final directory = await getDirectory(identifier);
    final path = join(directory.path, '$taskId.json');
    return File(path);
  }
}
