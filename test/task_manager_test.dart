import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/task_manager.dart';

import 'memory_storage.dart';

void main() {
  test('Run a task', () async {
    final worker = Worker();
    final task = worker.run(const CountdownOperation(), 10);
    expect(task.status, TaskStatus.running);
    await task.wait();
    expect(task.status, TaskStatus.completed);
    expect(worker.length, 0);
  });

  test('Pause task', () async {
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
  });

  test('Cancel task', () async {
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
  });

  test('Run a task in isolate', () async {
    final worker = Worker();
    final task = worker.run(const CountdownComputeOperation(), 10);
    _listenTask(task);
    expect(task.status, TaskStatus.running);
    await task.wait();
    expect(task.status, TaskStatus.completed);
  });

  test('Run a hydrated task', () async {
    final storage = MemoryStorage();
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
    expect(list.length, 0);
  });

  test('Task priority', () async {
    final worker = WorkerImpl();
    worker.maxConcurrencies = 1;

    /// Will be executed in the order of task1 task3 task2

    final task1 = worker.run(
      const CountdownOperation(),
      10,
      priority: TaskPriority.normal,
    );

    final task2 = worker.run(
      const CountdownOperation(),
      10,
      priority: TaskPriority.low,
    );

    final task3 = worker.run(
      const CountdownOperation(),
      10,
      priority: TaskPriority.high,
    );

    _listenTask(task1);
    _listenTask(task2);
    _listenTask(task3);

    await task1.wait();
    expect(task1.status, TaskStatus.completed);
    expect(task2.status, TaskStatus.pending);
    expect(task3.status, TaskStatus.running);

    await task3.wait();
    expect(task3.status, TaskStatus.completed);
    expect(task2.status, TaskStatus.running);

    await task2.wait();
    expect(task2.status, TaskStatus.completed);

    expect(worker.length, 0);
  });
}

void _listenTask(Task task) {
  task.stream.listen((event) {
    if (event.status == TaskStatus.running ||
        event.status == TaskStatus.paused) {
      debugPrint('${event.name}: ${event.data} - ${event.status}');
    } else {
      debugPrint('${event.name}: ${event.status}');
    }
  });
}

Future<void> _ensureDataStored() {
  return Future.delayed(const Duration(milliseconds: 100));
}

class CountdownOperation extends Operation<int, void> {
  const CountdownOperation();

  @override
  FutureOr<Result<int, void>> run(OperationContext<int, void> context) async {
    int data = context.data;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 200));
      data -= 1;
      if (context.shouldCancel) {
        return Result.canceled();
      } else if (context.shouldPause) {
        return Result.paused(data);
      } else if (data > 0) {
        context.emit(data);
      } else {
        return Result.completed();
      }
    }
  }
}

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

class CountdownComputeOperation extends CountdownOperation {
  const CountdownComputeOperation();

  @override
  bool get compute => true;
}
