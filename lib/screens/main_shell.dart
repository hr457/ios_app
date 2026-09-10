import 'package:flutter/material.dart';
import 'package:safl/screens/collection_screen.dart';
import 'package:safl/screens/dashboard_screen.dart';
import 'package:safl/screens/profile_screen.dart';
import 'package:safl/screens/reports_screen.dart';
import 'package:safl/screens/visit_screen.dart';
import 'package:safl/widgets/theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(refresh: () => setState(() {})),
      CollectionScreen(refresh: () => setState(() {})),
      VisitScreen(refresh: () => setState(() {})),
      const ReportsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        selectedItemColor: primaryRed,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (v) => setState(() => index = v),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.currency_rupee), label: 'Collect'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: 'Visit'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
