
import 'package:intl/intl.dart';

class CaseActivity {
  final String title;
  final String description;
  final DateTime dateTime;
  final double? amount;
  final String? photo;
  final String? location;
  final DateTime? followUpDate;

  CaseActivity({
    required this.title,
    required this.description,
    DateTime? dateTime,
    this.amount,
    this.photo,
    this.location,
    this.followUpDate,
  }) : dateTime = dateTime ?? DateTime.now();
}

class CustomerCase {
  final int id;

  String customer;
  String mobile;
  String city;
  String address;
  String vehicleNo;
  String loanNo;
  String type;
  String status;

  double dueAmount;
  double collectedAmount;
  double emiAmount;
  double pos;
  double overdue;
  double posAch;

  int emiDue;
  int bucket;
  String bucketName;
  int lateByDay;
  String remarks;
  DateTime? ptpDate;
  
  String executive;
  String acm;
  String dma;
  String tl;
  String salesExecutive;
  String tcName;
  String dealer;
  String emiDate;
  String fiExecutive;

  final List<CaseActivity> activities;
  final Map<String, dynamic> rawJson;

  CustomerCase({
    required this.id,
    required this.customer,
    required this.mobile,
    required this.city,
    required this.address,
    required this.vehicleNo,
    required this.loanNo,
    required this.type,
    required this.status,
    required this.dueAmount,
    this.collectedAmount = 0.0,
    this.emiAmount = 0.0,
    this.pos = 0.0,
    this.overdue = 0.0,
    this.posAch = 0.0,
    required this.emiDue,
    this.bucket = 0,
    this.bucketName = '',
    this.lateByDay = 0,
    this.remarks = '',
    this.ptpDate,
    this.executive = '',
    this.acm = '',
    this.dma = '',
    this.tl = '',
    this.salesExecutive = '',
    this.tcName = '',
    this.dealer = '',
    this.emiDate = '',
    this.fiExecutive = '',
    List<CaseActivity>? activities,
    this.rawJson = const {},
  }) : activities = activities ?? [];

