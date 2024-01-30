part of '../task_manager.dart';

class DefaultDesktopAndMobileStorage extends Storage {
  const DefaultDesktopAndMobileStorage();

  @override
  Stream<TaskEntity> readAll(String identifier) async* {
    final directory = await getDirectory(identifier);
    final list = await directory.list().toList();
    for (var element in list) {
      final file = File(element.path);
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      yield TaskEntity.fromJson(json);
    }
  }

  @override
  void write(TaskEntity task, String identifier) async {
    getFile(task.id, identifier).then(
      (value) => value.writeAsString(
        json.encode(task.toJson()),
      ),
    );
  }

  @override
  void delete(String taskId, String identifier) {
    getFile(taskId, identifier).then((value) => value.delete());
  }

  @override
  void clear(String identifier) {
    getDirectory(identifier).then((value) => value.delete());
  }

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

  @override
  Future<void> close() {
    return Future.value();
  }
}
