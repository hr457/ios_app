import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/collection_api_service.dart';
import '../services/auth_service.dart';
import '../services/executive_service.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';
import 'case_list_screen.dart';
import 'map_tracking_page.dart';
import 'login_page.dart';
import 'main_page.dart';
import '../utils/format_utils.dart';

class CollectionDashboardPage extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final String title;

  const CollectionDashboardPage({
    super.key, 
    this.initialFilters = const {}, 
    this.title = 'Collection Analytics'
  });

  @override
  State<CollectionDashboardPage> createState() => _CollectionDashboardPageState();
}

class _CollectionDashboardPageState extends State<CollectionDashboardPage> {
  late Future<Map<String, dynamic>> dashboardFuture;
  Map<String, dynamic> filters = {};
  bool showFilters = false;
  String? userRole;
  String? loggedInUserName;
  int? currentContextUserId;

  Map<String, int> outcomeCounts = {
    'v_done': 0, 'v_skip': 0, 'v_shift': 0,
    'p_done': 0, 'p_skip': 0, 'p_shift': 0,
  };

  Map<String, dynamic> enhancedStats = {
    'allocated': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'yetToVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'inProgress': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'completed': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'jointVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'totalPtp': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'totalVisit': {'count': 0, 'coll': 0.0, 'due': 0.0},
    'topPerformers': <Map<String, dynamic>>[],
  };

  @override
  void initState() {
    super.initState();
    filters = Map.from(widget.initialFilters);
    _checkRole();
    _refresh();
  }

