import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/collection_api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';

class VisitListScreen extends StatefulWidget {
  final String title;
  final Map<String, dynamic> filters;

  const VisitListScreen({super.key, required this.title, required this.filters});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> visits = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  bool isSyncing = false;
  Map<String, dynamic> activeFilters = {};

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _init() async {
    await _prepareFilters();
    final key = CollectionApiService.getCacheKey("visits", activeFilters);
    final cachedFull = await CollectionApiService.loadFromCacheFull(key);
    
    bool needsSync = true;
    if (cachedFull != null && mounted) {
      setState(() {
        visits = List<Map<String, dynamic>>.from(cachedFull['data']);
        isLoading = false;
      });
      needsSync = CollectionApiService.isCacheStale(cachedFull['ts'], hours: 5);
    }

    if (needsSync) {
      _loadInitial();
    }
  }

  Future<void> _prepareFilters() async {
    activeFilters = Map.from(widget.filters);
  }

  Future<void> _loadCachedData() async {
    // Deprecated
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      if (visits.isEmpty) isLoading = true;
      isSyncing = true;
      currentPage = 1;
      hasMore = true;
    });

    if (activeFilters.isEmpty) await _prepareFilters();

    List<Map<String, dynamic>> results = visits;
    try {
      results = await CollectionApiService.fetchVisits(filters: activeFilters, page: 1);
    } catch (_) {}

    if (mounted) {
      setState(() {
        visits = results;
        isLoading = false;
        isSyncing = false;
        hasMore = CollectionApiService.serverCurrentPage < CollectionApiService.serverLastPage;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => isLoadingMore = true);
    
    final nextPage = currentPage + 1;
    final results = await CollectionApiService.fetchVisits(filters: activeFilters, page: nextPage);

    if (mounted) {
      setState(() {
        visits.addAll(results);
        currentPage = nextPage;
        isLoadingMore = false;
        hasMore = CollectionApiService.serverCurrentPage < CollectionApiService.serverLastPage;
      });
    }
  }

  void _refresh() => _loadInitial();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
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
            const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue))),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue)),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryBlue))
        : visits.isEmpty 
          ? _buildEmpty() 
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              color: primaryBlue,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: visits.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == visits.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2)),
                    );
                  }
                  return _buildVisitCard(visits[index]);
                },
              ),
            ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> v) {
    final photo = v['visit_image'] ?? v['visit_photo'];
    final date = DateTime.tryParse(v['created_at']?.toString() ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: premiumCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo != null && photo.toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.network(
                _getImageUrl(photo),
                height: 180, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(
                  height: 100, color: bodyBg,
                  child: const Icon(Icons.image_not_supported_outlined, color: textMuted),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v['subject']?.toString().toUpperCase() ?? 'VISIT', 
                      style: const TextStyle(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 14)),
                    Text(DateFormat('dd MMM, hh:mm a').format(date), 
                      style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _row("Loan No", v['loan_no']?.toString() ?? '--'),
                _row("Executive", v['exe_name']?.toString() ?? '--'),
                _row("Remarks", v['visit_remark']?.toString() ?? v['remark']?.toString() ?? '--'),
                if (v['location'] != null || v['visit_address'] != null)
                  _row("Location", (v['location'] ?? v['visit_address']).toString(), color: textMuted),
                if (v['payment_rec'] != null && (v['payment_rec'] is num && v['payment_rec'] != 0.0))
                  _row("Collected", "₹${v['payment_rec']}", color: successGreen),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _row(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(child: Text(val, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color ?? textHeading))),
        ],
      ),
    );
  }

  String _getImageUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return "";
    String p = path.toString();
    if (p.startsWith('http')) return p;
    if (p.contains('upload')) return "http://103.207.168.245/safl/public/$p";
    return "http://103.207.168.245/safl/public/upload/visit/$p";
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_toggle_off_rounded, size: 80, color: textMuted.withValues(alpha: 0.1)), const Text("No visit records found", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))]));
}
