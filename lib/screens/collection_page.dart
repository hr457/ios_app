import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_case.dart';
import '../services/collection_api_service.dart';
import '../utils/app_colors.dart';
import 'customer_detail_screen.dart';
import '../widgets/case_card.dart';

class CollectionPage extends StatefulWidget {
  final VoidCallback onChanged;
  const CollectionPage({super.key, required this.onChanged});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  String search = '';
  String activeFilter = 'All';
  late Future<List<CustomerCase>> futureCases;
  int totalCount = 0;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final Map<String, dynamic> f = {};
    if (search.isNotEmpty) f['search'] = search;
    
    if (activeFilter == 'Pending') {
      f['status'] = 'Pending';
    } else if (activeFilter == 'Visit Done') {
      f['status'] = 'Visited';
    } else if (activeFilter == 'PTP Done') {
      f['status'] = 'PTP';
    } else if (activeFilter == 'Closed') {
      f['status'] = 'Collected';
    }

    setState(() {
      futureCases = CollectionApiService.fetchCollections(filters: f).then((list) {
        if (mounted) {
          setState(() => totalCount = CollectionApiService.serverTotalCount);
        }
        return list;
      });
    });
  }

  void _onSearchChanged(String v) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() => search = v);
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text('Cases Portfolio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
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
            child: FutureBuilder<List<CustomerCase>>(
              future: futureCases,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryBlue));
                }
                final list = snapshot.data ?? [];
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    itemBuilder: (context, index) => CaseCard(
                      item: list[index],
                      onChanged: _refresh,
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

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by Name / Mobile / Loan ID',
          hintStyle: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600),
          prefixIcon: const Icon(Icons.search_rounded, color: textMuted, size: 22),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTotalCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Text("Portfolio Size: ", style: const TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
          Text("$totalCount", style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Pending', 'Visit Done', 'PTP Done', 'Closed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: filters.map<Widget>((f) {
          bool isSel = activeFilter == f;
          return GestureDetector(
            onTap: () {
              setState(() => activeFilter = f);
              _refresh();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? primaryBlue : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Text(f, style: TextStyle(color: isSel ? Colors.white : textBody, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          );
        }).toList(),
      ),
    );
  }

}
