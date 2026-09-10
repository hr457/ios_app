import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../models/customer_case.dart';
import '../services/collection_api_service.dart';
import '../services/location_service.dart';
import '../services/receipt_service.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';
import 'attendance_dashboard.dart';
import 'collection_dashboard_page.dart';
import 'executive_monitoring_page.dart';
import 'login_page.dart';
import 'main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerDetailScreen extends StatefulWidget {
  final CustomerCase item;
  final bool isPtpContext;
  const CustomerDetailScreen({super.key, required this.item, this.isPtpContext = false});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late CustomerCase c;
  bool isLoading = true;
  bool isSyncing = false;
  final ImagePicker _picker = ImagePicker();
  dynamic currentUser;
  List<Map<String, dynamic>> caseLocations = [];

  @override
  void initState() {
    super.initState();
    c = widget.item;
    _init();
  }

  Future<void> _init() async {
    await _loadUser();
    
    final cachedFull = await CollectionApiService.loadFromCacheFull("case_details_${c.id}");
    final cachedHistory = await CollectionApiService.loadFromCacheFull("case_history_${c.loanNo}");
    
    bool needsSync = true;
    if (mounted) {
      if (cachedFull != null) {
        setState(() {
          c = CustomerCase.fromJson(Map<String, dynamic>.from(cachedFull['data']));
          isLoading = false;
        });
      }
      if (cachedHistory != null) {
        final historyList = (cachedHistory['data'] as List).map((e) {
           final m = Map<String, dynamic>.from(e);
           return CaseActivity(
             title: m['title'], description: m['description'],
             dateTime: DateTime.parse(m['dateTime']), amount: (m['amount'] ?? 0.0).toDouble(),
             photo: m['photo'], location: m['location'],
             followUpDate: m['followUpDate'] != null ? DateTime.parse(m['followUpDate']) : null
           );
        }).toList();
        setState(() {
          c.activities.clear();
          c.activities.addAll(historyList);
          c.activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          isLoading = false;
        });
      }
      
      // Throttle details sync
      if (cachedFull != null) {
        needsSync = CollectionApiService.isCacheStale(cachedFull['ts'], hours: 5);
      }
    }

    if (needsSync) {
      _loadFullDetails();
    }
  }

  Future<void> _loadCachedData() async {
    // Deprecated
  }

  Future<void> _loadFullDetails() async {
    setState(() => isSyncing = true);
    try {
      final full = await CollectionApiService.fetchCaseDetails(c.id);
      final history = await CollectionApiService.fetchCaseVisitHistory(c.loanNo);
      final locations = await LocationService().fetchLocationsByLoanNo(c.loanNo);
      
      if (mounted) {
        setState(() {
          if (full != null) {
            c = full;
          }
          // Always set activities from history to ensure strict matching
          c.activities.clear();
          c.activities.addAll(history);
          c.activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          
          caseLocations = locations;
          isLoading = false;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null && mounted) {
      setState(() => currentUser = jsonDecode(userJson));
    }
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
            Text(c.customer, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (isSyncing)
               const Text("Syncing...", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryBlue)),
          ],
        ),
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
          if (isSyncing)
             const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue))),
          IconButton(onPressed: _loadFullDetails, icon: const Icon(Icons.refresh_rounded, color: primaryBlue)),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryBlue))
        : RefreshIndicator(
            onRefresh: _loadFullDetails,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStatsHeader(),
                  _buildSectionTitle("System Data (All Columns)"),
                  _buildAllApiColumns(),
                  _buildSectionTitle("Visit History"),
                  _buildVisitHistory(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildQuickStatsHeader() {
    final vDate = c.latestVisitDate;
    final fDate = c.upcomingFollowUpDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: mainGradient,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerStat("EMI Amount", "₹${_format(c.emiAmount)}"),
              _headerStat("Overdue", "₹${_format(c.overdue)}"),
              _headerStat("Bucket", "B${c.bucket}"),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dateInfoBox(Icons.history_toggle_off_rounded, "Last Visit", vDate),
              _dateInfoBox(Icons.event_note_rounded, "Next F/Up", fDate, color: warningOrange),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _openAddressInMap,
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(c.address, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                const Icon(Icons.map_rounded, color: Colors.white, size: 20),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _dateInfoBox(IconData icon, String label, DateTime? date, {Color? color}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : "--/--/----", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _openAddressInMap() async {
    final lat = c.rawJson['latitude'] ?? c.rawJson['lat'] ?? c.rawJson['visit_lat'] ?? c.rawJson['latitude_actual'];
    final lng = c.rawJson['longitude'] ?? c.rawJson['lng'] ?? c.rawJson['visit_long'] ?? c.rawJson['longitude_actual'];
    
    Uri url;
    if (lat != null && lng != null && lat.toString().isNotEmpty && lat.toString() != '0.0' && lat.toString() != '0') {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(c.address)}');
    }
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps"), backgroundColor: primaryRed)
        );
      }
    }
  }

  Widget _headerStat(String label, String val) => Column(
    children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
    ],
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textMuted, letterSpacing: 1)),
  );

  Widget _buildAllApiColumns() {
    final Map<String, dynamic> data = c.rawJson;
    if (data.isEmpty) return const SizedBox();

    // List of keys to hide as they are heavy or internal
    final hideKeys = [
      'calling_visits', 'all_visits', 'visits', 'visit_history', 
      'allVisits', 'activities', 'raw_json', 'visit_image', 'visit_photo',
      'finance', 'last_month_bkt', 'follow_up', 'due_dt_case', 'cluster', 
      'branch_repeat', 'cash_rec', 'calling', 'upi_pay', 'short_cheque', 
      'bw_received', 'case_ptp', 'visit', 'settlement_amount', 'action_plan', 
      'action_plan_date', 'remark', 'case_category', 'auto_bkt', 
      'repo_status', 'created_at', 'updated_at', 'actions',
      // New requested hide keys
      'id', 'insurance_user', 'mora_done', 'bkt', 'resolution_status',
      'repo_revise_jv', 'pdc', 'case_expired', 'case_running', 'district',
      'total_call', 'total_visit', 'feb_rec', 'mar_rec', 'tl_visit_case_mar',
      'acm_visit_case_mar', 'last_month_exe', 'last_month_tc', 'exe_name',
      'tc_name', 'acm_name', 'due_date_exe', 'pay_yesterday', 'pay_today',
      'sales_exec', 'sales_executive', 'reference', 'dma', 'vehicle_for_repo',
      'latest_action'
    ];

    final entries = data.entries.toList();
    final List<MapEntry<String, dynamic>> filteredList = [];
    bool inSkipRange = false;

    for (var entry in entries) {
      final key = entry.key.toLowerCase().trim();
      
      // Check if we should start skipping
      if (key.contains('acm_visit_case_march')) {
        inSkipRange = true;
      }

      // If not in skip range and not in standard hide list, add it
      if (!inSkipRange && !hideKeys.contains(key)) {
        filteredList.add(entry);
      }

      // Check if we should stop skipping (after this entry)
      if (key.contains('pay_today')) {
        inSkipRange = false;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: premiumCardDecoration(),
      child: Column(
        children: filteredList.map((e) {
          String label = e.key.replaceAll('_', ' ').replaceAll('.', ' ').toUpperCase();
          String value = e.value?.toString() ?? '--';
          
          // DATE FORMATTING FIX: Detect ISO dates and convert to IST dd-MM-yyyy
          if (value.length > 10 && value.contains('T') && value.endsWith('Z')) {
            try {
              final dt = DateTime.parse(value).toLocal();
              value = DateFormat('dd-MM-yyyy').format(dt);
            } catch (_) {}
          } else if (value == 'null' || value.isEmpty || value == '[]' || value == '{}') {
            value = '--';
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 120, child: Text(label, style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text(value, style: const TextStyle(color: textHeading, fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVisitHistory() {
    if (c.activities.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No visit history found", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: c.activities.length,
      itemBuilder: (context, index) {
        final a = c.activities[index];
        
        // Match logic: Find location from caseLocations by time proximity
        LatLng? visitLoc = _parseLatLng(a.location);
        
        if (visitLoc == null && caseLocations.isNotEmpty) {
          try {
            // Find location record created within 5 minutes of the activity
            final match = caseLocations.where((loc) {
              final locTimeStr = loc['time'] ?? loc['created_at'] ?? loc['timestamp'];
              if (locTimeStr == null) return false;
              final locTime = DateTime.parse(locTimeStr.toString());
              return locTime.difference(a.dateTime).inMinutes.abs() <= 5;
            }).firstOrNull;

            if (match != null) {
              final double lat = double.tryParse(match['latitude']?.toString() ?? match['lat']?.toString() ?? '0') ?? 0.0;
              final double lng = double.tryParse(match['longitude']?.toString() ?? match['lng']?.toString() ?? '0') ?? 0.0;
              if (lat != 0.0) visitLoc = LatLng(lat, lng);
            }
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: premiumCardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.photo != null && a.photo!.isNotEmpty)
                Image.network(
                  _getImageUrl(a.photo!),
                  height: 200, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(height: 100, color: bodyBg, child: const Icon(Icons.image_not_supported_outlined, color: textMuted)),
                ),
              if (visitLoc != null)
                _buildMiniMap(visitLoc),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: primaryBlue)),
                        Text(DateFormat('dd MMM, hh:mm a').format(a.dateTime), style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _historyInfoRow(Icons.comment_rounded, "Remark: ${a.description}"),
                    if (a.location != null && a.location!.isNotEmpty)
                      _historyInfoRow(Icons.location_on_rounded, "Location: ${a.location}"),
                    if (a.followUpDate != null)
                      _historyInfoRow(Icons.event_note_rounded, "Follow-up: ${DateFormat('dd MMM yyyy').format(a.followUpDate!)}", color: warningOrange),
                    if (a.amount != null && a.amount! > 0) ...[
                      const SizedBox(height: 8),
                      Text("Payment Rec: ₹${_format(a.amount)}", style: const TextStyle(fontWeight: FontWeight.w900, color: successGreen, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color ?? textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color ?? textBody, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(color: surfaceWhite, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                if (await LocationService().ensureLocationAccess(context)) {
                  _openActionDialog('visit');
                }
              },
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text("MARK VISIT", style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                if (await LocationService().ensureLocationAccess(context)) {
                  _openActionDialog('collect');
                }
              },
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: Text(widget.isPtpContext ? "COLLECT PTP" : "PTP / COLLECT", style: const TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ],
      ),
    );
  }


  void _openActionDialog(String type) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo == null) return;
    if (!mounted) return;

    final remarksController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? followUpDate;
    String subject = type == 'visit' ? 'Visited' : 'Cash Ptp';
    String callingRemark = type == 'visit' ? 'visit' : 'ptp';

    // Joint Visit State
    String? selectedExe;
    String? selectedTl;
    String? selectedAcm;
    Map<String, List<String>> hierarchy = {'executives': [], 'tls': [], 'acms': []};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(type == 'visit' ? 'New Visit' : 'PTP / Collection', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb ? Image.network(photo.path, height: 120, width: double.infinity, fit: BoxFit.cover) : Image.file(File(photo.path), height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: callingRemark,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: ['ptp', 'visit', 'joint visit'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                  onChanged: (v) async {
                    setDialogState(() => callingRemark = v!);
                    if (callingRemark == 'joint visit' && hierarchy['tls']!.isEmpty) {
                       final data = await CollectionApiService.fetchHierarchyNames();
                       setDialogState(() => hierarchy = data);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (callingRemark == 'joint visit') ...[
                  DropdownButtonFormField<String>(
                    value: selectedExe,
                    hint: const Text("Select Executive"),
                    items: hierarchy['executives']!.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedExe = v),
                    decoration: const InputDecoration(labelText: 'Joint Executive', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTl,
                    hint: const Text("Select TL"),
                    items: hierarchy['tls']!.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedTl = v),
                    decoration: const InputDecoration(labelText: 'Joint TL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedAcm,
                    hint: const Text("Select ACM"),
                    items: hierarchy['acms']!.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedAcm = v),
                    decoration: const InputDecoration(labelText: 'Joint ACM', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                ],
                if (callingRemark != 'joint visit') ...[
                  DropdownButtonFormField<String>(
                    value: subject,
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    items: ['Visited', 'Cash Ptp', 'Chq. Ptp', 'B/W Received', 'Upi Pay'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => subject = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: 'Amount (If Collected)', border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(controller: remarksController, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(followUpDate == null ? 'Set Follow-up Date' : 'Follow-up: ${DateFormat('dd/MM/yyyy').format(followUpDate!)}'),
                  trailing: const Icon(Icons.calendar_month, color: primaryBlue),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (picked != null) setDialogState(() => followUpDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitData(photo, subject, remarksController.text, amountController.text, followUpDate, callingRemark, selectedExe, selectedTl, selectedAcm);
              },
              child: const Text("SUBMIT"),
            ),
          ],
        ),
      ),
    );
  }

  void _submitData(XFile photo, String subject, String remarks, String amountStr, DateTime? followUp, String callingRemark, String? jointExe, String? jointTl, String? jointAcm) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: primaryBlue)));
    
    try {
      final success = await CollectionApiService.submitVisit(
        customer: c,
        subject: subject,
        remarks: remarks,
        followUp: followUp,
        collectedAmount: double.tryParse(amountStr),
        callingRemark: callingRemark,
        photo: photo,
        jointExe: jointExe,
        jointTl: jointTl,
        jointAcm: jointAcm,
      ).timeout(const Duration(seconds: 40));

      if (!mounted) return;
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action Saved Successfully! (Syncing in background)"), backgroundColor: successGreen));
        _loadFullDetails();
        // Receipt generation is currently disabled per request
        /*
        if (amountStr.isNotEmpty) {
          await ReceiptService.generateAndDownloadReceipt(item: c, amount: double.tryParse(amountStr) ?? 0.0, remark: remarks);
        }
        */
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Server error. Please verify network or login status."), 
            backgroundColor: primaryRed,
          )
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: primaryRed)
      );
    }
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
                _drawerTile('Detailed Reports', Icons.pie_chart_rounded, false, () => _push(const CollectionDashboardPage())),
                _drawerTile('Team Monitoring', Icons.supervisor_account_rounded, false, () => _push(const ExecutiveMonitoringPage())),
                _drawerTile('Attendance Records', Icons.watch_later_rounded, false, () => _push(const AttendanceDashboard())),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
      decoration: const BoxDecoration(gradient: mainGradient),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(currentUser?['name'] ?? "User", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(currentUser?['role'] ?? "Employee", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ]))
        ],
      ),
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

  void _push(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
      await SharedPreferences.getInstance().then((p) => p.clear());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  String _format(dynamic v) {
    return FormatUtils.safeFormat(v, compact: false); // Full amount in details
  }

  String _getImageUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return "";
    String p = path.toString();
    if (p.startsWith('http')) return p;
    // CRITICAL PATH FIX: Ensure images are retrieved from public/upload/visit/
    if (p.contains('upload')) return "http://103.207.168.245/safl/public/$p";
    return "http://103.207.168.245/safl/public/upload/visit/$p";
  }

  LatLng? _parseLatLng(String? loc) {
    if (loc == null || loc.isEmpty || loc == 'null' || loc == 'null,null') return null;
    try {
      // Handles "26.9124, 75.7873" or "lat: 26.9124, lng: 75.7873"
      final clean = loc.replaceAll(RegExp(r'[a-zA-Z:\s]'), '');
      if (clean.isEmpty) return null;
      
      final parts = clean.split(',');
      if (parts.length >= 2) {
        final double? lat = double.tryParse(parts[0].trim());
        final double? lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null && lat != 0.0) {
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint("Coordinate Parse Error ($loc): $e");
    }
    return null;
  }

  Future<void> _openMap(LatLng point) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps"), backgroundColor: primaryRed)
        );
      }
    }
  }

  Widget _buildMiniMap(LatLng point) {
    return InkWell(
      onTap: () => _openMap(point),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bodyBg,
          border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
        ),
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.safl',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: primaryRed, size: 35),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
