class ExecutiveStatus {
  final int id;
  final String name;
  final bool isOnline;
  final double totalKm;
  final double currentLat;
  final double currentLng;
  final String lastSeen;
  final String profilePic;
  final int totalCases;
  final int todayVisits;
  final double todayCollection;
  final int todayPtp;
  final int totalPtp;
  final String? punchIn;
  final String? punchOut;
  final String? code;
  final String? department;
  final String? lateBy;
  final String? totalTime;
  final String? status;

  ExecutiveStatus({
    required this.id,
    required this.name,
    required this.isOnline,
    required this.totalKm,
    required this.currentLat,
    required this.currentLng,
    required this.lastSeen,
    required this.profilePic,
    this.totalCases = 0,
    this.todayVisits = 0,
    this.todayCollection = 0.0,
    this.todayPtp = 0,
    this.totalPtp = 0,
    this.punchIn,
    this.punchOut,
    this.code,
    this.department,
    this.lateBy,
    this.totalTime,
    this.status,
  });

  double get allowance => totalKm * 2.5;

  factory ExecutiveStatus.fromJson(Map<String, dynamic> json) {
    String getName() {
      final keys = ['exe_name', 'name', 'username', 'user_name', 'full_name', 'display_name'];
      for (var key in keys) {
        final val = json[key];
        if (val != null && 
            val.toString().toLowerCase() != 'null' && 
            val.toString().trim().isNotEmpty &&
            val.toString().length > 2) {
          return val.toString();
        }
      }
      return 'User';
    }

    return ExecutiveStatus(
      id: _int(json['id']),
      name: getName(),
      isOnline: json['login_status'] == 'login' || 
                json['is_online'] == true ||
                json['is_online'] == 1 || 
                json['status'] == 'active' || 
                json['login_status'] == 1 || 
                json['online_status'] == 1 ||
                json['is_active'] == 1,
      totalKm: _double(json['total_km'] ?? json['distance'] ?? 0.0),
      currentLat: _double(json['lat'] ?? json['latitude'] ?? 0.0),
      currentLng: _double(json['lng'] ?? json['longitude'] ?? 0.0),
      lastSeen: _str(json['last_seen'] ?? json['updated_at'] ?? 'Active Now'),
      profilePic: _str(json['profile_pic'] ?? json['image'] ?? ''),
      totalCases: _int(json['total_cases'] ?? 0),
      todayVisits: _int(json['today_visits'] ?? json['visits_count'] ?? 0),
      todayCollection: _double(json['today_collection'] ?? json['received_amount'] ?? 0.0),
      todayPtp: _int(json['today_ptp'] ?? 0),
      totalPtp: _int(json['total_ptp'] ?? 0),
      punchIn: _str(json['First_in'] ?? json['punch_in'] ?? json['login_time']),
      punchOut: _str(json['Last_out'] ?? json['punch_out'] ?? json['logout_time']),
      code: _str(json['Code']),
      department: _str(json['Department']),
      lateBy: _str(json['Late_by_actual']),
      totalTime: _str(json['Total_time']),
      status: _str(json['Status']),
    );
  }

  static String _str(dynamic v) => v == null ? '' : v.toString();
  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
  static double _double(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v.isNaN ? 0.0 : v;
    if (v is int) return v.toDouble();
    final double? parsed = double.tryParse(v.toString());
    if (parsed == null || parsed.isNaN) return 0.0;
    return parsed;
  }
}
