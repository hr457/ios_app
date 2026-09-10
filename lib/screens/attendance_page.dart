import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../utils/app_colors.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Future<List<Map<String, dynamic>>> attendanceFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      attendanceFuture = AttendanceService().getAttendanceLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fd),
      appBar: AppBar(
        title: const Text('Attendance Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryRed));
          }
          
          final logs = snapshot.data ?? [];
          final currentMonthLogs = _filterCurrentMonth(logs);
          
          int totalDays = _getDaysInMonth(DateTime.now());
          int presentCount = currentMonthLogs.length;
          int absentCount = _getElapsedDaysInMonth() - presentCount;
          if (absentCount < 0) absentCount = 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildDashboardHeader(presentCount, absentCount, totalDays),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attendance Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      logs.isEmpty 
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final status = AttendanceService().calculateStatus(log['punch_in'], log['punch_out']);
                            return _buildAttendanceCard(log, status);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardHeader(int present, int absent, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      decoration: const BoxDecoration(
        color: primaryRed,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Text(DateFormat('MMMM yyyy').format(DateTime.now()), 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dashboardStat("Present", "$present", Colors.greenAccent),
              _dashboardStat("Absent", "$absent", Colors.orangeAccent),
              _dashboardStat("Holidays", "0", Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 25),
          LinearProgressIndicator(
            value: present / total,
            backgroundColor: Colors.white24,
            color: Colors.greenAccent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Monthly Progress", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              Text("${(present / total * 100).toStringAsFixed(1)}%", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _dashboardStat(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> log, String status) {
    final DateTime date = DateTime.tryParse(log['date'] ?? '') ?? DateTime.now();
    final punchIn = log['punch_in'] != null ? DateFormat('hh:mm a').format(DateTime.parse(log['punch_in'])) : '--';
    final punchOut = log['punch_out'] != null ? DateFormat('hh:mm a').format(DateTime.parse(log['punch_out'])) : 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: primaryRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(DateFormat('dd').format(date), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryRed)),
                Text(DateFormat('MMM').format(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryRed)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(punchIn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 16),
                    const Icon(Icons.logout_rounded, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(punchOut, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(DateFormat('EEEE').format(date), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          _statusChip(status),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.green;
    if (status.contains('Absent')) color = Colors.red;
    if (status.contains('Half')) color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No attendance records found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterCurrentMonth(List<Map<String, dynamic>> logs) {
    final now = DateTime.now();
    return logs.where((log) {
      final date = DateTime.tryParse(log['date'] ?? '');
      return date != null && date.month == now.month && date.year == now.year;
    }).toList();
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getElapsedDaysInMonth() {
    return DateTime.now().day;
  }
}
