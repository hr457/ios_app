import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/collection_api_service.dart';
import '../utils/app_colors.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? user;
  Map<String, dynamic> summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final u = await AuthService.getUserData();
    final s = await CollectionApiService.fetchDashboardData();
    if (mounted) {
      setState(() {
        user = u;
        summary = s['summary'] ?? {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: bodyBg,
        foregroundColor: textHeading,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileCard(),
            const SizedBox(height: 32),
            _buildStatsGrid(),
            const SizedBox(height: 32),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: premiumCardDecoration(),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor: accentBlue,
            child: Icon(Icons.person_rounded, size: 50, color: primaryBlue),
          ),
          const SizedBox(height: 20),
          Text(user?.name ?? "Loading...", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textHeading)),
          const SizedBox(height: 4),
          Text(user?.role ?? "User Profile", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textMuted)),
          const SizedBox(height: 2),
          const Text("SAFL Business", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        _infoTile("Daily Target", "₹${_format(summary['total_recovery_required'] ?? summary['overdue'])}"),
        _infoTile("Employee ID", "CE1234"),
        _infoTile("Mobile Number", user?.email ?? "9876543210"),
        _infoTile("Email", "${user?.name.toLowerCase().replaceAll(' ', '') ?? 'user'}@safl.com"),
        _infoTile("Attendance", "Present", isGreen: true),
        _infoTile("App Version", "1.0.0"),
      ],
    );
  }

  Widget _infoTile(String label, String value, {bool isGreen = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: premiumCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isGreen ? successGreen : textHeading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _handleLogout,
      icon: const Icon(Icons.logout_rounded, color: primaryRed, size: 20),
      label: const Text("Logout", style: TextStyle(color: primaryRed, fontWeight: FontWeight.w900, fontSize: 15)),
    );
  }

  Future<void> _handleLogout() async {
    await SharedPreferences.getInstance().then((p) => p.clear());
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  String _format(dynamic v) {
    if (v == null) return "0";
    double val = (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);
    return NumberFormat('#,##,###').format(val);
  }
}