  String? get latestVisitPhoto {
    if (activities.isEmpty) return null;
    try {
      final withPhoto = activities.where((a) => a.photo != null && a.photo!.isNotEmpty).toList();
      if (withPhoto.isNotEmpty) {
        return withPhoto.first.photo;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  double get pendingAmount {
    final pending = dueAmount - collectedAmount;
    return pending < 0 ? 0 : pending;
  }

  DateTime? get latestVisitDate {
    if (activities.isNotEmpty) return activities.first.dateTime;
    final String? dateStr = rawJson['last_visit_date'] ?? 
                           rawJson['today_entry_date'] ?? 
                           rawJson['visit_date'] ?? 
                           rawJson['last_visit'];
    if (dateStr != null && dateStr.isNotEmpty && dateStr != 'null') {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  DateTime? get upcomingFollowUpDate {
    if (ptpDate != null) return ptpDate;
    if (activities.isNotEmpty) {
       final withFup = activities.where((a) => a.followUpDate != null).toList();
       if (withFup.isNotEmpty) return withFup.first.followUpDate;
    }
    final String? dateStr = rawJson['projection_date'] ?? 
                           rawJson['ptp_date'] ?? 
                           rawJson['follow_up'] ?? 
                           rawJson['next_ptp_date'] ??
                           rawJson['next_ptp'];
    if (dateStr != null && dateStr.isNotEmpty && dateStr != 'null') {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  void addActivity({
    required String title,
    required String description,
    double? amount,
    String? photo,
    String? location,
    DateTime? followUpDate,
  }) {
    activities.add(
      CaseActivity(
        title: title,
        description: description,
        amount: amount,
        photo: photo,
        location: location,
        followUpDate: followUpDate,
      ),
    );
    // Keep latest first
    activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  factory CustomerCase.fromJson(Map<String, dynamic> json) {
    final List<CaseActivity> activities = [];
    
    // Check multiple possible keys for visit history
    final visits = json['all_visits'] ?? json['visits'] ?? json['visit_history'] ?? json['allVisits'];
    
    if (visits is List) {
      for (var v in visits) {
        final map = Map<String, dynamic>.from(v);
        
        // Extract location intelligently from many possible keys
        String loc = _str(map['visit_address'] ?? map['location'] ?? map['address'] ?? map['sync_address'] ?? map['lat_lng'] ?? map['coordinates']);
        if (loc.isEmpty || loc == '0,0' || loc == '0.0,0.0' || loc == 'null,null') {
          final lat = map['latitude'] ?? map['lat'] ?? map['visit_lat'] ?? map['latitude_actual'];
          final lng = map['longitude'] ?? map['lng'] ?? map['visit_long'] ?? map['visit_lng'] ?? map['longitude_actual'];
          if (lat != null && lng != null) {
            loc = "$lat,$lng";
          }
        }

        activities.add(CaseActivity(
          title: _str(map['subject']).toUpperCase(),
          description: _str(map['remark'] ?? map['remarks'] ?? map['visit_remark']),
          dateTime: _date(map['created_at']) ?? DateTime.now(),
          amount: _double(map['payment_rec'] ?? map['amount']),
          photo: _str(map['visit_image'] ?? map['visit_photo'] ?? map['photo']),
          location: loc,
          followUpDate: _date(map['projection_date'] ?? map['ptp_date'] ?? map['follow_up_date']),
        ));
      }
      // Sort activities by date descending (latest first)
      activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }

    return CustomerCase(
      id: _int(json['id']),
      customer: _str(json['name'] ?? json['customer_name'] ?? json['cust_name']),
      mobile: _str(json['mobile']),
      city: _str(json['district'] ?? json['branch'] ?? json['city']),
      address: _str(json['address']),
      vehicleNo: _str(json['veh_no'] ?? json['vehicle_no']),
      loanNo: _str(json['case_no'] ?? json['loan_no']),
      type: _str(json['Product'] ?? json['product'] ?? json['case_category'] ?? json['casetype'] ?? json['type']),
      status: _str(json['status']).isEmpty ? 'Pending' : _str(json['status']),
      dueAmount: _double(json['overdue'] ?? json['due_amount']),
      collectedAmount: _double(json['cash_rec'] ?? json['collected_amount'] ?? json['payment_rec']),
      emiAmount: _double(json['current_emi'] ?? json['current_emi_amt'] ?? json['emi_amount'] ?? json['emi']),
      pos: _double(json['pos'] ?? json['principal_outstanding'] ?? json['outstanding']),
      posAch: _double(json['pos_ach'] ?? json['pos_achieve'] ?? json['pos Ach.']),
      overdue: _double(json['overdue_amount'] ?? json['total_overdue']),
      emiDue: _int(json['current_emi'] ?? json['emi_due'] ?? json['emi_count']),
      bucket: _int(json['bucket'] ?? json['bkt'] ?? 0),
      bucketName: _str(json['BKT.'] ?? json['bkt'] ?? json['bucket']).trim(),
      lateByDay: _int(json['late_by_day'] ?? json['dpd'] ?? json['days_late'] ?? 0),
      remarks: _str(json['remark'] ?? json['remarks']),
      ptpDate: _date(json['follow_up'] ?? json['ptp_date']),
      executive: _str(json['exe_name'] ?? json['executive'] ?? json['executive_name']),
      acm: _str(json['acm'] ?? json['acm_name']),
      dma: _str(json['dma'] ?? json['dma_name']),
      tl: _str(json['tl'] ?? json['tl_name']),
      salesExecutive: _str(json['sales_executive'] ?? json['sales_exe']),
      tcName: _str(json['tc_name']),
      dealer: _str(json['dealer'] ?? json['dealer_name']),
      emiDate: _str(json['curremi_dt'] ?? json['emi_date'] ?? json['last_emi_date']),
      fiExecutive: _str(json['fi_executive'] ?? json['fi_exe']),
      activities: activities,
      rawJson: json,
    );
  }

  static String _str(dynamic v) {
    if (v == null || v == 'null') return '';
    String s = v.toString();
    // Format ISO dates if detected
    if (s.length > 10 && s.contains('T') && s.endsWith('Z')) {
      try {
        final dt = DateTime.parse(s).toLocal();
        return DateFormat('dd-MM-yyyy').format(dt);
      } catch (_) {}
    }
    return s;
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _double(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  static DateTime? _date(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    return DateTime.tryParse(v.toString());
  }
}