  Future<void> _checkRole() async {
    final user = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        userRole = user?.role.toLowerCase();
        loggedInUserName = user?.name;
        if (filters['exe_name'] == null && filters['tl_name'] == null) {
          currentContextUserId = user?.id;
        }
      });
    }
  }

  void _refresh() {
    setState(() {
      dashboardFuture = CollectionApiService.fetchDashboardData(filters: filters);
    });
    _updateContextUserId();

    // Fetch precise outcome counts for the 6 boxes
    CollectionApiService.fetchOutcomeCounts().then((counts) {
      if (mounted) setState(() => outcomeCounts = counts);
    });

    // Fetch new 4-box enhanced summary respecting current page filters
    CollectionApiService.fetchEnhancedDashboardStats(filters: filters).then((stats) {
      if (mounted && stats.isNotEmpty) setState(() => enhancedStats = stats);
    });
  }

  Future<void> _updateContextUserId() async {
    final targetName = filters['exe_name'] ?? filters['tl_name'];
    if (targetName != null) {
      final users = await ExecutiveService.fetchExecutives();
      final found = users.where((u) => u.name == targetName).firstOrNull;
      if (found != null && mounted) {
        setState(() => currentContextUserId = found.id);
      }
    }
  }

  void _navigateToDrillDown(Map<String, dynamic> drillFilters, String title) {
    Map<String, dynamic> newFilters = Map.from(filters);
    newFilters.addAll(drillFilters);
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => CollectionDashboardPage(
          initialFilters: newFilters,
          title: title,
        )
      )
    );
  }

  void _navigateToCaseList(Map<String, dynamic> listFilters, String title, {bool isVisitList = false}) {
    Map<String, dynamic> newFilters = Map.from(filters);
    newFilters.addAll(listFilters);
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => CaseListScreen(
          title: title,
          filters: newFilters,
          isVisitList: isVisitList,
          refresh: _refresh,
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: surfaceWhite,
        foregroundColor: textHeading,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => showFilters = !showFilters),
            icon: Icon(showFilters ? Icons.filter_alt : Icons.filter_alt_outlined, color: primaryBlue),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (showFilters) _buildFiltersSection(),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: primaryBlue));
                }
                final data = snapshot.data ?? {};
                if (data.isEmpty) return _buildEmptyState();

                final summary = data['summary'] ?? {};

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEnhancedSummaryGrid(summary),
                        const SizedBox(height: 32),
                        _buildPortfolioHeader(summary),
                        const SizedBox(height: 32),
                        _buildSectionHeader("Deep Analysis"),
                        const SizedBox(height: 16),
                        _buildGroupSection(data),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSummaryGrid(Map<String, dynamic> summary) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Column(
      children: [
        _enhancedBox("Total Allocated", enhancedStats['allocated'], const Color(0xFFF8BBD0), const Color(0xFFC2185B), 
          onTap: () => _navigateToCaseList({}, "Portfolio Summary"), isFullWidth: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Pending Visit", enhancedStats['yetToVisit'], const Color(0xFFC8E6C9), const Color(0xFF2E7D32),
              onTap: () => _navigateToCaseList({'yet_to_visit': '1'}, "Pending Visit (Month)"))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("In Progress", enhancedStats['inProgress'], const Color(0xFFBBDEFB), const Color(0xFF1565C0),
              onTap: () => _navigateToCaseList({'in_progress': '1'}, "In Progress (Visited/Unpaid)"))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Completed", enhancedStats['completed'], const Color(0xFFFFCCBC), const Color(0xFFD84315),
              onTap: () => _navigateToCaseList({'resolution_status': 'paid'}, "Completed (Paid)"))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Joint Visit", enhancedStats['jointVisit'], const Color(0xFFE1BEE7), const Color(0xFF7B1FA2),
              onTap: () => _navigateToCaseList({'joint_visit': '1', 'calling_remark': 'joint visit'}, "Joint Visits (Month)", isVisitList: true))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Visits Done", {'count': outcomeCounts['v_done'] ?? 0, 'coll': 0.0, 'due': 0.0}, const Color(0xFFF3E5F5), Colors.purple,
              onTap: () => _navigateToCaseList({'today_entry_date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'calling_remark': 'visit'}, "Visits Done Today", isVisitList: true))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Distance", {'count': "${(summary['total_km'] ?? summary['distance'] ?? 0.0).toStringAsFixed(1)} KM", 'coll': 0.0, 'due': 0.0}, const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapTrackingPage(
                lat: 26.9124, lng: 75.7873, 
                name: filters['exe_name'] ?? filters['tl_name'] ?? loggedInUserName ?? "User",
                executiveId: currentContextUserId,
              ))))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _enhancedBox("Total PTP", enhancedStats['totalPtp'], const Color(0xFFE1F5FE), const Color(0xFF0288D1),
              onTap: () => _navigateToCaseList({'calling_remark': 'ptp'}, "Total PTP (Month)", isVisitList: true))),
            const SizedBox(width: 12),
            Expanded(child: _enhancedBox("Total Visit", enhancedStats['totalVisit'], const Color(0xFFFFF3E0), const Color(0xFFE65100),
              onTap: () => _navigateToCaseList({'calling_remark': 'visit'}, "Total Visits (Month)", isVisitList: true))),
          ],
        ),
      ],
    );
  }

  Widget _enhancedBox(String title, Map<String, dynamic>? data, Color bg, Color text, {VoidCallback? onTap, bool isFullWidth = false}) {
    final stats = data ?? {'count': 0, 'coll': 0.0, 'due': 0.0};
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$title-${stats['count']}", style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text("Coll - ₹${_format(stats['coll'])}", style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
                Text("Due - ₹${_format(stats['due'])}", style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: text, shape: BoxShape.circle),
                child: const Icon(Icons.call_made_rounded, color: Colors.white, size: 10),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildFilterDropdown('Bucket', 'bucket', ['ALL', '0', '1', '2', '3', '4', '5+'])),
              const SizedBox(width: 12),
              Expanded(child: _buildFilterDropdown('Category', 'case_category', ['ALL', 'LIVE', 'REPO', 'NS', 'WRITE OFF'])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () { setState(() => filters.clear()); _refresh(); }, 
                  style: ElevatedButton.styleFrom(backgroundColor: bodyBg, foregroundColor: textHeading, elevation: 0), 
                  child: const Text("RESET")
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _refresh, 
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, elevation: 0), 
                  child: const Text("APPLY")
                )
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String key, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted)),
        DropdownButton<String>(
          value: (filters[key] ?? 'ALL').toString(),
          isExpanded: true,
          underline: Container(height: 1, color: bodyBg),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
          onChanged: (v) => setState(() => filters[key] = v),
        ),
      ],
    );
  }

  Widget _buildPortfolioHeader(Map<String, dynamic> s) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Container(
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
              _headerItem("Portfolio", "${s['total_cases'] ?? 0} Cs", Icons.folder_copy_rounded, onTap: () => _navigateToCaseList({}, "Complete Portfolio")),
              _headerItem("Today Rec.", "₹${_format(s['total_received'])}", Icons.payments_rounded, onTap: () => _navigateToCaseList({'action_start_date': todayStr, 'action_end_date': todayStr}, "Today's Collection")),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.white24, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerItem("Overdue/Req", "₹${_format(s['total_recovery_required'] ?? s['overdue'])}", Icons.pending_actions_rounded, onTap: () => _navigateToCaseList({'bucket': '1,2,3,4,5+'}, "Overdue Cases")),
              _headerItem("EMI Amt", "₹${_format(s['total_emi'])}", Icons.calendar_today_rounded, onTap: () => _navigateToCaseList({'has_emi': '1'}, "EMI Portfolio")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerItem(String label, String val, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildGroupSection(Map<String, dynamic> data) {
    bool isTL = (userRole?.contains('tl') ?? false) || (userRole?.contains('admin') ?? false);

    return Column(
      children: [
        if (filters['tl_name'] != null || isTL)
          _buildHorizontalList(
            enhancedStats['topPerformers'].isNotEmpty ? enhancedStats['topPerformers'] : data['executive_summary'], 
            "Executive Performance (Ranked)", 
            onTap: (item) => _navigateToCaseList({'exe_name': item['name']}, "Executive: ${item['name']}")
          ),
        
        const SizedBox(height: 24),
        _buildHorizontalList(data['bucket_summary'], "Bucket Breakdown", onTap: (item) => _navigateToCaseList({'bucket': item['name']}, "Bucket: ${item['name']}")),
        
        const SizedBox(height: 24),
        if (filters['tl_name'] == null && !isTL)
          _buildHorizontalList(data['tl_summary'], "Team Leaders", onTap: (item) => _navigateToDrillDown({'tl_name': item['name']}, "TL: ${item['name']}")),
        
        const SizedBox(height: 24),
        _buildHorizontalList(data['branch_summary'], "Branch Summaries", onTap: (item) => _navigateToCaseList({'branch': item['name']}, "Branch: ${item['name']}")),
      ],
    );
  }

  Widget _buildHorizontalList(dynamic list, String title, {Function(Map<String, dynamic>)? onTap}) {
    if (list == null || (list is List && list.isEmpty)) return const SizedBox();
    final dataList = list as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textHeading)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: dataList.length,
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(dataList[index]);
              double ach = double.tryParse((item['achievement_percentage'] ?? 0).toString()) ?? 0.0;
              return InkWell(
                onTap: onTap != null ? () => onTap(item) : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: premiumCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${item['name']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textHeading), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${item['total_cases']} Cs", style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                          Text("${ach.toStringAsFixed(0)}%", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ach > 50 ? successGreen : primaryRed)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: ach / 100, backgroundColor: bodyBg, color: ach > 50 ? successGreen : primaryRed, minHeight: 4, borderRadius: BorderRadius.circular(2)),
                      const SizedBox(height: 12),
                      Text("₹${_format(item['total_received'])}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: successGreen)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textHeading));

  Widget _buildEmptyState() => const Center(child: Text("No data available", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)));

  String _format(dynamic v) {
    return FormatUtils.safeFormat(v);
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
                _drawerTile('Detailed Reports', Icons.pie_chart_rounded, true, () => Navigator.pop(context)),
                _drawerTile('Team Monitoring', Icons.supervisor_account_rounded, false, () {
                  Navigator.pop(context);
                  // Navigate to Team tab in MainPage or similar logic
                }),
                _drawerTile('Attendance Records', Icons.watch_later_rounded, false, () {
                  Navigator.pop(context);
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
    return FutureBuilder<UserModel?>(
      future: AuthService.getUserData(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
          decoration: const BoxDecoration(gradient: mainGradient),
          child: Row(
            children: [
              const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.name ?? "User", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(user?.role ?? "Employee", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              ]))
            ],
          ),
        );
      }
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
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }
}
