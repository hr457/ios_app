import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/collection_api_service.dart';
import 'case_list_screen.dart';

class EfficiencyBreakdownScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final String type; // 'regular' or 'od'
  final VoidCallback refresh;

  const EfficiencyBreakdownScreen({
    super.key, 
    required this.title, 
    required this.data, 
    required this.type,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> exeBreakdown = data['by_exe'] ?? {};
    final Map<String, dynamic> bucketBreakdown = data['by_bucket'] ?? {};
    final Map<String, dynamic> productBreakdown = data['by_product'] ?? {};

    return DefaultTabController(
      length: 3, // Now 3 tabs: EXE, BUCKET, PRODUCT
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          backgroundColor: surfaceWhite,
          foregroundColor: textHeading,
          elevation: 0,
          bottom: TabBar(
            labelColor: primaryBlue,
            indicatorColor: primaryBlue,
            unselectedLabelColor: textMuted,
            tabs: [
              const Tab(text: "BY EXECUTIVE"),
              const Tab(text: "BY BUCKET"),
              const Tab(text: "BY PRODUCT"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(context, exeBreakdown, 'exe_name'),
            _buildList(context, bucketBreakdown, 'bucket'),
            _buildList(context, productBreakdown, 'case_category'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Map<String, dynamic> breakdown, String filterKey) {
    if (breakdown.isEmpty) {
      return const Center(child: Text("No data found", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)));
    }

    final keys = breakdown.keys.toList()..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final name = keys[index];
        final item = Map<String, dynamic>.from(breakdown[name]);
        
        final int paid = item['paid'] ?? 0;
        final int unpaid = item['unpaid'] ?? 0;
        final int total = paid + unpaid;
        
        double paidPerc = total > 0 ? (paid / total) * 100 : 0.0;
        double unpaidPerc = total > 0 ? (unpaid / total) * 100 : 0.0;

        // POS Efficiency Calculation
        final double posAch = (item['pos_ach'] ?? 0.0).toDouble();
        final double posTotal = (item['pos_total'] ?? 0.0).toDouble();
        final double posPerc = posTotal > 0 ? (posAch / posTotal) * 100 : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: premiumCardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: filterKey == 'exe_name' ? () => _openExeBucketSummary(context, name) : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textHeading)),
                              if (filterKey == 'exe_name')
                                const Text("Click to view bucket summary", style: TextStyle(fontSize: 9, color: primaryBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Total Cs: $total", style: const TextStyle(color: textHeading, fontWeight: FontWeight.w900, fontSize: 11)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text("POS Ach: ${posPerc.toStringAsFixed(1)}%", style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _clickableCount(
                        context, 
                        "Paid", 
                        paid, 
                        paidPerc,
                        successGreen, 
                        {filterKey: name, 'resolution_status': 'paid'}
                      ),
                      const SizedBox(width: 12),
                      _clickableCount(
                        context, 
                        "Unpaid", 
                        unpaid, 
                        unpaidPerc,
                        primaryRed, 
                        {filterKey: name, 'resolution_status': 'unpaid'}
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openExeBucketSummary(BuildContext context, String exeName) async {
    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: primaryBlue)));
    
    try {
      final stats = await CollectionApiService.fetchEnhancedDashboardStats(filters: {'exe_name': exeName});
      if (!context.mounted) return;
      Navigator.pop(context);

      final breakdown = stats['efficiency_breakdown']?[type];
      if (breakdown == null) return;

      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => EfficiencyBreakdownScreen(
            title: "$exeName - ${type.toUpperCase()} Breakdown", 
            data: Map<String, dynamic>.from(breakdown), 
            type: type,
            refresh: refresh,
          )
        )
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _clickableCount(BuildContext context, String label, int count, double percentage, Color color, Map<String, dynamic> filters) {
    return Expanded(
      child: InkWell(
        onTap: () {
          // Merge with global category filters
          final Map<String, dynamic> finalFilters = Map.from(filters);
          
          // Use putIfAbsent to ensure specific row filters (like a specific bucket) 
          // are not overwritten by general category filters.
          if (type == 'regular') {
            finalFilters.putIfAbsent('bucket', () => 'regular_cat');
          } else if (type == 'od') {
            finalFilters.putIfAbsent('bucket', () => 'delinquent_cat');
          } else if (type == 'delinquent') {
            finalFilters.putIfAbsent('bucket', () => 'delinquent_new_cat');
          } else if (type == 'nonStarter') {
            finalFilters['is_non_starter'] = '1';
          } else if (type == 'rollBack') {
            finalFilters['is_rollback'] = '1';
          }
          // For 'overall', no additional categorical bucket filter is needed

          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => CaseListScreen(
                title: "${filters.values.first} - $label", 
                filters: finalFilters,
                refresh: refresh,
              )
            )
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(width: 4),
                  Text("(${percentage.toStringAsFixed(1)}%)", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
              Text(label, style: const TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
