import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/utils/priority_queue.dart';

void main() {
  test('priority_queue', () {
    final queue = PriorityQueueImpl<ExamplePriorityValue>();
    queue.add(ExamplePriorityValue(1, priority: 1));
    queue.add(ExamplePriorityValue(2, priority: 2));
    queue.add(ExamplePriorityValue(3, priority: 3));
    queue.add(ExamplePriorityValue(4, priority: 4));

    expect(queue.length, 4);
    expect(queue.first.value, 1);

    queue.add(ExamplePriorityValue(5, priority: 0));
    expect(queue.first.value, 5);
    expect(queue.length, 5);

    final first = queue.removeFirst();
    expect(first.value, 5);
    expect(queue.length, 4);

    expect(queue.removeAll().length, 4);
    expect(queue.length, 0);
  });
}

class ExamplePriorityValue with PriorityMixin {
  ExamplePriorityValue(this.value, {this.priority = 0});

  final int value;
  final int priority;

  @override
  int get priorityValue => priority;

  @override
  int get hashCode => Object.hashAll([value, priority]);

  @override
  bool operator ==(Object other) {
    if (other is ExamplePriorityValue) {
      return value == other.value && priority == other.priority;
    }
    return super == other;
  }
}
