import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_add.dart';
import 'task_calendar.dart';
import '../alarm/alarm_list.dart';
import '../group/group_list.dart';
import '../profile/profile.dart';

class TaskMainPage extends StatefulWidget {
  const TaskMainPage({super.key});

  @override
  State<TaskMainPage> createState() => _TaskMainPageState();
}

class _TaskMainPageState extends State<TaskMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 2; // タスクタブを選択状態にする

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkDateChange();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkDateChange() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 最後にチェックした日付を取得
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final lastCheckDate = userDoc.data()?['lastCheckDate'] as String?;

    if (lastCheckDate != todayStr) {
      // 日付が変わった場合、全タスクのチェックをリセット
      await _resetAllTasks();
      // 最後にチェックした日付を更新
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastCheckDate': todayStr,
      });
    }
  }

  Future<void> _resetAllTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tasks = await FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .get();

    for (var doc in tasks.docs) {
      await doc.reference.update({'isCompleted': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("タスク管理"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "タスクリスト"),
            Tab(text: "カレンダー"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TaskListView(),
          const TaskCalendarPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskAddPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AlarmListPage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GroupListPage()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: "アラーム",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: "共有アラーム",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: "タスク",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "プロフィール",
          ),
        ],
      ),
    );
  }
}

class _TaskListView extends StatefulWidget {
  @override
  State<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<_TaskListView> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("ログインが必要です"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs;

        if (tasks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "タスクがありません",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "右下の+ボタンからタスクを追加してください",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final data = task.data() as Map<String, dynamic>;
            final isCompleted = data['isCompleted'] ?? false;

            return Dismissible(
              key: Key(task.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                _deleteTask(task.id);
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Checkbox(
                    value: isCompleted,
                    onChanged: (value) {
                      _toggleTask(task.id, value ?? false);
                    },
                  ),
                  title: Text(
                    data['content'] ?? '',
                    style: TextStyle(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(data['time'] ?? ''),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleTask(String taskId, bool isCompleted) async {
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .update({'isCompleted': isCompleted});

    if (isCompleted) {
      _checkAllTasksCompleted();
    }
  }

  void _checkAllTasksCompleted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tasks = await FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .get();

    final allCompleted = tasks.docs.every((doc) {
      final data = doc.data();
      return data['isCompleted'] == true;
    });

    if (allCompleted && tasks.docs.isNotEmpty) {
      _showCompletionDialog();
      _saveCompletionRecord();
      _resetAllTasks();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🎉 おめでとうございます！"),
        content: const Text("今日のタスクを全て完了しました！"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _saveCompletionRecord() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await FirebaseFirestore.instance.collection('task_records').add({
      'userId': uid,
      'date': todayStr,
      'completed': true,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _resetAllTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tasks = await FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .get();

    for (var doc in tasks.docs) {
      await doc.reference.update({'isCompleted': false});
    }
  }

  void _deleteTask(String taskId) {
    FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
  }
}