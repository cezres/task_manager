import 'package:flutter/foundation.dart';

mixin ReusedObjectMixin {
  @protected
  @visibleForTesting
  T createReusedObject<T>();

  T getReusedObject<T>(String key) {
    throw UnimplementedError();
  }
}

class ReusedObject<T> {
  ReusedObject(this.builder);
  final T Function() builder;

  T create() => builder();
}

class GlobalReusedObject {
  static final Map<String, ReusedObject> _reusedObjects = {};

  static void register<T>(T Function() builder) {
    _reusedObjects[T.toString()] = ReusedObject(builder);
  }

  static T get<T>() {
    final reusedObject = _reusedObjects[T.toString()];
    if (reusedObject == null) {
      throw StateError('Reused object not found: ${T.toString()}');
    }
    return reusedObject.create();
  }
}
