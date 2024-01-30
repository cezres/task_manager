import 'package:example/countdown_task.dart';
import 'package:example/task_manager_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:task_manager/task_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  RendererBinding.instance.addPostFrameCallback((timeStamp) {
    debugPrint('post frame callback: $timeStamp');
  });

  StorageManager.registerTask<int, CountdownTask>(
    encode: (data) {
      return data;
    },
    decode: (json) {
      return json;
    },
    create: (data) {
      return CountdownTask(data);
    },
  );

  final directory = await getApplicationDocumentsDirectory();
  debugPrint('directory: ${directory.path}');

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
  final TaskManager manager = TaskManagerImpl(identifier: 'default');

  @override
  void initState() {
    super.initState();

    manager.maximumNumberOfConcurrencies = 2;
  }

  void _incrementCounter() {
    for (var i = 0; i < 1; i++) {
      manager.add(CountdownTask(60));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TaskManagerView(manager: manager),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
