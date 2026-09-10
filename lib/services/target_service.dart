import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/target_model.dart';

class TargetService {
  static const String targetUrl = 'http://103.207.168.245/safl/api/targets';
  static const String targetMastersUrl = 'http://103.207.168.245/safl/api/target-masters';

  static Map<String, dynamic>? _cachedMasters;
  static DateTime? _lastFetch;

  static Future<Map<String, dynamic>?> fetchTargetMasters({bool force = false}) async {
    try {
      if (!force && _cachedMasters != null && _lastFetch != null && DateTime.now().difference(_lastFetch!).inMinutes < 30) {
        return _cachedMasters;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');

      final response = await http.get(
        Uri.parse(targetMastersUrl),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          _cachedMasters = data['data'];
          _lastFetch = DateTime.now();
          
          // Persist to storage
          await prefs.setString('cache_target_masters', jsonEncode({
            'data': _cachedMasters,
            'ts': DateTime.now().toIso8601String(),
          }));
          
          return _cachedMasters;
        }
      }
      
      // Load from persistence if server fails or status is false
      final saved = prefs.getString('cache_target_masters');
      if (saved != null) {
        final decoded = jsonDecode(saved);
        _cachedMasters = decoded['data'];
        return _cachedMasters;
      }
    } catch (e) {
      debugPrint("Target Masters API Error: $e");
      
      // Fallback to local storage on error
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('cache_target_masters');
        if (saved != null) {
          final decoded = jsonDecode(saved);
          return decoded['data'];
        }
      } catch (_) {}
    }
    return _cachedMasters;
  }

  static Future<TargetModel?> fetchTLTarget() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockTarget("Team Leader");
  }

  static Future<TargetModel?> fetchACMTarget() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockTarget("ACM");
  }

  static TargetModel _getMockTarget(String role) {
    if (role == "Team Leader") {
      return TargetModel(
        title: "TL Monthly Target",
        targetAmount: 2500000,
        achievedAmount: 1800000,
        totalCases: 800,
        visitedCases: 550,
        month: "July 2024",
      );
    } else if (role == "ACM") {
      return TargetModel(
        title: "ACM Monthly Target",
        targetAmount: 10000000,
        achievedAmount: 7500000,
        totalCases: 3000,
        visitedCases: 2100,
        month: "July 2024",
      );
    }
    return TargetModel(
      title: "Executive Monthly Target",
      targetAmount: 500000,
      achievedAmount: 325000,
      totalCases: 150,
      visitedCases: 95,
      month: "July 2024",
    );
  }
}
