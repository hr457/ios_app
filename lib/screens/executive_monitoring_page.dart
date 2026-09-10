import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/executive_status.dart';
import 'case_list_screen.dart';
import 'efficiency_breakdown_screen.dart';
import 'executive_details_page.dart';
import 'map_tracking_page.dart';
import '../services/executive_service.dart';
import '../services/collection_api_service.dart';
import '../services/auth_service.dart';
import '../services/target_service.dart';
import '../utils/app_colors.dart';
import 'attendance_dashboard.dart';
import 'collection_dashboard_page.dart';
import 'login_page.dart';
import '../utils/format_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExecutiveMonitoringPage extends StatefulWidget {
  final String? filterTlName;
  const ExecutiveMonitoringPage({super.key, this.filterTlName});

  @override
  State<ExecutiveMonitoringPage> createState() => _ExecutiveMonitoringPageState();
}

class _ExecutiveMonitoringPageState extends State<ExecutiveMonitoringPage> {
  late Future<List<dynamic>> futureData;
  bool isShowingTls = true;
  dynamic currentUser;

  Map<String, dynamic> enhancedStats = {
    'allocated': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'yetToVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'inProgress': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'completed': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'jointVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'totalPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'totalVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'visitsDone': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'totalOverdue': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'totalEmi': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'xBkt': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'zeroToNinetyBkt': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'delinquentBkt': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'skipVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'skipPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'shiftVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'shiftPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'todayVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'todayPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'rollBack': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
    'efficiency': {
      'regular': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
      'od': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
      'delinquent': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
      'nonStarter': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
      'overall': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
      'rollBack': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
    },
    'monthly_distance': {'count': '0.0 KM', 'coll': 0.0, 'due': 0.0},
    'efficiency_breakdown': {
      'regular': {}, 'od': {}, 'delinquent': {}, 'nonStarter': {}, 'rollBack': {}, 'overall': {},
    },
  };

  Map<String, dynamic>? targetMasterData;

  @override
  void initState() {
    super.initState();
    isShowingTls = widget.filterTlName == null;
    futureData = Future.value([]); // Avoid LateInitializationError
    _refresh();
    _loadUser();
  }

  void _refresh() {
    final String? role = currentUser?.role?.toLowerCase();
    String? tlFilter = widget.filterTlName;
    
    // If TL logs in, they should see their team based on their name
    if (role != null && role.contains('tl') && tlFilter == null) {
      tlFilter = currentUser.name; 
    }

    setState(() {
      if (isShowingTls) {
        futureData = ExecutiveService.fetchTlSummaries();
      } else {
        futureData = ExecutiveService.fetchExecutives(tlName: tlFilter);
        _loadEnhancedStats(tlFilter);
      }
    });
  }

