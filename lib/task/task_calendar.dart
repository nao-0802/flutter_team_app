import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskCalendarPage extends StatefulWidget {
  const TaskCalendarPage({super.key});

  @override
  State<TaskCalendarPage> createState() => _TaskCalendarPageState();
}

class _TaskCalendarPageState extends State<TaskCalendarPage> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, bool> _completionRecords = {};

  @override
  void initState() {
    super.initState();
    _loadCompletionRecords();
  }

  Future<void> _loadCompletionRecords() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final records = await FirebaseFirestore.instance
        .collection('task_records')
        .where('userId', isEqualTo: uid)
        .get();

    final Map<String, bool> completionMap = {};
    for (var doc in records.docs) {
      final data = doc.data();
      completionMap[data['date']] = data['completed'] ?? false;
    }

    setState(() {
      _completionRecords = completionMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildWeekDaysHeader(),
          Expanded(child: _buildCalendarGrid()),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
              _loadCompletionRecords();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_selectedMonth.year}年 ${_selectedMonth.month}月',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              });
              _loadCompletionRecords();
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaysHeader() {
    const weekDays = ['日', '月', '火', '水', '木', '金', '土'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: weekDays.map((day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: firstWeekday + daysInMonth,
      itemBuilder: (context, index) {
        if (index < firstWeekday) {
          return Container(); // 空のセル
        }

        final day = index - firstWeekday + 1;
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final isCompleted = _completionRecords[dateStr];
        final isToday = _isToday(date);

        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: isToday ? Colors.blue.shade100 : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isCompleted != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.cancel,
                    color: isCompleted ? Colors.green : Colors.red,
                    size: 16,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              const Text("完了"),
            ],
          ),
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              const Text("未完了"),
            ],
          ),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                color: Colors.blue.shade100,
              ),
              const SizedBox(width: 4),
              const Text("今日"),
            ],
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
           date.month == today.month &&
           date.day == today.day;
  }
}