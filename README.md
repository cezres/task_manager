# Task Manager

Task Manager is a tool for managing and scheduling task execution, designed to simplify and optimize the execution of asynchronous tasks.

*[Task Manager Example Web Page](https://flutter-task-manager.github.io/)*

* [Features](#features)
* [Getting started](#getting-started)
* [Usage](#usage)
  * [Create a task](#create-a-task)
  * [Pause or cancel a task](#pause-or-cancel-a-task)
  * [Create hydrated task](#create-hydrated-task)

## Features

- Pause and resume task
- Cancel task
- Task priority
- Hydrated task
- Isolate Task

## Getting started

Add the following dependencies to your `pubspec.yaml file:

```
task_manager:
    git:
        url: https://github.com/cezres/task_manager.git
        ref: main
```

## Usage


### Run a task

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
  // Create a worker
  final worker = Worker();
  worker.maxConcurrencies = 2;
  // Add a task
  final task = worker.run(const ExampleOperation(), 1);
  // Wait for the task to complete
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
    expect(task.status, TaskStatus.running);

    await Future.delayed(const Duration(milliseconds: 400));
    task.cancel();

    await task.wait().onError((error, stackTrace) {
      debugPrint('Error: $error');
    }).whenComplete(() {
      expect(task.status, TaskStatus.canceled);
    });
}
```

### Run a task in isolate

```dart
class CountdownComputeOperation extends CountdownOperation {
  const CountdownComputeOperation();

  @override
  bool get compute => true;
}

void example() async {
    final worker = Worker();
    final task = worker.run(const CountdownComputeOperation(), 10);
    _listenTask(task);
    expect(task.status, TaskStatus.running);
    await task.wait();
    expect(task.status, TaskStatus.completed);
}
```

### Run a hydrated task


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
    expect(task.status, TaskStatus.running);
    await _ensureDataStored();

    var list = await storage.readAll('test').toList();
    expect(list.length, 1);

    await task.wait();
    expect(task.status, TaskStatus.completed);
    await _ensureDataStored();

    list = await storage.readAll('test').toList();
    expect(list.length, 0);}
```


