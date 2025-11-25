import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskAddPage extends StatefulWidget {
  const TaskAddPage({super.key});

  @override
  State<TaskAddPage> createState() => _TaskAddPageState();
}

class _TaskAddPageState extends State<TaskAddPage> {
  final List<TaskItem> _tasks = [TaskItem()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("タスクを追加"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: _tasks.length + 1,
                itemBuilder: (context, index) {
                  if (index == _tasks.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addTask,
                          icon: const Icon(Icons.add),
                          label: const Text("タスクを追加"),
                        ),
                      ),
                    );
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text("タスク ${index + 1}"),
                              const Spacer(),
                              if (_tasks.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeTask(index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _tasks[index].timeController,
                                  decoration: const InputDecoration(
                                    labelText: "時刻",
                                    hintText: "例: 09:00",
                                    border: OutlineInputBorder(),
                                  ),
                                  onTap: () => _selectTime(index),
                                  readOnly: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _tasks[index].contentController,
                                  decoration: const InputDecoration(
                                    labelText: "タスク内容",
                                    hintText: "例: 朝食を食べる",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _saveTasks,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("保存"),
            ),
          ),
        ],
      ),
    );
  }

  void _addTask() {
    setState(() {
      _tasks.add(TaskItem());
    });
  }

  void _removeTask(int index) {
    setState(() {
      _tasks[index].dispose();
      _tasks.removeAt(index);
    });
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _tasks[index].timeController.text = formattedTime;
    }
  }

  Future<void> _saveTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 入力チェック
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].timeController.text.isEmpty || _tasks[i].contentController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('タスク${i + 1}の時刻と内容を入力してください')),
        );
        return;
      }
    }

    try {
      // 全タスクを保存
      for (final task in _tasks) {
        await FirebaseFirestore.instance.collection('tasks').add({
          'userId': uid,
          'time': task.timeController.text,
          'content': task.contentController.text,
          'isCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('タスクを保存しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました')),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }
}

class TaskItem {
  final TextEditingController timeController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  void dispose() {
    timeController.dispose();
    contentController.dispose();
  }
}