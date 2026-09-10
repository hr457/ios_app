import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/executive_status.dart';
import '../services/collection_api_service.dart';
import '../services/target_service.dart';
import '../utils/app_colors.dart';
import 'map_tracking_page.dart';
import 'collection_dashboard_page.dart';
import 'case_list_screen.dart';
import 'efficiency_breakdown_screen.dart';
import '../utils/format_utils.dart';

class ExecutiveDetailsPage extends StatefulWidget {
  final ExecutiveStatus executive;

  const ExecutiveDetailsPage({super.key, required this.executive});

  @override
  State<ExecutiveDetailsPage> createState() => _ExecutiveDetailsPageState();
}

class _ExecutiveDetailsPageState extends State<ExecutiveDetailsPage> {
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
  bool isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    setState(() => isStatsLoading = true);

    Future.wait<dynamic>([
      CollectionApiService.fetchEnhancedDashboardStats(filters: {'exe_name': widget.executive.name}),
      TargetService.fetchTargetMasters(),
    ]).then((results) {
      if (mounted) {
        setState(() {
          enhancedStats.addAll(results[0] as Map<String, dynamic>);
          targetMasterData = results[1] as Map<String, dynamic>?;
          isStatsLoading = false;
        });
      }
    });

    // Also fetch monthly distance specifically for this executive
    final now = CollectionApiService.istNow;
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    CollectionApiService.fetchDashboardData(filters: {'exe_name': widget.executive.name, 'start_date': monthStart}).then((data) {
      if (mounted) {
        final summary = data['summary'] ?? {};
        setState(() {
          enhancedStats['monthly_distance'] = {
            'count': "${FormatUtils.safeFixed(summary['total_km'] ?? summary['distance'] ?? 0.0, 1)} KM", 
            'coll': 0.0, 
            'due': 0.0
          };
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fd),
      appBar: AppBar(
        title: Text(widget.executive.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(CupertinoIcons.back, size: 22),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildProfileHeader(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Executive Summary (Monthly)'),
                    const SizedBox(height: 12),
                    _buildEnhancedSummaryGrid(),
                    const SizedBox(height: 32),
                    _buildCollectionEfficiencySection(),
                    const SizedBox(height: 32),
                    _buildVisitPtpStatusSection(),
                    const SizedBox(height: 32),
                    _sectionTitle('Quick Actions'),
                    const SizedBox(height: 12),
                    _buildActionButtons(context),
                    const SizedBox(height: 24),
                    _sectionTitle('Visit & Payment Report'),
                    const SizedBox(height: 12),
                    _buildDetailedReport(),
                    const SizedBox(height: 24),
                    _sectionTitle('Live Tracking & History'),
                    const SizedBox(height: 12),
                    _buildTrackingCard(context),
                    const SizedBox(height: 12),
                    _buildAttendanceHistoryCard(context),
                    const SizedBox(height: 12),
                    _buildHistoryCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSummaryGrid() {
    final nameFilter = {'exe_name': widget.executive.name};
    final now = CollectionApiService.istNow;
    final today = DateFormat('yyyy-MM-dd').format(now);
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";

    return Column(
      children: [
        _enhancedBox("Total Allocated", enhancedStats['allocated'], const Color(0xFFF8BBD0), const Color(0xFFC2185B), 
          onTap: () => _openCases("Portfolio: ${widget.executive.name}", nameFilter), isFullWidth: true, showPOS: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Pending Visit (Month)", enhancedStats['yetToVisit'], const Color(0xFFC8E6C9), const Color(0xFF2E7D32),
              onTap: () => _openCases("Pending Visit (Month)", {...nameFilter, 'yet_to_visit': '1', 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("In Progress (Month)", enhancedStats['inProgress'], const Color(0xFFBBDEFB), const Color(0xFF1565C0),
              onTap: () => _openCases("In Progress (Visited/Unpaid)", {...nameFilter, 'in_progress': '1', 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Completed (Paid)", enhancedStats['completed'], const Color(0xFFFFCCBC), const Color(0xFFD84315),
              onTap: () => _openCases("Completed (Paid)", {...nameFilter, 'resolution_status': 'paid'}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Distance (Month)", enhancedStats['monthly_distance'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapTrackingPage(lat: widget.executive.currentLat, lng: widget.executive.currentLng, name: widget.executive.name, executiveId: widget.executive.id))))),
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
          refresh: _loadStats,
        )
      )
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

  Widget _buildVisitPtpStatusSection() {
    final now = CollectionApiService.istNow;
    final today = DateFormat('yyyy-MM-dd').format(now);
    final monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final nameFilter = {'exe_name': widget.executive.name};

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
              onTap: () => _openCases("Skip Visit Portfolio", {...nameFilter, 'calling_remark': 'visit', 'max_projection_date': today, 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Skip PTP", enhancedStats['skipPtp'], const Color(0xFFFFEBEE), const Color(0xFFC62828),
              onTap: () => _openCases("Skip PTP Portfolio", {...nameFilter, 'calling_remark': 'ptp', 'max_projection_date': today, 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Today PTP", enhancedStats['todayPtp'], const Color(0xFFE3F2FD), const Color(0xFF1565C0),
              onTap: () => _openCases("Today PTP List", {...nameFilter, 'calling_remark': 'ptp', 'projection_date': today, 'start_date': monthStart}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Shift Visit", enhancedStats['shiftVisit'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _openCases("Shift Visit Portfolio", {...nameFilter, 'calling_remark': 'visit', 'min_projection_date': today, 'start_date': monthStart}))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Shift PTP", enhancedStats['shiftPtp'], const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => _openCases("Shift PTP Portfolio", {...nameFilter, 'calling_remark': 'ptp', 'min_projection_date': today, 'start_date': monthStart}))),
          ],
        ),
      ],
    );
  }


  void _openCases(String title, Map<String, dynamic> filters, {bool isVisitList = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CaseListScreen(
      title: title, 
      filters: filters, 
      isVisitList: isVisitList,
      refresh: _loadStats,
    )));
  }

  Widget _buildAttendanceHistoryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.orange, size: 30),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                Text('View full punch-in/out logs for this user', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showAttendanceDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View Logs', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showAttendanceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.executive.name}\'s Attendance', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _attendanceRow('Today\'s Punch In', widget.executive.punchIn ?? '--:--'),
            const Divider(),
            _attendanceRow('Today\'s Punch Out', widget.executive.punchOut ?? '--:--'),
            const Divider(),
            _attendanceRow('Current Status', widget.executive.isOnline ? 'Punched In' : 'Punched Out'),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _attendanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapTrackingPage(
              lat: widget.executive.currentLat,
              lng: widget.executive.currentLng,
              name: widget.executive.name,
              executiveId: widget.executive.id,
              initialHistoryMode: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.green, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location Timeline', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text('View full travel history for the day', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: primaryRed,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(widget.executive.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(widget.executive.isOnline ? 'Currently Online' : 'Offline', 
            style: TextStyle(color: widget.executive.isOnline ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _statCard('Total Cases', '${widget.executive.totalCases}', Icons.assignment, Colors.blue),
        _statCard('Visits Done', '${widget.executive.todayVisits}', Icons.directions_walk, Colors.orange),
        _statCard('Today PTP', '${widget.executive.todayPtp}', Icons.handshake, Colors.purple),
        _statCard('Collected', '₹${widget.executive.todayCollection}', Icons.payments, Colors.green),
        _statCard('Distance', '${widget.executive.totalKm.toStringAsFixed(1)} KM', Icons.route, Colors.purple),
        _statCard('Total PTP', '${widget.executive.totalPtp}', Icons.calendar_today, Colors.indigo),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollectionDashboardPage(
                    initialFilters: {'exe_name': widget.executive.name},
                    title: '${widget.executive.name}\'s Dashboard',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
            label: const Text('View Full Record', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: darkBg,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailedReport() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _reportRow('Travel Allowance (₹2.5/KM)', '₹${widget.executive.allowance.toStringAsFixed(1)}'),
          const Divider(),
          _reportRow('Last Sync Time', widget.executive.lastSeen),
          const Divider(),
          _reportRow('Branch', 'Jaipur Branch'),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MapTrackingPage(lat: widget.executive.currentLat, lng: widget.executive.currentLng, name: widget.executive.name, executiveId: widget.executive.id)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_rounded, color: primaryBlue, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Map View', style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue)),
                  Text('Current: ${widget.executive.currentLat.toStringAsFixed(4)}, ${widget.executive.currentLng.toStringAsFixed(4)}', 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: primaryBlue),
          ],
        ),
      ),
    );
  }

  String _format(dynamic v) {
    return FormatUtils.safeFormat(v, compact: false); // Full amount on executive details
  }
}
