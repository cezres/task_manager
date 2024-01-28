import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:task_manager/task_manager.dart';

class TaskManagerView extends StatelessWidget {
  const TaskManagerView({super.key, required this.manager});

  final TaskManager manager;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildExpandedTaskList(
          context,
          title: 'Running',
          color: Colors.green[300],
          tasks: (scheduler) => scheduler.runningTasks,
        ),
        const VerticalDivider(width: 1, thickness: 1),
        _buildExpandedTaskList(
          context,
          title: 'Pending',
          color: Colors.orange[300],
          tasks: (scheduler) => scheduler.pendingTasks,
        ),
        const VerticalDivider(width: 1, thickness: 1),
        _buildExpandedTaskList(
          context,
          title: 'Pasued',
          color: Colors.blue[300],
          tasks: (scheduler) => scheduler.pausedTasks,
        ),
      ],
    );
  }

  Widget _buildExpandedTaskList(
    BuildContext context, {
    required String title,
    required Color? color,
    required List<Task> Function(TaskScheduler scheduler) tasks,
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
          Expanded(
            child: Container(
              color: color,
              child: StreamBuilder(
                initialData: tasks(manager),
                stream: manager.stream
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
  const _TaskListView({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _TaskListItem(task: tasks[index]);
      },
    );
  }
}

class _TaskListItem extends StatelessWidget {
  const _TaskListItem({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final title = Text(task.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        return StreamBuilder(
          key: ValueKey(task.id),
          initialData: task,
          stream: task.stream,
          builder: (context, snapshot) {
            final task = snapshot.requireData;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    color: Colors.green,
                    width: constraints.maxWidth * (60 - task.data) / 60,
                  ),
                ),
                ListTile(
                  title: title,
                  subtitle: Text(task.data.toString()),
                  trailing: _buildActionsView(context, task: task),
                )
              ],
            );
          },
        );
      },
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
}
