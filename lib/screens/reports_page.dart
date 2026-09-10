import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/collection_api_service.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../models/customer_case.dart';
import 'case_list_screen.dart';

class ReportsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const ReportsPage({super.key, required this.onChanged});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String, dynamic>> dashboardFuture;
  late Future<Map<String, dynamic>> enhancedStatsFuture;
  String activeTab = 'Today';
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUserData();
    if (user != null && mounted) setState(() => currentUser = user);
  }

  void _refresh() {
    setState(() {
      dashboardFuture = CollectionApiService.fetchDashboardData();
      enhancedStatsFuture = CollectionApiService.fetchEnhancedDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: bodyBg,
        foregroundColor: textHeading,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
          ),
        ),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([dashboardFuture, enhancedStatsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryBlue));
          }
          final Map<String, dynamic> data = (snapshot.data != null && snapshot.data!.isNotEmpty) ? Map<String, dynamic>.from(snapshot.data![0]) : {};
          final Map<String, dynamic> enhanced = (snapshot.data != null && snapshot.data!.length > 1) ? Map<String, dynamic>.from(snapshot.data![1]) : {};
          
          final Map<String, dynamic> summary = data['summary'] != null ? Map<String, dynamic>.from(data['summary']) : {};
          final Map<String, dynamic> visit = data['visit_summary'] != null ? Map<String, dynamic>.from(data['visit_summary']) : {};

          final List<dynamic> topPerformers = enhanced['topPerformers'] ?? [];

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabs(),
                  const SizedBox(height: 24),
                  _buildSummaryGrid(summary, visit),
                  const SizedBox(height: 32),
                  _buildCollectionTargetCircle(summary),
                  const SizedBox(height: 32),
                  _buildTopPerformance(topPerformers),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isExecutive() {
    final role = currentUser?.role.toLowerCase() ?? '';
    return role.contains('executive') || role.contains('collection executive');
  }

  Widget _buildTabs() {
    final tabs = ['Today', 'Week', 'Month', 'Custom'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: tabs.map((t) {
        bool isSel = activeTab == t;
        return GestureDetector(
          onTap: () => setState(() => activeTab = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(t, style: TextStyle(color: isSel ? Colors.white : textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> s, Map<String, dynamic> v) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _reportBox("Total Assigned", "${s['total_cases'] ?? 0}", primaryBlue),
        _reportBox("Total Collected", "₹${_format(s['total_received'])}", successGreen),
        _reportBox("Total Visits", "${v['today_visits'] ?? 0}", Colors.purple),
        _reportBox("Success Rate", "${s['recovery_achievement_percentage'] ?? 0}%", warningOrange),
      ],
    );
  }

  Widget _reportBox(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: premiumCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCollectionTargetCircle(Map<String, dynamic> s) {
    double percent = double.tryParse((s['recovery_achievement_percentage'] ?? 0).toString()) ?? 0.0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: premiumCardDecoration(),
      child: Column(
        children: [
          const Text("Collection vs Target", style: TextStyle(fontWeight: FontWeight.w900, color: textHeading)),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 140, width: 140,
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 12,
                  backgroundColor: accentBlue,
                  color: primaryBlue,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text("${percent.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textHeading)),
                  const Text("Achieved", style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleLegend("Collected", "₹${_format(s['total_received'])}", primaryBlue),
              const SizedBox(width: 40),
              _circleLegend("Target", "₹${_format(s['total_recovery_required'] ?? s['overdue'])}", textMuted),
            ],
          )
        ],
      ),
    );
  }

  Widget _circleLegend(String label, String val, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _buildTopPerformance(List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No performance data available", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Top Performance", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textHeading)),
        const SizedBox(height: 16),
        ...list.asMap().entries.map((e) {
          final item = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: premiumCardDecoration(),
            child: Row(
              children: [
                Text("${e.key + 1}", style: const TextStyle(fontWeight: FontWeight.w900, color: textMuted, fontSize: 16)),
                const SizedBox(width: 16),
                const CircleAvatar(radius: 18, backgroundColor: accentBlue, child: Icon(Icons.person, size: 18, color: primaryBlue)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${item['name']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text("${item['paid_count']} Paid Resolutions", style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text("₹${_format(item['total_received'])}", style: const TextStyle(fontWeight: FontWeight.w900, color: successGreen, fontSize: 14)),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _format(dynamic v) {
    return FormatUtils.safeFormat(v);
  }
}
