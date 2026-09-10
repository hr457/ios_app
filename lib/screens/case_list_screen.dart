import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_case.dart';
import '../widgets/case_card.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import '../services/collection_api_service.dart';
import '../models/user_model.dart';
import 'main_page.dart';
import 'login_page.dart';
import 'attendance_dashboard.dart';
import 'collection_dashboard_page.dart';
import 'executive_monitoring_page.dart';

class CaseListScreen extends StatefulWidget {
  final String title;
  final Map<String, dynamic> filters;
  final bool isVisitList;
  final VoidCallback refresh;

  const CaseListScreen({
    super.key, 
    required this.title, 
    this.filters = const {}, 
    this.isVisitList = false,
    required this.refresh
  });

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<CustomerCase> cases = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  bool isSyncing = false;
  String search = '';
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _init() async {
    final prefix = widget.isVisitList ? "visited_cases" : "collections";
    final key = CollectionApiService.getCacheKey(prefix, widget.filters);
    var cachedFull = await CollectionApiService.loadFromCacheFull(key);
    
    // Fallback: If specific filter cache is missing, try loading from Master Collection Cache
    if (cachedFull == null && !widget.isVisitList) {
      final master = await CollectionApiService.loadFromCacheFull("master_collections");
      if (master != null && mounted) {
        final List rawData = master['data'] as List;
        final List<CustomerCase> allCases = rawData.map((e) => CustomerCase.fromJson(Map<String, dynamic>.from(e))).toList();
        
        // Apply virtual filters locally for instant UI
        final filtered = await CollectionApiService.enrichCases(allCases).then((list) {
            // Re-use API logic for filtering
            // (Note: CollectionApiService doesn't expose a public filter-only method easily, 
            // but we can trust the cache hit in _loadInitial)
            return list;
        });

        // Actually, fetchCollections is async anyway. 
        // Let's just make _loadInitial run immediately.
      }
    }

    bool needsSync = true;
    if (cachedFull != null && mounted) {
      final List rawData = cachedFull['data'] as List;
      final List<CustomerCase> localCases = rawData.map((e) => CustomerCase.fromJson(Map<String, dynamic>.from(e))).toList();
      
      setState(() {
        cases = localCases;
        isLoading = false;
      });

      // ENRICH cached data immediately using recent visits cache
      CollectionApiService.enrichCases(localCases).then((enriched) {
        if (mounted) setState(() => cases = enriched);
      });

      // Skip sync if cache is less than 5 hours old
      needsSync = CollectionApiService.isCacheStale(cachedFull['ts'], hours: 5);
    }

    // Force _loadInitial if we have no cases yet to leverage Master Cache instantly
    if (needsSync || cases.isEmpty) {
      _loadInitial();
    }
  }

  Future<void> _loadCachedData() async {
    // Deprecated in favor of integrated _init logic
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (hasMore && !isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      if (cases.isEmpty) isLoading = true;
      isSyncing = true;
      currentPage = 1;
      hasMore = true;
    });

    final Map<String, dynamic> finalFilters = Map.from(widget.filters);
    if (search.isNotEmpty) finalFilters['search'] = search;

    List<CustomerCase> results = cases;
    try {
      if (widget.isVisitList) {
        results = await CollectionApiService.fetchVisitedCases(filters: finalFilters);
        hasMore = false; 
      } else {
        results = await CollectionApiService.fetchCollections(filters: finalFilters, page: 1);
        hasMore = CollectionApiService.serverCurrentPage < CollectionApiService.serverLastPage;
      }
    } catch (_) {
      // Keep existing cases on error
    }

    if (mounted) {
      setState(() {
        cases = results;
        isLoading = false;
        isSyncing = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => isLoadingMore = true);
    
    final nextPage = currentPage + 1;
    final Map<String, dynamic> finalFilters = Map.from(widget.filters);
    if (search.isNotEmpty) finalFilters['search'] = search;

    final results = await CollectionApiService.fetchCollections(
      filters: finalFilters, 
      page: nextPage
    );

    if (mounted) {
      setState(() {
        cases.addAll(results);
        currentPage = nextPage;
        isLoadingMore = false;
        hasMore = CollectionApiService.serverCurrentPage < CollectionApiService.serverLastPage;
      });
    }
  }

  void _onSearchChanged(String v) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() => search = v);
      _loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (isSyncing)
               const Text("Syncing...", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryBlue)),
          ],
        ),
        backgroundColor: surfaceWhite,
        foregroundColor: textHeading,
        elevation: 0,
        actions: [
          if (isSyncing)
             const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue)))),
        ],
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: surfaceWhite,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Cases (Loan No, Name, City)...',
                prefixIcon: const Icon(Icons.search, color: textMuted),
                filled: true,
                fillColor: bodyBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: primaryBlue)))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitial,
                color: primaryBlue,
                child: cases.isEmpty 
                  ? _buildEmpty() 
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: cases.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == cases.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2)),
                          );
                        }
                        final bool isPtp = widget.filters['calling_remark']?.toString().contains('ptp') ?? false;
                        return CaseCard(
                          item: cases[index], 
                          isPtpContext: isPtp,
                          onChanged: () {
                            widget.refresh();
                          }
                        );
                      },
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 80, color: textMuted.withValues(alpha: 0.1)),
        const SizedBox(height: 16),
        const Text("No matches found", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
      ],
    ),
  );

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
                _drawerTile('Detailed Reports', Icons.pie_chart_rounded, false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionDashboardPage()));
                }),
                _drawerTile('Team Monitoring', Icons.supervisor_account_rounded, false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExecutiveMonitoringPage()));
                }),
                _drawerTile('Attendance Records', Icons.watch_later_rounded, false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceDashboard()));
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()), 
        (_) => false
      );
    }
  }
}
