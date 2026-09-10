import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'collection_api_service.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  static const String baseUrl = 'http://103.207.168.245/safl/api';
  static const String attendanceUrl = 'http://103.207.168.245/safl/api/collection-attendance';

  Future<bool> punchIn() async {
    final now = DateTime.now();
    final punchTime = now.toIso8601String();
    bool serverSuccess = await _postAttendance('punch_in', punchTime);
    if (serverSuccess) await LocationService().startTracking();
    try {
      await LocationService().syncLocationNow(action: 'punch_in');
    } catch (_) {}
    return serverSuccess;
  }

  Future<bool> punchOut() async {
    final now = DateTime.now();
    final punchTime = now.toIso8601String();
    bool serverSuccess = await _postAttendance('punch_out', punchTime);
    await LocationService().stopTracking();
    try {
      await LocationService().syncLocationNow(action: 'punch_out');
    } catch (_) {}
    return serverSuccess;
  }

  Future<bool> _postAttendance(String type, String timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final currentUser = await AuthService.getUserData(forceRefresh: false);
      if (currentUser == null) return false;

      final now = DateTime.now();
      final String timeStr = DateFormat('HH:mm:ss').format(now);
      final String todayDate = DateFormat('yyyy-MM-dd').format(now);
      final raw = currentUser.rawJson;

      String empCode = (currentUser.code ?? "").trim();
      if (empCode.isEmpty || empCode == 'null') empCode = currentUser.email.split('@')[0];

      int? entryId;
      String? existingInTime;
      String? existingZone;
      
      final summary = await getAttendanceSummary(filters: {'Date': todayDate});
      if (summary.isNotEmpty) {
        entryId = int.tryParse(summary['id']?.toString() ?? "");
        existingInTime = summary['punch_in'];
        existingZone = summary['zone'];
      }

      // FETCH CURRENT LOCATION FOR ZONE COLUMN
      String locStr = "";
      try {
        Position? pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
        
        if (pos != null) locStr = "${pos.latitude}, ${pos.longitude}";
      } catch (_) {
        try {
          Position? pos = await Geolocator.getLastKnownPosition();
          if (pos != null) locStr = "${pos.latitude}, ${pos.longitude}";
        } catch (_) {}
      }

      // LOGIC: Use new coordinates for Punch In, preserve existing coordinates for Punch Out
      String zoneToSubmit = (raw['Zone'] ?? raw['zone'] ?? '').toString();
      if (type == 'punch_in') {
        if (locStr.isNotEmpty) zoneToSubmit = locStr;
      } else {
        if (existingZone != null && existingZone.contains(',')) {
          zoneToSubmit = existingZone;
        } else if (locStr.isNotEmpty) {
          zoneToSubmit = locStr;
        }
      }

      // 4. ATTD LOGIC: Dynamic status
      String attdStatus = 'P';
      final int hour = now.hour;
      final int minute = now.minute;
      
      if (type == 'punch_in') {
        if (hour > 11 || (hour == 11 && minute > 30)) {
          attdStatus = 'HD';
        } else if (hour > 9 || (hour == 9 && minute > 15)) {
          attdStatus = 'P/D';
        } else {
          attdStatus = 'P';
        }
      }

      final Map<String, dynamic> body = {
        if (entryId != null) 'id': entryId,
        'user_id': currentUser.id,
        'Date': todayDate,
        'Code': empCode,
        'name': currentUser.name,
        'salary_status': raw['salary_status'] ?? 'Present',
        'Zone': zoneToSubmit,
        'Branch': raw['branch'] ?? currentUser.city,
        'Department': raw['department'] ?? '',
        'Division': raw['division'] ?? '',
        'Day': DateFormat('EEEE').format(now),
        'Day_Desc': DateFormat('EEEE').format(now),
        'Shift_time': raw['shift_time'] ?? '09:30 AM - 06:30 PM',
        'First_in': (type == 'punch_in') ? timeStr : (existingInTime ?? timeStr),
        'Last_out': (type == 'punch_out') ? timeStr : null,
        'intime_outtime': timeStr,
        'Total_time': '00:00',
        'Attd': attdStatus,
        'Status': type == 'punch_in' ? 'Active' : 'Inactive',
        'Head': raw['head'] ?? '',
        'Cluster': raw['cluster'] ?? '',
        'Doj': raw['doj'] ?? '',
        'Actions': 'Mobile App',
      };

      if (type == 'punch_out' && existingInTime != null) {
        try {
          final parts = existingInTime.split(':');
          final startTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
          final diff = now.difference(startTime);
          body['Total_time'] = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}";
          if (diff.inHours >= 8) body['Attd'] = 'P'; else body['Attd'] = 'HD';
        } catch (_) {}
      }

      final response = await http.post(
        Uri.parse(attendanceUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 || response.statusCode == 201) return true;
      if (response.statusCode == 409) return true; 
      return false;
    } catch (e) {
      debugPrint("Attendance POST Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> getAttendanceSummary({Map<String, String>? filters}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final currentUser = await AuthService.getUserData();
      if (currentUser == null || token == null) return {};
      
      // OPTIMIZED FETCH: Default to today if no date filter is provided
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      Map<String, String> f = {'Date': today, 'per_page': '1'}; // Fast check for today only
      if (filters != null) f.addAll(filters);

      final qs = "?" + f.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&");
      final response = await http.get(Uri.parse("$attendanceUrl$qs"), headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List logs = (decoded['data'] is List) ? decoded['data'] : (decoded['data']?['data'] ?? []);

        final String empCode = (currentUser.code ?? "").toLowerCase().trim();
        final String emailPrefix = currentUser.email.split('@')[0].toLowerCase().trim();

        final latest = logs.where((l) {
          final String d = (l['Date'] ?? l['date'] ?? "").toString().split(' ')[0].split('T')[0];
          final String c = (l['Code'] ?? l['code'] ?? "").toString().toLowerCase().trim();
          final String uid = (l['user_id'] ?? "").toString();
          return (d == f['Date']) && (uid == currentUser.id.toString() || c == empCode || c == emailPrefix);
        }).firstOrNull;

        if (latest != null) {
          final summary = {
            'is_punched_in': (latest['Status'] ?? latest['status']).toString().toLowerCase() == 'active',
            'id': latest['id'],
            'punch_in': latest['First_in'] ?? latest['First In'] ?? latest['punch_in'],
            'punch_out': latest['Last_out'] ?? latest['Last Out'] ?? latest['punch_out'],
            'zone': latest['Zone'] ?? latest['zone'],
          };
          CollectionApiService.saveToCache("attendance_summary_${f['Date']}", summary);
          return summary;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> getAttendanceData({Map<String, String>? filters, bool includeTeam = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final currentUser = await AuthService.getUserData();
      if (currentUser == null || token == null) return {};

      Map<String, String> f = {'per_page': '1000'};
      if (filters != null) f.addAll(filters);

      final qs = "?" + f.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&");
      final response = await http.get(Uri.parse("$attendanceUrl$qs"), headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List logs = (decoded['data'] is List) ? decoded['data'] : (decoded['data']?['data'] ?? []);
        final String empCode = (currentUser.code ?? "").toLowerCase().trim();
        final String emailPrefix = currentUser.email.split('@')[0].toLowerCase().trim();
        final String empName = currentUser.name.toLowerCase().trim();

        Set<String> teamNames = {};
        if (includeTeam) {
          final stats = await CollectionApiService.fetchEnhancedDashboardStats();
          final List summaries = stats['executive_summary'] ?? [];
          teamNames = summaries.map((s) => (s['name'] ?? "").toString().toLowerCase().trim()).toSet();
        }

        final mapped = logs.where((l) {
          final String c = (l['Code'] ?? l['code'] ?? "").toString().toLowerCase().trim();
          final String uid = (l['user_id'] ?? "").toString();
          final String n = (l['name'] ?? l['Name'] ?? "").toString().toLowerCase().trim();
          bool isSelf = (uid == currentUser.id.toString() || c == empCode || c == emailPrefix || n == empName);
          if (isSelf) return true;
          if (includeTeam && teamNames.isNotEmpty) return teamNames.contains(n);
          return false;
        }).map((e) => _mapAttendanceFields(e)).toList();

        mapped.sort((a, b) => (b['date'] ?? "").toString().compareTo((a['date'] ?? "").toString()));
        final result = {'data': mapped, 'total': mapped.length};
        CollectionApiService.saveToCache(CollectionApiService.getCacheKey("attendance_data_$includeTeam", filters), result);
        return result;
      }
    } catch (_) {}
    return {};
  }

  Map<String, dynamic> _mapAttendanceFields(dynamic e) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(e);
    m['punch_in'] = m['First_in'] ?? m['First In'] ?? m['punch_in'];
    m['punch_out'] = m['Last_out'] ?? m['Last Out'] ?? m['punch_out'];
    m['date'] = m['Date'] ?? m['date'];
    
    // RULE: Comprehensive Status Detection
    final bool hasIn = (m['punch_in'] != null && m['punch_in'].toString().isNotEmpty && m['punch_in'] != 'null');
    final bool hasOut = (m['punch_out'] != null && m['punch_out'].toString().isNotEmpty && m['punch_out'] != 'null');

    if (!hasIn && !hasOut) {
      m['status'] = "A";
    } else if (hasIn && !hasOut) {
      m['status'] = "MP";
    } else {
      m['status'] = m['Attd'] ?? m['Status'] ?? m['status'] ?? "P";
    }
    
    m['total_time'] = m['Total_time'] ?? m['Total Time'] ?? m['total_time'];
    return m;
  }

  Future<bool> isPunchedIn() async {
    final today = await getAttendanceSummary();
    return today['is_punched_in'] == true;
  }

  Future<dynamic> loadFromCache(String key) async {
    return CollectionApiService.loadFromCache(key);
  }

  Future<Map<String, dynamic>?> loadFromCacheFull(String key) async {
    return CollectionApiService.loadFromCacheFull(key);
  }

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final res = await getAttendanceSummary();
    return res.isNotEmpty ? res : null;
  }
}
