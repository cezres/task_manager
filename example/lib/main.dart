import 'package:example/countdown_operation.dart';
import 'package:example/storage/custom_storage.dart';
import 'package:example/task_manager_view.dart';
import 'package:flutter/material.dart';
import 'package:task_manager/task_manager.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final HydratedWorker worker;

  @override
  void initState() {
    super.initState();

    worker = HydratedWorker(
      storage: CustomStorage.adapter(),
      identifier: 'default',
    );
    worker.maxConcurrencies = 2;
    worker.register(() => const CountdownOperation());
    worker.loadTasks();
  }

  void _addTasks() {
    for (var i = 0; i < 1; i++) {
      worker.run(const CountdownOperation(), 60);
    }
  }

  void _showMaxConcurrenciesDialog() {
    final controller =
        TextEditingController(text: worker.maxConcurrencies.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Max Concurrencies"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) {
                worker.maxConcurrencies = value;
              }
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Manager Example"),
        centerTitle: true,
        actions: [
          IconButton.outlined(
            onPressed: _showMaxConcurrenciesDialog,
            icon: const Icon(Icons.settings),
          ),
          const SizedBox(width: 24)
        ],
      ),
      body: TaskManagerView(worker: worker),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTasks,
        child: const Icon(Icons.add),
      ),
    );
  }
}
