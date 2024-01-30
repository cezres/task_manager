part of '../task_manager.dart';

class StorageManager {
  static Storage? _storage;

  static void registerStorage(Storage storage) {
    _storage = storage;
  }

  static Storage get instance {
    if (_storage == null) {
      if (kIsWeb) {
        _storage = const DefaultWebStorage();
      } else {
        _storage = const DefaultDesktopAndMobileStorage();
      }
    }
    return _storage!;
  }

  static void registerTask<Data, T extends Task<Data, dynamic>>({
    required TaskEncoder<Data> encode,
    required TaskDecoder<Data> decode,
    required TaskCreater<Data, T> create,
    bool Function(T task) willSave = _defaultWillSave,
  }) {
    _builders[T.toString()] = _TaskBuilder<Data, T>(
      encoder: encode,
      decoder: decode,
      creater: create,
      willSave: willSave,
    );
  }

  static final Map<String, _TaskBuilder> _builders = {};

  static void _saveTask(Task task) {
    final builder = _builders[task.runtimeType.toString()];
    if (builder == null) {
      return;
    }

    if (!builder.willSave(task)) {
      return;
    }

    final String identifier;
    if (task._scheduler is TaskManager) {
      identifier = (task._scheduler as TaskManager).identifier;
    } else {
      return;
    }

    final encodedData = builder.encode(task.data);
    final entity = TaskEntity(
      type: task.runtimeType.toString(),
      id: task.id,
      identifier: task.identifier,
      status: task.status,
      priority: task.priority,
      data: encodedData,
    );
    instance.write(entity, identifier);
  }

  static void _deleteTask<T extends Task>(T task) {
    if (!_builders.containsKey(task.runtimeType.toString())) {
      return;
    }

    final String identifier;
    if (task._scheduler is TaskManager) {
      identifier = (task._scheduler as TaskManager).identifier;
    } else {
      return;
    }

    instance.delete(task.id, identifier);
  }

  static Stream<Task> _loadTasks(String identifier) {
    return instance
        .readAll(identifier)
        .map((event) {
          final builder = _builders[event.type];
          if (builder == null) {
            return null;
          }
          try {
            final data = builder.decode(event.data);
            final Task task = builder.create(data);

            task._id = event.id;
            task._identifier = event.identifier;
            task._status = event.status;
            task._priority = event.priority;

            return task;
          } catch (e) {
            debugPrint('Error when loading task: ${event.id} - $e');
            instance.delete(event.id, identifier);
            return null;
          }
        })
        .skipWhile((element) => element == null)
        .cast<Task>();
  }
}

typedef TaskEncoder<Data> = dynamic Function(Data data);
typedef TaskDecoder<Data> = Data Function(dynamic json);
typedef TaskCreater<Data, T> = T Function(Data data);

bool _defaultWillSave(Task task) {
  return true;
}

class _TaskBuilder<Data, T extends Task<Data, dynamic>> {
  _TaskBuilder({
    required this.encoder,
    required this.decoder,
    required this.creater,
    required this.willSave,
  });
  final TaskEncoder<Data> encoder;
  final TaskDecoder<Data> decoder;
  final TaskCreater<Data, T> creater;
  final bool Function(T task) willSave;

  dynamic encode(dynamic data) {
    return encoder(data as Data);
  }

  dynamic decode(dynamic json) {
    return decoder(json as Map<String, dynamic>);
  }

  dynamic create(dynamic data) {
    return creater(data as Data);
  }
}
