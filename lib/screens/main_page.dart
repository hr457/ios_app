import 'dart:ui'; // Trigger Refresh
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import 'dashboard_page.dart';
import 'attendance_dashboard.dart';
import 'collection_page.dart';
import 'executive_monitoring_page.dart';
import 'reports_page.dart';
import 'more_page.dart';
import 'collection_dashboard_page.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  UserModel? currentUser;
  late List<Widget> _pages;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(onChanged: _onChanged),
      const AttendanceDashboard(),
      CollectionPage(onChanged: _onChanged),
      const ExecutiveMonitoringPage(),
      ReportsPage(onChanged: _onChanged),
      const MorePage(),
    ];
    _loadUser();
    
    // Trigger Global Sync on Startup
    SyncService().init();
    SyncService().performFullSync();
    
    // Check for 11:00 AM refresh every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      SyncService().checkScheduledSync();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUserData();
    if (user != null && mounted) {
      setState(() {
        currentUser = user;
        // Re-initialize pages with user data
        _pages = [
          DashboardPage(onChanged: _onChanged, user: user),
          const AttendanceDashboard(),
          CollectionPage(onChanged: _onChanged),
          const ExecutiveMonitoringPage(),
          ReportsPage(onChanged: _onChanged),
          const MorePage(),
        ];
      });

      // Auto-resume tracking if already punched in
      _resumeTrackingIfNeeded();
    }
  }

  Future<void> _resumeTrackingIfNeeded() async {
    final isPunchedIn = await AttendanceService().isPunchedIn();
    if (isPunchedIn) {
      debugPrint("Auto-resuming location tracking for active session...");
      LocationService().startTracking();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildCupertinoTabBar(),
    );
  }

  Widget _buildCupertinoTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tabItem(0, CupertinoIcons.house_fill, "Home"),
                _tabItem(1, CupertinoIcons.stopwatch_fill, "Attend"),
                _tabItem(2, CupertinoIcons.square_list_fill, "Cases"),
                _tabItem(3, CupertinoIcons.group_solid, "Team"),
                _tabItem(4, CupertinoIcons.chart_pie_fill, "Reports"),
                _tabItem(5, CupertinoIcons.ellipsis_circle_fill, "More"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryBlue : textMuted.withValues(alpha: 0.6),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? primaryBlue : textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: surfaceWhite,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _drawerTile('Dashboard', Icons.grid_view_rounded, _currentIndex == 0, () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                }),
                _drawerTile('Detailed Reports', Icons.pie_chart_rounded, false, () => _push(const CollectionDashboardPage())),
                _drawerTile('Team Monitoring', Icons.supervisor_account_rounded, _currentIndex == 3, () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                }),
                _drawerTile('Attendance Records', Icons.watch_later_rounded, _currentIndex == 1, () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                }),
                const Divider(height: 40),
                _drawerTile('Logout', Icons.power_settings_new_rounded, false, () => _confirmLogout(context), color: primaryRed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
      decoration: const BoxDecoration(gradient: mainGradient),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(currentUser?.name ?? "User", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(currentUser?.role ?? "Employee", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ]))
        ],
      ),
    );
  }

  Widget _drawerTile(String title, IconData icon, bool selected, VoidCallback onTap, {Color? color}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: selected ? primaryBlue : (color ?? textBody)),
      title: Text(title, style: TextStyle(color: selected ? primaryBlue : (color ?? textHeading), fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
    );
  }

  void _push(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()), 
        (_) => false
      );
    }
  }
}
