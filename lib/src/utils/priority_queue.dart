mixin PriorityMixin {
  int get priorityValue;
}

abstract class PriorityQueue<E extends PriorityMixin> {
  /// Number of elements in the queue.
  int get length;

  /// Whether the queue is empty.
  bool get isEmpty;

  /// Whether the queue has any elements.
  bool get isNotEmpty;

  /// Checks if [object] is in the queue.
  ///
  /// Returns true if the element is found.
  ///
  /// Uses the [Object.==] of elements in the queue to check
  bool contains(E object);

  /// Adds element to the queue.
  void add(E element);

  /// Adds all [elements] to the queue.
  void addAll(Iterable<E> elements);

  /// Returns the next element that will be returned by [removeFirst].
  ///
  /// The element is not removed from the queue.
  ///
  /// The queue must not be empty when this method is called.
  E get first;

  /// Removes and returns the element with the highest priority.
  ///
  /// The queue must not be empty when this method is called.
  E removeFirst();

  /// Removes an element of the queue that compares equal to [element].
  ///
  /// Returns true if an element is found and removed,
  /// and false if no equal element is found.
  ///
  /// If the queue contains more than one object equal to [element],
  /// only one of them is removed.
  ///
  /// Uses the [Object.==] of elements in the queue to check
  bool remove(E element, {int? priority});

  /// Removes all the elements from this queue and returns them.
  List<E> removeAll();

  /// Removes all the elements from this queue.
  void clear();

  /// Returns a list of the elements of this queue in priority order.
  List<E> toList();
}

class PriorityQueueImpl<E extends PriorityMixin> implements PriorityQueue<E> {
  PriorityQueueImpl();

  final List<int> _priorities = [];
  final Map<int, List<E>> _listOfPriority = {};

  @override
  int get length => _priorities.isEmpty
      ? 0
      : _listOfPriority.values
          .map((e) => e.length)
          .reduce((value, element) => value + element);

  @override
  bool get isEmpty => _priorities.isEmpty;

  @override
  bool get isNotEmpty => _priorities.isNotEmpty;

  @override
  bool contains(E object) {
    final priority = object.priorityValue;
    final list = _listOfPriority[priority];
    if (list == null) {
      return false;
    }
    return list.contains(object);
  }

  @override
  void add(E element) {
    final priority = element.priorityValue;
    final list = _listOfPriority[priority];
    if (list == null) {
      _priorities.add(priority);
      _priorities.sort();
      _listOfPriority[priority] = [element];
    } else {
      list.add(element);
    }
  }

  @override
  void addAll(Iterable<E> elements) {
    for (var element in elements) {
      add(element);
    }
  }

  @override
  E get first {
    if (_priorities.isEmpty) {
      throw StateError('PriorityQueue is empty');
    }
    final priority = _priorities.first;
    final list = _listOfPriority[priority]!;
    return list.first;
  }

  @override
  E removeFirst() {
    if (_priorities.isEmpty) {
      throw StateError('PriorityQueue is empty');
    }
    final priority = _priorities.last; // highest priority
    final list = _listOfPriority[priority]!;
    final element = list.removeAt(0);
    if (list.isEmpty) {
      _priorities.removeLast();
      _listOfPriority.remove(priority);
    }
    return element;
  }

  @override
  bool remove(E element, {int? priority}) {
    final priorityValue = priority ?? element.priorityValue;
    final list = _listOfPriority[priorityValue];
    if (list == null) {
      return false;
    }
    final removed = list.remove(element);
    if (list.isEmpty) {
      _priorities.remove(priorityValue);
      _listOfPriority.remove(priorityValue);
    }
    return removed;
  }

  @override
  List<E> removeAll() {
    final list = toList();
    _priorities.clear();
    _listOfPriority.clear();
    return list;
  }

  @override
  void clear() {
    _priorities.clear();
    _listOfPriority.clear();
  }

  @override
  List<E> toList() {
    final List<E> list = [];
    for (var element in _listOfPriority.values) {
      list.addAll(element);
    }
    return list;
  }
}
