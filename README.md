# Task Manager

Task Manager is a tool for managing and scheduling task execution, designed to simplify and optimize the execution of asynchronous tasks.

*[Task Manager Example Web Page](https://flutter-task-manager.github.io/)*

* [Getting started](#getting-started)
* [Usage](#usage)
  * [Run task](#run-task)
  * [Pause task](#pause-task)
  * [Cancel task](#cancel-task)
  * [Run task in isolate](#run-task-in-isolate)
  * [Run hydrated task](#run-hydrated-task)


## Getting started

Add the following dependencies to your `pubspec.yaml` file:

```
task_manager:
    git:
        url: https://github.com/cezres/task_manager.git
        ref: main
```

## Usage


### Run task

```dart
class ExampleOperation extends Operation<int, String> {
  const ExampleOperation();

  @override
  FutureOr<Result<int, String>> run(OperationContext<int, void> context) async {
    await Future.delayed(const Duration(seconds: 1));
    return Result.completed('Hello World - ${context.data}');
  }
}

void example() async {
  final worker = Worker();
  worker.maxConcurrencies = 2;
  final task = worker.run(const ExampleOperation(), 1);
  await task.wait(); // 'Hello World - 1'
}
```

### Pause task

```dart
class CountdownOperation extends Operation<int, void> {
  const CountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      data -= 1;

      /// Check if the operation should be paused or canceled
      if (context.shouldPause) {
        return Result.paused(data);
      } else if (context.shouldCancel) {
        return Result.canceled();
      } else {
        context.emit(data);
      }
    }
    return Result.completed();
  }
}

void example() async {
    final worker = Worker();
    final task = worker.run(const CountdownOperation(), 10, isPaused: true);
    expect(task.status, TaskStatus.paused);

    task.resume();
    expect(task.status, TaskStatus.running);
    await Future.delayed(const Duration(milliseconds: 400));
    expect(task.status, TaskStatus.running);

    task.pause();
    await Future.delayed(const Duration(milliseconds: 400));
    expect(task.status, TaskStatus.paused);

    task.resume();
    expect(task.status, TaskStatus.running);

    await task.wait();
    expect(task.status, TaskStatus.completed);
}
```

### Cancel task

```dart
void example() async {
    final worker = Worker();
    final task = worker.run(const CountdownOperation(), 10);

    await Future.delayed(const Duration(milliseconds: 400));
    task.cancel();

    await task.wait().onError((error, stackTrace) {
      debugPrint('Error: $error');
    }).whenComplete(() {
      expect(task.status, TaskStatus.canceled);
    });
}
```

### Run task in isolate

```dart
class CountdownComputeOperation extends CountdownOperation {
  const CountdownComputeOperation();

  @override
  bool get compute => true;
}

void example() async {
    final worker = Worker();
    final task = worker.run(const CountdownComputeOperation(), 10);
    await task.wait();
}
```

### Run hydrated task


```dart
class CountdownHydratedOperation extends CountdownOperation
    implements HydratedOperation<int, void> {
  const CountdownHydratedOperation();

  @override
  int fromJson(json) {
    return json;
  }

  @override
  toJson(int data) {
    return data;
  }
}

void example() {
    final storage = CustomStorage();
    final worker = HydratedWorker(storage: storage, identifier: 'test');
    worker.register(() => const CountdownHydratedOperation());

    final task = worker.run(const CountdownHydratedOperation(), 10);
    await task.wait();
}
```


