import 'package:example/countdown_operation.dart';
import 'package:example/storage/custom_storage.dart';
import 'package:example/task_manager_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:task_manager/task_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StorageManager.registerStorage(CustomStorage.adapter());
  StorageManager.registerOperation(() => const CountdownOperation());

  if (!kIsWeb) {
    final directory = await getApplicationDocumentsDirectory();
    debugPrint('directory: ${directory.path}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Task Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Worker worker = Worker();

  @override
  void initState() {
    super.initState();

    worker.maxConcurrencies = 2;
    worker.loadTasksWithStorage();
  }

  void _addTasks() {
    for (var i = 0; i < 1; i++) {
      worker.addTask(const CountdownOperation(), 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TaskManagerView(worker: worker),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTasks,
        child: const Icon(Icons.add),
      ),
    );
  }
}
