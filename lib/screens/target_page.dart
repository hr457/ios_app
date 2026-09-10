import 'package:flutter/material.dart';
import '../models/target_model.dart';
import '../services/target_service.dart';
import '../utils/app_colors.dart';

class TargetPage extends StatefulWidget {
  const TargetPage({super.key});

  @override
  State<TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<TargetPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<TargetModel?> executiveTarget;
  late Future<TargetModel?> tlTarget;
  late Future<TargetModel?> acmTarget;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTargets();
  }

  void _loadTargets() {
    executiveTarget = TargetService.fetchMyTarget();
    tlTarget = TargetService.fetchTLTarget();
    acmTarget = TargetService.fetchACMTarget();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fd),
      appBar: AppBar(
        title: const Text('Target Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Executive'),
            Tab(text: 'TL'),
            Tab(text: 'ACM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _targetList(executiveTarget),
          _targetList(tlTarget),
          _targetList(acmTarget),
        ],
      ),
    );
  }

  Widget _targetList(Future<TargetModel?> future) {
    return FutureBuilder<TargetModel?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryRed));
        }
        final target = snapshot.data;
        if (target == null) {
          return const Center(child: Text("No targets assigned"));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadTargets();
            });
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTargetOverview(target),
                const SizedBox(height: 24),
                _sectionTitle('Collection Target Detail'),
                const SizedBox(height: 12),
                _buildCollectionDetail(target),
                const SizedBox(height: 24),
                _sectionTitle('Visit Target Detail'),
                const SizedBox(height: 12),
                _buildVisitDetail(target),
                const SizedBox(height: 30),
                _buildAchieverIncentive(target),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTargetOverview(TargetModel target) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            target.title.contains('ACM') ? Colors.indigo : (target.title.contains('TL') ? Colors.purple : primaryRed),
            target.title.contains('ACM') ? Colors.indigo.shade800 : (target.title.contains('TL') ? Colors.purple.shade800 : const Color(0xFFE53935)),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(target.month, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(target.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: target.percentageAchieved / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
              Text(
                '${target.percentageAchieved.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Performance Achievement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)));
  }

  Widget _buildCollectionDetail(TargetModel target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _targetRow('Assigned Target', '₹${target.targetAmount.toStringAsFixed(0)}', Colors.blue),
          const Divider(height: 24),
          _targetRow('Achieved Amount', '₹${target.achievedAmount.toStringAsFixed(0)}', Colors.green),
          const Divider(height: 24),
          _targetRow('Balance to Target', '₹${target.pendingAmount.toStringAsFixed(0)}', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildVisitDetail(TargetModel target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _targetRow('Total Cases Allocated', '${target.totalCases}', Colors.purple),
          const Divider(height: 24),
          _targetRow('Actual Visits Done', '${target.visitedCases}', Colors.teal),
          const Divider(height: 24),
          _targetRow('Remaining Visits', '${target.totalCases - target.visitedCases}', Colors.grey),
        ],
      ),
    );
  }

  Widget _targetRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _buildAchieverIncentive(TargetModel target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.stars, color: Colors.green, size: 30),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Incentive Eligibility', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Text('Complete 95% target to unlock performance bonus.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
