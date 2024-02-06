# Task Manager

Task Manager is a tool for managing and scheduling task execution, designed to simplify and optimize the execution of asynchronous tasks.

*[Task Manager Example Web Page](https://flutter-task-manager.github.io/)*

* [Features](#features)
* [Getting started](#getting-started)
* [Usage](#usage)
  * [Run a task](#run-a-task)
  * [Run a task in isolate](#run-a-task-in-isolate)
  * [Emit task progress](#emit-task-progress)
  * [Pause task](#pause-task)
  * [Cancel task](#cancel-task)
  * [Run a hydrated task](#run-a-hydrated-task)


## Features

- Cancel and pause tasks that are currently running
- Pause the task and preserve its state
- Change the priority of tasks
- Automatically persist and restore task states
- Send progress data while tasks are running
- Reuse or cancel tasks with the same identifier

## Getting started

Add the following dependencies to your `pubspec.yaml` file:

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
  final worker = Worker();
  worker.maxConcurrencies = 2;
  final task = worker.run(const ExampleOperation(), 1);
  await task.wait(); // 'Hello World - 1'
}
```

### Run a task in isolate

```dart
class ExampleComputeOperation extends ExampleOperation {
  const ExampleComputeOperation();

  /// Mark this task to be executed in the background.
  @override
  bool get compute => true;
}
```

### Emit task progress

```dart
class CountdownOperation extends Operation<int, void> {
  const CountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      data -= 1;

      /// Emit task progress data
      context.emit(data);
    }
    return Result.completed();
  }
}

void example() async {
  final worker = Worker();
  final task = worker.run(const CountdownOperation(), 10);
  task.stream.map((event) => event.data).distinct().listen((event) {
    debugPrint('Data: $event'); /// 9 8 7 6 5 4 ....
  });
  await task.wait();
}
```

### Pause task

```dart
class PauseableCountdownOperation extends CountdownOperation {
  const PauseableCountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      data -= 1;

      /// Check if a task should be paused.
      if (context.shouldPause) {
        /// Pause the task and preserve its state.
        return Result.paused(data);
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

    task.pause();
    await Future.delayed(const Duration(milliseconds: 400));
    expect(task.data < 10, true);
    expect(task.status, TaskStatus.paused);

    task.resume();
    expect(task.status, TaskStatus.running);

    await task.wait();
    expect(task.status, TaskStatus.completed);
}
```

### Cancel task

```dart
class CancellableCountdownOperation extends CountdownOperation {
  const CancellableCountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      data -= 1;

      /// Check if a task should be cancelled.
      if (context.shouldCancel) {
        /// Cancel the task.
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
    await task.wait();
}
```


