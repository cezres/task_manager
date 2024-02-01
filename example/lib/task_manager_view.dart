import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:task_manager/task_manager.dart';

class TaskManagerView extends StatelessWidget {
  const TaskManagerView({super.key, required this.worker});

  final Worker worker;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: Row(
            children: [
              _buildExpandedTaskList(
                context,
                title: 'Running',
                color: Colors.green[300],
                tasks: (worker) => worker.runningTasks,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              _buildExpandedTaskList(
                context,
                title: 'Pending',
                color: Colors.orange[300],
                tasks: (worker) => worker.pendingTasks,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              _buildExpandedTaskList(
                context,
                title: 'Pasued',
                color: Colors.blue[300],
                tasks: (worker) => worker.pausedTasks,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedTaskList(
    BuildContext context, {
    required String title,
    required Color? color,
    required List<Task> Function(Worker worker) tasks,
  }) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Container(
              // color: color,
              child: StreamBuilder(
                initialData: tasks(worker),
                stream: worker.stream
                    .map((event) => tasks(event))
                    .distinct(listEquals),
                builder: (context, snapshot) {
                  final tasks = snapshot.requireData;
                  return _TaskListView(tasks: tasks);
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({
    required this.tasks,
  });

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return ImplicitlyAnimatedList(
      padding: const EdgeInsets.symmetric(vertical: 4),
      items: tasks,
      insertDuration: const Duration(milliseconds: 200),
      removeDuration: const Duration(milliseconds: 200),
      updateDuration: const Duration(),
      itemBuilder: (context, animation, item, i) {
        return SizeTransition(
          sizeFactor: animation,
          child: _TaskListItem(task: item),
        );
      },
      areItemsTheSame: (oldItem, newItem) {
        return oldItem.id == newItem.id;
      },
      removeItemBuilder: (context, animation, item) {
        return SizeTransition(
          sizeFactor: animation,
          child: _TaskListItem(task: item),
        );
      },
    );
  }
}

class _TaskListItem extends StatelessWidget {
  const _TaskListItem({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => StreamBuilder(
        key: ValueKey(task.id),
        initialData: task,
        stream: task.stream,
        builder: (context, snapshot) => _buildTaskContentWidgets(
          context,
          task: task,
          constraints: constraints,
        ),
      ),
    )
        .decorated(
          color: Theme.of(context).colorScheme.onInverseSurface,
          borderRadius: BorderRadius.circular(8),
        )
        .constrained(
          height: 52,
        )
        .padding(
          horizontal: 8,
          vertical: 4,
        );
  }

  Widget _buildTaskContentWidgets(BuildContext context,
      {required Task task, required BoxConstraints constraints}) {
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 1000),
          width: constraints.maxWidth * (60 - task.data) / 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
        ).positioned(left: 0, top: 0, bottom: 0),
        [
          Expanded(child: Text("${task.name} (${task.data})")),
          _buildActionsView(context, task: task),
        ].toRow(crossAxisAlignment: CrossAxisAlignment.center).padding(all: 8)
      ],
    );
  }

  Widget _buildActionsView(BuildContext context, {required Task task}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPauseOrResumeView(context, task: task),
        _buildCancelView(context, task: task),
      ],
    );
  }

  Widget _buildCancelView(BuildContext context, {required Task task}) {
    if (task.shouldCancel) {
      return const Text('Cancelling');
    } else {
      return IconButton(
        icon: const Icon(Icons.cancel),
        onPressed: () {
          task.cancel();
        },
      );
    }
  }

  Widget _buildPauseOrResumeView(BuildContext context, {required Task task}) {
    if (task.shouldPause) {
      return const Text('Pausing');
    } else if (task.status == TaskStatus.running ||
        task.status == TaskStatus.pending) {
      return IconButton(
        icon: const Icon(Icons.pause),
        onPressed: () {
          task.pause();
        },
      );
    } else if (task.status == TaskStatus.paused) {
      return IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () {
          task.resume();
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  // Widget _buildProgressView(BuildContext context, {required Task task}) {
  //   return
  // }
}
