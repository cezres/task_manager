# Task Manager

Task Manager is a tool for managing and scheduling task execution, designed to simplify and optimize the execution of asynchronous tasks.

* [Features](#features)
* [Getting started](#getting-started)
* [Usage](#usage)
  * [Create a task](#create-a-task)
  * [Pause or cancel a task](#pause-or-cancel-a-task)
  * [Create hydrated task](#create-hydrated-task)

## Features

- Supports canceling and pausing ongoing tasks
- Allows adjustment of task priority
- Enables persistent storage of task states, supporting continued execution after application interruption and restart

## Getting started

Add the following dependencies to your `pubspec.yaml file:

```
task_manager:
    git:
        url: https://github.com/cezres/task_manager.git
        ref: main
```

## Usage


### Create a task

The following example demonstrates how to create a simple task:

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
  final task = worker.addTask(const ExampleOperation(), 1);
  // Wait for the task to complete
  await task.wait(); // Result.completed('Hello World - 1')
}
```

### Pause or cancel a task

For tasks in progress, you need to check if the operation should be paused or canceled, as shown below:

```dart
class CountdownOperation extends Operation<int, void> {
  const CountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (data > 0) {
      await Future.delayed(const Duration(milliseconds: 1000));
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

void example() {
  task.cancel();
  task.pause();
  task.resume();
}
```

### Create hydrated task

To create a hydrated task, refer to the following code:

```dart
class ExampleHydratedOperation extends HydratedOperation<int, void> {
  const ExampleHydratedOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    await Future.delayed(const Duration(seconds: 1));
    return Result.completed('Hello World - ${context.data}');
  }

  @override
  toJson(int data) {
    return data;
  }

  @override
  int fromJson(json) {
    return json;
  }
}

void example() {
  StorageManager.registerStorage(CustomStorage());
  StorageManager.registerOperation(() => const ExampleHydratedOperation());
}
```
