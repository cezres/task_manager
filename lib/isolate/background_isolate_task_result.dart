final class BackgroundIsolateTaskCompleted<T> {
  const BackgroundIsolateTaskCompleted(this.id, this.value, this.isIdle);

  final String id;
  final T value;
  final bool isIdle;
}

final class BackgroundIsolateTaskError {
  const BackgroundIsolateTaskError(this.id, this.error, this.isIdle);

  final String id;
  final dynamic error;
  final bool isIdle;
}

final class BackgroundIsolateTaskEmit<Data> {
  const BackgroundIsolateTaskEmit(this.id, this.value);

  final String id;
  final Data value;
}

enum BackgroundIsolateTaskResultType {
  completed,
  error,
}
