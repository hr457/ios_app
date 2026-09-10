import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/customer_case.dart';
import '../screens/customer_detail_screen.dart';
import '../services/receipt_service.dart';
import '../services/collection_api_service.dart';
import '../services/location_service.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';

class CaseCard extends StatelessWidget {
  final CustomerCase item;
  final VoidCallback onChanged;
  final bool isPtpContext;

  const CaseCard({
    super.key,
    required this.item,
    required this.onChanged,
    this.isPtpContext = false,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = item.latestVisitPhoto ?? 
                     item.rawJson['visit_image'] ?? 
                     item.rawJson['visit_photo'] ?? 
                     item.rawJson['photo'] ?? 
                     item.rawJson['photo_url'];

    final fup = item.upcomingFollowUpDate;
    final now = CollectionApiService.istNow;
    final today = DateTime(now.year, now.month, now.day);
    final bool isOverdue = fup != null && 
                           DateTime(fup.year, fup.month, fup.day).isBefore(today) && 
                           item.status.toLowerCase() != 'paid' && 
                           item.status.toLowerCase() != 'collected';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(
                item: item,
                isPtpContext: isPtpContext,
              ),
            ),
          ).then((_) => onChanged());
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: premiumCardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glass blur
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOverdue) _buildOverdueAlert(),
                if (photoUrl != null && photoUrl.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.network(
                      _getImageUrl(photoUrl),
                      height: 160, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Image.network(
                        photoUrl.toString().startsWith('http') ? photoUrl.toString() : "http://103.207.168.245/safl/$photoUrl",
                        height: 160, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (ctx2, err2, st2) => const SizedBox(),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.customer,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Loan No: ${item.loanNo}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          _statusChip(item.status),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniInfo('Mobile', item.mobile),
                          _miniInfo('City', item.city),
                          _miniInfo('Bucket/Late', '${item.bucketName.isNotEmpty ? item.bucketName : item.bucket} / ${item.lateByDay}D'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryBlue.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.clock_fill, size: 14, color: primaryBlue),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("LAST VISIT", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: textMuted)),
                                      Text(
                                        item.latestVisitDate != null ? DateFormat('dd/MM/yyyy').format(item.latestVisitDate!) : "--/--/----",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primaryBlue),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: warningOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: warningOrange.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.calendar_badge_plus, size: 14, color: warningOrange),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("NEXT F/UP", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: textMuted)),
                                      Text(
                                        item.upcomingFollowUpDate != null ? DateFormat('dd/MM/yyyy').format(item.upcomingFollowUpDate!) : "--/--/----",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: warningOrange),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.status == 'Visited') ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(CupertinoIcons.chat_bubble_2_fill, size: 14, color: primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Remark: ${item.remarks}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textHeading))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.location_solid, size: 14, color: primaryRed),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Loc: ${item.rawJson['visit_address'] ?? item.city}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_parseLatLng(item.rawJson['latitude']?.toString(), item.rawJson['longitude']?.toString()) != null)
                           _buildMiniMap(_parseLatLng(item.rawJson['latitude']?.toString(), item.rawJson['longitude']?.toString())!),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bodyBg.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _amountBox('Overdue', item.dueAmount, primaryRed),
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.shade300.withValues(alpha: 0.5)),
                            Expanded(
                              child: _amountBox('Paid', item.collectedAmount, successGreen),
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.shade300.withValues(alpha: 0.5)),
                            Expanded(
                              child: _amountBox('EMI', item.emiAmount, infoBlue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              color: primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(15),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                if (await LocationService().ensureLocationAccess(context)) {
                                  _updateVisit(context);
                                }
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.camera_fill, size: 18, color: primaryBlue),
                                  SizedBox(width: 8),
                                  Text('VISIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primaryBlue, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(15),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                if (await LocationService().ensureLocationAccess(context)) {
                                  _collectDialog(context);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.money_dollar_circle_fill, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(isPtpContext ? 'PTP' : 'COLLECT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildOverdueAlert() {
    return const _BlinkingOverdueBanner();
  }

  Widget _amountBox(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(
          '₹${FormatUtils.safeFormat(value, compact: false)}', // Show full amount on card
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  void _updateVisit(BuildContext context) async {
    _openUnifiedDialog(context, 'visit');
  }

  void _collectDialog(BuildContext context) {
    _openUnifiedDialog(context, 'collect');
  }

  void _openUnifiedDialog(BuildContext context, String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo == null) return;
    if (!context.mounted) return;

    final amountController = TextEditingController(text: item.pendingAmount.toStringAsFixed(0));
    final remarksController = TextEditingController();
    DateTime? followUpDate;
    String callingRemark = type == 'visit' ? 'visit' : 'ptp';
    String subject = type == 'visit' ? 'Visited' : 'Cash Ptp';

    // Joint Visit State
    String? selectedExe;
    String? selectedTl;
    String? selectedAcm;
    Map<String, List<String>> hierarchy = {'executives': [], 'tls': [], 'acms': []};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) => AlertDialog(
          title: Text(type == 'visit' ? 'Mark Visit' : 'PTP / Collection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: kIsWeb
                    ? Image.network(photo.path, height: 120, width: double.infinity, fit: BoxFit.cover)
                    : Image.file(File(photo.path), height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: callingRemark,
                  items: ['ptp', 'visit', 'joint visit'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                  onChanged: (v) async {
                    setDialogState(() => callingRemark = v!);
                    if (callingRemark == 'joint visit' && hierarchy['tls']!.isEmpty) {
                       final data = await CollectionApiService.fetchHierarchyNames();
                       setDialogState(() => hierarchy = data);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
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
                    items: ['Visited', 'Cash Ptp', 'Chq. Ptp', 'B/W Received', 'Upi Pay'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => subject = v!),
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: 'Amount (If Collected)', border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(followUpDate == null ? 'Set Follow-up Date' : 'Follow-up: ${DateFormat('dd/MM/yyyy').format(followUpDate!)}'),
                  trailing: const Icon(Icons.calendar_month, color: primaryBlue),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: builderCtx, 
                      initialDate: DateTime.now().add(const Duration(days: 1)), 
                      firstDate: DateTime.now(), 
                      lastDate: DateTime.now().add(const Duration(days: 90))
                    );
                    if (picked != null) setDialogState(() => followUpDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                final String finalRemarks = remarksController.text;
                final double finalPaid = double.tryParse(amountController.text) ?? 0.0;
                final String finalSubject = subject;
                final String finalCallingRemark = callingRemark;
                final DateTime? finalFollowUp = followUpDate;
                final String? finalJointExe = selectedExe;
                final String? finalJointTl = selectedTl;
                final String? finalJointAcm = selectedAcm;

                // 1. Close input dialog
                Navigator.pop(dialogCtx);
                
                // 2. Show loader
                showDialog(
                  context: context, 
                  barrierDismissible: false,
                  builder: (loaderCtx) => const Center(child: CircularProgressIndicator(color: primaryRed))
                );
                
                try {
                  final success = await CollectionApiService.submitVisit(
                    customer: item,
                    subject: finalSubject,
                    remarks: finalRemarks,
                    collectedAmount: finalPaid,
                    callingRemark: finalCallingRemark,
                    followUp: finalFollowUp,
                    photo: photo,
                    jointExe: finalJointExe,
                    jointTl: finalJointTl,
                    jointAcm: finalJointAcm,
                  ).timeout(const Duration(seconds: 45));

                  // 3. Close loader
                  if (context.mounted) Navigator.of(context).pop();
                  
                  if (success) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Action Saved Successfully! (Syncing in background)"), backgroundColor: Colors.green)
                      );
                    }
                    if (finalPaid > 0) item.collectedAmount += finalPaid;
                    item.addActivity(
                      title: type == 'visit' ? 'Visit' : finalSubject, 
                      description: finalRemarks, 
                      amount: finalPaid, 
                      photo: photo.path,
                      followUpDate: finalFollowUp,
                    );
                    onChanged();
                    if (finalPaid > 0) {
                      await ReceiptService.generateAndDownloadReceipt(item: item, amount: finalPaid, remark: finalRemarks);
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Submission failed. Check logs."), backgroundColor: Colors.red)
                      );
                    }
                  }
                } catch (e) {
                  // 3. Close loader on error/timeout
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = primaryRed;
    String label = status;
    
    if (status == 'Collected') {
      color = Colors.green;
    } else if (status == 'Visited') {
      color = Colors.blue;
      label = "Visit Done";
    } else if (status == 'PTP') {
      color = Colors.orange;
      label = "PTP Pending";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  String _getImageUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return "";
    String p = path.toString();
    if (p.startsWith('http')) return p;
    
    // Common directories: public/, public/upload/visit/, upload/visit/
    const String host = "http://103.207.168.245/safl";
    
    // Try all likely path variants based on previous feedback
    if (p.contains('upload/visit')) {
      return "$host/$p";
    }
    
    if (p.contains('public/')) {
       return "$host/$p";
    }

    if (p.startsWith('upload')) {
       return "$host/public/$p";
    }
    
    // If it's just a filename like "image123.jpg", try the direct public path
    return "$host/public/upload/visit/$p";
  }

  LatLng? _parseLatLng(String? latStr, String? lngStr) {
    if (latStr == null || lngStr == null) return null;
    try {
      final double? lat = double.tryParse(latStr.trim());
      final double? lng = double.tryParse(lngStr.trim());
      if (lat != null && lng != null && lat != 0.0) {
        return LatLng(lat, lng);
      }
    } catch (_) {}
    return null;
  }

  Widget _buildMiniMap(LatLng point) {
    return Container(
      height: 120,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 13.0,
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
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.location_on, color: primaryRed, size: 25),
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

class _BlinkingOverdueBanner extends StatefulWidget {
  const _BlinkingOverdueBanner();

  @override
  State<_BlinkingOverdueBanner> createState() => _BlinkingOverdueBannerState();
}

class _BlinkingOverdueBannerState extends State<_BlinkingOverdueBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          color: primaryRed,
          boxShadow: [BoxShadow(color: primaryRed, blurRadius: 12, spreadRadius: 2)],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              "FOLLOW-UP OVERDUE",
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}
