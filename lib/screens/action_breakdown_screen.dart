import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/collection_api_service.dart';
import '../utils/app_colors.dart';
import '../models/customer_case.dart';
import 'case_list_screen.dart';

enum BreakdownType { visit, ptp }

class ActionBreakdownScreen extends StatefulWidget {
  final String date;
  final BreakdownType type;
  
  const ActionBreakdownScreen({super.key, required this.date, required this.type});

  @override
  State<ActionBreakdownScreen> createState() => _ActionBreakdownScreenState();
}

class _ActionBreakdownScreenState extends State<ActionBreakdownScreen> {
  late Future<List<dynamic>> dataFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      if (widget.type == BreakdownType.visit) {
        dataFuture = CollectionApiService.fetchVisits(filters: {'date': widget.date}, perPage: 1000);
      } else {
        dataFuture = CollectionApiService.fetchCollections(filters: {'ptp_date': widget.date}, perPage: 1000);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.type == BreakdownType.visit ? 'Visits Breakdown' : 'PTP Breakdown';
    
    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: surfaceWhite,
        foregroundColor: textHeading,
        elevation: 0,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: primaryBlue)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryBlue));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) return _buildEmpty();

          // Grouping logic
          final Map<String, List<dynamic>> exeGroups = {};
          final Map<String, List<dynamic>> tlGroups = {};

          for (var item in items) {
            String exe = '';
            String tl = '';
            
            if (widget.type == BreakdownType.visit) {
              exe = item['exe_name']?.toString() ?? 'Unknown Executive';
              tl = item['tl_name']?.toString() ?? 'Unknown TL';
            } else {
              // item is CustomerCase
              exe = item.executive.isNotEmpty ? item.executive : (item.rawJson['exe_name']?.toString() ?? 'Unknown Executive');
              tl = item.tl.isNotEmpty ? item.tl : (item.rawJson['tl_name']?.toString() ?? 'Unknown TL');
            }
            
            exeGroups.putIfAbsent(exe, () => []).add(item);
            tlGroups.putIfAbsent(tl, () => []).add(item);
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  labelColor: primaryBlue,
                  unselectedLabelColor: textMuted,
                  indicatorColor: primaryBlue,
                  tabs: [
                    Tab(text: "By Executive"),
                    Tab(text: "By Team Leader"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(exeGroups, widget.type == BreakdownType.visit ? 'exe_name' : 'exe_name'),
                      _buildList(tlGroups, widget.type == BreakdownType.visit ? 'tl_name' : 'tl_name'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(Map<String, List<dynamic>> groups, String filterKey) {
    final sortedKeys = groups.keys.toList()..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final name = sortedKeys[index];
        final count = groups[name]!.length;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: premiumCardDecoration(),
          child: ListTile(
            onTap: () => _openCases(name, filterKey),
            leading: CircleAvatar(
              backgroundColor: primaryBlue.withOpacity(0.1),
              child: Text(count.toString(), style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Total ${widget.type == BreakdownType.visit ? 'Visits' : 'PTPs'}: $count", style: const TextStyle(fontSize: 11, color: textMuted)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
          ),
        );
      },
    );
  }

  void _openCases(String name, String filterKey) {
    final Map<String, dynamic> filters = { filterKey: name };

    if (widget.type == BreakdownType.visit) {
      filters['date'] = widget.date;
    } else {
      filters['ptp_date'] = widget.date;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => CaseListScreen(
      title: "$name - ${widget.type == BreakdownType.visit ? 'Visits' : 'PTPs'}", 
      filters: filters,
      isVisitList: widget.type == BreakdownType.visit,
      refresh: _refresh
    )));
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_toggle_off_rounded, size: 80, color: textMuted.withValues(alpha: 0.1)), Text("No ${widget.type == BreakdownType.visit ? 'visits' : 'PTPs'} found for today", style: const TextStyle(color: textMuted, fontWeight: FontWeight.bold))]));
}