  void _loadEnhancedStats(String? tlName) async {
    Future.wait<dynamic>([
      CollectionApiService.fetchEnhancedDashboardStats(filters: tlName != null ? {'tl_name': tlName} : {}),
      TargetService.fetchTargetMasters(),
    ]).then((results) {
      if (mounted) {
        setState(() {
          enhancedStats.addAll(results[0] as Map<String, dynamic>);
          targetMasterData = results[1] as Map<String, dynamic>?;
        });
      }
    });
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUserData();
    if (user != null && mounted) {
      setState(() {
        currentUser = user;
        final role = user.role.toLowerCase();
        
        // If regular executive (not admin/tl/acm), skip TL list and show their own card
        if (!role.contains('admin') && !role.contains('tl') && !role.contains('acm')) {
          isShowingTls = false;
          _refresh();
        }

        // If TL, skip TL summary list and show their team immediately
        if (role.contains('tl') && widget.filterTlName == null) {
          isShowingTls = false;
          // Important: We need to use the user's name as the TL filter
          futureData = ExecutiveService.fetchExecutives(tlName: user.name);
        }

        // If ACM, they might want to see TLs first, so we can keep isShowingTls = true
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(
          isShowingTls ? 'EXECUTIVE MONITORING' : 'TEAM: ${widget.filterTlName ?? currentUser?.name ?? ''}', 
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: Icon(CupertinoIcons.bars, size: 24),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _refresh();
            }, 
            icon: Icon(CupertinoIcons.arrow_2_circlepath, color: primaryBlue, size: 20)
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryBlue));
          }
          
          final list = snapshot.data ?? [];
          if (list.isEmpty && snapshot.connectionState == ConnectionState.done) return _buildEmptyState();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              if (list.isNotEmpty)
                SliverToBoxAdapter(child: _buildSummaryHeader(list)),
              
              if (!isShowingTls && list.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text("Team Performance Dashboard", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
                      const SizedBox(height: 16),
                      _buildEnhancedSummaryGrid(),
                      const SizedBox(height: 32),
                      _buildCollectionEfficiencySection(),
                      const SizedBox(height: 32),
                      _buildVisitPtpStatusSection(),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text("Individual Team Members", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = list[index];
                      return isShowingTls 
                        ? _buildTlCard(item) 
                        : _buildExecutiveCard(item as ExecutiveStatus);
                    },
                    childCount: list.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnhancedSummaryGrid() {
    final now = CollectionApiService.istNow;
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final tlFilter = {'tl_name': widget.filterTlName ?? currentUser?.name};

    return Column(
      children: [
        _enhancedBox("Total Allocated", enhancedStats['allocated'], const Color(0xFFF8BBD0), const Color(0xFFC2185B), 
          onTap: () => _openCases("Team Portfolio", tlFilter), isFullWidth: true, showPOS: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Pending Visit (Month)", enhancedStats['yetToVisit'], const Color(0xFFC8E6C9), const Color(0xFF2E7D32),
              onTap: () => _openCases("Pending Visit (Month)", {...tlFilter, 'yet_to_visit': '1', 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("In Progress (Month)", enhancedStats['inProgress'], const Color(0xFFBBDEFB), const Color(0xFF1565C0),
              onTap: () => _openCases("In Progress (Visited/Unpaid)", {...tlFilter, 'in_progress': '1', 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Completed (Paid)", enhancedStats['completed'], const Color(0xFFFFCCBC), const Color(0xFFD84315),
              onTap: () => _openCases("Completed (Paid)", {...tlFilter, 'resolution_status': 'paid'}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Distance (Month)", enhancedStats['monthly_distance'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: null)),
          ],
        ),
      ],
    );
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kGlassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: bg.withValues(alpha: 0.12),
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
                              _miniLabel("Coll", "₹${_formatNum(stats['coll'])}", text),
                              const SizedBox(width: 16),
                              _miniLabel("Due", "₹${_formatNum(stats['due'])}", text),
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
      Text(val, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800)),
    ],
  );

  Widget _buildCollectionEfficiencySection() {
    final eff = enhancedStats['efficiency'] as Map<String, dynamic>?;
    if (eff == null) return const SizedBox.shrink();

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
            Text("Collection Efficiency (Team)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
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
                    child: _efficiencyCircle("Regular", eff['regular']['percentage'], eff['regular']['count'], "Regular\n(X-BKT)", 
                      onTap: () => _openEfficiencyBreakdown("Team Regular Breakdown", "regular"),
                      posPercentage: (eff['regular']['pos_total'] > 0) ? (eff['regular']['pos_ach'] / eff['regular']['pos_total'] * 100) : 0.0,
                      target: regTgt),
                  ),
                  Expanded(
                    child: _efficiencyCircle("0-90", eff['od']['percentage'], eff['od']['count'], "0-90\nAccount", 
                      onTap: () => _openEfficiencyBreakdown("Team 0-90 Breakdown", "od"),
                      posPercentage: (eff['od']['pos_total'] > 0) ? (eff['od']['pos_ach'] / eff['od']['pos_total'] * 100) : 0.0,
                      target: odTgt),
                  ),
                  Expanded(
                    child: _efficiencyCircle("Delinquent", eff['delinquent']['percentage'], eff['delinquent']['count'], "Delinquent\nAccount", 
                      onTap: () => _openEfficiencyBreakdown("Team Delinquent Breakdown", "delinquent"),
                      posPercentage: (eff['delinquent']['pos_total'] > 0) ? (eff['delinquent']['pos_ach'] / eff['delinquent']['pos_total'] * 100) : 0.0,
                      target: delTgt),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _efficiencyCircle("Roll Back", eff['rollBack']['percentage'], eff['rollBack']['count'], "Roll Back\nAccount", 
                      onTap: () => _openEfficiencyBreakdown("Team Roll Back Breakdown", "rollBack"),
                      posPercentage: (eff['rollBack']['pos_total'] > 0) ? (eff['rollBack']['pos_ach'] / eff['rollBack']['pos_total'] * 100) : 0.0),
                  ),
                  Expanded(
                    child: _efficiencyCircle("Non-Starter", eff['nonStarter']['percentage'], eff['nonStarter']['count'], "Non-Starter\nAccount", 
                      onTap: () => _openEfficiencyBreakdown("Team Non-Starter Breakdown", "nonStarter"),
                      posPercentage: (eff['nonStarter']['pos_total'] > 0) ? (eff['nonStarter']['pos_ach'] / eff['nonStarter']['pos_total'] * 100) : 0.0),
                  ),
                  Expanded(
                    child: _efficiencyCircle("Overall", eff['overall']['percentage'], eff['overall']['count'], "Overall\nEfficiency", 
                      onTap: () => _openEfficiencyBreakdown("Team Overall Breakdown", "overall"),
                      posPercentage: (eff['overall']['pos_total'] > 0) ? (eff['overall']['pos_ach'] / eff['overall']['pos_total'] * 100) : 0.0,
                      target: overallTgt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitPtpStatusSection() {
    final now = CollectionApiService.istNow;
    final today = DateFormat('yyyy-MM-dd').format(now);
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final tlFilter = {'tl_name': widget.filterTlName ?? currentUser?.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: primaryRed, size: 18),
            SizedBox(width: 8),
            Text("Visit & PTP Tracking (Team)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textHeading)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _enhancedBox("Skip Visit", enhancedStats['skipVisit'], const Color(0xFFFFEBEE), const Color(0xFFC62828),
              onTap: () => _openCases("Team Skip Visit", {...tlFilter, 'calling_remark': 'visit', 'max_projection_date': today, 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Skip PTP", enhancedStats['skipPtp'], const Color(0xFFFFEBEE), const Color(0xFFC62828),
              onTap: () => _openCases("Team Skip PTP", {...tlFilter, 'calling_remark': 'ptp', 'max_projection_date': today, 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Today PTP", enhancedStats['todayPtp'], const Color(0xFFE3F2FD), const Color(0xFF1565C0),
              onTap: () => _openCases("Team Today PTP", {...tlFilter, 'calling_remark': 'ptp', 'projection_date': today, 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Shift Visit", enhancedStats['shiftVisit'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _openCases("Team Shift Visit", {...tlFilter, 'calling_remark': 'visit', 'min_projection_date': today, 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Shift PTP", enhancedStats['shiftPtp'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _openCases("Team Shift PTP", {...tlFilter, 'calling_remark': 'ptp', 'min_projection_date': today, 'start_date': monthStart}))),
          ],
        ),
      ],
    );
  }

  void _openEfficiencyBreakdown(String title, String type) {
    final breakdown = enhancedStats['efficiency_breakdown']?[type];
    if (breakdown == null || breakdown.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data is loading...")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => EfficiencyBreakdownScreen(title: title, data: Map<String, dynamic>.from(breakdown), type: type, refresh: _refresh)));
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
                  SizedBox(width: 75, height: 75, child: CircularProgressIndicator(value: (percentage / 100).clamp(0.0, 1.0), strokeWidth: 6, backgroundColor: bodyBg, color: primaryRed, strokeCap: StrokeCap.round)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(percentage > 0 ? "${percentage.toStringAsFixed(1)}%" : "0%", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: textHeading)),
                      Text("POS:${posPercentage.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: primaryBlue)),
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
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted, height: 1.1)),
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
                child: Text("$count Cs", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textHeading)),
              ),
            ],
          ),
        ),
      ),
    );
  }


  String _formatNum(dynamic v) => FormatUtils.safeFormat(v);

  Widget _buildSummaryHeader(List<dynamic> list) {
    int totalCases = 0;
    double totalColl = 0;
    
    for (var item in list) {
      if (item is ExecutiveStatus) {
        totalCases += item.totalCases;
        totalColl += item.todayCollection;
      } else {
        totalCases += (item['total_cases'] as num? ?? 0).toInt();
        totalColl += (item['total_received'] as num? ?? 0).toDouble();
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Team Members', '${list.length}', Icons.groups_outlined),
          _statItem('Total Cases', '$totalCases', Icons.assignment_outlined),
          _statItem('Total Rec.', '₹${_format(totalColl)}', Icons.payments_outlined),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTlCard(dynamic tl) {
    final String name = tl['name'] ?? 'TL Name';
    final int cases = (tl['total_cases'] ?? 0).toInt();
    final double received = (tl['total_received'] ?? 0.0).toDouble();
    final double ach = (tl['achievement_percentage'] ?? 0.0).toDouble();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExecutiveMonitoringPage(filterTlName: name),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: premiumCardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_pin_rounded, color: primaryBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textHeading)),
                      const Text("Team Leader", style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo("CASES", "$cases"),
                _miniInfo("COLLECTION", "₹${_format(received)}"),
                _miniInfo("ACHIEVEMENT", "${ach.toStringAsFixed(1)}%"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveCard(ExecutiveStatus ex) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExecutiveDetailsPage(executive: ex))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: premiumCardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: bodyBg,
                      child: const Icon(Icons.person_rounded, color: textMuted),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(color: ex.isOnline ? successGreen : textMuted, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                    )
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textHeading)),
                      Text("Dist: ${FormatUtils.safeFixed(ex.totalKm, 1)} KM", style: const TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${_format(ex.todayCollection)}", style: const TextStyle(color: successGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                    const Text("Collected Today", style: TextStyle(fontSize: 9, color: textMuted, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo("VISITS", "${ex.todayVisits}"),
                _miniInfo("TODAY PTP", "${ex.todayPtp}"),
                _miniInfo("CASES", "${ex.totalCases}"),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapTrackingPage(lat: ex.currentLat, lng: ex.currentLng, name: ex.name, executiveId: ex.id))),
                    icon: const Icon(Icons.location_on_rounded, size: 14),
                    label: const Text("LIVE TRACK", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: infoBlue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapTrackingPage(
                      lat: ex.currentLat, 
                      lng: ex.currentLng, 
                      name: ex.name, 
                      executiveId: ex.id,
                      initialHistoryMode: true,
                    ))),
                    icon: const Icon(Icons.history_rounded, size: 14),
                    label: const Text("TIMELINE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textHeading)),
      ],
    );
  }

  void _openCases(String title, Map<String, dynamic> filters, {bool isVisitList = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CaseListScreen(
      title: title, 
      filters: filters, 
      isVisitList: isVisitList,
      refresh: _refresh,
    )));
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.supervised_user_circle_rounded, size: 80, color: textMuted.withValues(alpha: 0.2)), const SizedBox(height: 16), const Text("No data found for this context", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))]));

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
                  Navigator.pop(context);
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
      await SharedPreferences.getInstance().then((p) => p.clear());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  String _format(dynamic v) {
    return FormatUtils.safeFormat(v);
  }
}
