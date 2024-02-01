import 'dart:async';

import 'package:example/storage/custom_storage.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:task_manager/task_manager.dart';

class CustomStorageWebImpl extends CustomStorage {
  final _store = StoreRef<String, dynamic>.main();

  late Database _database;
  final Completer<void> _ready = Completer<void>();

  CustomStorageWebImpl() {
    databaseFactoryWeb.openDatabase('task_manager.db').then((value) {
      _database = value;
      _ready.complete();
    }).onError((error, stackTrace) {
      _ready.completeError(error ?? -1, stackTrace);
    });
  }

  @override
  FutureOr<void> clear(String identifier) async {
    await _ready.future;
    _database.transaction((transaction) {
      return _store.delete(
        transaction,
        finder: Finder(filter: Filter.equals('identifier', identifier)),
      );
    });
  }

  @override
  FutureOr<void> close() {
    return _database.close();
  }

  @override
  FutureOr<void> delete(String taskId, String identifier) async {
    await _ready.future;
    await _database.transaction((transaction) {
      final record = _store.record(taskId);
      return record.delete(transaction);
    });
  }

  @override
  Stream<TaskEntity> readAll(String identifier) {
    final controller = StreamController<TaskEntity>();

    _ready.future.then((value) {
      return _database.transaction((transaction) async {
        final finder = Finder(
          filter: Filter.equals('identifier', identifier),
        );
        final records = await _store.find(transaction, finder: finder);
        for (var element in records) {
          controller.add(
            TaskEntity.fromJson(element['entity'] as Map<String, dynamic>),
          );
        }
        controller.close();
      });
    }).onError((error, stackTrace) {
      controller.addError(error ?? -1, stackTrace);
      controller.close();
    });

    return controller.stream;
  }

  @override
  FutureOr<void> write(TaskEntity task, String identifier) async {
    await _ready.future;
    await _database.transaction((transaction) {
      final record = _store.record(task.id);
      record.put(
        transaction,
        {
          'identifier': identifier,
          'entity': task.toJson(),
        },
      );
    });
  }
}
