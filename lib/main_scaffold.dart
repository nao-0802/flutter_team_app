import "package:flutter/material.dart";
import "package:flutter_team_app/alarm/alarm_list.dart";
import "package:flutter_team_app/group/group_list.dart";
import "package:flutter_team_app/profile/profile.dart";
import "package:flutter_team_app/task/task_main.dart";

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;

        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AlarmListPage()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const GroupListPage()),
            );
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TaskMainPage()),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
            break;
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
    );
  }
}
