import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import 'login_page.dart';
import 'attendance_dashboard.dart';
import 'executive_monitoring_page.dart';
import 'user_report_dashboard.dart';
import 'collection_dashboard_page.dart';
import 'main_page.dart';
import 'emi_calculator_page.dart';
import 'collection_page.dart';
import 'visit_list_screen.dart';
import 'dart:convert';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUserData();
    if (user != null && mounted) {
      setState(() => currentUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Menu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: bodyBg,
        foregroundColor: textHeading,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildGrid(context),
            const SizedBox(height: 32),
            _buildLogoutButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final items = [
      {'label': 'Attendance', 'icon': Icons.watch_later_rounded, 'color': primaryBlue, 'page': const AttendanceDashboard()},
      {'label': 'Team Monitor', 'icon': Icons.supervisor_account_rounded, 'color': Colors.purple, 'page': const ExecutiveMonitoringPage()},
      {'label': 'User Dashboard', 'icon': Icons.admin_panel_settings_rounded, 'color': Colors.amber, 'page': const UserReportDashboard()},
      {'label': 'My Documents', 'icon': Icons.description_rounded, 'color': Colors.blue, 'action': () => _showMsg(context, "Documents module coming soon")},
      {'label': 'Customer List', 'icon': Icons.groups_rounded, 'color': Colors.green, 'page': CollectionPage(onChanged: () {})},
      {'label': 'Statement', 'icon': Icons.receipt_long_rounded, 'color': Colors.indigo, 'page': const CollectionDashboardPage()},
      {'label': 'EMI Calc', 'icon': Icons.calculate_rounded, 'color': Colors.orange, 'page': const EmiCalculatorPage()},
      {'label': 'Visit History', 'icon': Icons.history_rounded, 'color': Colors.cyan, 'page': const VisitListScreen(title: "My Visits", filters: {})},
      {'label': 'Sync Data', 'icon': Icons.sync_rounded, 'color': Colors.teal, 'action': () => _syncData(context)},
      {'label': 'Settings', 'icon': Icons.settings_rounded, 'color': Colors.grey, 'action': () => _showMsg(context, "Settings updated")},
      {'label': 'Support', 'icon': Icons.help_outline_rounded, 'color': Colors.pink, 'action': () => _showMsg(context, "Contacting support...")},
      {'label': 'About Us', 'icon': Icons.info_outline_rounded, 'color': primaryBlue, 'action': () => _showMsg(context, "SAFL Business v1.0.0")},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            if (item['page'] != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'] as Widget));
            } else if (item['action'] != null) {
              (item['action'] as Function)();
            }
          },
          child: Container(
            decoration: premiumCardDecoration(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                const SizedBox(height: 12),
                Text(
                  item['label'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textHeading),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _syncData(BuildContext context) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: primaryBlue),
            const SizedBox(height: 20),
            const Text("Syncing all data...", style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("This stores data to phone storage", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      await SyncService().performFullSync(force: true);
      if (mounted) {
        Navigator.pop(context);
        _showMsg(context, "Data sync successful. All data stored locally.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showMsg(context, "Sync failed: $e");
      }
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: () async {
          await SharedPreferences.getInstance().then((p) => p.clear());
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
        label: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
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
                _drawerTile('Dashboard', Icons.grid_view_rounded, false, () {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainPage()), (_) => false);
                }),
                _drawerTile('Detailed Reports', Icons.pie_chart_rounded, false, () => _push(const CollectionDashboardPage())),
                _drawerTile('Team Monitoring', Icons.supervisor_account_rounded, false, () => _push(const ExecutiveMonitoringPage())),
                _drawerTile('Attendance Records', Icons.watch_later_rounded, false, () => _push(const AttendanceDashboard())),
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
      final navigator = Navigator.of(context);
      await SharedPreferences.getInstance().then((p) => p.clear());
      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }
}
