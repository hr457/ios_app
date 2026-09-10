import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/attendance_service.dart';
import '../utils/app_colors.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/collection_api_service.dart';

class AttendanceDashboard extends StatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  late Future<Map<String, dynamic>> summaryFuture;
  late Future<Map<String, dynamic>> logsFuture;
  late Future<Map<String, dynamic>> teamLogsFuture;
  bool isPunchedIn = false;
  bool isPunchedOut = false;
  bool isPunching = false; 
  String? punchInTime;
  String? punchOutTime;
  UserModel? currentUser;
  bool isSyncing = false;
  Map<String, dynamic>? cachedSummary;
  Map<String, dynamic>? cachedLogs;

  @override
  void initState() {
    super.initState();
    // Initialize futures with dummy values to avoid LateInitializationError
    summaryFuture = Future.value({});
    logsFuture = Future.value({'data': [], 'total': 0});
    teamLogsFuture = Future.value({'data': [], 'total': 0});
    _init();
  }

  Future<void> _init() async {
    await _loadUser();
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sFull = await AttendanceService().loadFromCacheFull("attendance_summary_$today");
    final lFull = await AttendanceService().loadFromCacheFull(CollectionApiService.getCacheKey("attendance_data_false", null));
    final ltFull = await AttendanceService().loadFromCacheFull(CollectionApiService.getCacheKey("attendance_data_true", null));
    
    bool needsSync = true;
    if (mounted) {
      setState(() {
        if (sFull != null) {
          final s = sFull['data'];
          cachedSummary = s;
          isPunchedIn = s['is_punched_in'] == true;
          punchInTime = _formatTime(s['punch_in']);
          punchOutTime = _formatTime(s['punch_out']);
          summaryFuture = Future.value(Map<String, dynamic>.from(s));
        }
        if (lFull != null) {
          cachedLogs = lFull['data'];
          logsFuture = Future.value(Map<String, dynamic>.from(lFull['data']));
        }
        if (ltFull != null) {
          teamLogsFuture = Future.value(Map<String, dynamic>.from(ltFull['data']));
        }
      });
      
      // Sync only if log data is stale
      if (lFull != null) {
        needsSync = CollectionApiService.isCacheStale(lFull['ts'], hours: 5);
      }
    }

    if (needsSync) {
      _refresh();
    }
  }

  Future<void> _loadCachedData() async {
    // Deprecated
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUserData();
    if (mounted) setState(() => currentUser = user);
  }

  void _refresh() {
    setState(() {
      isSyncing = true;
      summaryFuture = AttendanceService().getAttendanceSummary();
      logsFuture = AttendanceService().getAttendanceData();
      teamLogsFuture = AttendanceService().getAttendanceData(includeTeam: true);
      _checkStatus();
    });
    
    Future.wait([summaryFuture, logsFuture, teamLogsFuture]).then((_) {
      if (mounted) setState(() => isSyncing = false);
    }).catchError((_) {
      if (mounted) setState(() => isSyncing = false);
    });
  }

  Future<void> _checkStatus() async {
    try {
      final summary = await AttendanceService().getAttendanceSummary();
      
      if (mounted) {
        setState(() {
          isPunchedIn = summary['is_punched_in'] == true;
          punchInTime = _formatTime(summary['punch_in']);
          punchOutTime = _formatTime(summary['punch_out']);
          
          // Reset UI after check out as requested
          if (punchOutTime != null && !isPunchedIn) {
             isPunchedOut = false; 
             punchInTime = null;
             punchOutTime = null;
          } else {
             isPunchedOut = false; 
          }
        });
      }
    } catch (e) {
      debugPrint("Status Check Error: $e");
    }
  }

  String? _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == 'null') return null;
    try {
      if (timeStr.contains('AM') || timeStr.contains('PM')) return timeStr;
      final dt = DateTime.tryParse(timeStr);
      if (dt != null) return DateFormat('hh:mm a').format(dt);
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, h, m));
      }
    } catch (e) {}
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    final String role = currentUser?.role.toLowerCase() ?? "";
    final bool isManagement = role.contains('tl') || role.contains('leader') || role.contains('acm') || role.contains('manager') || role.contains('admin');

    if (isManagement) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: bodyBg,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                if (isSyncing)
                  const Text("Syncing...", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryBlue)),
              ],
            ),
            backgroundColor: surfaceWhite,
            foregroundColor: textHeading,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
              ),
            ),
            bottom: const TabBar(
              labelColor: primaryBlue,
              indicatorColor: primaryBlue,
              unselectedLabelColor: textMuted,
              tabs: [
                Tab(text: "MY RECORDS"),
                Tab(text: "TEAM RECORDS"),
              ],
            ),
            actions: [
              if (isSyncing)
                const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue))),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue))
            ],
          ),
          body: TabBarView(
            children: [
              _buildMainView(),
              _buildTeamView(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: bodyBg,
        foregroundColor: textHeading,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
          ),
        ),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue))],
      ),
      body: _buildMainView(),
    );
  }

  Widget _buildMainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(),
          const SizedBox(height: 32),
          _buildPunchCard(),
          const SizedBox(height: 40),
          const Text("My History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
          const SizedBox(height: 16),
          _buildLogsList(logsFuture),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTeamView() {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("Team Members Logs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
          const SizedBox(height: 16),
          _buildLogsList(teamLogsFuture, isTeam: true),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: summaryFuture,
      initialData: cachedSummary,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        // If summary is missing, try to count from logs
        int total = data['total_days'] ?? 0;
        int present = data['present'] ?? 0;
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _statCard("Total Days", "$total", primaryBlue),
              _statCard("Present", "$present", successGreen),
              _statCard("Absent", "${data['absent'] ?? 0}", primaryRed),
              _statCard("Half Day", "${data['half_day'] ?? 0}", warningOrange),
            ],
          ),
        );
      }
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: premiumCardDecoration(),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPunchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: mainGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.2), blurRadius: 25, offset: const Offset(0, 15))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE, dd MMM').format(DateTime.now()), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(isPunchedOut ? "Duty Completed" : (isPunchedIn ? "Active Duty" : "Not Punched In"), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12), 
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)), 
                child: Icon(isPunchedOut ? Icons.check_circle_outline_rounded : (isPunchedIn ? Icons.timer_rounded : Icons.login_rounded), color: Colors.white, size: 28)
              ),
            ],
          ),
          if (punchInTime != null || punchOutTime != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  if (punchInTime != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.login_rounded, color: Colors.white70, size: 12),
                              SizedBox(width: 4),
                              Text("IN TIME", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(punchInTime!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  if (punchOutTime != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.white70, size: 12),
                              SizedBox(width: 4),
                              Text("OUT TIME", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(punchOutTime!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: (isPunchedOut || isPunching) ? null : () async {
                setState(() => isPunching = true);
                
                try {
                  bool success = false;
                  if (isPunchedIn) {
                    success = await AttendanceService().punchOut();
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Checked Out Successfully!"), backgroundColor: successGreen)
                      );
                    }
                  } else {
                    success = await AttendanceService().punchIn();
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Checked In Successfully!"), backgroundColor: successGreen)
                      );
                    }
                  }
                  
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Action failed. Please try again."), backgroundColor: primaryRed)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: primaryRed)
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => isPunching = false);
                    _refresh();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isPunchedOut ? Colors.white24 : Colors.white, 
                foregroundColor: primaryBlue, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), 
                elevation: 0,
              ),
              child: isPunching 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3))
                : Text(
                    isPunchedOut ? "PUNCHED OUT" : (isPunchedIn ? "CHECK OUT" : "CHECK IN NOW"), 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)
                  ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLogsList(Future<Map<String, dynamic>> future, {bool isTeam = false}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      initialData: isTeam ? null : cachedLogs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: primaryBlue)));
        }
        final Map<String, dynamic> fullData = snapshot.data != null ? Map<String, dynamic>.from(snapshot.data!) : {};
        final List logs = fullData['data'] is List ? fullData['data'] : [];
        if (logs.isEmpty) return _emptyState();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) => _logTile(logs[index] as Map, isTeam: isTeam),
        );
      },
    );
  }

  Widget _logTile(Map log, {bool isTeam = false}) {
    final Map<String, dynamic> data = log.cast<String, dynamic>();
    final dateStr = data['date'] ?? data['Date'] ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final status = (data['status'] ?? data['Status'] ?? 'Present').toString();
    final String name = (data['name'] ?? data['Name'] ?? 'Member').toString();
    
    // Use First_in and Last_out explicitly
    final String inTime = _formatTime(data['punch_in']) ?? "--:--";
    final String outTime = _formatTime(data['punch_out']) ?? "--:--";

    // Duration Calculation
    String duration = (data['Total_time'] ?? data['Total Time'] ?? data['total_time'] ?? "--").toString();
    if (duration == "--" || duration == "00:00") {
      if (data['punch_in'] != null && data['punch_out'] != null) {
        try {
          final i = _parseTime(data['punch_in']);
          final o = _parseTime(data['punch_out']);
          if (i != null && o != null) {
            final diff = o.difference(i);
            duration = "${diff.inHours}h ${diff.inMinutes % 60}m";
          }
        } catch (e) {}
      }
    }

    Color statusColor = successGreen;
    String statusText = status == 'Active' ? 'Active' : (status == 'Inactive' ? 'Completed' : status);
    
    // Status Logic for A, MP, HD, P/D, P
    if (status == 'A') {
      statusText = "Absent";
      statusColor = primaryRed;
    } else if (status == 'MP' || (inTime != "--:--" && outTime == "--:--")) {
      statusText = "MP";
      statusColor = primaryRed;
    } else if (status == 'A' || status == 'Absent') { 
      statusColor = primaryRed; 
      statusText = "Absent"; 
    } else if (status == 'HD' || status == 'Half Day') { 
      statusColor = warningOrange; 
      statusText = "Half Day"; 
    } else if (status == 'P/D') {
      statusColor = warningOrange;
      statusText = "Late P";
    } else if (status == 'P' || status == 'Present') {
      statusColor = successGreen;
      statusText = "Present";
    }

    final String zone = (data['Zone'] ?? data['zone'] ?? '').toString();
    final bool hasCoords = zone.contains(',') && RegExp(r'[0-9]').hasMatch(zone);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: premiumCardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: bodyBg, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                Text(DateFormat('dd').format(date), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textHeading)),
                Text(DateFormat('MMM').format(date).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isTeam)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: primaryBlue)),
                  ),
                Row(
                  children: [
                    Text(inTime, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textHeading)),
                    const Text(" - ", style: TextStyle(color: textMuted)),
                    Text(outTime, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textHeading)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: textMuted),
                    const SizedBox(width: 4),
                    Text("Duration: $duration", style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10)),
              ),
              if (hasCoords)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: InkWell(
                    onTap: () => _openSatelliteMap(zone),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: accentBlue, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.map_rounded, size: 16, color: primaryBlue),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }

  DateTime? _parseTime(dynamic timeStr) {
    if (timeStr == null) return null;
    try {
      final s = timeStr.toString();
      if (s.contains(':')) {
        final p = s.split(':');
        return DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
      }
      return DateTime.tryParse(s);
    } catch (e) { return null; }
  }

  void _openSatelliteMap(String? zone) async {
    if (zone == null || !zone.contains(',')) return;
    try {
      final parts = zone.split(',');
      final lat = parts[0].trim();
      final lng = parts[1].trim();
      final url = Uri.parse('http://maps.google.com/maps?t=k&q=loc:$lat+$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Map Launch Error: $e");
    }
  }

  Widget _emptyState() => Center(child: Column(children: [const SizedBox(height: 60), Icon(Icons.history_rounded, size: 80, color: textMuted.withValues(alpha: 0.1)), const SizedBox(height: 16), const Text("No records found", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))]));
}
