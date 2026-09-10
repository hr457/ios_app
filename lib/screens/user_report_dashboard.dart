import 'package:flutter/material.dart';
import '../models/executive_status.dart';
import '../services/executive_service.dart';
import '../utils/app_colors.dart';
import 'executive_details_page.dart';

class UserReportDashboard extends StatefulWidget {
  const UserReportDashboard({super.key});

  @override
  State<UserReportDashboard> createState() => _UserReportDashboardState();
}

class _UserReportDashboardState extends State<UserReportDashboard> {
  List<ExecutiveStatus> allUsers = [];
  List<ExecutiveStatus> filteredUsers = [];
  bool isLoading = true;
  String searchQuery = '';
  String statusFilter = 'All'; // All, Online, Offline

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final users = await ExecutiveService.fetchExecutives();
    if (mounted) {
      setState(() {
        allUsers = users;
        _applyFilters();
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    filteredUsers = allUsers.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesStatus = true;
      if (statusFilter == 'Online') {
        matchesStatus = user.isOnline;
      } else if (statusFilter == 'Offline') {
        matchesStatus = !user.isOnline;
      }
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _onStatusFilterChanged(String? filter) {
    if (filter != null) {
      setState(() {
        statusFilter = filter;
        _applyFilters();
      });
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty || time == 'null') return '--:--';
    try {
      // Handle "2023-10-27 09:00:00" or ISO format
      if (time.contains(' ')) {
        return time.split(' ')[1].substring(0, 5);
      }
      if (time.contains('T')) {
        return time.split('T').last.substring(0, 5);
      }
      if (time.length >= 5) {
        return time.substring(0, 5);
      }
      return time;
    } catch (e) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Stats based on filtered list
    int totalUsers = filteredUsers.length;
    int onlineUsers = filteredUsers.where((u) => u.isOnline).length;
    double totalCollection = filteredUsers.fold(0, (sum, u) => sum + u.todayCollection);
    double totalKm = filteredUsers.fold(0, (sum, u) => sum + u.totalKm);

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fd),
      appBar: AppBar(
        title: const Text('User Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : Column(
              children: [
                _buildSummaryHeader(totalUsers, onlineUsers, totalCollection, totalKm),
                _buildSearchBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    color: primaryRed,
                    child: filteredUsers.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(child: Text("No users found matching your criteria")),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              return _buildUserCard(filteredUsers[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader(int total, int online, double collection, double km) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryStat('Total List', '$total', Icons.format_list_bulleted),
              _summaryStat('Online', '$online', Icons.circle, color: Colors.greenAccent),
              _summaryStat('Offline', '${total - online}', Icons.circle, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryStat('Selected Collection', '₹${collection.toStringAsFixed(0)}', Icons.payments_outlined),
              _summaryStat('Selected Dist.', '${km.toStringAsFixed(1)} km', Icons.route_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, IconData icon, {Color color = Colors.white}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: statusFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: primaryRed),
              items: ['All', 'Online', 'Offline'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: _onStatusFilterChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(ExecutiveStatus user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: sleekCard,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExecutiveDetailsPage(executive: user),
            ),
          );
        },
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: bodyBg,
                        backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null,
                        child: user.profilePic.isEmpty ? const Icon(Icons.person_rounded, color: textMuted, size: 30) : null,
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: user.isOnline ? successGreen : textMuted,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textHeading)),
                            ),
                            if (user.code != null && user.code!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: bodyBg, borderRadius: BorderRadius.circular(6)),
                                child: Text(user.code!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(user.isOnline ? 'Active Now' : 'Last seen: ${user.lastSeen}', 
                          style: TextStyle(color: user.isOnline ? successGreen : textBody, fontSize: 12, fontWeight: user.isOnline ? FontWeight.w800 : FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: textMuted),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: bodyBg, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _userStatItem('PUNCH IN', user.punchIn ?? '--:--', primaryRed),
                        _userStatItem('PUNCH OUT', user.punchOut ?? '--:--', textHeading),
                        _userStatItem('TOTAL TIME', user.totalTime ?? '--:--', successGreen),
                      ],
                    ),
                    if (user.lateBy != null && user.lateBy != "00:00" && user.lateBy!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: warningOrange),
                          const SizedBox(width: 6),
                          Text("Late by: ${user.lateBy}", style: const TextStyle(fontSize: 12, color: warningOrange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statBadge(Icons.explore_rounded, '${user.todayVisits} Visits', infoBlue),
                  _statBadge(Icons.payments_rounded, '₹${user.todayCollection.toStringAsFixed(0)}', successGreen),
                  _statBadge(Icons.route_rounded, '${user.totalKm.toStringAsFixed(1)} KM', primaryRed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _statBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _userMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryBlue)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }
}
