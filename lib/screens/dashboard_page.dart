import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';
import '../models/user_model.dart';
import '../services/collection_api_service.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import '../services/target_service.dart';
import '../services/sync_service.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';

import 'login_page.dart';
import 'attendance_dashboard.dart';
import 'collection_dashboard_page.dart';
import 'executive_monitoring_page.dart';
import 'case_list_screen.dart';
import 'action_breakdown_screen.dart';
import 'efficiency_breakdown_screen.dart';
import 'task_center_screen.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback onChanged;
  final UserModel? user;

  const DashboardPage({super.key, required this.onChanged, this.user});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> dashboardDataFuture;
  Future<double> todayDistanceFuture = Future.value(0.0);
  UserModel? currentUser;
  bool isPunchedIn = false;
  String? punchInTime;
  String? punchOutTime;

  Map<String, dynamic> filters = {
    'resolution_status': 'ALL',
    'case_category': 'ALL',
    'allocation_type': 'ALL',
  };

  Map<String, int> outcomeCounts = {
    'v_done': 0, 'v_skip': 0, 'v_shift': 0,
    'p_done': 0, 'p_skip': 0, 'p_shift': 0,
  };

  Map<String, dynamic> enhancedStats = {
    'overdueFollowupCount': 0,
    'allocated': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'yetToVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'inProgress': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'completed': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'jointVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'totalPtp': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'totalVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'visitsDone': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'totalOverdue': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'totalEmi': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'xBkt': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'zeroToNinetyBkt': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'delinquentBkt': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'skipVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'skipPtp': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'shiftVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'shiftPtp': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'todayVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'todayPtp': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'rollBack': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'monthly_distance': {'count': '0.0 KM', 'coll': 0.0, 'due': 0.0},
    'efficiency_breakdown': {
      'regular': {},
      'od': {},
      'delinquent': {},
      'nonStarter': {},
      'rollBack': {},
      'overall': {},
    },
  };

  List<TaskModel> myTasks = [];
  Map<String, dynamic>? targetMasterData;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    // Pre-initialize to avoid LateInitializationError
    dashboardDataFuture = Future.value({});
    _init();
    CollectionApiService.syncPendingVisits();
  }

  Future<void> _init() async {
    final bool stale = await _loadCachedData();
    if (stale) {
      _loadData();
    } else {
      // If not stale, we still need to set the future for the UI if it's currently dummy
      setState(() {
        dashboardDataFuture = CollectionApiService.fetchDashboardData();
      });
    }
    SyncService().checkScheduledSync();
  }

  Future<bool> _loadCachedData() async {
    final cachedFull = await CollectionApiService.loadFromCacheFull("dashboard_stats");
    final cachedOutcomes = await CollectionApiService.loadOutcomeCounts();
    final cachedDashboard = await CollectionApiService.loadFromCache("dashboard_data");

    if (mounted) {
      setState(() {
        if (cachedFull != null) enhancedStats.addAll(Map<String, dynamic>.from(cachedFull['data']));
        if (cachedOutcomes != null) outcomeCounts = Map<String, int>.from(cachedOutcomes);
        if (cachedDashboard != null) {
          dashboardDataFuture = Future.value(Map<String, dynamic>.from(cachedDashboard));
        }
      });
    }
    return cachedFull == null || CollectionApiService.isCacheStale(cachedFull['ts'], hours: 5);
  }

  void _loadData() async {
    setState(() {
      isSyncing = true;
      dashboardDataFuture = CollectionApiService.fetchDashboardData();
    });

    // Priority 1: Main Stats (Fast)
    final coreTasks = [
      CollectionApiService.fetchOutcomeCounts().then((counts) {
        if (mounted) {
          setState(() => outcomeCounts = counts);
          CollectionApiService.saveOutcomeCounts(counts);
        }
      }),
      dashboardDataFuture,
    ];

    // Priority 2: Detailed Data (Slow)
    final heavyTasks = [
      CollectionApiService.fetchEnhancedDashboardStats().then((stats) {
        if (mounted && stats.isNotEmpty) {
          setState(() {
            enhancedStats.addAll(stats);
          });
          CollectionApiService.saveDashboardStats(stats);
        }
      }),
      CollectionApiService.fetchMyTasks().then((tasks) {
        if (mounted) setState(() => myTasks = tasks);
      }),
      TargetService.fetchTargetMasters().then((target) {
        if (mounted) setState(() => targetMasterData = target);
      }),
      _checkAttendance(),
      _loadInitialDistance(),
    ];

    // Hide Syncing indicator as soon as Priority 1 is done
    Future.wait(coreTasks).then((_) {
      if (mounted) setState(() => isSyncing = false);
    });

    // Heavy tasks run silently in background
    Future.wait(heavyTasks).catchError((e) {
      debugPrint("Heavy Background Task Error: $e");
    });
  }

  Future<void> _loadInitialDistance() async {
    if (currentUser == null) await _loadUser();
    if (currentUser != null) {
      final km = await LocationService().fetchMonthlyDistance(currentUser!.id);
      if (mounted) {
        setState(() => enhancedStats['monthly_distance'] = {
          'count': "${FormatUtils.safeFixed(km, 1)} KM", 
          'coll': 0.0, 
          'due': 0.0
        });
      }
    }
  }

  Future<void> _checkAttendance() async {
    bool status = false;
    String? pIn;
    String? pOut;
    
    try {
      final summary = await AttendanceService().getAttendanceSummary();
      status = summary['is_punched_in'] == 1 || summary['is_punched_in'] == true;
      pIn = summary['punch_in'];
      pOut = summary['punch_out'];
    } catch (e) {
      status = await AttendanceService().isPunchedIn();
    }
    
    // Fallback to local data if server times are missing
    if (pIn == null) {
      final local = await AttendanceService().getTodayAttendance();
      if (local != null) {
        pIn = local['punch_in'];
        pOut = local['punch_out'];
      }
    }

    if (mounted) {
      setState(() {
        isPunchedIn = status;
        punchInTime = _formatTime(pIn);
        punchOutTime = _formatTime(pOut);
      });
    }
  }

  String? _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == 'null') return null;
    try {
      // Check if it's already a time string like "09:30 AM"
      if (timeStr.contains('AM') || timeStr.contains('PM')) return timeStr;
      
      final dt = DateTime.tryParse(timeStr);
      if (dt != null) return DateFormat('hh:mm a').format(dt);
      
      // Try parsing HH:mm:ss
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
         final h = int.parse(parts[0]);
         final m = int.parse(parts[1]);
         final d = DateTime(2000, 1, 1, h, m);
         return DateFormat('hh:mm a').format(d);
      }
    } catch (e) {}
    return timeStr;
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUserData();
    if (user != null && mounted) {
      setState(() {
        currentUser = user;
        // Add role-based filter to global filters map for accurate drilling down
        final String role = user.role.toLowerCase();
        if (role.contains('tl')) {
          filters['tl_name'] = user.name;
        } else if (role.contains('acm') || role.contains('manager')) {
          filters['acm_name'] = user.name;
        } else {
          // Default for Executive or others: isolation by exe_name
          filters['exe_name'] = user.name;
        }
      });
    }
  }

  Future<void> loadCases() async {
    setState(() => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
          await dashboardDataFuture;
        },
        color: primaryBlue,
        child: FutureBuilder<Map<String, dynamic>>(
          future: dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && enhancedStats['allocated']?['count'] == 0) {
              return const Center(child: CircularProgressIndicator(color: primaryBlue));
            }

            final Map<String, dynamic> data = snapshot.data ?? {};
            final Map<String, dynamic> summary = data['summary'] != null ? Map<String, dynamic>.from(data['summary']) : {};
            
            return CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildFinAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildWelcomeHeader(),
                      const SizedBox(height: 20),
                      _buildEnhancedSummaryGrid(),
                      const SizedBox(height: 32),
                      _buildCollectionEfficiencySection(),
                      const SizedBox(height: 32),
                      _buildVisitPtpStatusGrid(),
                      const SizedBox(height: 32),
                      _buildTargetCard(summary),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedSummaryGrid() {
    final now = CollectionApiService.istNow;
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";

    return Column(
      children: [
        _enhancedBox("Total Allocated", enhancedStats['allocated'], const Color(0xFFF8BBD0), const Color(0xFFC2185B), 
          onTap: () => _open("Total Allocated Portfolio", {}), isFullWidth: true, showPOS: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Pending Visit (Month)", enhancedStats['yetToVisit'], const Color(0xFFC8E6C9), const Color(0xFF2E7D32),
              onTap: () => _open("Pending Visit (Month)", {'yet_to_visit': '1', 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("In Progress (Month)", enhancedStats['inProgress'], const Color(0xFFBBDEFB), const Color(0xFF1565C0),
              onTap: () => _open("In Progress (Visited/Unpaid)", {'in_progress': '1', 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Completed (Paid)", enhancedStats['completed'], const Color(0xFFFFCCBC), const Color(0xFFD84315),
              onTap: () => _open("Completed (Paid)", {'resolution_status': 'paid'}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Distance (Month)", enhancedStats['monthly_distance'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _openTeamMonitoring())),
          ],
        ),
      ],
    );
  }

  void _open(String title, Map<String, dynamic> f, {bool isVisitList = false}) {
    debugPrint("Dashboard Opening: $title with filters: $f");
    Map<String, dynamic> merged = Map.from(filters);
    merged.addAll(f);
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => CaseListScreen(
      title: title, 
      filters: merged, 
      isVisitList: isVisitList,
      refresh: _loadData
    )));
  }

  Widget _enhancedBox(String title, Map<String, dynamic>? data, Color bg, Color text, {VoidCallback? onTap, bool isFullWidth = false, bool showPOS = false}) {
    final stats = data ?? {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0};
    final double posAch = (stats['pos_ach'] ?? 0.0).toDouble();
    final double posTotal = (stats['pos_total'] ?? 0.0).toDouble();
    final double posPerc = posTotal > 0 ? (posAch / posTotal) * 100 : 0.0;

    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kGlassRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kGlassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: bg.withValues(alpha: 0.15), 
            child: InkWell(
              onTap: () {
                if (onTap != null) {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              },
              splashColor: text.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                          const SizedBox(height: 6),
                          Text("${stats['count']}", style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _miniLabel("Coll", "₹${_format(stats['coll'])}", text),
                              const SizedBox(width: 16),
                              _miniLabel("Due", "₹${_format(stats['due'])}", text),
                            ],
                          ),
                          if (showPOS) ...[
                            const SizedBox(height: 8),
                            Text("POS ACHIEVED: ${posPerc.toStringAsFixed(1)}%", style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Icon(CupertinoIcons.chevron_right_circle_fill, color: text.withValues(alpha: 0.3), size: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniLabel(String label, String val, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: TextStyle(color: c.withValues(alpha: 0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
      Text(val, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
    ],
  );

  Widget _buildCollectionEfficiencySection() {
    final eff = enhancedStats['efficiency'] as Map<String, dynamic>?;
    if (eff == null) return const SizedBox.shrink();

    // Extract bucket-wise targets from master data
    dynamic rawTarget = targetMasterData;
    if (rawTarget is List && rawTarget.isNotEmpty) rawTarget = rawTarget.first;

    final double? regTgt = double.tryParse((rawTarget?['x bkr'] ?? rawTarget?['x_bkr']).toString());
    final double? odTgt = double.tryParse((rawTarget?['0-90']).toString());
    final double? delTgt = double.tryParse((rawTarget?['91-180']).toString());
    final double? overallTgt = double.tryParse((rawTarget?['pos_ach']).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.analytics_rounded, color: primaryRed, size: 18),
            SizedBox(width: 8),
            Text("Collection Efficiency", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: premiumCardDecoration(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _efficiencyCircle(
                      "Regular", 
                      eff['regular']['percentage'], 
                      eff['regular']['count'], 
                      "Regular\n(X-BKT)",
                      onTap: () => _openEfficiencyBreakdown("Regular Breakdown (X-BKT)", "regular"),
                      posPercentage: (eff['regular']['pos_total'] > 0) ? (eff['regular']['pos_ach'] / eff['regular']['pos_total'] * 100) : 0.0,
                      target: regTgt,
                    ),
                  ),
                  Expanded(
                    child: _efficiencyCircle(
                      "0-90", 
                      eff['od']['percentage'], 
                      eff['od']['count'], 
                      "0-90\nAccount",
                      onTap: () => _openEfficiencyBreakdown("0-90 Account Breakdown", "od"),
                      posPercentage: (eff['od']['pos_total'] > 0) ? (eff['od']['pos_ach'] / eff['od']['pos_total'] * 100) : 0.0,
                      target: odTgt,
                    ),
                  ),
                  Expanded(
                    child: _efficiencyCircle(
                      "Delinquent", 
                      eff['delinquent']['percentage'], 
                      eff['delinquent']['count'], 
                      "Delinquent\nAccount",
                      onTap: () => _openEfficiencyBreakdown("Delinquent Breakdown (90+)", "delinquent"),
                      posPercentage: (eff['delinquent']['pos_total'] > 0) ? (eff['delinquent']['pos_ach'] / eff['delinquent']['pos_total'] * 100) : 0.0,
                      target: delTgt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _efficiencyCircle(
                      "Roll Back", 
                      eff['rollBack']['percentage'], 
                      eff['rollBack']['count'], 
                      "Roll Back\nAccount",
                      onTap: () => _openEfficiencyBreakdown("Roll Back Breakdown", "rollBack"),
                      posPercentage: (eff['rollBack']['pos_total'] > 0) ? (eff['rollBack']['pos_ach'] / eff['rollBack']['pos_total'] * 100) : 0.0,
                    ),
                  ),
                  Expanded(
                    child: _efficiencyCircle(
                      "Non-Starter", 
                      eff['nonStarter']['percentage'], 
                      eff['nonStarter']['count'], 
                      "Non-Starter\nAccount",
                      onTap: () => _openEfficiencyBreakdown("Non-Starter Breakdown", "nonStarter"),
                      posPercentage: (eff['nonStarter']['pos_total'] > 0) ? (eff['nonStarter']['pos_ach'] / eff['nonStarter']['pos_total'] * 100) : 0.0,
                    ),
                  ),
                  Expanded(
                    child: _efficiencyCircle(
                      "Overall", 
                      eff['overall']['percentage'], 
                      eff['overall']['count'], 
                      "Overall\nEfficiency",
                      onTap: () => _openEfficiencyBreakdown("Overall Breakdown", "overall"),
                      posPercentage: (eff['overall']['pos_total'] > 0) ? (eff['overall']['pos_ach'] / eff['overall']['pos_total'] * 100) : 0.0,
                      target: overallTgt,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
    );
  }

  Widget _buildVisitPtpStatusGrid() {
    final now = CollectionApiService.istNow;
    final today = DateFormat('yyyy-MM-dd').format(now);
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: primaryRed, size: 18),
            SizedBox(width: 8),
            Text("Visit & PTP Tracking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _enhancedBox("Skip Visit", enhancedStats['skipVisit'], const Color(0xFFFFEBEE), const Color(0xFFC62828),
              onTap: () => _open("Skip Visit Portfolio", {'calling_remark': 'visit', 'max_projection_date': today, 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Skip PTP", enhancedStats['skipPtp'], const Color(0xFFFFEBEE), const Color(0xFFC62828),
              onTap: () => _open("Skip PTP Portfolio", {'calling_remark': 'ptp', 'max_projection_date': today, 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Today PTP", enhancedStats['todayPtp'], const Color(0xFFE3F2FD), const Color(0xFF1565C0),
              onTap: () => _open("Today PTP List", {'calling_remark': 'ptp', 'projection_date': today, 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Shift Visit", enhancedStats['shiftVisit'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _open("Shift Visit Portfolio", {'calling_remark': 'visit', 'min_projection_date': today, 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Shift PTP", enhancedStats['shiftPtp'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _open("Shift PTP Portfolio", {'calling_remark': 'ptp', 'min_projection_date': today, 'start_date': monthStart}))),
          ],
        ),
      ],
    );
  }


  Widget _efficiencyCircle(String key, double percentage, int count, String label, {VoidCallback? onTap, double posPercentage = 0.0, double? target}) {
  double gap = (target ?? 0) - posPercentage;
  
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 75, height: 75,
                child: CircularProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: bodyBg,
                  color: primaryRed,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    percentage > 0 ? "${(percentage > 100 ? 100 : percentage).toStringAsFixed(1)}%" : "0%",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: textHeading),
                  ),
                  Text(
                    "POS:${posPercentage.toStringAsFixed(1)}%",
                    style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: primaryBlue),
                  ),
                  if (target != null)
                    Text(
                      "TGT:${target.toStringAsFixed(0)}%",
                      style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: textMuted),
                    ),
                ],
              ),
            ],
          ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted, height: 1.1),
            ),
            if (target != null && gap > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  "${gap.toStringAsFixed(1)}% SHORT",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: primaryRed),
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: bodyBg, borderRadius: BorderRadius.circular(6)),
              child: Text(
                "$count Cs",
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textHeading),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFinAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: bodyBg.withValues(alpha: 0.8),
      elevation: 0,
      pinned: true,
      centerTitle: true,
      leading: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Scaffold.of(context).openDrawer();
        },
        icon: const Icon(CupertinoIcons.bars, color: textHeading, size: 24),
      ),
      title: const Text("SAFL BUSINESS", style: TextStyle(color: textHeading, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2)),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => TaskCenterScreen(onRefresh: _loadData)));
              }, 
              icon: const Icon(CupertinoIcons.square_list_fill, color: textHeading, size: 22)
            ),
            if (myTasks.isNotEmpty)
              Positioned(
                top: 12, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: primaryBlue, shape: BoxShape.circle),
                  child: Text(
                    "${myTasks.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                if (enhancedStats['overdueFollowupCount'] > 0) {
                  _open("Overdue Follow-ups", {'followup_overdue': '1'});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No overdue follow-ups"), duration: Duration(seconds: 1))
                  );
                }
              }, 
              icon: const Icon(CupertinoIcons.bell_fill, color: textHeading, size: 22)
            ),
            if (enhancedStats['overdueFollowupCount'] > 0)
              Positioned(
                top: 12, right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: primaryRed, shape: BoxShape.circle),
                  child: Text(
                    "${enhancedStats['overdueFollowupCount']}",
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    String displayName = currentUser?.name ?? 'User';
    if (displayName.toLowerCase() == 'user' || displayName.isEmpty) displayName = 'Welcome';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(), style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      if (isSyncing) ...[
                        const SizedBox(width: 8),
                        const SizedBox(height: 8, width: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: textMuted)),
                        const SizedBox(width: 4),
                        const Text("SYNCING...", style: TextStyle(color: textMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("$displayName", style: const TextStyle(color: textHeading, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
                ],
              ),
            ),
            if (punchInTime != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: successGreen.withValues(alpha: 0.2)),
                ),
                child: Text("IN: $punchInTime", style: const TextStyle(color: successGreen, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> s) {
    // Determine the target source from target-masters API
    dynamic rawTarget = targetMasterData;
    if (rawTarget is List && rawTarget.isNotEmpty) {
      rawTarget = rawTarget.first;
    }

    // 1. Actual POS Achievement from our enhanced calculations
    final overallEff = enhancedStats['efficiency']?['overall'] ?? {};
    double currentPosAch = double.tryParse((overallEff['pos_percentage'] ?? 0).toString()) ?? 0.0;
    
    if (currentPosAch == 0) {
      currentPosAch = double.tryParse((s['pos_achieve_percentage'] ?? 0).toString()) ?? 0.0;
    }
    
    // 2. Target POS Achievement (using 'pos_ach' as specified by user)
    double targetPosAch = double.tryParse((rawTarget?['pos_ach'] ?? 
                                         rawTarget?['pos_target'] ?? 
                                         50.0).toString()) ?? 50.0;

    // 3. Month Name (using 'target_month' as specified by user)
    String targetMonth = (rawTarget?['target_month'] ?? rawTarget?['month'] ?? 'Current Month').toString();

    // 4. Shortfall/Gap Calculation
    double gap = targetPosAch - currentPosAch;
    if (gap < 0) gap = 0;

    // 5. Progress ratio
    double progressRatio = targetPosAch > 0 ? (currentPosAch / targetPosAch) * 100 : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$targetMonth POS Target", style: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
              if (gap > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text("${gap.toStringAsFixed(1)}% SHORT", style: const TextStyle(color: primaryRed, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text("${targetPosAch.toStringAsFixed(1)}%", style: const TextStyle(color: successGreen, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Actual Achievement", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text("${currentPosAch.toStringAsFixed(1)}%", style: const TextStyle(color: textHeading, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Gap to Target", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text("${gap.toStringAsFixed(1)}%", style: TextStyle(color: gap > 0 ? primaryRed : successGreen, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (progressRatio / 100).clamp(0.0, 1.0),
              backgroundColor: gap > 0 ? primaryRed.withValues(alpha: 0.1) : successGreen.withValues(alpha: 0.1),
              color: gap > 0 ? warningOrange : successGreen,
              minHeight: 8,
            ),
          ),
          if (gap > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Need ${gap.toStringAsFixed(1)}% more to reach $targetMonth goal", style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textHeading)),
        Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue)),
      ],
    );
  }

  Widget _buildOverviewGrid(Map<String, dynamic> s, Map<String, dynamic> v, Map<String, dynamic> f) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _overviewBox("Allocated Cases", "${s['total_cases'] ?? 0}", Icons.folder_rounded, primaryBlue, 
          () => _open('Allocated Portfolio', {})),
        _overviewBox("Visits Done", "${v['today_visits'] ?? 0}", Icons.directions_run_rounded, Colors.purple, 
          () => _open('Visits Done Today', {'today_entry_date': todayStr}, isVisitList: true)),
        FutureBuilder<double>(
          future: todayDistanceFuture,
          builder: (context, snap) {
            final dist = snap.data ?? 0.0;
            return _overviewBox("Today's Distance", "${dist.toStringAsFixed(1)} KM", Icons.route_rounded, successGreen, 
              () => _openTeamMonitoring());
          },
        ),
        _overviewBox("PTP Due Today", "${f['today'] ?? 0}", Icons.calendar_month_rounded, warningOrange, 
          () => _open("Today's PTP Cases", {'calling_remark': 'ptp', 'next_ptp': todayStr})),
      ],
    );
  }

  Widget _buildOutcomeGrid(Map<String, dynamic> v) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Column(
      children: [
        _outcomeSectionHeader("Visit Outcomes"),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            _outcomeTile("Done", "${outcomeCounts['v_done']}", successGreen, {'visit_done': 'done', 'calling_remark': 'visit', 'date': todayStr}, isVisitList: true),
            _outcomeTile("Skip", "${outcomeCounts['v_skip']}", primaryRed, {'visit_done': 'skip', 'calling_remark': 'visit'}, isVisitList: true),
            _outcomeTile("Shift", "${outcomeCounts['v_shift']}", warningOrange, {'visit_done': 'shift', 'calling_remark': 'visit'}, isVisitList: true),
          ],
        ),
        const SizedBox(height: 24),
        _outcomeSectionHeader("PTP Outcomes"),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            _outcomeTile("Done", "${outcomeCounts['p_done']}", successGreen, {'visit_done': 'done', 'calling_remark': 'ptp', 'date': todayStr}, isVisitList: true),
            _outcomeTile("Skip", "${outcomeCounts['p_skip']}", primaryRed, {'visit_done': 'skip', 'calling_remark': 'ptp'}, isVisitList: true),
            _outcomeTile("Shift", "${outcomeCounts['p_shift']}", warningOrange, {'visit_done': 'shift', 'calling_remark': 'ptp'}, isVisitList: true),
          ],
        ),
      ],
    );
  }

  Widget _outcomeSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textHeading)),
      ],
    );
  }

  Widget _outcomeTile(String label, String val, Color color, Map<String, dynamic> filter, {bool isVisitList = false}) {
    return InkWell(
      onTap: () => _open(label, filter, isVisitList: isVisitList),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _openEfficiencyBreakdown(String title, String type) {
    final breakdown = enhancedStats['efficiency_breakdown']?[type];
    if (breakdown == null || breakdown.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data is still loading, please wait..."), duration: Duration(seconds: 1))
      );
      return;
    }

    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => EfficiencyBreakdownScreen(
          title: title, 
          data: Map<String, dynamic>.from(breakdown), 
          type: type,
          refresh: _loadData,
        )
      )
    );
  }

  void _openTeamMonitoring() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExecutiveMonitoringPage()));
  }

  Widget _overviewBox(String label, String val, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: premiumCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color.withValues(alpha: 0.2), size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceRow(Map<String, dynamic> s, Map<String, dynamic> v) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Row(
      children: [
        Expanded(child: InkWell(
          onTap: () => _open('Calls Done Today', {'calling_date': todayStr}),
          borderRadius: BorderRadius.circular(16),
          child: _perfCard("Calls Done", "${v['calling'] ?? 0}", Icons.call_rounded, primaryBlue),
        )),
        const SizedBox(width: 12),
        Expanded(child: InkWell(
          onTap: () => _open('Visits Done Today', {'today_entry_date': todayStr}, isVisitList: true),
          borderRadius: BorderRadius.circular(16),
          child: _perfCard("Visits Done", "${v['today_visits'] ?? 0}", Icons.pin_drop_rounded, successGreen),
        )),
      ],
    );
  }

  Widget _perfCard(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: premiumCardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
              Text(label, style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRecoveryRow(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: successGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Recovery Today", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text("₹42,500", style: TextStyle(color: successGreen, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("vs Yesterday", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: successGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text("+12%", style: TextStyle(color: successGreen, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(dynamic v) {
    return FormatUtils.safeFormat(v);
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
                _drawerTile('Dashboard', Icons.grid_view_rounded, true, () => Navigator.pop(context)),
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
