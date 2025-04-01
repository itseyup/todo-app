import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 700),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    center: true, // Center the window on startup
    title: 'Rise To Do App', // Set window title
    alwaysOnTop: true, // Add this line to keep window always on top
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rise To Do App',
      home: TodoApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TodoApp extends StatefulWidget {
  @override
  _TodoAppState createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final List<Task> _tasks = [];
  final TextEditingController _controller = TextEditingController();
  late SharedPreferences _prefs;
  bool _autoStart = false;
  bool _moveCompletedToBottom = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadTasks();
    _loadAutoStartPreference();
    _loadMoveCompletedToBottomPreference();
  }

  void _loadTasks() {
    final String? tasksJson = _prefs.getString('tasks');
    if (tasksJson != null) {
      final List<dynamic> decodedTasks = jsonDecode(tasksJson);
      setState(() {
        _tasks.clear();
        _tasks.addAll(decodedTasks.map((taskMap) => Task.fromJson(taskMap)));
      });
    }
  }

  Future<void> _saveTasks() async {
    final String tasksJson = jsonEncode(_tasks.map((task) => task.toJson()).toList());
    await _prefs.setString('tasks', tasksJson);
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
      _saveTasks(); // Görevleri kaydet
    });
    if (_moveCompletedToBottom) {
      _moveCompletedTasks();
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      _tasks[index].isExpanded = !_tasks[index].isExpanded;
    });
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
      _saveTasks(); // Görevleri kaydet
    });
  }

  void _addTask(String text) {
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(Task(text: text));
      _saveTasks(); // Görevleri kaydet
    });
    _controller.clear();
  }

  void _toggleSubtask(int taskIndex, int subtaskIndex) {
    setState(() {
      _tasks[taskIndex].subtasks[subtaskIndex].isCompleted = 
        !_tasks[taskIndex].subtasks[subtaskIndex].isCompleted;
      _saveTasks(); // Görevleri kaydet
    });
  }

  void _removeSubtask(int taskIndex, int subtaskIndex) {
    setState(() {
      _tasks[taskIndex].subtasks.removeAt(subtaskIndex);
      _saveTasks(); // Görevleri kaydet
    });
  }

  void _addSubtask(int taskIndex, String subtaskText) {
    if (subtaskText.isEmpty) return;
    setState(() {
      _tasks[taskIndex].subtasks.add(Task(text: subtaskText));
      _saveTasks(); // Görevleri kaydet
    });
  }

  Future<void> _loadAutoStartPreference() async {
    setState(() {
      _autoStart = _prefs.getBool('autoStart') ?? false;
    });
  }

  Future<void> _loadMoveCompletedToBottomPreference() async {
    setState(() {
      _moveCompletedToBottom = _prefs.getBool('moveCompletedToBottom') ?? false;
    });
  }

  Future<void> _toggleAutoStart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoStart = value;
      prefs.setBool('autoStart', value);
    });
    await _registerStartup(value);
  }

  Future<void> _toggleMoveCompletedToBottom(bool value) async {
    setState(() {
      _moveCompletedToBottom = value;
      _prefs.setBool('moveCompletedToBottom', value);
    });
    if (value) {
      _moveCompletedTasks();
    }
  }

  void _moveCompletedTasks() {
    setState(() {
      _tasks.sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;
        return 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onPanStart: (details) async {
            await windowManager.startDragging();
          },
          child: Row(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: const Text('Görevlerim', style: TextStyle(color: Colors.white)),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SettingsPopup(
                        moveCompletedToBottom: _moveCompletedToBottom,
                        onToggleMoveCompletedToBottom: _toggleMoveCompletedToBottom,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1E2530),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: () async => await windowManager.minimize(),
          ),
          IconButton(
            icon: const Icon(Icons.crop_square, color: Colors.white),
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async => await windowManager.close(),
          ),
        ],
        flexibleSpace: GestureDetector(
          onPanStart: (details) async {
            await windowManager.startDragging();
          },
        ),
      ),
      body: GestureDetector(
        onPanStart: (details) async {
          await windowManager.startDragging();
        },
        child: Container(
          padding: const EdgeInsets.all(16.0),
          color: const Color(0xFF1E2530),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yeni görev ekle...',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A3543),
                  suffixIcon: TextButton(
                    onPressed: () => _addTask(_controller.text),
                    child: const Text('Ekle', style: TextStyle(color: Colors.blue)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _tasks.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final task = _tasks.removeAt(oldIndex);
                      _tasks.insert(newIndex, task);
                    });
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  buildDefaultDragHandles: false, // Disable default handles
                  itemBuilder: (context, index) {
                    return TaskTile(
                      key: Key(index.toString()),
                      task: _tasks[index],
                      index: index, // Add this line
                      onToggle: () => _toggleTask(index),
                      onDelete: () => _removeTask(index),
                      onToggleExpanded: () => _toggleExpanded(index),
                      onToggleSubtask: (subtaskIndex) => _toggleSubtask(index, subtaskIndex),
                      onRemoveSubtask: (subtaskIndex) => _removeSubtask(index, subtaskIndex),
                      onAddSubtask: (subtaskText) => _addSubtask(index, subtaskText),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskTile extends StatefulWidget {
  final Task task;
  final int index; // Add this line
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpanded;
  final Function(int) onToggleSubtask;
  final Function(int) onRemoveSubtask;
  final Function(String) onAddSubtask;

  const TaskTile({
    super.key,
    required this.task,
    required this.index, // Add this line
    required this.onToggle,
    required this.onDelete,
    required this.onToggleExpanded,
    required this.onToggleSubtask,
    required this.onRemoveSubtask,
    required this.onAddSubtask,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  final TextEditingController _subtaskController = TextEditingController();

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A3543),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue),
                  color: widget.task.isCompleted ? Colors.blue : Colors.transparent,
                ),
                child: widget.task.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              title: Text(
                widget.task.text,
                style: TextStyle(
                  color: widget.task.isCompleted ? Colors.white70 : Colors.white,
                  decoration: widget.task.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[300], size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onDelete,
                  ),
                  const SizedBox(width: 4), // Reduced from 8 to 4
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onToggleExpanded,
                  ),
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: const Icon(Icons.drag_handle, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (widget.task.isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subtaskController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Alt görev...',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (_subtaskController.text.isNotEmpty) {
                              widget.onAddSubtask(_subtaskController.text);
                              _subtaskController.clear();
                            }
                          },
                          child: const Text('Ekle', style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                  ),
                  ...widget.task.subtasks.asMap().entries.map((entry) {
                    final subtask = entry.value;
                    final index = entry.key;
                    return InkWell(
                      onTap: () => widget.onToggleSubtask(index),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue),
                            color: subtask.isCompleted ? Colors.blue : Colors.transparent,
                          ),
                          child: subtask.isCompleted
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          subtask.text,
                          style: TextStyle(
                            color: subtask.isCompleted ? Colors.white70 : Colors.white,
                            decoration: subtask.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red[300], size: 18),
                          onPressed: () => widget.onRemoveSubtask(index),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Task {
  String text;
  bool isCompleted;
  bool isExpanded;
  List<Task> subtasks;

  Task({
    required this.text,
    this.isCompleted = false,
    this.isExpanded = false,
    List<Task>? subtasks,
  }) : subtasks = subtasks ?? [];

  // JSON'dan Task oluştur
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool,
      isExpanded: json['isExpanded'] as bool,
      subtasks: (json['subtasks'] as List<dynamic>)
          .map((subtaskJson) => Task.fromJson(subtaskJson as Map<String, dynamic>))
          .toList(),
    );
  }

  // Task'ı JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCompleted': isCompleted,
      'isExpanded': isExpanded,
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
    };
  }
}

class SettingsPopup extends StatelessWidget {
  final bool moveCompletedToBottom;
  final ValueChanged<bool> onToggleMoveCompletedToBottom;

  const SettingsPopup({
    required this.moveCompletedToBottom,
    required this.onToggleMoveCompletedToBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3543),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsOption(
              moveCompletedToBottom: moveCompletedToBottom,
              onToggleMoveCompletedToBottom: onToggleMoveCompletedToBottom,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsOption extends StatefulWidget {
  final bool moveCompletedToBottom;
  final ValueChanged<bool> onToggleMoveCompletedToBottom;

  const SettingsOption({
    required this.moveCompletedToBottom,
    required this.onToggleMoveCompletedToBottom,
  });

  @override
  _SettingsOptionState createState() => _SettingsOptionState();
}

class _SettingsOptionState extends State<SettingsOption> {
  bool _autoStart = false;
  bool _moveCompletedToBottom = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoStart = prefs.getBool('autoStart') ?? false;
      _moveCompletedToBottom = prefs.getBool('moveCompletedToBottom') ?? false;
    });
  }

  Future<void> _toggleAutoStart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoStart = value;
      prefs.setBool('autoStart', value);
    });
    await _registerStartup(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Sistem başlatıldığında otomatik olarak başlat',
              style: TextStyle(color: Colors.white)),
          value: _autoStart,
          onChanged: _toggleAutoStart,
          activeColor: Colors.blue,
        ),
        SwitchListTile(
          title: const Text('Bitmiş görevleri otomatik olarak aşağıya al',
              style: TextStyle(color: Colors.white)),
          value: _moveCompletedToBottom,
          onChanged: (value) {
            setState(() {
              _moveCompletedToBottom = value;
            });
            widget.onToggleMoveCompletedToBottom(value);
          },
          activeColor: Colors.blue,
        ),
      ],
    );
  }
}

class WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const WindowButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: onPressed,
    );
  }
}

// Function to register the app to start on Windows startup
Future<void> _registerStartup(bool enable) async {
  final executable = Platform.resolvedExecutable;
  final appPath = executable.replaceAll('flutter_tester.exe', 'RiseToDoApp.exe');

  final key = r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run';
  final name = 'RiseToDoApp';

  if (enable) {
    await Process.run('reg', ['add', key, '/v', name, '/d', appPath, '/f']);
  } else {
    await Process.run('reg', ['delete', key, '/v', name, '/f']);
  }
}
