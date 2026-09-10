import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_case.dart';
import '../services/collection_api_service.dart';
import '../utils/app_colors.dart';
import 'customer_detail_screen.dart';
import '../widgets/case_card.dart';

class VisitPage extends StatefulWidget {
  final VoidCallback onChanged;
  const VisitPage({super.key, required this.onChanged});

  @override
  State<VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends State<VisitPage> {
  final ScrollController _scrollController = ScrollController();
  String activeFilter = 'High Priority';
  List<CustomerCase> cases = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  String search = '';
  Timer? _searchTimer;
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
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
      isLoading = true;
      currentPage = 1;
      cases = [];
      hasMore = true;
    });

    final Map<String, dynamic> filters = _getFilterMap();
    final results = await CollectionApiService.fetchCollections(filters: filters, page: 1);

    if (mounted) {
      setState(() {
        cases = results;
        isLoading = false;
        totalCount = CollectionApiService.serverTotalCount;
        hasMore = CollectionApiService.serverCurrentPage < CollectionApiService.serverLastPage;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => isLoadingMore = true);
    
    final nextPage = currentPage + 1;
    final Map<String, dynamic> filters = _getFilterMap();
    final results = await CollectionApiService.fetchCollections(filters: filters, page: nextPage);

    if (mounted) {
      setState(() {
        cases.addAll(results);
        currentPage = nextPage;
        isLoadingMore = false;
        hasMore = CollectionApiService.serverCurrentPage < CollectionApiService.serverLastPage;
      });
    }
  }

  Map<String, dynamic> _getFilterMap() {
    final Map<String, dynamic> f = {};
    if (search.isNotEmpty) f['search'] = search;
    
    if (activeFilter == 'High Priority') {
      f['priority'] = 'high';
    } else if (activeFilter == 'PTP Due') {
      f['ptp_date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    return f;
  }

  void _onSearchChanged(String v) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() => search = v);
      _loadInitial();
    });
  }

  void _refresh() => _loadInitial();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text("Today's Work Queue", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: bodyBg,
        foregroundColor: textHeading,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: textHeading, size: 28),
        ),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue)),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          _buildFilters(),
          _buildTotalCount(),
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator(color: primaryBlue))
              : RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: primaryBlue,
                  child: cases.isEmpty 
                    ? _buildEmpty() 
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: cases.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == cases.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2)),
                            );
                          }
                          return CaseCard(
                            item: cases[index],
                            onChanged: _refresh,
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
        Icon(Icons.assignment_turned_in_rounded, size: 80, color: textMuted.withValues(alpha: 0.1)),
        const SizedBox(height: 16),
        const Text("No cases found in this category", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search Loan No, Customer...',
          prefixIcon: const Icon(Icons.search, color: textMuted),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTotalCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Text("Total Cases: ", style: const TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
          Text("$totalCount", style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['High Priority', 'PTP Due', 'Near By'];
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: filters.map<Widget>((f) {
                bool isSel = activeFilter == f;
                return GestureDetector(
                  onTap: () {
                    if (!isSel) {
                      setState(() => activeFilter = f);
                      _loadInitial();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? primaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? primaryBlue : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Text(f, style: TextStyle(color: isSel ? Colors.white : textBody, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }


  String _format(dynamic v) {
    if (v == null) return "0";
    double val = (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);
    return NumberFormat('#,##,###').format(val);
  }
}
